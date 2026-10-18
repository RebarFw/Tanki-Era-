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

 public class ReleaseTransport {
  private static const IDLE_TIMEOUT_MS:int=45000;
  private static var counters:Object={githubStarted:0,githubCompleted:0,fallbackStarted:0,fallbackCompleted:0,failed:0,bytes:0};
  private static var recent:Array=[];

  public static function get statistics():Object { return {counters:counters,recent:recent.concat()}; }

  public static function download(cache:Object,fallbackUrl:String,done:Function,failed:Function,info:Object):void {
   var primary:String=info!=null && info.url!=null ? String(info.url) : "";
   var expected:String=info==null ? "" : String(info.sha256);
   var size:Number=info==null ? -1 : Number(info.size);
   var finished:Boolean=false;
   var attempt:Function;
   if(!/^[0-9a-f]{64}$/.test(expected) || size<0 || size>2147483647) {failed("Invalid package metadata");return;}
   var validPrimary:Boolean=new RegExp("^https://github\\.com/RebarFw/Tanki-Era-/releases/download/resource-cache-v[0-9]+/"+expected+"\\.tpk$").test(primary);

   attempt=function(url:String,isPrimary:Boolean):void {
    var input:URLStream=new URLStream();
    var timer:Timer=new Timer(IDLE_TIMEOUT_MS,1);
    var output:Object=null;
    var target:Object=null;
    var complete:Boolean=false;
    var count:Number=0;
    var path:String="downloads/release-"+new Date().time+"-"+int(Math.random()*2147483647)+".tmp";
    var progress:Function;
    var received:Function;
    var errored:Function;
    var timeout:Function;
    var drain:Function;
    var cleanup:Function;
    var reject:Function;
    var source:String=isPrimary ? "github" : "fallback";
    counters[isPrimary ? "githubStarted" : "fallbackStarted"]++;
    recent.push({source:source,sha256:expected});if(recent.length>32)recent.shift();

    cleanup=function():void {
     timer.stop();timer.removeEventListener(TimerEvent.TIMER_COMPLETE,timeout);
     input.removeEventListener(ProgressEvent.PROGRESS,progress);
     input.removeEventListener(Event.COMPLETE,received);
     input.removeEventListener(IOErrorEvent.IO_ERROR,errored);
     input.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,errored);
     try {input.close();}catch(ignore:Error){}
     if(output!=null)try {output.close();}catch(ignore2:Error){}
    };
    reject=function(message:String):void {
     if(complete || finished)return;
     complete=true;cleanup();
     if(target!=null)try {if(target.exists)target.deleteFile();}catch(ignore:Error){}
     if(isPrimary) {attempt(fallbackUrl,false);return;}
     finished=true;counters.failed++;failed(message);
    };
    drain=function():void {
     if(input.bytesAvailable==0)return;
     var bytes:ByteArray=new ByteArray();input.readBytes(bytes);
     count+=bytes.length;
     if(count>size)throw new Error("Resource package exceeded its declared size");
     output.writeBytes(bytes);counters.bytes+=bytes.length;
     bytes.clear();timer.reset();timer.start();
    };
    progress=function(event:ProgressEvent):void {
     if(complete || finished)return;
     try {drain();}catch(error:Error){reject(error.toString());}
    };
    errored=function(event:Event):void {reject("Resource transfer failed ("+source+")");};
    timeout=function(event:TimerEvent):void {reject("Resource transfer stalled ("+source+")");};
    received=function(event:Event):void {
     if(complete || finished)return;
     try {drain();cleanup();}catch(error:Error){reject(error.toString());return;}
     if(count!=size){reject("Resource package size mismatch ("+source+")");return;}
     cache.verify(path,size,expected,function(valid:Boolean):void {
      if(complete || finished)return;
      if(!valid){reject("Resource package SHA-256 mismatch ("+source+")");return;}
      complete=true;finished=true;
      counters[isPrimary ? "githubCompleted" : "fallbackCompleted"]++;
      done(path);
     });
    };
    try {
     target=cache.file(path);target.parent.createDirectory();
     var Stream:Class=getDefinitionByName("flash.filesystem.FileStream") as Class;
     output=new Stream();output.open(target,"write");
     input.addEventListener(ProgressEvent.PROGRESS,progress);
     input.addEventListener(Event.COMPLETE,received);
     input.addEventListener(IOErrorEvent.IO_ERROR,errored);
     input.addEventListener(SecurityErrorEvent.SECURITY_ERROR,errored);
     timer.addEventListener(TimerEvent.TIMER_COMPLETE,timeout);timer.start();
     input.load(new URLRequest(url));
    }catch(error:Error){reject(error.toString());}
   };
   attempt(validPrimary ? primary : fallbackUrl,validPrimary);
  }
 }
}
