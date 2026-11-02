import java.io.*;
import java.nio.file.*;
import java.util.*;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.abc.ABC;
import com.jpexs.decompiler.flash.abc.types.*;
import com.jpexs.decompiler.flash.abc.types.traits.*;
import com.jpexs.decompiler.flash.tags.*;

/** Produce the player library without changing the developer input library.
 * Requires FFDec 26.2.1. Only ClientLog.write/startup become immediate returns. */
public class PublicLibrary {
    record Target(ABCContainerTag tag, MethodBody body) {}
    static void require(boolean ok, String message) {
        if (!ok) throw new IllegalStateException(message);
    }
    static SWF read(String path) throws Exception {
        try (var in = Files.newInputStream(Path.of(path))) { return new SWF(in, true); }
    }
    static String name(ABC abc, int index) {
        return abc.constants.getString(abc.constants.getMultiname(index).name_index);
    }
    static List<Target> targets(SWF swf) {
        var result = new ArrayList<Target>();
        for (var tag : swf.getAbcList()) {
            var abc = tag.getABC();
            for (int i = 0; i < abc.instance_info.size(); i++) {
                var mn = abc.constants.getMultiname(abc.instance_info.get(i).name_index);
                if (!name(abc, abc.instance_info.get(i).name_index).equals("ClientLog")) continue;
                var ns = abc.constants.getNamespace(mn.namespace_index);
                if (!abc.constants.getString(ns.name_index).equals("alternativa.osgi.service.clientlog")) continue;
                for (var trait : abc.class_info.get(i).static_traits.traits) {
                    if (trait instanceof TraitMethodGetterSetter method &&
                            Set.of("write", "startup").contains(name(abc, trait.name_index))) {
                        var body = abc.findBody(method.method_info);
                        require(body != null, "Missing diagnostic body");
                        result.add(new Target(tag, body));
                    }
                }
            }
        }
        require(result.size() == 2, "Expected exactly ClientLog.write and ClientLog.startup");
        return result;
    }
    static boolean silent(MethodBody body) {
        return Arrays.equals(body.getCodeBytes(), new byte[]{0x47}) && body.exceptions.length == 0;
    }
    static void verify(SWF before, SWF after) {
        var oldTargets = targets(before); var newTargets = targets(after);
        require(before.getTags().size() == after.getTags().size(), "Tag count changed");
        int changed = 0, preserved = 0;
        for (int i = 0; i < before.getAbcList().size(); i++) {
            var oldAbc = before.getAbcList().get(i).getABC();
            var newAbc = after.getAbcList().get(i).getABC();
            require(oldAbc.bodies.size() == newAbc.bodies.size(), "Method count changed");
            for (int b = 0; b < oldAbc.bodies.size(); b++) {
                var oldBody = oldAbc.bodies.get(b); var newBody = newAbc.bodies.get(b);
                if (Arrays.equals(oldBody.getCodeBytes(), newBody.getCodeBytes())) preserved++;
                else {
                    final var selected = newBody;
                    require(newTargets.stream().anyMatch(t -> t.body == selected), "Unrelated method changed");
                    changed++;
                }
            }
        }
        for (int i = 0; i < newTargets.size(); i++) {
            var target = newTargets.get(i); var old = oldTargets.get(i);
            require(silent(target.body), "Public diagnostic entry point is not an immediate return");
            // Restoring the two bodies must recover every serialized ABC byte.
            target.body.setCodeBytes(old.body.getCodeBytes());
            target.body.exceptions = old.body.exceptions;
            target.body.getCode();
            target.body.setModified(); ((Tag)target.tag).setModified(true);
        }
        for (int i = 0; i < before.getTags().size(); i++) {
            var old = before.getTags().get(i); var restored = after.getTags().get(i);
            require(old.getId() == restored.getId(), "Tag order/type changed");
            if (old instanceof ABCContainerTag)
                require(Arrays.equals(old.getData(), restored.getData()), "ABC differs outside the two diagnostic bodies");
            else require(Arrays.equals(old.getOriginalData(), restored.getOriginalData()), "Non-code asset changed");
        }
        System.out.println("VERIFIED changed_methods=" + changed + " preserved_methods=" + preserved +
                " all_other_ABC_data_and_noncode_assets_preserved=true");
    }
    public static void main(String[] args) throws Exception {
        require(args.length == 2 || args.length == 3 && args[0].equals("--verify"),
                "Usage: PublicLibrary developer.swf player.swf OR PublicLibrary --verify developer.swf player.swf");
        if (args.length == 3) { verify(read(args[1]), read(args[2])); System.exit(0); }
        var swf = read(args[0]);
        for (var target : targets(swf)) {
            target.body.setCodeBytes(new byte[]{0x47}); // AVM2 returnvoid
            target.body.exceptions = new ABCException[0];
            target.body.getCode();
            target.body.setModified(); ((Tag)target.tag).setModified(true);
        }
        try (var out = Files.newOutputStream(Path.of(args[1]), StandardOpenOption.CREATE_NEW)) { swf.saveTo(out); }
        verify(read(args[0]), read(args[1]));
        System.exit(0);
    }
}
