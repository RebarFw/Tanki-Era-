package {
 import flash.display.*;import flash.events.*;import flash.desktop.*;import flash.filesystem.*;import flash.system.*;import flash.utils.*;import flash.net.URLRequest;
 import tanki.updater.Files;
 /** Runs only inside the fully verified game directory after the original Play click. */
 [SWF(width="1000",height="600",frameRate="30",backgroundColor="#101820")]
 public class GameEntry extends Sprite {
  protected var target:Loader=new Loader();private var locale:String="en";private var started:Boolean=false;
  public function GameEntry(){super();
   NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE,function(e:InvokeEvent):void{
    if(started){for each(var window:NativeWindow in NativeApplication.nativeApplication.openedWindows)if(window.visible){if(window.displayState==NativeWindowDisplayState.MINIMIZED)window.restore();window.activate();}return;}
    for(var i:int=0;i<e.arguments.length;i++)if(e.arguments[i]=="--locale"&&i+1<e.arguments.length)locale=String(e.arguments[++i]);start();
   });setTimeout(start,250);
  }
  private function start():void{
   if(started)return;started=true;if(["en","ru","pt_BR"].indexOf(locale)<0)locale="en";
   var context:LoaderContext=new LoaderContext(false,new ApplicationDomain(ApplicationDomain.currentDomain));context.allowCodeImport=true;
   context.parameters={lang:locale,socket:"socket.cfg",swf:"Loader.swf",library:"app:/library.swf"};
   target.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void{
    // The player already chose Play in the original menu. Continue that same action.
    var button:DisplayObject=find(target,"protanki.launcher.controls.buttons::StartButton");
    if(!button)throw new Error("Original Play control unavailable");startOriginal(button);
   });addChild(target);target.load(new URLRequest(File.applicationDirectory.resolvePath("Prelauncher.swf").url+"?lang="+encodeURIComponent(locale)+"&socket=socket.cfg&swf=Loader.swf&library=library.swf"),context);
  }
  protected function startOriginal(button:DisplayObject):void{button.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));}
  private function find(node:DisplayObject,name:String):DisplayObject{
   if(getQualifiedClassName(node)==name)return node;
   if(node is DisplayObjectContainer){var c:DisplayObjectContainer=node as DisplayObjectContainer;for(var i:int=0;i<c.numChildren;i++){var found:DisplayObject=find(c.getChildAt(i),name);if(found)return found;}}return null;
  }
 }
}
