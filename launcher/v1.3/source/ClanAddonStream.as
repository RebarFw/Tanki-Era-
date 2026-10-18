package {
 import flash.display.Loader;
 import flash.display.Sprite;
 import flash.events.Event;
 import flash.events.IOErrorEvent;
 import flash.events.SecurityErrorEvent;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.net.URLLoader;
 import flash.net.URLLoaderDataFormat;
 import flash.net.URLRequest;
 import flash.system.ApplicationDomain;
 import flash.system.LoaderContext;
 import flash.utils.ByteArray;

 /** Small local entry for the existing game's ClanAddon.swf interface.
  * The full, unchanged clan module streams from the owner's fixed GitHub URL.
  */
 public class ClanAddonStream extends Sprite {
  private var bytesLoader:URLLoader=new URLLoader();
  private var implementation:Loader=new Loader();
  private var bar:Object;private var network:Object;private var locale:Object;
  private var argumentsReady:Boolean=false;private var moduleReady:Boolean=false;
  private var installed:Boolean=false;
  public function ClanAddonStream(){
   super();addChild(implementation);
   bytesLoader.dataFormat=URLLoaderDataFormat.BINARY;
   bytesLoader.addEventListener(Event.COMPLETE,function(e:Event):void{
    var bytes:ByteArray=bytesLoader.data as ByteArray;
    if(bytes==null||bytes.length<8||bytes.length>8388608){trace("Invalid clan module download");return;}
    var context:LoaderContext=new LoaderContext(false,new ApplicationDomain(null));
    context.allowCodeImport=true;implementation.loadBytes(bytes,context);
   });
   implementation.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void{moduleReady=true;install();});
   bytesLoader.addEventListener(IOErrorEvent.IO_ERROR,function(e:Event):void{trace("Clan module download failed");});
   bytesLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,function(e:Event):void{trace("Clan module download failed");});
   var revision:String = savedRevision();
   if(revision.length == 40) downloadRevision(revision);
   else {
    var ref:URLLoader = new URLLoader();
    ref.addEventListener(Event.COMPLETE,function(e:Event):void {
     try { downloadRevision(String(JSON.parse(ref.data).object.sha)); }
     catch(error:Error) { trace("Clan release lookup failed"); }
    });
    ref.addEventListener(IOErrorEvent.IO_ERROR,function(e:Event):void { trace("Clan release lookup failed"); });
    ref.addEventListener(SecurityErrorEvent.SECURITY_ERROR,function(e:Event):void { trace("Clan release lookup failed"); });
    ref.load(new URLRequest("https://api.github.com/repos/RebarFw/Tanki-Era-/git/ref/heads/main?update="+new Date().time));
   }
  }
  private function savedRevision():String {
   try {
    var file:File = File.applicationStorageDirectory.resolvePath("client-release.json");
    if(!file.exists) return "";
    var stream:FileStream = new FileStream();stream.open(file,FileMode.READ);
    var text:String;
    try { text = stream.readUTFBytes(stream.bytesAvailable); } finally { stream.close(); }
    var revision:String = String(JSON.parse(text).revision);
    return /^[0-9a-f]{40}$/.test(revision) ? revision : "";
   } catch(error:Error) { return ""; }
  }
  private function downloadRevision(revision:String):void {
   if(!/^[0-9a-f]{40}$/.test(revision)) { trace("Invalid clan release revision"); return; }
   bytesLoader.load(new URLRequest("https://raw.githubusercontent.com/RebarFw/Tanki-Era-/"+revision+"/assets/ClanAddon.swf"));
  }
  public function initialize(hostBar:Object,hostNetwork:Object,hostLocale:Object):void{
   if(argumentsReady)return;bar=hostBar;network=hostNetwork;locale=hostLocale;argumentsReady=true;install();
  }
  private function install():void{
   if(installed||!argumentsReady||!moduleReady)return;
   installed=true;Object(implementation.content).initialize(bar,network,locale);
  }
 }
}
