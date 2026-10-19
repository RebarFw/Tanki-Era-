package era2019.garage {
 import flash.display.Sprite;
 import flash.display.Stage;
 import flash.events.Event;
 import flash.events.KeyboardEvent;
 import flash.events.MouseEvent;

 public class GarageConfirmKeyboard extends Sprite {
  private var dialog:Sprite;
  private var yesButton:Object;
  private var boundStage:Stage;
  private var accepted:Boolean=false;

  public function GarageConfirmKeyboard(dialog:Sprite,yesButton:Object){
   this.dialog=dialog;this.yesButton=yesButton;
   dialog.addEventListener(Event.ADDED_TO_STAGE,onAdded);
   dialog.addEventListener(Event.REMOVED_FROM_STAGE,onRemoved);
   if(dialog.stage!=null)onAdded(null);
  }

  public static function install(dialog:Sprite,yesButton:Object):void{
   new GarageConfirmKeyboard(dialog,yesButton);
  }

  private function onAdded(event:Event):void{
   if(boundStage!=null)boundStage.removeEventListener(KeyboardEvent.KEY_UP,onKeyUp);
   boundStage=dialog.stage;accepted=false;
   if(boundStage!=null)boundStage.addEventListener(KeyboardEvent.KEY_UP,onKeyUp,false,-4);
  }

  private function onRemoved(event:Event):void{
   if(boundStage!=null)boundStage.removeEventListener(KeyboardEvent.KEY_UP,onKeyUp);
   boundStage=null;
  }

  private function onKeyUp(event:KeyboardEvent):void{
   if(event.keyCode!=13||event.ctrlKey||event.altKey||accepted)return;
   if(boundStage==null||dialog.stage!=boundStage||!dialog.visible||dialog.parent==null)return;
   if(dialog.parent.getChildAt(dialog.parent.numChildren-1)!=dialog)return;
   if(yesButton==null||!yesButton.enable)return;
   event.preventDefault();event.stopImmediatePropagation();accepted=true;
   yesButton.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));
  }
 }
}
