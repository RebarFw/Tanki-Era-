"""Rebuild the v1.2-based client using an original v1.2 folder and trusted tools."""
from pathlib import Path
import argparse,subprocess,shutil,os,zipfile
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--template',type=Path,required=True);parser.add_argument('--ffdec',type=Path,required=True);parser.add_argument('--sdk',type=Path,required=True);parser.add_argument('--java',default='java');parser.add_argument('--output',type=Path,default=Path('out'));args=parser.parse_args()
 here=Path(__file__).resolve().parent;template=args.template.resolve();output=args.output.resolve();package=output/'Tanki Era'
 if package.exists():raise ValueError('Use a fresh output directory')
 shutil.copytree(template,package)
 subprocess.run([args.java,'-Dfile.encoding=UTF-8','-Xmx1200M','-jar',str(args.ffdec.resolve()),'-air','-replace',str(template/'Prelauncher.swf'),str(package/'Prelauncher.swf'),'protanki.launcher.Prelauncher',str(here/'source/Prelauncher.as'),'protanki.launcher.controls.bottompanel.PartnerLogo.PartnerLogo',str(here/'source/PartnerLogo.as'),'protanki.launcher.controls.toppanel.TopPanelButton',str(here/'source/TopPanelButton.as')],check=True)
 shutil.copy2(here/'application.xml',package/'META-INF/AIR/application.xml')
 stale=package/'META-INF/AIR/hash'
 if stale.exists():stale.unlink()
 sdk=args.sdk.resolve();minimal=output/'minimal.xml';minimal.write_text('<flex-config/>')
 excluded={'guava-r08.jar','guava-compiler.jar','commons-io-2.0.1.jar','commons-io-2.11.0.jar'}
 jars=[sdk/'lib/guava-compiler.jar',sdk/'lib/commons-io-2.11.0.jar']+[p for p in(sdk/'lib').glob('*.jar')if p.name not in excluded]
 subprocess.run([args.java,'-cp',os.pathsep.join(map(str,jars)),'com.adobe.flash.compiler.clients.MXMLC','-load-config='+str(minimal),'-target-player=11.3','-swf-version=19','-external-library-path='+str(sdk/'frameworks/libs/air/airglobal.swc'),'-output='+str(package/'ClanAddon.swf'),str(here/'source/ClanAddonStream.as')],check=True)
 with zipfile.ZipFile(output/'Tanki era.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9)as z:
  for p in sorted(package.rglob('*')):
   if p.is_file():z.write(p,'Tanki Era/'+p.relative_to(package).as_posix())
 print('Built:',output/'Tanki era.zip')
if __name__=='__main__':main()
