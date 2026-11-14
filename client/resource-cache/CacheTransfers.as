package tanki.cache {
 import flash.events.Event;
 import flash.events.IOErrorEvent;
 import flash.events.ProgressEvent;
 import flash.events.SecurityErrorEvent;
 import flash.events.TimerEvent;
 import flash.net.URLRequest;
 import flash.net.URLStream;
 import flash.utils.ByteArray;
 import flash.utils.Timer;
 import flash.utils.getDefinitionByName;

 public class CacheTransfers {
  private static const IDLE_TIMEOUT_MS:int=45000;
  private static var counters:Object={githubStarted:0,githubCompleted:0,manifestStarted:0,manifestCompleted:0,fallbackStarted:0,fallbackCompleted:0,failed:0,bytes:0};
  private static var recent:Array=[];
  private static const MAX_TRANSFERS:int=5;
  private static var waiting:Array=[];
  private static var active:int=0;
  private static var peak:int=0;

  public static function get statistics():Object { return {counters:counters,recent:recent.concat(),peak:peak}; }

  public static function discard(cache:Object, path:String):void {
   try {
    var file:Object=cache.file(path);
    if(file.exists)file.deleteFile();
   }catch(ignore:Error){}
  }

  public static function download(cache:Object, fallbackUrl:String, done:Function, failed:Function, info:Object):void {
   var operation:Function=function():void {
    downloadPackage(cache,info,function(path:String):void {
     --active;
     drainQueue();
     done(path);
    },function(message:String):void {
     --active;
     drainQueue();
     failed(message);
    });
   };
   if(fallbackUrl=="")waiting.push(operation);
   else waiting.unshift(operation);
   drainQueue();
  }

  private static function drainQueue():void {
   while(active<MAX_TRANSFERS && waiting.length>0) {
    var start:Function=waiting.shift();
    ++active;
    peak=Math.max(peak,active);
    start();
   }
  }

  private static function downloadPackage(cache:Object, info:Object, done:Function, failed:Function):void {
   var url:String=String(info.url);
   var expected:String=String(info.sha256);
   var size:Number=Number(info.size);
   var github:String="^https://github\\.com/RebarFw/Tanki-Era-/releases/download/resource-cache-v[0-9]+/";
   if(!/^[0-9a-f]{64}$/.test(expected) || !isFinite(size) || size<=0 || size>2147483647 ||
      !(new RegExp(github+expected+"\\.tpk$")).test(url)) {
    failed("Invalid GitHub resource package metadata");
    return;
   }

   function original():void {
    transfer(cache,url,size,expected,done,failed);
   }

   var compressed:Object=info.zlib;
   if(compressed==null || !/^[0-9a-f]{64}$/.test(String(compressed.sha256)) ||
      !(Number(compressed.size)>0 && Number(compressed.size)<size) ||
      !(new RegExp(github+compressed.sha256+"\\.tpk\\.zlib$")).test(String(compressed.url))) {
    original();
    return;
   }

   transfer(cache,compressed.url,compressed.size,compressed.sha256,function(path:String):void {
    try {
     var bytes:ByteArray=cache.read(path);
     bytes.uncompress();
     if(bytes.length!=size)throw new Error("Incorrect expanded package size");
     cache.writeAtomic(path,bytes);
    }catch(error:Error) {
     discard(cache,path);
     original();
     return;
    }

    cache.verify(path,size,expected,function(valid:Boolean):void {
     if(valid) {
      done(path);
      return;
     }
     discard(cache,path);
     original();
    });
   },function(message:String):void {
    original();
   });
  }

  private static function transfer(cache:Object, url:String, size:Number, expected:String,
                                   done:Function, failed:Function):void {
   var input:URLStream=new URLStream();
   var timer:Timer=new Timer(IDLE_TIMEOUT_MS,1);
   var output:Object;
   var complete:Boolean;
   var count:Number=0;
   var path:String="downloads/release-"+new Date().time+"-"+int(Math.random()*2147483647)+".tmp";
   var received:Function;
   var progress:Function;
   var errored:Function;
   var timeout:Function;

   function cleanup():void {
    timer.stop();
    timer.removeEventListener(TimerEvent.TIMER_COMPLETE,timeout);
    input.removeEventListener(ProgressEvent.PROGRESS,progress);
    input.removeEventListener(Event.COMPLETE,received);
    input.removeEventListener(IOErrorEvent.IO_ERROR,errored);
    input.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,errored);
    try {input.close();}catch(ignore:Error){}
    if(output!=null)try {output.close();}catch(ignore:Error){}
   }

   function reject(message:String):void {
    if(complete)return;
    complete=true;
    cleanup();
    discard(cache,path);
    counters.failed++;
    failed(message);
   }

   function drain():void {
    if(input.bytesAvailable==0)return;
    var bytes:ByteArray=new ByteArray();
    input.readBytes(bytes);
    count+=bytes.length;
    if(count>size)throw new Error("Resource package exceeded its declared size");
    output.writeBytes(bytes);
    counters.bytes+=bytes.length;
    timer.reset();
    timer.start();
   }

   progress=function(event:ProgressEvent):void {
    if(complete)return;
    try {drain();}catch(error:Error){reject(error.toString());}
   };
   errored=function(event:Event):void {reject("GitHub resource transfer failed");};
   timeout=function(event:TimerEvent):void {reject("GitHub resource transfer stalled");};
   received=function(event:Event):void {
    if(complete)return;
    try {drain();cleanup();}catch(error:Error){reject(error.toString());return;}
    if(count!=size){reject("GitHub resource package size mismatch");return;}
    cache.verify(path,size,expected,function(valid:Boolean):void {
     if(complete)return;
     if(!valid){reject("GitHub resource package SHA-256 mismatch");return;}
     complete=true;
     counters.githubCompleted++;
     done(path);
    });
   };

   counters.githubStarted++;
   recent.push({source:"github",sha256:expected});
   if(recent.length>32)recent.shift();
   try {
    var target:Object=cache.file(path);
    target.parent.createDirectory();
    var stream:Class=getDefinitionByName("flash.filesystem.FileStream") as Class;
    output=new stream();
    output.open(target,"write");
    input.addEventListener(ProgressEvent.PROGRESS,progress);
    input.addEventListener(Event.COMPLETE,received);
    input.addEventListener(IOErrorEvent.IO_ERROR,errored);
    input.addEventListener(SecurityErrorEvent.SECURITY_ERROR,errored);
    timer.addEventListener(TimerEvent.TIMER_COMPLETE,timeout);
    timer.start();
    input.load(new URLRequest(url));
   }catch(error:Error){reject(error.toString());}
  }
 }
}
