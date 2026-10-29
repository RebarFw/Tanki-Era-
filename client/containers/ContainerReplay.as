package era2019.containers {
 import flash.display.*;
 import flash.events.*;
 import flash.text.*;
 import flash.utils.*;
 import platform.client.fp10.core.resource.Resource;
 import platform.client.fp10.core.resource.IResourceLoadingListener;

 public class ContainerReplay {
  private static const records:Dictionary=new Dictionary(true);
  private static const PREVIEW_WAIT:int=8000;
  private static const REQUEST_WAIT:int=15000;
  private static function record(d:Object):Object {
   if(records[d]==null)records[d]={count:0,known:false,phase:'ready',generation:0,entries:[],timer:0};
   return records[d];
  }
  private static function valid(d:Object,r:Object,g:int):Boolean{return records[d]===r&&r.generation==g&&DisplayObject(d).stage!=null;}
  public static function update(d:Object,count:int):void {if(d==null)return;var r:Object=record(d);r.count=Math.max(0,count);r.known=true;if(r.phase=='ready'||r.phase=='recovered')controls(r);}
  public static function frame(d:Object,state:int,panel:Sprite,window:DisplayObjectContainer,boxes:int,close:Object=null):void {
   var r:Object=record(d);r.panel=panel;r.window=window;if(close!=null)r.close=close;
   if(!r.known){r.count=Math.max(0,boxes);r.known=true;}
   if(state==0||state==5){r.phase='ready';cleanup(r);hideStatus(r);controls(r);}
  }
  private static function controls(r:Object):void {
   if(r.panel==null)return;
   for(var i:int=0;i<r.panel.numChildren;i++){var button:Object=r.panel.getChildAt(i);button.enabled=int(button.count)>0&&int(button.count)<=r.count;}
   if(r.window!=null&&r.panel.parent!=r.window)r.window.addChild(r.panel);
   showClose(r);
  }
  private static function showClose(r:Object):void{if(r.close!=null&&r.window!=null&&r.close.parent!=r.window)r.window.addChild(r.close as DisplayObject);}
  private static function hideClose(r:Object):void{if(r.close!=null&&r.close.parent!=null)r.close.parent.removeChild(r.close as DisplayObject);}
  private static function watch(d:Object,r:Object):void {
   if(r.timer)clearInterval(r.timer);
   var g:int=r.generation;var id:uint=0;
   id=setInterval(function():void{if(valid(d,r,g))tick(d,r,g);else{clearInterval(id);if(records[d]!==r)cleanup(r);}},200);r.timer=id;
  }
  public static function begin(d:Object,state:int,boxes:int,panel:Sprite,event:MouseEvent):Boolean {
   var r:Object=record(d);
   if((state!=0&&state!=5&&r.phase!='recovered')||panel.parent==null||DisplayObject(d).stage==null)return false;
   var b:Object=event.currentTarget;if(b==null||b.parent!=panel||!b.enabled)return false;
   var count:int=r.known?r.count:boxes,amount:int=int(b.count);if(amount<=0||amount>count)return false;
   cleanup(r);hideStatus(r);r.count=count-amount;r.known=true;r.phase='server';r.started=getTimer();r.generation++;r.requestId=null;r.send=null;r.amount=amount;
   var g:int=r.generation;watch(d,r);setTimeout(function():void{if(valid(d,r,g)&&r.phase=='server'){hideClose(r);}},0);
   return true;
  }
  public static function request(d:Object,id:String,amount:int,send:Function):void {
   if(d==null)return;var r:Object=record(d);r.requestId=id;r.amount=amount;r.send=send;r.phase='server';r.started=getTimer();hideClose(r);
  }
  private static function status(r:Object,text:String):void {
   if(r.window==null)return;
   if(r.status==null){var label:TextField=new TextField();label.defaultTextFormat=new TextFormat('Arial',12,0xffffff);label.mouseEnabled=false;label.width=510;label.height=20;label.x=15;label.y=r.window.height-78;r.status=label;}
   r.status.text=text;if(r.status.parent!=r.window)r.window.addChild(r.status);
  }
  private static function hideStatus(r:Object):void {if(r.status!=null&&r.status.parent!=null)r.status.parent.removeChild(r.status);if(r.retry!=null&&r.retry.parent!=null)r.retry.parent.removeChild(r.retry);}
  private static function retry(d:Object,r:Object):void {
   if(r.requestId==null||r.send==null)return;
   if(r.retry==null){var C:Class=getDefinitionByName('controls.buttons.h50px.GreyBigButton')as Class;var b:Object=new C();b.label='Retry';b.width=130;b.x=r.panel.x;b.y=r.panel.y;b.addEventListener(MouseEvent.CLICK,function(e:MouseEvent):void{if(records[d]!==r||r.phase!='server'||getTimer()-r.started<REQUEST_WAIT)return;r.started=getTimer();hideStatus(r);hideClose(r);status(r,'Retrying the same opening…');try{r.send('garage;containers_open;'+r.amount+';'+r.requestId);}catch(error:Error){showClose(r);status(r,'Connection unavailable. You can close this window.');}});r.retry=b;}
   if(r.retry.parent!=r.window)r.window.addChild(r.retry);
  }
  private static function tick(d:Object,r:Object,g:int):void {
   if(r.phase=='server'&&getTimer()-r.started>=REQUEST_WAIT){showClose(r);status(r,'Still waiting for rewards. Retry or Close.');retry(d,r);}
   else if(r.phase=='images')checkImages(d,r,g,getTimer()-r.started>=PREVIEW_WAIT);
   else if(r.phase=='displaying'&&getTimer()-r.started>Math.max(30000,r.rewardCount*8000+20000))renderError(d,new Error('Reward animation timed out'));
  }
  private static function ready(image:Object):Boolean {try{return image!=null&&image.isLoaded&&image.data is BitmapData&&image.data.width>0&&image.data.height>0;}catch(e:Error){return false;}}
  private static function placeholder():Object {var assets:Object=getDefinitionByName('era2019.containers.Assets');return assets.image(assets.preview);}
  public static function safeImage(reward:Object,resolve:Function):Object {try{var image:Object=resolve(reward);if(image!=null)return image;}catch(e:Error){}return placeholder();}
  public static function safeColor(value:String,apply:Function):void {try{apply(value);}catch(e:Error){}}
  public static function inventory(panel:Object,item:Object,rows:Array,apply:Function):void {if(rows==null)return;for each(var row:Object in rows){try{apply(panel,item,[row]);}catch(e:Error){}}}
  public static function prepare(d:Object,rewards:Object,start:Function):void {
   var r:Object=record(d);cleanupResources(r);hideStatus(r);r.phase='images';r.started=getTimer();r.rewards=rewards;r.rewardCount=rewards.length;r.start=start;r.entries=[];
   var g:int=r.generation;hideClose(r);watch(d,r);
   if(rewards.length==0){renderError(d,new Error('No rewards to display'));return;}
   r.collecting=true;var seen:Dictionary=new Dictionary(true);
   for each(var reward:Object in rewards){
    var image:Object=reward.image;
    if(ready(image))continue;
    if(image is Resource){
     if(seen[image])continue;seen[image]=true;
     var entry:Object={image:image,failed:false};r.entries.push(entry);
     var listener:ReplayImageListener=new ReplayImageListener(d,r,g,entry);entry.listener=listener;
     try{Resource(image).loadLazyResource(listener);}catch(error:Error){if(!ready(image))entry.failed=true;}
    }else{reward.image=placeholder();}
   }
   r.collecting=false;checkImages(d,r,g,false);
  }
  public static function imageEvent(d:Object,r:Object,g:int,entry:Object,failed:Boolean):void {if(!valid(d,r,g)||r.phase!='images')return;if(failed)entry.failed=true;if(!r.collecting)checkImages(d,r,g,false);}
  private static function checkImages(d:Object,r:Object,g:int,expired:Boolean):void {
   if(!valid(d,r,g)||r.phase!='images')return;
   for each(var entry:Object in r.entries)if(!entry.failed&&!ready(entry.image)&&!expired)return;
   for each(var reward:Object in r.rewards)if(!ready(reward.image))reward.image=placeholder();
   var start:Function=r.start;r.start=null;r.rewards=null;cleanupResources(r);hideStatus(r);r.phase='displaying';r.started=getTimer();
   try{start();}catch(error:Error){renderError(d,error);}
  }
  private static function cleanupResources(r:Object):void {for each(var entry:Object in r.entries){try{Resource(entry.image).removeLazyListener(entry.listener);}catch(e:Error){}ReplayImageListener(entry.listener).dispose();}r.entries=[];r.start=null;r.rewards=null;}
  private static function cleanup(r:Object):void {if(r.timer){clearInterval(r.timer);r.timer=0;}cleanupResources(r);}
  public static function renderError(d:Object,error:Object):void {var r:Object=records[d];if(r==null)return;cleanup(r);r.phase='recovered';hideStatus(r);status(r,'Rewards received. The preview could not finish.');controls(r);}
  public static function normalize(state:int,index:int,presents:Array):int {return state==4&&index>=presents.length-1?5:state;}
  public static function reset(plane:Sprite,closed:Sprite,opened:Sprite,light:Sprite,present:Sprite,multiplier:Object,layers:Array):void {
   for each(var layer:DisplayObject in layers)if(layer.parent!=null)layer.parent.removeChild(layer);DisplayObject(layers[3]).alpha=0;
   if(opened.parent!=null)opened.parent.removeChild(opened);if(light.parent!=null)light.parent.removeChild(light);plane.addChild(closed);closed.alpha=1;opened.alpha=0;light.alpha=0;
   present.removeChildren();present.alpha=0;present.scaleX=present.scaleY=1;multiplier.alpha=0;multiplier.scaleX=multiplier.scaleY=1;
  }
  public static function removed(d:Object):void {var r:Object=records[d];if(r==null)return;r.generation++;cleanup(r);hideStatus(r);r.send=null;r.requestId=null;r.panel=null;r.window=null;r.close=null;r.retry=null;r.status=null;delete records[d];}
 }
}
