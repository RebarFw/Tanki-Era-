# Player diagnostics policy

The public `assets/library.swf` disables the extra `ClientLog.write` and
`ClientLog.startup` diagnostic hooks. These are immediate AVM2 returns, so the
player library neither creates/appends `TankiEra_diagnostics.log` on the desktop
nor starts the `Tanki_client_latest` diagnostic SharedObject or batch timer.
The normal logging service API, errors, gameplay and UI remain intact.

The two developer libraries in the Lovesick1 workspace retain their existing
diagnostics. Keep this distinction when publishing future library changes:
**do not copy the developer library directly over the public asset.**

Compile the supplied converter with FFDec 26.2.1 and create a fresh output file:

```powershell
javac -cp C:/tools/ffdec.jar -d C:/build client/diagnostics/PublicLibrary.java
java -Xmx1600M -cp "C:/tools/ffdec.jar;C:/build" PublicLibrary C:/dev/library.swf C:/build/library.public.swf
java -Xmx1600M -cp "C:/tools/ffdec.jar;C:/build" PublicLibrary --verify C:/dev/library.swf C:/build/library.public.swf
```

The converter checks the exact class/package and preserves method signatures.
Verification restores the two original method bodies in memory and compares all
serialized ABC data; every other code definition and non-code asset must match.
It also accepts an already silent input. It never modifies the input file.

Validate the resulting library in AIR, then publish it as `assets/library.swf`
and update `SHA256SUMS.txt` in the same commit. The existing streaming launcher
uses the new library on the next full game restart. Existing desktop log files
from an older release are not deleted.
