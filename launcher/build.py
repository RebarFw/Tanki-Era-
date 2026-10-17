"""Build the source-visible AIR updater using a trusted local AIR SDK.

No downloaded executables are run. Vendor files are copied from the existing
public release only after matching the fixed SHA-256 allowlist.
"""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,zipfile

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk',type=Path,required=True)
    parser.add_argument('--java',default='java')
    parser.add_argument('--base-zip',type=Path,required=True)
    parser.add_argument('--output',type=Path,default=Path('out'))
    args=parser.parse_args();here=Path(__file__).resolve().parent
    package=args.output.resolve()/'Tanki Era';package.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((here/'vendor-manifest.json').read_text())
    with zipfile.ZipFile(args.base_zip) as archive:
        for name,expected in manifest.items():
            raw=archive.read('Tanki Era/'+name)
            if hashlib.sha256(raw).hexdigest()!=expected:
                raise ValueError('Vendor file failed verification: '+name)
            target=package/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
    for name in ['application.xml','META-INF/AIR/application.xml']:
        target=package/name;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(here/'application.xml',target)
    minimal=args.output.resolve()/'minimal.xml';minimal.write_text('<flex-config/>')
    excluded={'guava-r08.jar','guava-compiler.jar','commons-io-2.0.1.jar','commons-io-2.11.0.jar'}
    jars=[args.sdk/'lib/guava-compiler.jar',args.sdk/'lib/commons-io-2.11.0.jar']+[p for p in (args.sdk/'lib').glob('*.jar')if p.name not in excluded]
    if not jars or any(not p.is_file()for p in jars):
        raise ValueError('AIR SDK compiler dependencies are missing; see launcher/README.md')
    command=[args.java,'-cp',os.pathsep.join(str(p)for p in jars),'com.adobe.flash.compiler.clients.MXMLC',
        '-load-config='+str(minimal),'-source-path='+str(here/'src'),'-target-player=11.3','-swf-version=19',
        '-external-library-path='+str(args.sdk/'frameworks/libs/air/airglobal.swc'),
        '-output='+str(package/'TankiEraLauncher.swf'),str(here/'src/TankiEraLauncher.as')]
    subprocess.run(command,check=True)
    allowed=set(manifest)|{'application.xml','META-INF/AIR/application.xml','TankiEraLauncher.swf'}
    actual={p.relative_to(package).as_posix()for p in package.rglob('*')if p.is_file()}
    if actual!=allowed:raise ValueError('Unexpected files in output; use a new empty output directory')
    output=args.output.resolve()/'Tanki era.zip'
    with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=9)as archive:
        for name in sorted(allowed):
            item=zipfile.ZipInfo('Tanki Era/'+name,(2026,10,17,0,0,0))
            item.compress_type=zipfile.ZIP_DEFLATED;item.external_attr=0o644<<16
            archive.writestr(item,(package/name).read_bytes(),compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
    print('ZIP SHA256:',hashlib.sha256(output.read_bytes()).hexdigest())

if __name__=='__main__':main()
