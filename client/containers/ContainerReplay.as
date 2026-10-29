package era2019.containers {
 import flash.display.DisplayObject;
 import flash.display.DisplayObjectContainer;
 import flash.display.Sprite;
 import flash.events.MouseEvent;
 import flash.utils.Dictionary;

 public class ContainerReplay {
  private static const balances:Dictionary=new Dictionary(true);

  public static function update(dialog:Object,count:int):void {
   if(dialog!=null)balances[dialog]=Math.max(0,count);
  }
  private static function remaining(dialog:Object,fallback:int):int {
   if(balances[dialog]===undefined)update(dialog,fallback);
   return int(balances[dialog]);
  }
  public static function frame(dialog:Object,state:int,panel:Sprite,window:DisplayObjectContainer,boxes:int):void {
   if(state!=0&&state!=5)return;
   var count:int=remaining(dialog,boxes);
   for(var i:int=0;i<panel.numChildren;i++) {
    var button:Object=panel.getChildAt(i);
    button.enabled=int(button.count)>0&&int(button.count)<=count;
   }
   if(state==5&&panel.parent!=window)window.addChild(panel);
  }
  public static function begin(dialog:Object,state:int,boxes:int,panel:Sprite,event:MouseEvent):Boolean {
   if((state!=0&&state!=5)||panel.parent==null||DisplayObject(dialog).stage==null)return false;
   var button:Object=event.currentTarget;
   if(button==null||button.parent!=panel||!button.enabled)return false;
   var amount:int=int(button.count),count:int=remaining(dialog,boxes);
   if(amount<=0||amount>count)return false;
   update(dialog,count-amount);
   return true;
  }
  public static function reset(plane:Sprite,closed:Sprite,opened:Sprite,light:Sprite,present:Sprite,multiplier:Object,layers:Array):void {
   for each(var layer:DisplayObject in layers)if(layer.parent!=null)layer.parent.removeChild(layer);
   // The fourth transient layer is Stars; it starts hidden until the new reward appears.
   DisplayObject(layers[3]).alpha=0;
   if(opened.parent!=null)opened.parent.removeChild(opened);
   if(light.parent!=null)light.parent.removeChild(light);
   plane.addChild(closed);closed.alpha=1;opened.alpha=0;light.alpha=0;
   present.removeChildren();present.alpha=0;present.scaleX=present.scaleY=1;
   multiplier.alpha=0;multiplier.scaleX=multiplier.scaleY=1;
  }
  public static function removed(dialog:Object):void {delete balances[dialog];}
 }
}
