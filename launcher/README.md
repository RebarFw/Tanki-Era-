# v1.2-based direct client

The package keeps the supplied v1.2 native executable, runtime, icons, StandaloneLoader and artwork. Only the original Prelauncher connection/default-language/link handling and the application descriptor are adjusted. The legacy window-resize callback accepts its Event argument correctly.

The main game library and Loader are requested directly from the fixed HTTPS GitHub assets URL, using the old launch flow. Local loader/library paths in the shared socket config are ignored by this streaming client, preserving compatibility with older cached clients that use the same config.

The full game library is unchanged. A 1,345-byte local clan entry implements the existing `initialize(bar, network, locale)` interface and streams the unchanged full clan module from GitHub into the AIR application sandbox. It adds no new UI or executable process. The full module remains **assets/ClanAddon.swf**; never overwrite it with the tiny local entry.

The original v1.2 source folder is untouched. No third-party antivirus uploads or scans were performed for this revision, as requested by the owner. Previous release scan counts are not claims about this new ZIP.

Validation: the v1.2 native runtime reached login/register using the current GitHub library in a real launch probe, and the complete clan module loaded from GitHub. No credentials were submitted or account created. No game library file was written locally. Executable/runtime/icon hashes match the supplied v1.2 client, and all original artwork/font/non-code SWF tags are retained. A fresh battle/garage playthrough was not performed.

## Rebuild

Requires the original v1.2 folder, Python 3, Java, FFDec and a trusted AIR/Flex compiler SDK. The tested compiler classpath uses guava-compiler.jar and commons-io-2.11.0.jar alongside the SDK libraries.

```powershell
python launcher/build.py --template "C:/path/to/Tanki era v1.2" --ffdec C:/tools/ffdec.jar --sdk C:/tools/AIR --java C:/tools/Java/bin/java.exe --output out
```

Use a fresh output directory. The script applies the supplied AS3 source to the original Prelauncher, compiles the small clan entry and packages the native client. It does not run downloaded executables, install certificates or change security settings. Remove any obsolete installer hash because the updated SWF no longer matches it.
