import java.io.*;
import java.nio.file.*;
import java.util.*;
import com.jpexs.decompiler.flash.*;
import com.jpexs.decompiler.flash.abc.*;
import com.jpexs.decompiler.flash.abc.avm2.instructions.AVM2Instruction;
import com.jpexs.decompiler.flash.abc.types.traits.TraitMethodGetterSetter;
import com.jpexs.decompiler.flash.tags.*;

class PatchPackageQueue {
    static String name(ABC abc, int index) {
        return abc.constants.getString(abc.constants.getMultiname(index).name_index);
    }
    static String className(ABC abc, int index) {
        return abc.instance_info.get(index).getName(abc.constants)
            .getNameWithNamespace(new HashSet<String>(), abc, abc.constants, false).toRawString();
    }
    static AVM2Instruction op(int opcode, int...args) {
        return new AVM2Instruction(0, opcode, args);
    }
    public static void main(String[] args) throws Exception {
        SWF.initPlayer();
        var swf = new SWF(new FileInputStream(args[0]), false);
        for (var tag : swf.getAbcList()) {
            var abc = tag.getABC();
            for (int i = 0; i < abc.instance_info.size(); ++i) {
                if (!className(abc, i).equals("tanki.cache.ResourceManager")) continue;
                int manager = i;
                var traits = abc.instance_info.get(manager).instance_traits.traits;
                int cache = traits.stream().filter(t -> name(abc, t.name_index).equals("cache"))
                    .findFirst().orElseThrow().name_index;
                int manifest = traits.stream().filter(t -> name(abc, t.name_index).equals("manifest"))
                    .findFirst().orElseThrow().name_index;
                int total = traits.stream().filter(t -> name(abc, t.name_index).equals("total"))
                    .findFirst().orElseThrow().name_index;
                var method = (TraitMethodGetterSetter) traits.stream()
                    .filter(t -> name(abc, t.name_index).equals("runNext")).findFirst().orElseThrow();
                var body = abc.bodies.get(abc.findBodyIndex(method.method_info));

                var compiled = new SWF(new FileInputStream(args[1]), false);
                int queue = -1;
                int transfers = -1;
                for (var helperTag : compiled.getAbcList()) {
                    ABC helper = helperTag.getABC();
                    int classOffset = abc.instance_info.size();
                    for (int k = 0; k < helper.instance_info.size(); ++k) {
                        String helperName = className(helper, k);
                        if (helperName.equals("tanki.cache.CacheTransfers")) transfers = classOffset + k;
                        if (helperName.equals("tanki.cache.PackageQueue")) queue = classOffset + k;
                    }
                    // The compiler emits a document class in its own tag. Other helper
                    // classes are exported as scripts from their compiled ABC.
                    if (abc.instance_info.size() <= Math.max(transfers, queue)) abc.mergeABC(helper);
                }
                if (queue < 0 || transfers < 0)
                    throw new IllegalStateException("Compiled cache helpers missing");
                int transport = abc.instance_info.get(transfers).name_index;
                int download = abc.class_info.get(transfers).static_traits.traits.stream()
                    .filter(t -> name(abc, t.name_index).equals("download")).findFirst().orElseThrow().name_index;
                int patched = 0;
                for (var callback : abc.bodies) {
                    var instructions = callback.getCode().code;
                    for (int j = 0; j < instructions.size(); ++j) {
                        var instruction = instructions.get(j);
                        if (!instruction.definition.instructionName.equals("callpropvoid")
                            || instruction.operands[1] != 5 || !name(abc, instruction.operands[0]).equals("download"))
                            continue;
                        for (int k = j - 1; k >= Math.max(0, j - 18); --k) {
                            var receiver = instructions.get(k);
                            if (!receiver.definition.instructionName.equals("getlex")
                                || !name(abc, receiver.operands[0]).equals("ReleaseTransport")) continue;
                            callback.replaceInstruction(k, op(0x60, transport));
                            callback.replaceInstruction(j, op(0x4f, download, 5));
                            callback.setCodeBytes(callback.getCode().getBytes());
                            callback.getCode().checkValidOffsets(callback);
                            ++patched;
                            break;
                        }
                    }
                }
                if (patched != 1) throw new IllegalStateException("Expected one original package transfer call");
                int queueName = abc.instance_info.get(queue).name_index;
                int start = abc.class_info.get(queue).static_traits.traits.stream()
                    .filter(t -> name(abc, t.name_index).equals("start")).findFirst().orElseThrow().name_index;

                var code = body.getCode().code;
                int target = -1;
                for (int j = 4; j < code.size(); ++j) {
                    var instruction = code.get(j);
                    if (instruction.definition.instructionName.equals("initproperty") && instruction.operands[0] == total
                        && code.get(j - 2).definition.instructionName.equals("getslot")
                        && code.get(j - 2).operands[0] == 2) {
                        if (target != -1) throw new IllegalStateException("Ambiguous common scope");
                        target = j + 1;
                    }
                }
                if (target == -1) throw new IllegalStateException("Common scope not found");
                // The previous conditional skip must still jump past this insertion.
                var skip = code.get(target - 9);
                if (!skip.definition.instructionName.equals("iffalse"))
                    throw new IllegalStateException("Unexpected common scope branch");
                var insertion = List.of(op(0x60, queueName), op(0xd0), op(0x66, cache),
                    op(0xd0), op(0x66, manifest), op(0x65, 1), op(0x6c, 2), op(0x4f, start, 3));
                int offset = skip.operands[0];
                body.insertAll(target, insertion);
                if (skip.operands[0] == offset)
                    skip.operands[0] += insertion.stream().mapToInt(AVM2Instruction::getBytesLength).sum();
                body.max_stack = Math.max(body.max_stack, 4);
                body.setCodeBytes(body.getCode().getBytes());
                body.getCode().checkValidOffsets(body);
                ((Tag)tag).setModified(true);
                try (var out = new FileOutputStream(args[2])) {
                    swf.saveTo(out);
                }
                System.exit(0);
            }
        }
        throw new IllegalStateException("Cache manager ABC missing");
    }
}
