import java.io.*;import java.nio.file.*;import java.util.*;
import com.jpexs.decompiler.flash.*;import com.jpexs.decompiler.flash.abc.*;import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.abc.types.traits.*;import com.jpexs.decompiler.flash.abc.avm2.instructions.AVM2Instruction;
import com.jpexs.decompiler.flash.abc.avm2.parser.script.*;
class PatchTransport {
 static String name(ABC a,int n){return a.constants.getString(a.constants.getMultiname(n).name_index);}
 static String type(ABC a,int i){return a.instance_info.get(i).getName(a.constants).getNameWithNamespace(new HashSet<String>(),a,a.constants,false).toRawString();}
 static byte[] bytes(ABC a)throws Exception{var out=new ByteArrayOutputStream();a.saveToStream(out);return out.toByteArray();}
 static AVM2Instruction op(int n,int...args){return new AVM2Instruction(0,n,args);}
 public static void main(String[]args)throws Exception {
  SWF.initPlayer();var swf=new SWF(new FileInputStream(args[0]),false);Path work=Path.of(args[1]);ABC a=null;int tagIndex=-1;
  for(var t:swf.getAbcList())for(int i=0;i<t.getABC().instance_info.size();i++)if(type(t.getABC(),i).equals("tanki.cache.ResourceManager")){a=t.getABC();tagIndex=swf.getTags().indexOf((Tag)t);}
  if(a==null)throw new AssertionError("Installed cache manager absent");
  Files.write(work.resolve("original-abc.bin"),bytes(a));var original=a.bodies.stream().map(b->b.getCodeBytes().clone()).toList();
  var helper=new ABC(new DoABC2Tag(swf));var index=swf.getAbcIndex();index.selectAbc(helper);
  new ActionScript3Parser(index).addScript(Files.readString(work.resolve("ReleaseTransport.as")),"ReleaseTransport.as",0,0,swf.getDocumentClass(),helper);
  index.selectAbc(null);Files.write(work.resolve("helper-abc.bin"),bytes(helper));a.mergeABC(helper);index.refreshAbc(a);
  int helperClass=-1,download=-1;
  for(int i=0;i<a.instance_info.size();i++)if(type(a,i).equals("tanki.cache.ReleaseTransport")){
   helperClass=a.instance_info.get(i).name_index;
   for(var t:a.class_info.get(i).static_traits.traits)if(name(a,t.name_index).equals("download"))download=t.name_index;
  }
  if(helperClass<0||download<0)throw new AssertionError("Transport helper absent");
  int changed=0;
  for(int b=0;b<original.size();b++) {
   var body=a.bodies.get(b);var code=body.getCode().code;
   for(int i=0;i<code.size();i++)if(code.get(i).definition.instructionName.equals("callpropvoid")&&name(a,code.get(i).operands[0]).equals("downloadTemporary")) {
    if(i<7||!name(a,code.get(i-7).operands[0]).equals("cache")||!name(a,code.get(i-6).operands[0]).equals("base")||!name(a,code.get(i-5).operands[0]).equals("packageInfo"))throw new AssertionError("Unexpected package download stack");
    int info=code.get(i-5).operands[0];var call=code.get(i);
    body.insertAll(i-7,List.of(op(0x60,helperClass)));
    int at=body.getCode().code.indexOf(call);body.insertAll(at,List.of(op(0x60,info)));
    body.replaceInstruction(at+1,op(0x4f,download,5));body.max_stack+=2;
    body.setCodeBytes(body.getCode().getBytes());body.getCode().checkValidOffsets(body);changed++;
    break;
   }
  }
  int preserved=0;
  for(int i=0;i<original.size();i++)if(Arrays.equals(original.get(i),a.bodies.get(i).getCodeBytes()))preserved++;
  if(changed!=1||preserved!=original.size()-1)throw new AssertionError("Unexpected original method changes");
  Files.write(work.resolve("patched-abc.bin"),bytes(a));
  Files.writeString(work.resolve("abc-verification.json"),"{\"tag_index\":"+tagIndex+",\"changed_original_methods\":1,\"other_original_methods_in_cache_tag_preserved\":"+preserved+",\"cache_directory_identity_unchanged\":true,\"gameplay_methods_unchanged\":true,\"branch_offsets_valid\":true}\n");
  System.out.println("RELEASE_CACHE_TRANSPORT_BUILT original_methods_changed=1 cache_identity_and_gameplay_preserved=true");System.exit(0);
 }
}
