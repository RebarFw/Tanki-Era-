package protanki.launcher.controls.toppanel
{
   import flash.display.DisplayObject;
   import flash.events.MouseEvent;
   import flash.net.URLRequest;
   import flash.net.navigateToURL;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import flash.text.TextLineMetrics;
   import flash.ui.Mouse;
   import protanki.launcher.Locale;
   import protanki.launcher.controls.LocalizedControl;
   import protanki.launcher.makeup.MakeUp;

   public class TopPanelButton extends LocalizedControl
   {

      public static const GAME:String = "game";

      public static const MATERIALS:String = "materials";

      public static const TOURNAMENTS:String = "tournaments";

      public static const FORUM:String = "forum";

      public static const WIKI:String = "wiki";

      public static const RATINGS:String = "ratings";

      public static const HELP:String = "help";

      public var BUTTON_WIDTH:int = 125;

      private var textField:TextField;

      private var type:String;

      public function TopPanelButton(param1:String)
      {
         super();
         this.type = param1;
         addEventListener("mouseOut",mouseOut);
         addEventListener("mouseOver",mouseOver);
         addEventListener("click",mouseClick);
         redraw();
      }

      private function redraw() : void
      {
         graphics.clear();
         graphics.lineStyle(0,0,0);
         graphics.beginFill(0,0);
         graphics.drawRect(0,0,BUTTON_WIDTH,TopPanel.topLineData.height);
         graphics.endFill();
      }

      private function mouseClick(param1:MouseEvent) : void
      {
         if(type == GAME || type == WIKI) return;
         navigateToURL(new URLRequest(Locale.current[type].link));
      }

      override public function switchLocale(param1:Locale) : void
      {
         removeChildren();
         if(param1[type] == null)
         {
            BUTTON_WIDTH = 0;
            return;
         }
         var _loc2_:TextFormat = new TextFormat();
         _loc2_.align = "center";
         _loc2_.font = MakeUp.getFont(param1);
         _loc2_.bold = true;
         _loc2_.size = 14;
         var _loc4_:DisplayObject = MakeUp.getIconMakeUp(type);
         verticalCenter(_loc4_);
         var _loc3_:DisplayObject = MakeUp.getActiveIconMakeUp(type);
         _loc3_.visible = false;
         verticalCenter(_loc3_);
         textField = new TextField();
         textField.autoSize = "right";
         textField.embedFonts = true;
         textField.defaultTextFormat = _loc2_;
         textField.selectable = false;
         textField.textColor = 16777215;
         textField.text = param1[type].text;
         var _loc5_:TextLineMetrics = textField.getLineMetrics(0);
         BUTTON_WIDTH = _loc5_.width + _loc4_.width + 30;
         textField.y = 50 - _loc5_.height >> 1;
         textField.x = 0;
         textField.width = BUTTON_WIDTH;
         textField.height = TopPanel.topLineData.height;
         _loc4_.x = _loc3_.x = 15;
         addChild(textField);
         addChild(_loc4_);
         addChild(_loc3_);
         graphics.clear();
         graphics.lineStyle(0,16711680,0);
         graphics.beginFill(0,0);
         graphics.drawRect(0,0,BUTTON_WIDTH,TopPanel.topLineData.height);
         graphics.endFill();
      }

      private function mouseOut(param1:MouseEvent) : void
      {
         Mouse.cursor = "auto";
         if(numChildren > 0)
         {
            textField.textColor = 16777215;
            getChildAt(1).visible = true;
            getChildAt(numChildren - 1).visible = false;
         }
      }

      private function mouseOver(param1:MouseEvent) : void
      {
         Mouse.cursor = "button";
         if(numChildren > 0)
         {
            textField.textColor = 65280;
            getChildAt(1).visible = false;
            getChildAt(numChildren - 1).visible = true;
         }
      }

      private function verticalCenter(param1:DisplayObject) : void
      {
         param1.y = 50 - param1.height >> 1;
      }
   }
}
