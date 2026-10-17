# Tanki Era client 3.3.0

The player folder contains `Tanki Era.exe`, `Adobe AIR`, `icons`, `META-INF` and `mimetype`. The bootstrap and game entry are ordinary SWFs under `META-INF/AIR`, referenced by the application descriptors. They are included in the public source and checksum manifest; no packer or hidden executable is used.

## Startup

`TankiEraLauncher.as` embeds the exact original `Prelauncher.swf` for the initial ERA menu. Its artwork, buttons, language selector and social links are unchanged. It intercepts only the original Play action, prepares GitHub game assets quietly and then continues that same action in the game process. It displays no checking text, progress bar or online/offline status.

`Engine.as` retains the fixed asset allowlist, immutable revision selection, bounded HTTPS downloads, Git blob verification, local SHA-256 verification, complete-version activation and verified saved-version fallback. It never downloads a native executable. The local AIR runtime is copied only after matching the fixed vendor hashes. There are no server availability probes in the launcher.

`GameEntry.as` starts the already-verified local `Prelauncher.swf` by its absolute file URL, preserving its correct base directory, and activates the original Play control once. The selected language is passed in the URL parameters. This avoids asking the player to click Play twice. Reinvoking an already running game brings its visible window forward. The public game identity is `TankiEraPlayerGame`, separate from the host's development clients; server-side accounts and gameplay progress are unchanged.

## Icon

The native entry point retains the SDK's exact executable code sections and original Windows manifest. Only RT_ICON and RT_GROUP_ICON resources change. `brand_icon.py` documents that developer-side step: it encodes the existing ERA PNG pixels as standard Windows 32-bit DIB icon frames with transparency masks, using AIR's icon group ID 100. It does not redraw the artwork, change game behavior or modify endpoint protection.

The native entry remains unsigned. Its bundled Adobe runtime DLLs retain their existing valid Adobe signatures. No certificate is installed or trusted, no antivirus exclusion is required, and no elevation is requested.

## Validation

- 26 checks cover the exact original menu, warm/cold preparation, one-click start, Exit, unchanged button appearance, absent checking/download text and absence of server-status probes.
- 69 checks cover the exact five-item package layout, real GitHub assets, verified runtime/cached files, source and production-library preservation.
- The actual native AIR runtime reached the game's login/register UI through the new entry, with no account credentials submitted. No battle playthrough was repeated during this packaging change.
- The library remains byte-identical to the owner-tested build: SHA-256 `6c2c9eb0856ee2cda3b0f5f3b43e4ae4475949a31054a047d23cf953074d36f4`.
- The unmodified original Prelauncher has a pre-existing window-resize callback argument mismatch. Native diagnostics recorded the same eight startup resize events; the separate debug run identified their exact original method. Those known original events are recorded separately from unexpected errors. The login/register UI still loads; the menu SWF and game library were not edited to suppress them.

## Scan reports

- [Final ZIP: 0/66](https://www.virustotal.com/gui/file/296cf162e17b14e82998b241998576038862abae3e49e871c15911988fc96266)
- [Final icon executable: 0/71](https://www.virustotal.com/gui/file/8e5f12ae38573c60a39ae9f9aebd3ade3d5ec48a561f2b4598105118babef1fa)
- [Final menu bootstrap: 0/61](https://www.virustotal.com/gui/file/f25610084df6fbb52aa0fc791b646e96e038d8c29a23d2e5c4f1364246ea04ca)
- [Final game entry: 0/59](https://www.virustotal.com/gui/file/29a84338b3f6873c059af7b345c2ae0e44110e6921ce02cc57358fcf18ec95a2)
- [Unchanged game library](https://www.virustotal.com/gui/file/6c2c9eb0856ee2cda3b0f5f3b43e4ae4475949a31054a047d23cf953074d36f4)

The previously checked Adobe AIR.dll, NPSWF32.dll, NPSWF64.dll, WebKit.dll and stock captive entry bytes are unchanged. Archive inspection has extraction limits, so the ZIP result is supplemented by component checks. Scan results are point-in-time observations. The retained legacy AIR/Flash runtime still requires a separate compatibility-tested modernization effort; a zero-detection result is not a claim of universal security.

An earlier icon-resource diagnostic used PNG icon frames and received one Malwarebytes heuristic detection. That diagnostic is not the release. The final Windows DIB icon build preserves the same artwork pixels and executable code and reports 0/71. No antivirus vendor was contacted, no report was suppressed, and no security setting was changed.

## Build

Use Python 3, Java and a trusted AIR/Flex compiler SDK with `com.adobe.flash.compiler.clients.MXMLC` and `airglobal.swc`. The tested compiler uses `guava-compiler.jar` and `commons-io-2.11.0.jar` alongside its SDK libraries. These developer dependencies are not distributed to players.

```powershell
python launcher/build.py --sdk C:/Tools/AIR --java C:/Tools/Java/bin/java.exe --base-zip downloads/Tanki-Era.zip --output out
```

The build verifies and copies the native runtime from the supplied current ZIP, compiles the two supplied AS3 entry points, regenerates the runtime receipt for that exact compiled entry and creates `out/Tanki era.zip`. It never runs an extracted executable. Use a fresh output directory. Compiler-dependent script/constant ordering can change SWF hashes; test and scan the exact rebuilt output before publishing.

`brand_icon.py` is an optional developer audit/reproduction helper for the icon-only resource change. It requires Windows, Pillow and pefile. Player builds reuse the verified branded native entry from the base ZIP and do not need these tools.
