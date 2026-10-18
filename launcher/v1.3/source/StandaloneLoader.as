package
{
   import flash.desktop.NativeApplication;
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.display.Loader;
   import flash.display.LoaderInfo;
   import flash.display.Screen;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.geom.Matrix;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.net.URLLoader;
   import flash.net.URLRequest;
   import flash.system.ApplicationDomain;
   import flash.system.LoaderContext;
   import flash.utils.ByteArray;

   public class StandaloneLoader extends Sprite
   {

      private var logo:Class = tank_png$9d3d90e47a688ab93bb1f25fb1eed88c631725215;

      private var logoBmp:Bitmap;

      private var gearWheel:Class = mainGearWheel_png$d6974aa17b05d8ceac8b0af1f932d2dd2005691756;

      private var miniGearWheel:Class = §miniGearWheel_png$00f0077fde64e1605c3ce415bd3556e4-754222322§;

      private var guiLayer:Sprite;

      private var prelauncher:Loader;

      private var locale:String;

      protected var prelauncherSwf:String;

      private var wheelRotateFunctionBig:Function;

      private var wheelRotateFunctionSmall:Function;

      public function StandaloneLoader()
      {
         super();
         addEventListener("addedToStage",this.init);
      }

      private function init(param1:Event = null) : void
      {
         removeEventListener("addedToStage",this.init);
         stage.align = "TL";
         stage.scaleMode = "noScale";
         this.prelauncherSwf = loaderInfo.parameters["prelauncher"] || "Prelauncher.swf";
         this.locale = loaderInfo.parameters["locale"] || "en";
         LocalizedTexts.setLocale(this.locale);
         this.configureStage();
         this.createGUI();
         this.loadStandalone();
      }

      private function configureStage() : void
      {
         stage.align = "TL";
         stage.stageHeight = 256;
         stage.stageWidth = 256;
         stage.nativeWindow.maxSize = new Point(stage.nativeWindow.width,stage.nativeWindow.height);
         stage.nativeWindow.minSize = new Point(stage.nativeWindow.width,stage.nativeWindow.height);
         this.setCenterPosition();
      }

      private function createMainGearWheel() : void
      {
         var rotation:Number;
         var bitmapData:BitmapData = new this.gearWheel().bitmapData;
         if(bitmapData == null) return;
         var bitmap:Bitmap = new Bitmap(bitmapData);
         bitmap.x = 100;
         bitmap.y = 32;
         this.guiLayer.addChild(bitmap);
         rotation = 0;
         this.wheelRotateFunctionBig = function(param1:Event):void
         {
            var _loc3_:Matrix = new Matrix();
            _loc3_.translate(-bitmap.width / 2,-bitmap.height / 2);
            _loc3_.rotate(rotation--);
            _loc3_.translate(bitmap.height / 2,bitmap.width / 2);
            var _loc2_:BitmapData = new BitmapData(bitmap.width,bitmap.height,true,0);
            _loc2_.draw(bitmapData,_loc3_,null,"normal",null,true);
            bitmap.bitmapData = _loc2_;
         };
         addEventListener("enterFrame",this.wheelRotateFunctionBig);
      }

      private function createMiniGearWheel() : void
      {
         var rotation:Number;
         var bitmapData:BitmapData = new this.miniGearWheel().bitmapData;
         if(bitmapData == null) return;
         var bitmap:Bitmap = new Bitmap(bitmapData);
         bitmap.x = 50;
         bitmap.y = 105;
         this.guiLayer.addChild(bitmap);
         rotation = 0;
         this.wheelRotateFunctionSmall = function(param1:Event):void
         {
            var _loc3_:Matrix = new Matrix();
            _loc3_.translate(-bitmap.width / 2,-bitmap.height / 2);
            _loc3_.rotate(rotation++);
            _loc3_.translate(bitmap.height / 2,bitmap.width / 2);
            var _loc2_:BitmapData = new BitmapData(bitmap.width,bitmap.height,true,0);
            _loc2_.draw(bitmapData,_loc3_,null,"normal",null,true);
            bitmap.bitmapData = _loc2_;
         };
         addEventListener("enterFrame",this.wheelRotateFunctionSmall);
      }

      private function createGUI() : void
      {
         this.guiLayer = new Sprite();
         this.createMainGearWheel();
         this.createMiniGearWheel();
         this.logoBmp = new this.logo() as Bitmap;
         this.guiLayer.addChild(this.logoBmp);
         stage.addChild(this.guiLayer);
      }

      private function removeGUI() : void
      {
         if(this.wheelRotateFunctionBig != null) removeEventListener("enterFrame",this.wheelRotateFunctionBig);
         if(this.wheelRotateFunctionSmall != null) removeEventListener("enterFrame",this.wheelRotateFunctionSmall);
         stage.removeChild(this.guiLayer);
      }

      private function get version() : String
      {
         var _loc2_:XML = NativeApplication.nativeApplication.applicationDescriptor;
         var _loc1_:Namespace = _loc2_.namespace();
         return _loc2_._loc1_::versionNumber;
      }

      private function loadStandalone() : void
      {
         if(this.prelauncherSwf.indexOf("file") < 0)
         {
            this.prelauncherSwf += "?rand=" + Math.random();
         }
         var _loc1_:URLRequest = new URLRequest(this.prelauncherSwf);
         var _loc2_:URLLoader = new URLLoader();
         _loc2_.dataFormat = "binary";
         _loc2_.addEventListener("complete",this.byteArrayLoadComplete);
         _loc2_.addEventListener("ioError",this.onLoadingError);
         _loc2_.addEventListener("securityError",this.onLoadingError);
         _loc2_.load(_loc1_);
      }

      private function onLoadingError(param1:Event) : void
      {
         Alert.showMessage(LocalizedTexts.CONNECTION_ERROR);
      }

      private function isNewVersionAvailable(param1:String) : Boolean
      {
         if(this.version != param1)
         {
            Alert.showMessage(LocalizedTexts.NEW_VERSION_AVAILABLE(param1,this.version));
         }
         return this.version == param1;
      }

      private function byteArrayLoadComplete(param1:Event) : void
      {
         var _loc4_:LoaderInfo = null;
         var _loc2_:ByteArray = URLLoader(param1.target).data as ByteArray;
         this.prelauncher = new Loader();
         _loc4_ = this.prelauncher.contentLoaderInfo;
         _loc4_.addEventListener("complete",this.onLauncherLoadingComplete);
         _loc4_.addEventListener("ioError",this.onLoadingError);
         _loc4_.addEventListener("securityError",this.onLoadingError);
         var _loc3_:LoaderContext = new LoaderContext(false,ApplicationDomain.currentDomain);
         _loc3_.allowCodeImport = true;
         _loc3_.parameters = _loc4_.parameters;
         this.prelauncher.loadBytes(_loc2_,_loc3_);
      }

      private function setCenterPosition() : void
      {
         var _loc1_:Rectangle = stage.nativeWindow.bounds;
         var _loc2_:Screen = Screen.getScreensForRectangle(_loc1_)[0];
         stage.nativeWindow.x = (_loc2_.bounds.width - stage.nativeWindow.width) / 2;
         stage.nativeWindow.y = (_loc2_.bounds.height - stage.nativeWindow.height) / 2;
      }

      private function onLauncherLoadingComplete(param1:Event) : void
      {
         this.removeGUI();
         if(this.isNewVersionAvailable(this.prelauncher.getChildAt(0)["version"]))
         {
            stage.nativeWindow.maxSize = new Point(1050,650);
            stage.nativeWindow.minSize = new Point(stage.nativeWindow.width,stage.nativeWindow.height);
            stage.nativeWindow.width = 1000;
            stage.nativeWindow.height = 600;
            addChild(this.prelauncher.getChildAt(0));
            stage.stageWidth = 1000;
            stage.stageHeight = 600;
            stage.nativeWindow.maxSize = new Point(stage.nativeWindow.width,stage.nativeWindow.height);
            stage.nativeWindow.minSize = new Point(stage.nativeWindow.width,stage.nativeWindow.height);
            this.setCenterPosition();
         }
      }
   }
}
