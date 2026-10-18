import java.io.*;import java.nio.file.*;import java.util.*;
import com.jpexs.decompiler.flash.*;import com.jpexs.decompiler.flash.abc.*;import com.jpexs.decompiler.flash.tags.*;
class UpdateLoadingText {
 static byte[] bytes(ABC a)throws Exception{var out=new ByteArrayOutputStream();a.saveToStream(out);return out.toByteArray();}
 public static void main(String[]args)throws Exception{
  SWF.initPlayer();var swf=new SWF(new FileInputStream(args[0]),false);ABC selected=null;int tagIndex=-1;
  for(var tag:swf.getAbcList())for(var info:tag.getABC().instance_info){
   var a=tag.getABC();String name=info.getName(a.constants).getNameWithNamespace(new HashSet<String>(),a,a.constants,false).toRawString();
   if(name.equals("tanki.cache.ResourceManager")){selected=a;tagIndex=swf.getTags().indexOf((Tag)tag);}
  }
  if(selected==null)throw new AssertionError("Installed cache manager absent");
  var a=selected;var original=bytes(a);var old=new HashMap<Integer,String>();
  String message="Getting things ready! First launch may take a few minutes. Next time will be faster! ";
  var bodies=a.bodies.stream().map(b->b.getCodeBytes().clone()).toList();
  for(int i=1;i<a.constants.getStringCount();i++){
   String value=a.constants.getString(i);
   if(value.equals("Resources: ")||value.equals("Resources: 0/0")){
    old.put(i,value);a.constants.setString(i,message+(value.endsWith("0/0")?"0/0":""));
   }
  }
  if(old.size()!=2)throw new AssertionError("Unexpected loading text count: "+old.size());
  Path work=Path.of(args[1]);Files.write(work.resolve("original-abc.bin"),original);Files.write(work.resolve("patched-abc.bin"),bytes(a));
  for(int i=0;i<bodies.size();i++)if(!Arrays.equals(bodies.get(i),a.bodies.get(i).getCodeBytes()))throw new AssertionError("Method body changed");
  for(var entry:old.entrySet())a.constants.setString(entry.getKey(),entry.getValue());
  if(!Arrays.equals(original,bytes(a)))throw new AssertionError("Unrelated ABC change");
  Files.writeString(work.resolve("abc-verification.json"),"{\"tag_index\":"+tagIndex+",\"changed_text_constants\":2,\"all_method_bodies_unchanged\":true,\"all_other_abc_bytes_unchanged\":true,\"progress_counter_preserved\":true}\n");
  System.out.println("FRIENDLY_LOADING_TEXT_VERIFIED constants_changed=2 code_unchanged=true");System.exit(0);
 }
}
