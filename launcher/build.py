"""Rebuild the portable AIR client from the source and a byte-verified base ZIP.
Requires Python, Java and a trusted local AIR/Flex compiler SDK. Never runs
executables from the ZIP and never changes antivirus or certificate trust.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,os,zipfile,shutil
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--sdk',type=Path,required=True);p.add_argument('--java',default='java');p.add_argument('--base-zip',type=Path,required=True);p.add_argument('--output',type=Path,default=Path('out'));args=p.parse_args()
 here=Path(__file__).resolve().parent;sdk=args.sdk.resolve();output=args.output.resolve();package=output/'Tanki Era';package.mkdir(parents=True,exist_ok=True)
 vendor=json.loads((here/'vendor-manifest.json').read_text())
 with zipfile.ZipFile(args.base_zip)as z:
  for name,digest in vendor.items():
   raw=z.read('Tanki Era/'+name)
   if hashlib.sha256(raw).hexdigest()!=digest:raise ValueError('Vendor hash mismatch: '+name)
   target=package/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
 source=output/'source';shutil.copytree(here/'src',source,dirs_exist_ok=True);shutil.copytree(here/'art',output/'art',dirs_exist_ok=True)
 minimal=output/'minimal.xml';minimal.write_text('<flex-config/>')
 excluded={'guava-r08.jar','guava-compiler.jar','commons-io-2.0.1.jar','commons-io-2.11.0.jar'}
 jars=[sdk/'lib/guava-compiler.jar',sdk/'lib/commons-io-2.11.0.jar']+[x for x in(sdk/'lib').glob('*.jar')if x.name not in excluded]
 if any(not x.exists()for x in jars):raise ValueError('Compiler SDK dependencies missing; see README')
 def compile(name):
  target=package/('META-INF/AIR/'+name+'.swf')
  subprocess.run([args.java,'-cp',os.pathsep.join(map(str,jars)),'com.adobe.flash.compiler.clients.MXMLC','-load-config='+str(minimal),'-source-path='+str(source),'-target-player=11.3','-swf-version=19','-external-library-path='+str(sdk/'frameworks/libs/air/airglobal.swc'),'-output='+str(target),str(source/(name+'.as'))],check=True)
 compile('GameEntry');vendor['META-INF/AIR/GameEntry.swf']=hashlib.sha256((package/'META-INF/AIR/GameEntry.swf').read_bytes()).hexdigest()
 fingerprint=hashlib.sha256(json.dumps(vendor,sort_keys=True,separators=(',',':')).encode()).hexdigest()
 (source/'tanki/updater/RuntimeManifest.as').write_text('package tanki.updater {public final class RuntimeManifest {public static const FINGERPRINT:String='+json.dumps(fingerprint)+';public static const HASHES:Object='+json.dumps(vendor,sort_keys=True)+';public static const GAME_DESCRIPTOR:String='+json.dumps((here/'game-descriptor.xml').read_text())+';}}')
 compile('TankiEraLauncher');shutil.copy2(here/'application.xml',package/'META-INF/AIR/application.xml')
 allowed=set(vendor)|{'META-INF/AIR/application.xml','META-INF/AIR/TankiEraLauncher.swf'}
 if {f.relative_to(package).as_posix()for f in package.rglob('*')if f.is_file()}!=allowed:raise ValueError('Unexpected output files; use an empty output directory')
 with zipfile.ZipFile(output/'Tanki era.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9)as z:
  for name in sorted(allowed):
   item=zipfile.ZipInfo('Tanki Era/'+name,(2026,10,17,0,0,0));item.compress_type=zipfile.ZIP_DEFLATED;item.external_attr=0o644<<16;z.writestr(item,(package/name).read_bytes(),compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
 print('ZIP SHA256:',hashlib.sha256((output/'Tanki era.zip').read_bytes()).hexdigest())
if __name__=='__main__':main()
