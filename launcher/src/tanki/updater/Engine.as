package tanki.updater {
 import flash.filesystem.*;import flash.utils.*;import flash.crypto.generateRandomBytes;
 public final class Engine {
  public static const NAMES:Array=["Loader.swf","Prelauncher.swf","library.swf","socket.cfg","StandaloneLoader.swf","ClanAddon.swf","communicator-chat.png","communicator-news.png"];
  public var root:File;public var fetch:Function;public var status:Function;public var runtime:File;
  private var previous:Object;private var prepared:Function;private var failed:Function;private var selected:Array;private var revision:String;private var stage:File;private var version:String;private var contentKey:String;private var hashes:Object;
  public function Engine(cache:File=null,transport:Function=null,progress:Function=null,vendor:File=null){
   root=cache||File.userDirectory.resolvePath("AppData/Local/TankiEraPlayer/air");runtime=vendor||File.applicationDirectory;fetch=transport||Transport.fetch;status=progress||function(s:String):void{};root.createDirectory();
  }
  public function log(message:String):void{try{var f:FileStream=new FileStream();f.open(root.resolvePath("launcher.log"),FileMode.APPEND);f.writeUTFBytes(new Date().toUTCString()+" "+message+"\n");f.close();}catch(ignore:Error){}}
  private function expectedFiles():Array{var a:Array=NAMES.concat(["application.xml","META-INF/AIR/application.xml"]);for(var key:String in RuntimeManifest.HASHES)a.push(key);return a;}
  private function nonce():String{var b:ByteArray=generateRandomBytes(16);var s:String="";for(var i:int=0;i<b.length;i++){var h:String=uint(b[i]).toString(16);s+=(h.length==1?"0":"")+h;}return s;}
  public function current(done:Function):void {
   var info:Object;var dir:File;var keys:Array;
   try{
    info=JSON.parse(Files.text(root.resolvePath("current-air.json")));
    if(!info||!/^[a-f0-9]{64}$/.test(String(info.Directory))||!/^[a-f0-9]{64}$/.test(String(info.ContentKey))||!/^[a-f0-9]{40}$/.test(String(info.Revision))||info.RuntimeHash!=RuntimeManifest.FINGERPRINT||!info.Hashes){done(null);return;}
    keys=expectedFiles();var actual:int=0;for(var key:String in info.Hashes){actual++;if(keys.indexOf(key)<0||!/^[a-f0-9]{64}$/.test(String(info.Hashes[key])))throw new Error("Invalid saved file");}
    if(actual!=keys.length)throw new Error("Incomplete saved version");
    dir=root.resolvePath("releases/"+info.Directory);if(!dir.isDirectory||dir.isSymbolicLink)throw new Error("Invalid saved directory");
   }catch(e:Error){done(null);return;}
   var at:int=0;
   function next():void {
    if(at==keys.length){done(info);return;}var name:String=keys[at++];var file:File=dir.resolvePath(name);
    if(!file.exists||file.isDirectory||file.isSymbolicLink||file.size>Transport.LIMIT){done(null);return;}
    Files.sha(file,function(d:Object):void{if(d.sha256!=info.Hashes[name]){done(null);return;}next();},function(e:Error):void{done(null);});
   }
   next();
  }
  public function prepare(done:Function,error:Function):void {
   prepared=done;failed=error;stage=null;
   status("Checking game files...");current(function(saved:Object):void{previous=saved;requestCommit();});
  }
  private function receive(url:String,done:Function):void {fetch(url,done,fail,function(loaded:Number,total:Number):void{if(total>0)status("Downloading game updates... "+Math.min(100,Math.floor(100*loaded/total))+"%");});}
  private function requestCommit():void{
   status("Checking for updates...");receive("https://api.github.com/repos/RebarFw/Tanki-Era-/commits/main",function(bytes:ByteArray):void{
    try{var commit:Object=JSON.parse(bytes.readUTFBytes(bytes.length));bytes.clear();revision=String(commit.sha);if(!/^[a-f0-9]{40}$/.test(revision))throw new Error("Invalid update revision");
     if(previous&&previous.Revision==revision){prepared(root.resolvePath("releases/"+previous.Directory));return;}requestAssets();
    }catch(e:Error){fail(e);}
   });
  }
  private function requestAssets():void{
   receive("https://api.github.com/repos/RebarFw/Tanki-Era-/contents/assets?ref="+revision,function(bytes:ByteArray):void{
    try{
     var entries:Array=JSON.parse(bytes.readUTFBytes(bytes.length))as Array;bytes.clear();if(!entries)throw new Error("Invalid asset list");selected=[];
     for each(var name:String in NAMES){var matches:Array=[];for each(var entry:Object in entries)if(entry.name===name)matches.push(entry);
      if(matches.length!=1)throw new Error("Incomplete game version");var item:Object=matches[0];
      if(item.type!="file"||!/^[a-f0-9]{40}$/.test(String(item.sha))||!(item.size is Number)||item.size<1||item.size>Transport.LIMIT||Math.floor(item.size)!=item.size)throw new Error("Invalid game asset");
      selected.push({name:name,sha:String(item.sha),size:Number(item.size)});
     }
     var identifiers:Array=[];for each(item in selected)identifiers.push(item.name+":"+item.sha);
     version=contentKey=Digest.text("air-player-v1:"+RuntimeManifest.FINGERPRINT+":"+identifiers.join(":"));
     if(previous&&previous.ContentKey==contentKey){previous.Revision=revision;save(previous);prepared(root.resolvePath("releases/"+previous.Directory));return;}
     stage=root.resolvePath("releases/.staging-"+nonce());stage.createDirectory();hashes={};obtain(0);
    }catch(e:Error){fail(e);}
   });
  }
  private function checkBlob(file:File,item:Object,done:Function):void{
   if(!file.exists||file.isDirectory||file.isSymbolicLink||file.size!=item.size){done(null);return;}
   Files.sha(file,function(d:Object):void{done(d.blob==item.sha?d:null);},function(e:Error):void{done(null);},true);
  }
  private function obtain(at:int):void{
   if(at==selected.length){finishAssets();return;}var item:Object=selected[at];var blob:File=root.resolvePath("blobs/"+item.sha);
   checkBlob(blob,item,function(d:Object):void{
    if(d){copyAsset(blob,item,d,at);return;}
    // Reuse only an individually re-verified blob from the old launcher cache.
    var legacy:File=File.userDirectory.resolvePath("AppData/Local/TankiEraPlayer/blobs/"+item.sha);
    checkBlob(legacy,item,function(old:Object):void{if(old){copyAsset(legacy,item,old,at);return;}download(item,blob,at);});
   });
  }
  private function download(item:Object,blob:File,at:int):void{
   receive("https://raw.githubusercontent.com/RebarFw/Tanki-Era-/"+revision+"/assets/"+item.name,function(bytes:ByteArray):void{
    try{
     if(bytes.length!=item.size)throw new Error("Incomplete game download");
     if(String(item.name).substr(-4)==".swf"&&(bytes.length<8||[67,70,90].indexOf(uint(bytes[0]))<0||bytes[1]!=87||bytes[2]!=83))throw new Error("Invalid game SWF");
     var partial:File=root.resolvePath("blobs/.part-"+nonce());Files.write(partial,bytes);bytes.clear();
     checkBlob(partial,item,function(d:Object):void{if(!d){try{partial.deleteFile();}catch(ignore:Error){}fail(new Error("Game download verification failed"));return;}
      try{partial.moveTo(blob,true);copyAsset(blob,item,d,at);}catch(e:Error){fail(e);}
     });
    }catch(e:Error){fail(e);}
   });
  }
  private function copyAsset(blob:File,item:Object,d:Object,at:int):void{
   try{var target:File=stage.resolvePath(item.name);blob.copyTo(target,true);hashes[item.name]=d.sha256;obtain(at+1);}catch(e:Error){fail(e);}
  }
  public static function normalize(config:Object):Object{
   if(!config||!validHost(String(config.ip))||isNaN(Number(config.port))||Number(config.port)!=int(config.port)||int(config.port)<1||int(config.port)>65535)throw new Error("Invalid public game endpoint");
   var resources:String=String(config.resources);var parts:Array=/^(https?):\/\/([A-Za-z0-9.-]+)(?::([0-9]+))?(\/[^?#]*)?$/.exec(resources);
   if(!parts||!validHost(parts[2])||(parts[3]&&(Number(parts[3])<1||Number(parts[3])>65535)))throw new Error("Invalid public resource endpoint");
   return {ip:String(config.ip),port:int(config.port),resources:resources.replace(/\/+$/,""),loader:"Loader.swf",library:"app:/library.swf"};
  }
  private static function validHost(host:String):Boolean{host=host.toLowerCase();return host.length<=253&&/^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$/.test(host)&&host!="localhost"&&host!="0.0.0.0"&&host.indexOf("127.")!=0&&host.indexOf("..")<0;}
  public static function descriptor(config:Object):String{
   var doc:XML=new XML(RuntimeManifest.GAME_DESCRIPTOR);var ns:Namespace=doc.namespace();
   doc.ns::filename="Tanki Era";doc.ns::name="Tanki Era";doc.ns::initialWindow.ns::title="Tanki Era";
   doc.ns::initialWindow.ns::content="StandaloneLoader.swf?resources="+encodeURIComponent(String(config.resources)+"/resource")+"&prelauncher=Prelauncher.swf&locale=en&library=library.swf&lang=en&swf=Loader.swf&socket=socket.cfg";
   return '<?xml version="1.0" encoding="utf-8"?>\n'+doc.toXMLString();
  }
  private function finishAssets():void{
   try{var config:Object=normalize(JSON.parse(Files.text(stage.resolvePath("socket.cfg"))));Files.writeText(stage.resolvePath("socket.cfg"),JSON.stringify(config));var xml:String=descriptor(config);
    Files.writeText(stage.resolvePath("application.xml"),xml);Files.writeText(stage.resolvePath("META-INF/AIR/application.xml"),xml);
    var vendorNames:Array=[];for(var name:String in RuntimeManifest.HASHES)vendorNames.push(name);vendorNames.sort();copyRuntime(vendorNames,0);
   }catch(e:Error){fail(e);}
  }
  private function copyRuntime(names:Array,at:int):void{
   if(at==names.length){hashGenerated(["socket.cfg","application.xml","META-INF/AIR/application.xml"],0);return;}
   var name:String=names[at];var source:File=runtime.resolvePath(name);
   if(!source.exists||source.isSymbolicLink||source.isDirectory){fail(new Error("Bundled runtime file missing"));return;}
   Files.sha(source,function(d:Object):void{try{if(d.sha256!=RuntimeManifest.HASHES[name])throw new Error("Bundled runtime verification failed");var dest:File=stage.resolvePath(name);dest.parent.createDirectory();source.copyTo(dest,true);hashes[name]=d.sha256;copyRuntime(names,at+1);}catch(e:Error){fail(e);}},fail);
  }
  private function hashGenerated(names:Array,at:int):void{
   if(at==names.length){activate();return;}var name:String=names[at];Files.sha(stage.resolvePath(name),function(d:Object):void{hashes[name]=d.sha256;hashGenerated(names,at+1);},fail);
  }
  private function activate():void{
   try{
    var destination:File=root.resolvePath("releases/"+version);
    if(destination.exists){
     // Never overwrite a directory which might be in use. Preserve it and
     // activate an independently verified generation with a new identifier.
     version=Digest.text(version+":"+nonce());destination=root.resolvePath("releases/"+version);
    }
    stage.moveTo(destination);stage=null;var info:Object={Directory:version,ContentKey:contentKey,Revision:revision,RuntimeHash:RuntimeManifest.FINGERPRINT,Hashes:hashes};save(info);prepared(destination);
   }catch(e:Error){fail(e);}
  }
  private function save(info:Object):void{var temp:File=root.resolvePath(".current-"+nonce()+".json");Files.writeText(temp,JSON.stringify(info));temp.moveTo(root.resolvePath("current-air.json"),true);}
  private function fail(error:Error):void{
   log("Update failed: "+error.toString());
   if(stage){try{var expected:String=root.resolvePath("releases").nativePath+File.separator;if(stage.nativePath.indexOf(expected)==0&&stage.name.indexOf(".staging-")==0&&!stage.isSymbolicLink)stage.deleteDirectory(true);}catch(ignore:Error){}stage=null;}
   if(previous){status("Starting saved game version...");prepared(root.resolvePath("releases/"+previous.Directory));}else failed(error);
  }
 }
}
