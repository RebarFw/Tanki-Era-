package {
 import flash.display.*;import flash.text.*;import flash.events.*;import flash.desktop.*;
 import flash.filesystem.*;import flash.utils.*;import flash.system.*;
 import tanki.updater.*;
 [SWF(width="1000",height="600",frameRate="30",backgroundColor="#101820")]
 public class TankiEraLauncher extends Sprite {
  // Exact original ERA launcher: artwork, controls, languages and links retained.
  [Embed(source="../art/Prelauncher.swf",mimeType="application/octet-stream")] private static const OriginalMenu:Class;
  protected var menu:Loader=new Loader();
  private var cache:File;private var engine:Engine;private var busy:Boolean=false;private var menuLoaded:Boolean=false;
  private var playRequested:Boolean=false;private var preparedGame:File;
  private var argsRead:Boolean=false;private var prepareOnly:Boolean=false;private var selectedLocale:String="en";
  private var dialog:Sprite;private var child:NativeProcess;
  public function TankiEraLauncher(){
   super();stage.align=StageAlign.TOP_LEFT;stage.scaleMode=StageScaleMode.NO_SCALE;
   NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE,function(e:InvokeEvent):void{readArgs(e.arguments);});
   setTimeout(function():void{if(!argsRead)readArgs([]);},250);
   stage.addEventListener(MouseEvent.CLICK,interceptPlay,true,1000);
   stage.addEventListener(KeyboardEvent.KEY_DOWN,function(e:KeyboardEvent):void{if(e.keyCode==27)NativeApplication.nativeApplication.exit();});
   menu.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void{
    menuLoaded=true;if(!prepareOnly)stage.nativeWindow.visible=true;menuReady();if(argsRead&&!busy)prepareQuietly();
   });
   menu.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,function(e:IOErrorEvent):void{failure(new Error(e.text));});
   var context:LoaderContext=new LoaderContext(false,new ApplicationDomain(ApplicationDomain.currentDomain));
   context.allowCodeImport=true;context.parameters={lang:"en",socket:"socket.cfg",swf:"Loader.swf",library:"app:/library.swf"};
   addChild(menu);menu.loadBytes(new OriginalMenu()as ByteArray,context);
  }
  private function readArgs(args:Array):void{
   if(argsRead)return;argsRead=true;
   try{for(var i:int=0;i<args.length;i++){
    if(args[i]=="--prepare-only")prepareOnly=true;
    else if(args[i]=="--cache-dir"&&i+1<args.length)cache=new File(String(args[++i]));
   }if(prepareOnly){stage.nativeWindow.visible=false;prepareQuietly();}else if(menuLoaded&&!busy)prepareQuietly();}catch(e:Error){failure(e);}
  }
  private function interceptPlay(e:MouseEvent):void{
   var node:DisplayObject=e.target as DisplayObject;
   while(node&&node!=stage){
    if(getQualifiedClassName(node)=="protanki.launcher.controls.buttons::StartButton"){
     e.stopImmediatePropagation();if(!playRequested){
      try{var localeClass:Class=menu.contentLoaderInfo.applicationDomain.getDefinition("protanki.launcher.Locale")as Class;selectedLocale=String(localeClass["current"]["name"]);}catch(ignore:Error){}
      if(["en","ru","pt_BR"].indexOf(selectedLocale)<0)selectedLocale="en";
      playRequested=true;if(preparedGame)launch(preparedGame,selectedLocale);else if(!busy)prepareQuietly();
     }return;
    }node=node.parent;
   }
  }
  private function prepareQuietly():void{
   if(busy)return;busy=true;
   try{
    engine=prepareGame(cache,function(status:String):void{
     // Update silently behind the unchanged original ERA launcher.
    },function(game:File):void{
     if(prepareOnly){engine.log("PREPARE_OK "+game.nativePath);NativeApplication.nativeApplication.exit(0);return;}
     preparedGame=game;if(playRequested)launch(game,selectedLocale);
    },failure);
   }catch(e:Error){failure(e);}
  }
  protected function menuReady():void{}
  protected function prepareGame(root:File,status:Function,done:Function,error:Function):Engine{var updater:Engine=new Engine(root,null,status);updater.prepare(done,error);return updater;}
  protected function launch(game:File,locale:String):void{
   try{if(!NativeProcess.isSupported)throw new Error("Native game launch unavailable");
    var info:NativeProcessStartupInfo=new NativeProcessStartupInfo();info.executable=game.resolvePath("Tanki Era.exe");info.workingDirectory=game;
    info.arguments=new <String>["--locale",locale];child=new NativeProcess();child.start(info);engine.log("Started verified local game runtime");NativeApplication.nativeApplication.exit(0);
   }catch(e:Error){failure(e);}
  }
  private function failure(error:Error):void{if(engine)engine.log(error.toString());if(prepareOnly){NativeApplication.nativeApplication.exit(1);return;}message("Tanki Era could not start. Check your internet connection and try again.");}
  protected function message(value:String):void{
   stage.nativeWindow.visible=true;if(dialog)return;
   dialog=new Sprite();dialog.graphics.beginFill(0,0.65);dialog.graphics.drawRect(0,0,1000,600);dialog.graphics.endFill();
   dialog.graphics.beginFill(0x202a34);dialog.graphics.drawRoundRect(255,230,490,140,8);dialog.graphics.endFill();
   var field:TextField=new TextField();var f:TextFormat=new TextFormat("Arial",16,0xffffff);f.align="center";field.defaultTextFormat=f;field.text=value;field.x=275;field.y=251;field.width=450;field.height=60;field.wordWrap=true;field.selectable=false;dialog.addChild(field);
   var ok:Sprite=new Sprite();ok.name="OK";ok.graphics.beginFill(0x31465b);ok.graphics.drawRoundRect(0,0,90,32,5);ok.graphics.endFill();ok.x=455;ok.y=321;ok.buttonMode=true;ok.mouseChildren=false;
   var title:TextField=new TextField();f.size=15;title.defaultTextFormat=f;title.text="OK";title.width=90;title.height=28;title.y=6;title.selectable=false;ok.addChild(title);
   ok.addEventListener(MouseEvent.CLICK,function(e:Event):void{NativeApplication.nativeApplication.exit();});dialog.addChild(ok);addChild(dialog);
  }
 }
}
