package era2019.startup {
 import flash.display.Sprite;
 import flash.display.StageDisplayState;
 import flash.events.Event;

 public class MaximizedGameWindow extends Sprite {
  public static function schedule(host:Sprite):void {
   // Queue the native maximize before the packaged launcher shows the window.
   maximize(host);
   var firstFrame:Function;
   firstFrame=function(event:Event):void {
    if(host.stage==null)return;
    host.removeEventListener(Event.ENTER_FRAME,firstFrame);
    // Handle a saved fullscreen preference without remaximizing later restores.
    maximize(host);
   };
   host.addEventListener(Event.ENTER_FRAME,firstFrame);
  }

  private static function maximize(host:Sprite):void {
   if(host.stage==null)return;
   try {
    var window:Object=host.stage["nativeWindow"];
    if(window==null||!window.maximizable)return;
    if(host.stage.displayState!=StageDisplayState.NORMAL)host.stage.displayState=StageDisplayState.NORMAL;
    if(window.displayState!="maximized")window.maximize();
   }catch(unavailable:Error){}
  }
 }
}
