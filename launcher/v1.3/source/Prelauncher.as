package protanki.launcher
{
   import flash.desktop.NativeApplication;
   import flash.display.Loader;
   import flash.display.LoaderInfo;
   import flash.display.NativeWindow;
   import flash.display.NativeWindowInitOptions;
   import flash.display.Screen;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.net.URLLoader;
   import flash.net.URLRequest;
   import flash.system.ApplicationDomain;
   import flash.system.LoaderContext;
   import flash.utils.ByteArray;
   import flash.utils.getTimer;
   import flash.text.TextField;
   import flash.utils.clearTimeout;
   import flash.utils.setTimeout;
   import protanki.launcher.controls.LocalizedControl;
   import protanki.launcher.controls.background.Background;
   import protanki.launcher.controls.bottompanel.BottomPanel;
   import protanki.launcher.controls.buttons.ExitButton;
   import protanki.launcher.controls.buttons.StartButton;
   import protanki.launcher.controls.logo.Logo;
   import protanki.launcher.controls.selector.LocaleSelectionEvent;
   import protanki.launcher.controls.selector.LocalizationSelector;
   import protanki.launcher.controls.toppanel.TopPanel;
   import protanki.launcher.locales.Locales;
   import protanki.launcher.storage.DisplayState;
   import protanki.launcher.storage.Storage;

   public class Prelauncher extends Sprite
   {

      private static const GITHUB_ASSETS:String = "https://raw.githubusercontent.com/RebarFw/Tanki-Era-/main/assets/";

      private var launchInProgress:Boolean = false;
      private var launchRequested:Boolean = false;
      private var preparedBytes:ByteArray;
      private var preparedAt:int = 0;
      private var startButton:StartButton;
      private var gameWindowShown:Boolean = false;

      private var guiLayer:Sprite;

      private var tanksLauncherLoader:Loader;

      private var selector:LocalizationSelector;

      private var airParameters:Object;

      private var swf:String;

      private var library:String;

      private var resources:String;

      private var socketUrl:String;

      private var defaultLocale:Locale;

      private var displayStateTimeout:int = 0;

      private var window:NativeWindow;

      private var socketLoader:URLLoader;

      private var releaseAssets:String;

      private var releaseRevision:String;

      public function Prelauncher()
      {
         super();
         this.defaultLocale = LocalesFactory.getLocale(loaderInfo.parameters["lang"] || "en");
         this.swf = loaderInfo.parameters["swf"] || GITHUB_ASSETS + "Loader.swf";
         this.library = loaderInfo.parameters["library"] || GITHUB_ASSETS + "library.swf";
         this.resources = loaderInfo.parameters["resources"] || "http://tankiera.duckdns.org:18080";
         this.socketUrl = loaderInfo.parameters["socket"] || GITHUB_ASSETS + "socket.cfg";
         addEventListener("addedToStage",this.init);
      }

      private static function pointIsVisibleOnScreens(param1:Point, param2:Array) : Boolean
      {
         var _loc3_:* = undefined;
         for each(_loc3_ in param2)
         {
            if(param1.x + 100 < _loc3_.bounds.x + _loc3_.bounds.width && param1.y + 100 < _loc3_.bounds.y + _loc3_.bounds.height)
            {
               return true;
            }
         }
         return false;
      }

      private function init(param1:Event = null) : void
      {
         removeEventListener("addedToStage",this.init);
         stage.addEventListener("click",this.mouseClick);
         Locale.current = Storage.getLastSessionLocale(this.defaultLocale);
         this.configureStage();
         this.createGUI();
         this.prepareLaunch();
      }

      private function setCenterPosition() : void
      {
         var _loc1_:Rectangle = stage.nativeWindow.bounds;
         var _loc2_:Screen = Screen.getScreensForRectangle(_loc1_)[0];
         stage.stageWidth = 1000;
         stage.stageHeight = 600;
         stage.nativeWindow.maxSize = new Point(stage.nativeWindow.width,stage.nativeWindow.height);
         stage.nativeWindow.minSize = new Point(stage.nativeWindow.width,stage.nativeWindow.height);
         stage.nativeWindow.x = (_loc2_.bounds.width - stage.nativeWindow.width) / 2;
         stage.nativeWindow.y = (_loc2_.bounds.height - stage.nativeWindow.height) / 2;
      }

      private function configureStage() : void
      {
         stage.align = "TL";
         stage.scaleMode = "noScale";
         stage.quality = "best";
         stage.displayState = "normal";
         stage.stageWidth = 1000;
         stage.stageHeight = 600;
         this.setCenterPosition();
      }

      private function createGUI() : void
      {
         this.guiLayer = new Sprite();
         var _loc6_:StartButton = new StartButton(this.startPressed);
         this.startButton = _loc6_;
         var _loc1_:ExitButton = new ExitButton();
         var _loc7_:Logo = new Logo();
         var _loc5_:Background = new Background();
         var _loc4_:TopPanel = new TopPanel();
         var _loc2_:BottomPanel = new BottomPanel();
         this.selector = new LocalizationSelector();
         this.guiLayer.addEventListener("selection",this.switchLocale,false,0,true);
         this.guiLayer.addChild(_loc5_);
         this.guiLayer.addChild(_loc7_);
         this.guiLayer.addChild(_loc1_);
         this.guiLayer.addChild(_loc6_);
         this.guiLayer.addChild(_loc4_);
         this.guiLayer.addChild(_loc2_);
         addChild(this.guiLayer);
         _loc4_.addAlignRight(this.selector);
         var _loc3_:LocaleSelectionEvent = new LocaleSelectionEvent("selection",false,false);
         _loc3_.locale = Locale.current;
         this.switchLocale(_loc3_);
      }

      private function switchLocale(param1:LocaleSelectionEvent) : void
      {
         var _loc2_:int = 0;
         var _loc3_:* = null;
         Locale.current = param1.locale;
         _loc2_ = 0;
         while(_loc2_ < this.guiLayer.numChildren)
         {
            _loc3_ = this.guiLayer.getChildAt(_loc2_);
            if(_loc3_ is LocalizedControl)
            {
               _loc3_.switchLocale(param1.locale);
            }
            _loc2_++;
         }
      }

      public function get version() : String
      {
         return "1.3";
      }

      private function startPressed(param1:MouseEvent = null) : void
      {
         if(this.launchRequested) return;
         this.launchRequested = true;
         this.setStartBusy(true);
         Storage.lastSessionLocale = Locales.list.indexOf(Locale.current.name);
         if(this.preparedBytes != null && getTimer() - this.preparedAt <= 10000)
         {
            this.loadPreparedGame();
         }
         else if(!this.launchInProgress)
         {
            this.prepareLaunch();
         }
      }

      private function prepareLaunch() : void
      {
         if(this.launchInProgress) return;
         this.launchInProgress = true;
         this.preparedBytes = null;
         this.airParameters = {};
         this.airParameters["resources"] = this.resources;
         this.airParameters["swf"] = this.library;
         this.airParameters["lang"] = Locale.current.name;
         var releaseLoader:URLLoader = new URLLoader();
         releaseLoader.dataFormat = "text";
         releaseLoader.addEventListener("complete",this.onReleaseResolved);
         releaseLoader.addEventListener("ioError",this.onLoadingError);
         releaseLoader.addEventListener("securityError",this.onLoadingError);
         var releaseRequest:URLRequest = new URLRequest(this.cacheBust("https://api.github.com/repos/RebarFw/Tanki-Era-/git/ref/heads/main"));
         releaseRequest.useCache = false;
         releaseRequest.cacheResponse = false;
         releaseLoader.load(releaseRequest);
      }

      private function setStartBusy(busy:Boolean) : void
      {
         if(this.startButton == null) return;
         this.startButton.mouseEnabled = !busy;
         this.startButton.mouseChildren = !busy;
         this.selector.mouseEnabled = !busy;
         this.selector.mouseChildren = !busy;
         for(var i:int = 0; i < this.startButton.numChildren; i++)
         {
            var label:TextField = this.startButton.getChildAt(i) as TextField;
            if(label != null)
            {
               label.text = busy ? "Opening..." : Locale.current.playText;
               label.x = -label.getLineMetrics(0).width >> 1;
            }
         }
      }

      private function onReleaseResolved(event:Event) : void
      {
         try
         {
            var ref:Object = JSON.parse(URLLoader(event.target).data);
            var revision:String = String(ref.object.sha);
            if(!/^[0-9a-f]{40}$/.test(revision)) throw new Error("Invalid GitHub revision");
            this.releaseRevision = revision;
            this.releaseAssets = "https://raw.githubusercontent.com/RebarFw/Tanki-Era-/" + revision + "/assets/";
            this.swf = this.releaseAssets + "Loader.swf";
            this.library = this.releaseAssets + "library.swf";
            this.socketUrl = this.releaseAssets + "socket.cfg";
            this.airParameters["swf"] = this.library;
            this.airParameters["clientRevision"] = revision;
            var pointer:FileStream = new FileStream();
            pointer.open(File.applicationStorageDirectory.resolvePath("client-release.json"),FileMode.WRITE);
            try { pointer.writeUTFBytes(JSON.stringify({revision:revision})); }
            finally { pointer.close(); }
            this.socketLoader = new URLLoader();
            this.socketLoader.dataFormat = "text";
            this.socketLoader.addEventListener("complete",this.onSocketLoadingComplete);
            this.socketLoader.addEventListener("ioError",this.onLoadingError);
            this.socketLoader.addEventListener("securityError",this.onLoadingError);
            this.socketLoader.load(new URLRequest(this.socketUrl));
         }
         catch(error:Error)
         {
            this.onLoadingError(new Event("releaseError"));
         }
      }

      private function onSocketLoadingComplete(param1:Event = null) : void
      {
         var _loc4_:Object = JSON.parse(this.socketLoader.data);
         this.airParameters["ip"] = String(_loc4_.ip);
         this.airParameters["port"] = String(_loc4_.port);
         if(_loc4_.resources != null && _loc4_.resources.length > 0)
         {
            this.airParameters["resources"] = _loc4_.resources;
         }
         if(_loc4_.library != null && String(_loc4_.library).indexOf(this.releaseAssets) == 0)
         {
            this.airParameters["swf"] = _loc4_.library;
         }
         if(_loc4_.loader != null && String(_loc4_.loader).indexOf(this.releaseAssets) == 0)
         {
            this.swf = _loc4_.loader;
         }
         this.airParameters["swf"] = this.cacheBust(String(this.airParameters["swf"]));
         var _loc2_:URLRequest = new URLRequest(this.cacheBust(this.swf));
         var _loc3_:URLLoader = new URLLoader();
         _loc3_.dataFormat = "binary";
         _loc3_.addEventListener("complete",this.byteArrayLoadComplete);
         _loc3_.addEventListener("ioError",this.onLoadingError);
         _loc3_.addEventListener("securityError",this.onLoadingError);
         _loc3_.load(_loc2_);
      }

      private function onConnectError(param1:Event = null) : void
      {
         this.launchInProgress = false;
         this.launchRequested = false;
         this.preparedBytes = null;
         this.setStartBusy(false);
         stage.nativeWindow.visible = true;
      }

      private function onLoadingError(param1:Event) : void
      {
         var requested:Boolean = this.launchRequested;
         this.launchInProgress = false;
         this.launchRequested = false;
         this.preparedBytes = null;
         this.setStartBusy(false);
         if(requested) Alert.showMessage("Connection error!");
         stage.nativeWindow.visible = true;
      }

      private function byteArrayLoadComplete(param1:Event) : void
      {
         this.preparedBytes = param1.target.data as ByteArray;
         this.preparedAt = getTimer();
         this.launchInProgress = false;
         if(this.launchRequested) this.loadPreparedGame();
      }

      private function loadPreparedGame() : void
      {
         if(this.preparedBytes == null) return;
         this.launchInProgress = true;
         this.airParameters["lang"] = Locale.current.name;
         this.tanksLauncherLoader = new Loader();
         var context:LoaderContext = new LoaderContext(false,new ApplicationDomain(ApplicationDomain.currentDomain));
         context.parameters = this.airParameters;
         context.allowCodeImport = true;
         var info:LoaderInfo = this.tanksLauncherLoader.contentLoaderInfo;
         info.addEventListener("complete",this.onLauncherLoadingComplete,false,0,true);
         info.addEventListener("ioError",this.onLoadingError,false,0,true);
         info.addEventListener("securityError",this.onLoadingError,false,0,true);
         this.tanksLauncherLoader.loadBytes(this.preparedBytes,context);
      }

      private function mouseClick(param1:MouseEvent) : void
      {
         if(!(param1.target == this.selector || param1.target.parent != null && param1.target.parent == this.selector))
         {
            this.selector.closeList();
         }
      }

      private function onLauncherLoadingComplete(param1:Event) : void
      {
         var options:NativeWindowInitOptions = new NativeWindowInitOptions();
         options.renderMode = "direct";
         options.maximizable = true;
         this.window = new NativeWindow(options);
         this.window.minSize = new Point(1024,768);
         this.window.maxSize = new Point(4095,2880);
         this.window.stage.addChild(new LauncherContainer(this.tanksLauncherLoader,this));
         this.window.stage.stageWidth = 1024;
         this.window.stage.stageHeight = 768;
         this.window.addEventListener("closing",this.onClosing);
         this.window.addEventListener("move",this.saveDisplayStateDelayed);
         this.window.addEventListener("resize",this.saveDisplayStateDelayed);
         this.window.addEventListener("displayStateChange",this.saveDisplayStateDelayed);
         this.window.addEventListener("displayStateChange",this.onGameWindowReady);
         this.loadDisplayState();
      }

      private function onClosing(param1:Event) : void
      {
         NativeApplication.nativeApplication.exit();
      }

      private function saveDisplayStateDelayed(event:Event = null) : void
      {
         if(this.displayStateTimeout != 0)
         {
            clearTimeout(this.displayStateTimeout);
         }
         this.displayStateTimeout = setTimeout(this.saveDisplayState,100);
      }

      private function loadDisplayState() : void
      {
         this.displayStateTimeout = 0;
         var saved:DisplayState = Storage.getDisplayState();
         var position:Point = new Point(saved.x,saved.y);
         if(pointIsVisibleOnScreens(position,Screen.screens))
         {
            this.window.x = position.x;
            this.window.y = position.y;
         }
         else
         {
            this.setDefaultWindowSize();
         }
         this.window.stage.displayState = "normal";
         this.window.maximize();
         this.onGameWindowReady();
      }

      private function onGameWindowReady(event:Event = null) : void
      {
         if(this.gameWindowShown || this.window == null || this.window.displayState != "maximized") return;
         this.gameWindowShown = true;
         this.window.removeEventListener("displayStateChange",this.onGameWindowReady);
         this.window.visible = true;
         this.window.activate();
         stage.nativeWindow.visible = false;
      }

      private function setDefaultWindowSize() : void
      {
         this.window.y = 100;
         this.window.x = 100;
         this.window.width = 1024;
         this.window.height = 768;
      }

      private function saveDisplayState() : void
      {
         this.displayStateTimeout = 0;
         Storage.setDisplayState(this.window.x,this.window.y,this.window.width,this.window.height,this.window.stage.displayState == "fullScreenInteractive");
      }

      public function closeLauncher() : void
      {
         NativeApplication.nativeApplication.exit();
      }
      private function cacheBust(url:String) : String
      {
         if(url == null || url.length == 0) return url;
         return url + (url.indexOf("?") < 0 ? "?" : "&") + "rand=" + Math.random();
      }
   }
}
