package era2019.startup {
 import flash.display.Sprite;
 import flash.display.StageDisplayState;
 import flash.events.Event;

 public class MaximizedGameWindow extends Sprite {
  public static function schedule(host:Sprite):void {
   var firstFrame:Function;
   firstFrame=function(event:Event):void {
    if(host.stage==null)return;
    host.removeEventListener(Event.ENTER_FRAME,firstFrame);
    try {
     var window:Object=host.stage["nativeWindow"];
     if(window==null||!window.maximizable)return;
     if(host.stage.displayState!=StageDisplayState.NORMAL)host.stage.displayState=StageDisplayState.NORMAL;
     window.maximize();
    }catch(unavailable:Error){}
   };
   // The package restores its saved bounds after adding the game loader.
   // Run once on the next frame, after that restoration has completed.
   host.addEventListener(Event.ENTER_FRAME,firstFrame);
  }
 }
}
