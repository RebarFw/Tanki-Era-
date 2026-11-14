package tanki.cache
{
   import flash.utils.setTimeout;

   public class PackageQueue
   {
      private static const LIMIT:int = 5;
      private var cache:Object;
      private var pending:Array = [];
      private var active:int;
      private var scheduled:Boolean;

      public function PackageQueue(cache:Object)
      {
         this.cache = cache;
      }

      public static function start(cache:Object, manifest:Object, keys:Array):void
      {
         new PackageQueue(cache).prefetch(manifest, keys);
      }

      private function prefetch(manifest:Object, keys:Array):void
      {
         var index:int = 0;
         var checked:Object = {};
         var scan:Function = function():void
         {
            var end:int = Math.min(index + 24, keys.length);
            while(index < end)
            {
               var resource:Object = manifest.resources[keys[index++]];
               var info:Object = manifest.packages[resource["package"]];
               if(checked[info.sha256])
                  continue;

               var bundle:Object = cache.file(packagePath(info));
               if(bundle.exists && bundle.size == info.size)
               {
                  checked[info.sha256] = true;
                  continue;
               }

               for each(var entry:Object in resource.files)
               {
                  var objectFile:Object = cache.file("objects/" + entry.sha256);
                  if(!objectFile.exists || objectFile.size != entry.size)
                  {
                     checkInstalled(info, resource);
                     break;
                  }
               }
            }
            if(index < keys.length)
               setTimeout(scan, 0);
         };
         setTimeout(scan, 0);

         function checkInstalled(info:Object, resource:Object):void
         {
            cache.findInstalledResource(resource, function(path:String):void
            {
               if(path == null && !checked[info.sha256])
               {
                  checked[info.sha256] = true;
                  enqueue(info);
               }
            });
         }
      }

      private function enqueue(info:Object):void
      {
         pending.push(info);
         schedule();
      }

      private function schedule():void
      {
         if(scheduled || pending.length == 0 || active == LIMIT)
            return;
         scheduled = true;
         setTimeout(function():void
         {
            scheduled = false;
            while(active < LIMIT && pending.length > 0)
            {
               ++active;
               transfer(pending.shift());
            }
         }, 0);
      }

      private function packagePath(info:Object):String
      {
         return "packages/" + info.sha256 + ".tpk";
      }

      private function transfer(info:Object):void
      {
         var path:String = packagePath(info);
         var finished:Boolean;
         function finish(message:String):void
         {
            if(finished)
               return;
            finished = true;
            --active;
            schedule();
         }

         cache.acquire(info.sha256, function(release:Function):void
         {
            function reject(message:String):void
            {
               release();
               finish(message);
            }

            cache.verify(path, info.size, info.sha256, function(valid:Boolean):void
            {
               if(valid)
               {
                  release();
                  finish(null);
                  return;
               }

               CacheTransfers.download(cache, "", function(temp:String):void
               {
                  try
                  {
                     cache.promoteTemporary(temp, path);
                     cache.rememberVerified(path, info.size, info.sha256);
                  }
                  catch(error:Error)
                  {
                     CacheTransfers.discard(cache, temp);
                     reject(error.toString());
                     return;
                  }
                  release();
                  finish(null);
               }, reject, info);
            });
         }, finish);
      }
   }
}
