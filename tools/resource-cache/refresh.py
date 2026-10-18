"""Rebuild only cache buckets whose registered public resource bytes changed."""
from __future__ import annotations
import hashlib,json,os,pathlib,struct,uuid
from publish import canonical,sha,validate_cache

EXTENSIONS={'jpg','jpeg','xml','3ds','tara','swf','png','tnk','json','mp3'}

def atomic(path,data):
    path=pathlib.Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    temporary=path.with_name(path.name+'.'+uuid.uuid4().hex+'.tmp')
    try:temporary.write_bytes(data);os.replace(temporary,path)
    finally:
        if temporary.exists():temporary.unlink()

def snapshot(root,payload):
    root=pathlib.Path(root);digest=hashlib.sha256(payload).hexdigest()
    target=root/('manifest-'+digest+'.json')
    if target.exists():assert target.read_bytes()==payload,'Immutable manifest changed'
    else:atomic(target,payload)
    return digest

def refresh(cache_root,static_root):
    cache_root=pathlib.Path(cache_root);static_root=pathlib.Path(static_root).resolve()
    manifest=json.loads((cache_root/'manifest.json').read_bytes());original_manifest=canonical(manifest);changed=[]
    for package_name,package in manifest['packages'].items():
        old=(cache_root/package['path']).read_bytes();assert hashlib.sha256(old).hexdigest()==package['sha256']
        header_length=struct.unpack('>I',old[5:9])[0];index=json.loads(old[9:9+header_length]);body=old[9+header_length:]
        content={row['path']:body[row['offset']:row['offset']+row['size']]for row in index['files']}
        original=dict(content)
        for key in package['resources']:
            resource=manifest['resources'].get(key)
            if resource is None or resource['package']!=package_name:continue
            files=resource['files'];before=canonical(files)
            parents={pathlib.PurePosixPath(meta['path']).parent for meta in files.values()}
            assert len(parents)==1,'Resource spans directories: '+key
            parent=next(iter(parents));directory=(static_root/str(parent)).resolve()
            directory.relative_to(static_root)
            if directory.is_dir():
                for path in sorted(directory.iterdir()):
                    if not path.is_file()or path.name.startswith('.')or path.suffix.lower().lstrip('.')not in EXTENSIONS:continue
                    path.resolve().relative_to(static_root)
                    relative=(parent/path.name).as_posix();data=path.read_bytes();digest=hashlib.sha256(data).hexdigest()
                    files[path.name]=dict(path=relative,sha256=digest,size=len(data));content[relative]=data
            # Missing source files remain recoverable from their already-verified
            # package. Removing a registered resource requires an explicit index edit.
            for meta in files.values():assert meta['path']in content and hashlib.sha256(content[meta['path']]).hexdigest()==meta['sha256']
            if canonical(files)!=before:resource['revision']=hashlib.sha256(canonical(files)).hexdigest()
        if content==original:continue
        rows=[];payload=bytearray()
        for path,data in content.items():
            rows.append(dict(path=path,sha256=hashlib.sha256(data).hexdigest(),size=len(data),offset=len(payload)));payload.extend(data)
        header=canonical(dict(files=rows,format=1));binary=b'TEPK\x01'+struct.pack('>I',len(header))+header+payload
        digest=hashlib.sha256(binary).hexdigest();relative='packages/'+digest+'.tpk'
        atomic(cache_root/relative,binary)
        package.update(path=relative,sha256=digest,size=len(binary),version=digest);package.pop('url',None)
        changed.append(package_name)
    if changed or canonical(manifest)!=original_manifest:
        manifest['version']=hashlib.sha256(canonical({k:v for k,v in manifest.items()if k!='version'})).hexdigest()
        payload=canonical(manifest);atomic(cache_root/'manifest.json',payload);atomic(cache_root/'manifest.sha256',(hashlib.sha256(payload).hexdigest()+'\n').encode())
    validate_cache(cache_root)
    return changed

def activate(source_root,runtime_root,candidate):
    source_root=pathlib.Path(source_root);runtime_root=pathlib.Path(runtime_root);candidate=pathlib.Path(candidate)
    payload=(candidate/'manifest.json').read_bytes();manifest=json.loads(payload);digest=hashlib.sha256(payload).hexdigest()
    assert (candidate/'manifest.sha256').read_text().strip()==digest
    # Content is installed before either active pointer moves. Older snapshots
    # and bundle names are retained so in-flight/reconnecting clients stay valid.
    for root in [source_root,runtime_root]:
        root.mkdir(parents=True,exist_ok=True)
        snapshot(root,payload)
        for package in manifest['packages'].values():
            target=root/package['path'];source=source_root/package['path']
            if target.resolve()!=source.resolve()and (not target.exists()or sha(target)!=package['sha256']):atomic(target,source.read_bytes())
        atomic(root/'manifest.json',payload)
        atomic(root/'manifest.sha256',(digest+'\n').encode())
    for root in [source_root,runtime_root]:atomic(root/'active-release.sha256',(digest+'\n').encode())
    return digest
