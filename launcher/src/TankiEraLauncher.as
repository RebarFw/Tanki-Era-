package {
 import flash.display.*;import flash.text.*;import flash.events.*;import flash.desktop.*;import flash.filesystem.*;import flash.utils.*;
 import tanki.updater.*;
 [SWF(width="390",height="140",frameRate="30",backgroundColor="#0f151c")]
 public class TankiEraLauncher extends Sprite {
  private var label:TextField=new TextField();private var button:Sprite;private var engine:Engine;private var started:Boolean=false;private var prepareOnly:Boolean=false;private var child:NativeProcess;
  public function TankiEraLauncher(){
   super();stage.scaleMode=StageScaleMode.NO_SCALE;stage.align=StageAlign.TOP_LEFT;
   label.defaultTextFormat=new TextFormat("Segoe UI",15,0xe2eff8);label.width=350;label.height=62;label.x=20;label.y=25;label.wordWrap=true;label.selectable=false;addChild(label);label.text="Starting Tanki Era...";
   NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE,function(e:InvokeEvent):void{if(started)return;start(e.arguments);});
   setTimeout(function():void{if(!started)start([]);},250);
  }
  private function start(args:Array):void{
   if(started)return;started=true;var root:File=null;
   for(var i:int=0;i<args.length;i++){if(args[i]=="--prepare-only")prepareOnly=true;if(args[i]=="--cache-dir"&&i+1<args.length)root=new File(String(args[++i]));}
   try{
    engine=new Engine(root,null,function(s:String):void{label.text=s;});
    engine.prepare(function(game:File):void{
     if(prepareOnly){engine.log("PREPARE_OK "+game.nativePath);NativeApplication.nativeApplication.exit(0);return;}
     label.text="Checking the game server...";
     try{Connections.run(game,function(report:String):void{engine.log(report);if(report.indexOf("FAILED")>=0){message("Server is offline");return;}launch(game);});}
     catch(error:Error){failure(error);}
    },failure);
   }catch(error:Error){failure(error);}
  }
  private function launch(game:File):void{
   try{
    if(!NativeProcess.isSupported)throw new Error("Native game launch is unavailable");
    var info:NativeProcessStartupInfo=new NativeProcessStartupInfo();info.executable=game.resolvePath("Tanki Era.exe");info.workingDirectory=game;
    child=new NativeProcess();child.start(info);engine.log("Started verified local game runtime");NativeApplication.nativeApplication.exit(0);
   }catch(error:Error){failure(error);}
  }
  private function failure(error:Error):void{if(engine)engine.log(error.toString());if(prepareOnly){NativeApplication.nativeApplication.exit(1);return;}message("Tanki Era could not start. Check your internet connection and try again.");}
  private function message(text:String):void{
   label.text=text;label.y=20;label.height=65;
   if(button)return;button=new Sprite();button.graphics.beginFill(0x253b51);button.graphics.drawRoundRect(0,0,90,30,6);button.graphics.endFill();button.x=150;button.y=95;button.buttonMode=true;
   var title:TextField=new TextField();title.defaultTextFormat=new TextFormat("Segoe UI",14,0xe2eff8);title.width=90;title.height=28;title.y=3;title.text="OK";title.selectable=false;title.mouseEnabled=false;var format:TextFormat=title.defaultTextFormat;format.align="center";title.setTextFormat(format);button.addChild(title);addChild(button);
   button.addEventListener(MouseEvent.CLICK,function(e:Event):void{NativeApplication.nativeApplication.exit(0);});stage.addEventListener(KeyboardEvent.KEY_DOWN,function(e:KeyboardEvent):void{if(e.keyCode==13||e.keyCode==27)NativeApplication.nativeApplication.exit(0);});
  }
 }
}
