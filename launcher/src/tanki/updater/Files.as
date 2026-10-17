package tanki.updater {
 import flash.filesystem.*;import flash.utils.*;
 public final class Files {
  public static function read(file:File):ByteArray{var f:FileStream=new FileStream();var b:ByteArray=new ByteArray();f.open(file,FileMode.READ);try{f.readBytes(b);}finally{f.close();}return b;}
  public static function text(file:File):String{var b:ByteArray=read(file);return b.readUTFBytes(b.length).replace(/^\uFEFF/,"");}
  public static function write(file:File,b:ByteArray):void{file.parent.createDirectory();var f:FileStream=new FileStream();f.open(file,FileMode.WRITE);try{f.writeBytes(b);}finally{f.close();}}
  public static function writeText(file:File,s:String):void{var b:ByteArray=new ByteArray();b.writeUTFBytes(s);write(file,b);}
  public static function sha(file:File,complete:Function,error:Function,blob:Boolean=false):void {
   var f:FileStream=new FileStream();var d:Digest=new Digest();var git:Digest=blob?new Digest("sha1"):null;var stopped:Boolean=false;
   try{f.open(file,FileMode.READ);if(git){var prefix:ByteArray=new ByteArray();prefix.writeUTFBytes("blob "+file.size+"\u0000");git.update(prefix);}}
   catch(e:Error){error(e);return;}
   function tick():void {
    if(stopped)return;
    try{
     if(f.bytesAvailable){var b:ByteArray=new ByteArray();f.readBytes(b,0,Math.min(262144,f.bytesAvailable));d.update(b);if(git)git.update(b);b.clear();setTimeout(tick,1);}
     else{stopped=true;f.close();complete({sha256:d.finish(),blob:git?git.finish():null});}
    }catch(e:Error){stopped=true;try{f.close();}catch(ignore:Error){}error(e);}
   }
   setTimeout(tick,1);
  }
 }
}
