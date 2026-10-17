package protanki.launcher.controls.bottompanel.PartnerLogo
{
   import flash.display.Bitmap;
   import flash.display.Sprite;
   import flash.events.MouseEvent;
   import flash.net.URLRequest;
   import flash.net.navigateToURL;
   import flash.ui.Mouse;

   public class PartnerLogo extends Sprite
   {

      public static var VK:String = "VK";

      public static var YOUTUBE:String = "YOUTUBE";

      public static var DISCORD:String = "DISCORD";

      public static var TELEGRAM:String = "TELEGRAM";

      private static var vkIcon:Class = §vkIcon_png$c4988c8636c12252cae1b71ae9bece62-911803205§;

      private static var youtubeIcon:Class = §youtubeIcon_png$497422960e8fd5e1451d3905bac2c246-1262728187§;

      private static var discordIcon:Class = discordIcon_png$1842ccf5ad1d1dd03883b7cd27c740dc1806320926;

      private static var telegramIcon:Class = telegramIcon_png$0e63ab1a4915df3760e336a1b9a25d00879327375;

      public var actualWidth:Number = 0;

      private var link:String;

      private var type:String;

      public function PartnerLogo(param1:String, param2:String)
      {
         var type:String = param1;
         var link:String = param2;
         super();
         this.link = link;
         this.type = type;
         addEventListener("mouseOver",function(param1:MouseEvent):void
         {
            Mouse.cursor = "button";
         });
         addEventListener("mouseOut",function(param1:MouseEvent):void
         {
            Mouse.cursor = "auto";
         });
         addEventListener("click",onClick);
         if(type != null)
         {
            addLogo(createIconByType(type));
         }
      }

      private function createIconByType(param1:String) : Bitmap
      {
         switch(param1)
         {
            case VK:
               return new vkIcon();
            case YOUTUBE:
               return new youtubeIcon();
            case DISCORD:
               return new discordIcon();
            case TELEGRAM:
               return new telegramIcon();
            default:
               throw new Error("Undefined icon type: " + param1);
         }
      }

      private function addLogo(param1:Bitmap) : void
      {
         actualWidth = param1.width;
         addChild(param1);
         param1.x = -param1.width >> 1;
         param1.y = -param1.height >> 1;
      }

      private function onClick(param1:MouseEvent) : void
      {
         if(type == YOUTUBE) navigateToURL(new URLRequest("https://www.youtube.com/@TankiEra"));
         else if(type == DISCORD) navigateToURL(new URLRequest("https://discord.com/invite/m5rtYWD4bf"));
      }
   }
}
