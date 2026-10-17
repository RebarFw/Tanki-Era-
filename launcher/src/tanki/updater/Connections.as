package tanki.updater {
 import flash.net.Socket;import flash.events.*;import flash.utils.Timer;import flash.filesystem.File;
 public final class Connections {
  public static function probe(host:String,port:int,name:String,complete:Function):void {
   var socket:Socket=new Socket();var timer:Timer=new Timer(5000,1);var done:Boolean=false;
   function finish(ok:Boolean,why:String):void{if(done)return;done=true;timer.stop();try{socket.close();}catch(ignore:Error){}complete((ok?"OK ":"FAILED ")+name+" ("+host+":"+port+")"+(why?": "+why:""));}
   socket.addEventListener(Event.CONNECT,function(e:Event):void{finish(true,"");});
   socket.addEventListener(IOErrorEvent.IO_ERROR,function(e:IOErrorEvent):void{finish(false,e.text);});socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR,function(e:SecurityErrorEvent):void{finish(false,e.text);});
   timer.addEventListener(TimerEvent.TIMER_COMPLETE,function(e:Event):void{finish(false,"timed out");});
   try{timer.start();socket.connect(host,port);}catch(e:Error){finish(false,e.toString());}
  }
  public static function run(game:File,complete:Function):void{
   var config:Object=Engine.normalize(JSON.parse(Files.text(game.resolvePath("socket.cfg"))));var resource:Array=/^(https?):\/\/([^\/:]+)(?::([0-9]+))?/.exec(String(config.resources));
   var report:Array=new Array(3);var pending:int=3;
   function record(index:int):Function{return function(message:String):void{report[index]=message;if(--pending==0)complete(report.join("\n"));};}
   probe(config.ip,config.port,"game",record(0));probe(config.ip,843,"Flash policy",record(1));probe(resource[2],resource[3]?int(resource[3]):(resource[1]=="https"?443:80),"resources",record(2));
  }
 }
}
