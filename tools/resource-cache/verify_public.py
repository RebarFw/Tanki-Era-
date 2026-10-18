"""Unauthenticated download and SHA256 verification of published release assets."""
import argparse,concurrent.futures,hashlib,json,pathlib,time,urllib.request,urllib.parse
from refresh import atomic

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--publication',required=True,type=pathlib.Path)
    parser.add_argument('--only-new',action='store_true');args=parser.parse_args()
    report=json.loads(args.publication.read_bytes());receipt=args.publication.parent/'public-download-verification.json'
    previous=json.loads(receipt.read_bytes()).get('assets',{})if receipt.exists()and args.only_new else{}
    rows=report['assets'];results={}
    def verify(item):
        digest,row=item
        if digest in previous and previous[digest].get('size')==row['size']:return digest,previous[digest]
        for attempt in range(3):
            try:
                request=urllib.request.Request(row['browser_download_url'],headers={'User-Agent':'TankiEra-Cache-Verification','Cache-Control':'no-cache'})
                h=hashlib.sha256();count=0;started=time.monotonic()
                with urllib.request.urlopen(request,timeout=90)as response:
                    assert response.status==200
                    final=response.geturl()
                    assert urllib.parse.urlparse(final).scheme=='https'
                    for chunk in iter(lambda:response.read(256*1024),b''):h.update(chunk);count+=len(chunk)
                assert count==row['size']and h.hexdigest()==digest
                return digest,dict(size=count,sha256=digest,seconds=time.monotonic()-started,redirect_host=urllib.parse.urlparse(final).hostname)
            except Exception:
                if attempt==2:raise
                time.sleep(2*(attempt+1))
    with concurrent.futures.ThreadPoolExecutor(max_workers=4)as executor:
        for index,(digest,result)in enumerate(executor.map(verify,rows.items()),1):
            results[digest]=result
            if index%20==0 or index==len(rows):print('PUBLIC_DOWNLOAD_VERIFIED '+str(index)+'/'+str(len(rows)),flush=True)
    base='https://github.com/RebarFw/Tanki-Era-/releases/download/'+report['release_tag']+'/'
    with urllib.request.urlopen(base+report['manifest_asset_name'],timeout=30)as response:manifest=response.read()
    assert hashlib.sha256(manifest).hexdigest()==report['manifest_sha256']
    with urllib.request.urlopen(base+report['manifest_asset_name'].replace('.json','.sha256'),timeout=30)as response:checksum=response.read().decode().strip()
    assert checksum==report['manifest_sha256']
    atomic(receipt,json.dumps(dict(passed=True,packages=len(results),bytes=sum(r['size']for r in results.values()),assets=results,
        public_manifest_sha256=report['manifest_sha256'],public_checksum_verified=True),indent=2).encode())

if __name__=='__main__':main()
