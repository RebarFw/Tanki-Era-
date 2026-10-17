package tanki.updater {
 import flash.utils.ByteArray;import flash.utils.Endian;
 /** Plain SHA-1/SHA-256 for Git blob integrity and local SHA-256 receipts.
  * Algorithms/constants: NIST FIPS 180-4. No encryption or executable payloads.
  */
 public final class Digest {
  private var sha1:Boolean;private var h:Vector.<uint>;private var w:Vector.<uint>=new Vector.<uint>(80,true);
  private var tail:ByteArray=new ByteArray();private var length:Number=0;private var finished:Boolean=false;
  private static const K:Vector.<uint>=Vector.<uint>([
   0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
   0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
   0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
   0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
   0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
   0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
   0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
   0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2]);
  public function Digest(algorithm:String="sha256") {
   if(algorithm!="sha1"&&algorithm!="sha256")throw new ArgumentError("Unsupported digest");
   sha1=algorithm=="sha1";h=sha1?Vector.<uint>([0x67452301,0xefcdab89,0x98badcfe,0x10325476,0xc3d2e1f0]):Vector.<uint>([0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19]);
  }
  private static function rr(x:uint,n:uint):uint{return (x>>>n)|(x<<(32-n));}
  private static function rl(x:uint,n:uint):uint{return (x<<n)|(x>>>(32-n));}
  public function update(data:ByteArray):void {
   if(finished)throw new Error("Digest already finished");length+=data.length;
   var at:uint=0;var old:uint=data.position;var endian:String=data.endian;data.endian=Endian.BIG_ENDIAN;
   if(tail.length){var take:uint=Math.min(64-tail.length,data.length);tail.position=tail.length;tail.writeBytes(data,0,take);at=take;if(tail.length==64){block(tail,0);tail.clear();}}
   while(at+64<=data.length){block(data,at);at+=64;}
   if(at<data.length){tail.position=tail.length;tail.writeBytes(data,at,data.length-at);}
   data.position=old;data.endian=endian;
  }
  private function block(input:ByteArray,at:uint):void {
   input.endian=Endian.BIG_ENDIAN;input.position=at;var i:uint;for(i=0;i<16;i++)w[i]=input.readUnsignedInt();
   var a:uint=h[0],b:uint=h[1],c:uint=h[2],d:uint=h[3],e:uint=h[4],f:uint,g:uint,j:uint,t:uint;
   if(sha1){
    for(i=16;i<80;i++)w[i]=rl(w[i-3]^w[i-8]^w[i-14]^w[i-16],1);
    for(i=0;i<80;i++){
     if(i<20){f=(b&c)|((~b)&d);g=0x5a827999;}else if(i<40){f=b^c^d;g=0x6ed9eba1;}else if(i<60){f=(b&c)|(b&d)|(c&d);g=0x8f1bbcdc;}else{f=b^c^d;g=0xca62c1d6;}
     t=uint(rl(a,5)+f+e+g+w[i]);e=d;d=c;c=rl(b,30);b=a;a=t;
    }
    h[0]=uint(h[0]+a);h[1]=uint(h[1]+b);h[2]=uint(h[2]+c);h[3]=uint(h[3]+d);h[4]=uint(h[4]+e);
   }else{
    for(i=16;i<64;i++){var s0:uint=rr(w[i-15],7)^rr(w[i-15],18)^(w[i-15]>>>3);var s1:uint=rr(w[i-2],17)^rr(w[i-2],19)^(w[i-2]>>>10);w[i]=uint(w[i-16]+s0+w[i-7]+s1);}
    f=h[5];g=h[6];j=h[7];
    for(i=0;i<64;i++){
     var big1:uint=rr(e,6)^rr(e,11)^rr(e,25);var choose:uint=(e&f)^((~e)&g);var t1:uint=uint(j+big1+choose+K[i]+w[i]);
     var big0:uint=rr(a,2)^rr(a,13)^rr(a,22);var majority:uint=(a&b)^(a&c)^(b&c);var t2:uint=uint(big0+majority);
     j=g;g=f;f=e;e=uint(d+t1);d=c;c=b;b=a;a=uint(t1+t2);
    }
    h[0]=uint(h[0]+a);h[1]=uint(h[1]+b);h[2]=uint(h[2]+c);h[3]=uint(h[3]+d);h[4]=uint(h[4]+e);h[5]=uint(h[5]+f);h[6]=uint(h[6]+g);h[7]=uint(h[7]+j);
   }
  }
  public function finish():String {
   if(finished)throw new Error("Digest already finished");finished=true;
   tail.position=tail.length;tail.writeByte(128);while(tail.length%64!=56)tail.writeByte(0);
   tail.endian=Endian.BIG_ENDIAN;tail.writeUnsignedInt(uint(Math.floor(length/536870912)));tail.writeUnsignedInt(uint(length*8));
   for(var at:uint=0;at<tail.length;at+=64)block(tail,at);tail.clear();
   var result:String="";for each(var n:uint in h){var s:String=n.toString(16);while(s.length<8)s="0"+s;result+=s;}return result;
  }
  public static function text(value:String,algorithm:String="sha256"):String {var bytes:ByteArray=new ByteArray();bytes.writeUTFBytes(value);var d:Digest=new Digest(algorithm);d.update(bytes);return d.finish();}
 }
}
