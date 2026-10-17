package tanki.updater {
 import flash.net.*;import flash.events.*;import flash.utils.*;
 public final class Transport {
  public static const LIMIT:uint=104857600;
  /** HTTPS only. Read a bounded stream; do not accept arbitrary download URLs. */
  public static function fetch(url:String,complete:Function,error:Function,progress:Function=null):void {
   if(url.indexOf("https://api.github.com/repos/RebarFw/Tanki-Era-/")!=0&&url.indexOf("https://raw.githubusercontent.com/RebarFw/Tanki-Era-/")!=0){error(new Error("Unexpected update source"));return;}
   var stream:URLStream=new URLStream();var bytes:ByteArray=new ByteArray();var done:Boolean=false;var timeout:Timer=new Timer(60000,1);
   function fail(e:Error):void{if(done)return;done=true;timeout.stop();try{stream.close();}catch(ignore:Error){}bytes.clear();error(e);}
   function drain():void{if(bytes.length+stream.bytesAvailable>LIMIT)throw new Error("Update file exceeds size limit");stream.readBytes(bytes,bytes.length,stream.bytesAvailable);}
   timeout.addEventListener(TimerEvent.TIMER_COMPLETE,function(e:Event):void{fail(new Error("Update request timed out"));});
   stream.addEventListener(IOErrorEvent.IO_ERROR,function(e:IOErrorEvent):void{fail(new Error(e.text));});
   stream.addEventListener(SecurityErrorEvent.SECURITY_ERROR,function(e:SecurityErrorEvent):void{fail(new Error(e.text));});
   stream.addEventListener(ProgressEvent.PROGRESS,function(e:ProgressEvent):void{try{drain();timeout.reset();timeout.start();if(progress!=null)progress(bytes.length,e.bytesTotal);}catch(x:Error){fail(x);}});
   stream.addEventListener(Event.COMPLETE,function(e:Event):void{if(done)return;try{drain();done=true;timeout.stop();stream.close();bytes.position=0;complete(bytes);}catch(x:Error){if(done){error(x);}else fail(x);}});
   try{var request:URLRequest=new URLRequest(url);request.manageCookies=false;request.useCache=false;request.cacheResponse=false;timeout.start();stream.load(request);}catch(e:Error){fail(e);}
  }
 }
}
