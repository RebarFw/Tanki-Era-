package era2019.containers {
 import platform.client.fp10.core.resource.Resource;
 import platform.client.fp10.core.resource.IResourceLoadingListener;
 internal class ReplayImageListener implements IResourceLoadingListener {
  private var dialog:Object,record:Object,entry:Object;private var generation:int;
  public function ReplayImageListener(d:Object,r:Object,g:int,e:Object){dialog=d;record=r;generation=g;entry=e;}
  public function onResourceLoadingStart(resource:Resource):void{}
  public function onResourceLoadingComplete(resource:Resource):void{notify(false);}
  public function onResourceLoadingError(resource:Resource,message:String):void{notify(true);}
  public function onResourceLoadingFatalError(resource:Resource,message:String):void{notify(true);}
  private function notify(failed:Boolean):void{if(dialog!=null)ContainerReplay.imageEvent(dialog,record,generation,entry,failed);}
  public function dispose():void{dialog=null;record=null;entry=null;}
 }
}
