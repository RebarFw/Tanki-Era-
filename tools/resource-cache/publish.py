"""Publish verified content-addressed Tanki cache bundles to GitHub Releases.

Only public cache assets are accepted. Credentials stay in memory and are never
written to a manifest, receipt, command argument, or client file.
"""
from __future__ import annotations
import argparse, concurrent.futures, hashlib, http.client, json, os, pathlib
import re, struct, subprocess, threading, time, urllib.error, urllib.parse, urllib.request

REPOSITORY = 'RebarFw/Tanki-Era-'
API = 'https://api.github.com/repos/' + REPOSITORY
HASH = re.compile(r'^[0-9a-f]{64}$')

def canonical(value):
    return json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=True).encode()

def sha(path):
    h=hashlib.sha256()
    with pathlib.Path(path).open('rb') as stream:
        for data in iter(lambda:stream.read(1024*1024),b''):h.update(data)
    return h.hexdigest()

def validate_cache(root):
    root=pathlib.Path(root).resolve()
    manifest=json.loads((root/'manifest.json').read_bytes())
    assert manifest['format']==1 and isinstance(manifest['cacheVersionBump'],int)
    packages=manifest['packages'];resources=manifest['resources']
    assert packages and resources
    covered={};total=files=historical_records=0
    for name,entry in sorted(packages.items()):
        digest=entry['sha256'];assert HASH.fullmatch(digest),name
        relative='packages/'+digest+'.tpk'
        assert entry['path']==relative,'Unexpected cache path: '+name
        path=root/relative;assert path.is_file() and path.stat().st_size==entry['size'],name
        assert sha(path)==digest,'Package checksum mismatch: '+name
        with path.open('rb') as stream:
            assert stream.read(5)==b'TEPK\x01',name
            length=struct.unpack('>I',stream.read(4))[0]
            assert 0<length<=min(entry['size']-9,16*1024*1024),name
            index=json.loads(stream.read(length));assert index['format']==1
            offset=9+length;rows={}
            for row in index['files']:
                file_path=row['path'];parts=pathlib.PurePosixPath(file_path).parts
                assert parts and not file_path.startswith('/') and not any(p in ('.','..')for p in parts)
                assert '\\' not in file_path and ':' not in file_path
                assert file_path not in rows and HASH.fullmatch(row['sha256'])
                assert isinstance(row['offset'],int) and row['offset']>=0 and row['size']>=0
                assert offset+row['offset']+row['size']<=entry['size']
                stream.seek(offset+row['offset']);data=stream.read(row['size'])
                assert hashlib.sha256(data).hexdigest()==row['sha256'],file_path
                rows[file_path]=row;files+=1
        for key in entry['resources']:
            # Old buckets can retain an immutable file after a resource moves
            # to a newer package. The authoritative resource table owns routing.
            if key not in resources or resources[key]['package']!=name:
                historical_records+=1
                continue
            resource=resources[key]
            assert key==str(resource['id'])+':'+str(resource['version']),key
            for filename,meta in resource['files'].items():
                row=rows[meta['path']]
                assert row['size']==meta['size'] and row['sha256']==meta['sha256'],key+'/'+filename
            assert key not in covered,key
            covered[key]=name
        total+=entry['size']
    assert set(covered)==set(resources),'Resource index has uncovered entries'
    for key in manifest['common']:assert key in covered,key
    for map_name,info in manifest['maps'].items():
        for key in info['resources']:assert key in covered,map_name+':'+key
    return manifest,dict(packages=len(packages),resources=len(resources),verified_file_records=files,
        bytes=total,common_resources=len(manifest['common']),maps=len(manifest['maps']),
        historical_package_records=historical_records,all_required_resources_covered=True)

class GitHub:
    def __init__(self,token=None,upload_bytes_per_second=2*1024*1024):
        if token is None:
            token=os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')
        if not token:
            result=subprocess.run(['git','credential','fill'],input='protocol=https\nhost=github.com\npath='+REPOSITORY+'.git\n\n',
                capture_output=True,text=True,env=dict(os.environ,GIT_TERMINAL_PROMPT='0'),timeout=30)
            fields=dict(line.split('=',1)for line in result.stdout.splitlines()if '='in line)
            token=fields.get('password')
        if not token:raise RuntimeError('GitHub repository write credentials are required')
        self.token=token;self.lock=threading.Lock();self.next_mutation=0.;self.next_byte_time=0.
        self.upload_rate=upload_bytes_per_second

    def pace_mutation(self):
        with self.lock:
            now=time.monotonic();delay=max(0,self.next_mutation-now)
            self.next_mutation=max(now,self.next_mutation)+.95
        if delay:time.sleep(delay)

    def request(self,path,method='GET',body=None):
        if method!='GET':self.pace_mutation()
        url=path if path.startswith('https://') else API+path
        assert url.startswith(API+'/') or url==API
        headers={'Authorization':'Bearer '+self.token,'Accept':'application/vnd.github+json',
            'User-Agent':'TankiEra-ResourceCache','X-GitHub-Api-Version':'2022-11-28'}
        payload=None if body is None else canonical(body)
        if payload is not None:headers['Content-Type']='application/json'
        request=urllib.request.Request(url,data=payload,headers=headers,method=method)
        with urllib.request.urlopen(request,timeout=60)as response:return json.load(response)

    def assets(self,release_id):
        result=[];page=1
        while True:
            rows=self.request('/releases/'+str(release_id)+'/assets?per_page=100&page='+str(page));result+=rows
            if len(rows)<100:return result
            page+=1

    def release(self,tag):
        try:return self.request('/releases/tags/'+urllib.parse.quote(tag,safe=''))
        except urllib.error.HTTPError as error:
            if error.code!=404:raise
        return self.request('/releases','POST',dict(tag_name=tag,target_commitish='main',name='Tanki Era resource cache '+tag,
            body='Content-addressed public game resource bundles. These files do not switch the public client or contain account data.',
            draft=False,prerelease=True,make_latest='false'))

    def upload(self,release_id,path):
        path=pathlib.Path(path);digest=sha(path);size=path.stat().st_size
        self.pace_mutation()
        connection=http.client.HTTPSConnection('uploads.github.com',timeout=90)
        try:
            route='/repos/'+REPOSITORY+'/releases/'+str(release_id)+'/assets?name='+urllib.parse.quote(path.name)
            connection.putrequest('POST',route)
            for k,v in {'Authorization':'Bearer '+self.token,'User-Agent':'TankiEra-ResourceCache',
                'Accept':'application/vnd.github+json','Content-Type':'application/octet-stream','Content-Length':str(size)}.items():connection.putheader(k,v)
            connection.endheaders()
            with path.open('rb')as stream:
                for chunk in iter(lambda:stream.read(64*1024),b''):
                    if self.upload_rate:
                        with self.lock:
                            now=time.monotonic();delay=max(0,self.next_byte_time-now)
                            self.next_byte_time=max(now,self.next_byte_time)+len(chunk)/self.upload_rate
                        if delay:time.sleep(delay)
                    connection.send(chunk)
            response=connection.getresponse();raw=response.read()
            if response.status!=201:raise RuntimeError('GitHub upload failed HTTP '+str(response.status)+' '+raw.decode(errors='replace')[:300])
            row=json.loads(raw)
            assert row['size']==size and row['state']=='uploaded'
            if row.get('digest'):assert row['digest']=='sha256:'+digest,'GitHub asset digest mismatch'
            return row
        finally:connection.close()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache-root',required=True,type=pathlib.Path)
    parser.add_argument('--output',required=True,type=pathlib.Path)
    parser.add_argument('--publish',action='store_true')
    args=parser.parse_args();root=args.cache_root.resolve();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    manifest,coverage=validate_cache(root)
    (out/'coverage.json').write_bytes(canonical(coverage)+b'\n')
    print('CACHE_COVERAGE '+json.dumps(coverage),flush=True)
    if not args.publish:return
    github=GitHub();catalog={};releases=[];page=1
    while True:
        rows=github.request('/releases?per_page=100&page='+str(page));releases+=rows
        if len(rows)<100:break
        page+=1
    for release in releases:
        if re.fullmatch(r'resource-cache-v\d+',release['tag_name']):
            for asset in github.assets(release['id']):
                if re.fullmatch(r'[0-9a-f]{64}\.tpk',asset['name']) and asset['state']=='uploaded':
                    digest=asset['name'][:-4]
                    if asset.get('digest'):assert asset['digest']=='sha256:'+digest
                    catalog[digest]=asset
    wanted={p['sha256']:root/p['path']for p in manifest['packages'].values()}
    pending={k:p for k,p in wanted.items()if k not in catalog}
    print('RELEASE_UPLOAD_PLAN missing='+str(len(pending))+' reusable='+str(len(wanted)-len(pending)),flush=True)
    number=max([int(r['tag_name'].rsplit('v',1)[1])for r in releases if re.fullmatch(r'resource-cache-v\d+',r['tag_name'])]+[1])
    release=github.release('resource-cache-v'+str(number))
    if len(github.assets(release['id']))+len(pending)+3>950:
        number+=1;release=github.release('resource-cache-v'+str(number))
    uploaded=0
    def upload(item):
        digest,path=item
        for attempt in range(3):
            try:return digest,github.upload(release['id'],path)
            except Exception:
                # Reconcile a possibly accepted request instead of overwriting a hash name.
                found=next((a for a in github.assets(release['id'])if a['name']==path.name and a['state']=='uploaded'),None)
                if found:
                    assert found['size']==path.stat().st_size and found.get('digest')=='sha256:'+digest
                    return digest,found
                if attempt==2:raise
                time.sleep(3*(attempt+1))
    with concurrent.futures.ThreadPoolExecutor(max_workers=2)as executor:
        for digest,row in executor.map(upload,pending.items()):
            catalog[digest]=row;uploaded+=1
            if uploaded%10==0 or uploaded==len(pending):print('RELEASE_UPLOAD_PROGRESS '+str(uploaded)+'/'+str(len(pending)),flush=True)
    candidate=json.loads(json.dumps(manifest))
    for name,p in candidate['packages'].items():
        row=catalog[p['sha256']]
        assert row['size']==p['size']
        p['url']=row['browser_download_url']
        assert p['url'].startswith('https://github.com/'+REPOSITORY+'/releases/download/resource-cache-v')
    candidate['transport']={'format':1,'primary':'github-releases','mode':'github-only','fallback':None}
    candidate['version']=hashlib.sha256(canonical({k:v for k,v in candidate.items()if k!='version'})).hexdigest()
    payload=canonical(candidate);digest=hashlib.sha256(payload).hexdigest()
    manifest_file=out/('manifest-'+digest+'.json');manifest_file.write_bytes(payload)
    checksum_file=out/('manifest-'+digest+'.sha256');checksum_file.write_text(digest+'\n')
    existing={a['name']:a for a in github.assets(release['id'])}
    for path in [manifest_file,checksum_file]:
        if path.name not in existing:github.upload(release['id'],path)
        else:assert existing[path.name].get('digest')=='sha256:'+sha(path)
    (out/'manifest.json').write_bytes(payload);(out/'manifest.sha256').write_text(digest+'\n')
    result=dict(coverage=coverage,uploaded_bundles=uploaded,reused_bundles=len(wanted)-uploaded,
        manifest_sha256=digest,manifest_asset_name=manifest_file.name,
        manifest_download_url='https://github.com/'+REPOSITORY+'/releases/download/'+release['tag_name']+'/'+manifest_file.name,
        release_url=release['html_url'],
        release_tag=release['tag_name'],assets={k:{n:v for n,v in row.items()if n in ['id','name','size','digest','browser_download_url']}for k,row in catalog.items()if k in wanted},
        public_players_switched=False)
    (out/'publication.json').write_bytes(canonical(result)+b'\n')
    print('RESOURCE_CACHE_RELEASE_READY '+release['html_url']+' manifest_sha256='+digest,flush=True)

if __name__=='__main__':main()
