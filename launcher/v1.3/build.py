"""Build the compact v1.3 player package from the current Tanki Era client."""
from pathlib import Path
import argparse,subprocess,shutil,os,zipfile,tempfile

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--template',type=Path,required=True,help='Current client game folder, including its native EXE and AIR runtime')
    parser.add_argument('--ffdec',type=Path,required=True)
    parser.add_argument('--sdk',type=Path,required=True)
    parser.add_argument('--java',default='java')
    parser.add_argument('--output',type=Path,default=Path('out-v13'))
    args=parser.parse_args();here=Path(__file__).resolve().parent;template=args.template.resolve();output=args.output.resolve()
    package=output/'Tanki Era v1,3'
    if package.exists():raise ValueError('Use a fresh output directory')
    package.mkdir(parents=True)
    for name in ['Adobe AIR','icons','META-INF']:shutil.copytree(template/name,package/name)
    for name in ['mimetype','communicator-chat.png','communicator-news.png']:shutil.copy2(template/name,package/name)
    shutil.copy2(template/'TankiEraClean.exe',package/'Tanki Era.exe')
    for name,cls in [('Prelauncher.swf','protanki.launcher.Prelauncher'),('StandaloneLoader.swf','StandaloneLoader')]:
        source=here/'source'/('Prelauncher.as' if name=='Prelauncher.swf' else 'StandaloneLoader.as')
        subprocess.run([args.java,'-Dfile.encoding=UTF-8','-Xmx1200M','-jar',str(args.ffdec.resolve()),'-air','-replace',str(template/name),str(package/name),cls,str(source)],check=True)
    shutil.copy2(here/'application.xml',package/'META-INF/AIR/application.xml')
    stale=package/'META-INF/AIR/hash'
    if stale.exists():stale.unlink()
    sdk=args.sdk.resolve();excluded={'guava-r08.jar','guava-compiler.jar','commons-io-2.0.1.jar','commons-io-2.11.0.jar'}
    jars=[sdk/'lib/guava-compiler.jar',sdk/'lib/commons-io-2.11.0.jar']+[p for p in (sdk/'lib').glob('*.jar') if p.name not in excluded]
    with tempfile.TemporaryDirectory(prefix='EraV13Compiler-') as temp:
        temp=Path(temp);config=temp/'minimal.xml';config.write_text('<flex-config/>');compiled=temp/'ClanAddon.swf'
        subprocess.run([args.java,'-cp',os.pathsep.join(map(str,jars)),'com.adobe.flash.compiler.clients.MXMLC','-load-config='+str(config),'-target-player=11.3','-swf-version=19','-external-library-path='+str(sdk/'frameworks/libs/air/airglobal.swc'),'-output='+str(compiled),str(here/'source/ClanAddonStream.as')],check=True)
        shutil.copy2(compiled,package/'ClanAddon.swf')
    archive=output/'Tanki Era v1,3.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for path in sorted(package.rglob('*')):
            if path.is_file():z.write(path,'Tanki Era v1,3/'+path.relative_to(package).as_posix())
    print('Built:',archive)

if __name__=='__main__':main()
