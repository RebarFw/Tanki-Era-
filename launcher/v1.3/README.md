# Tanki Era v1.3 compact player client

Built from the current client game folder. The v1.2 package is only a layout reference. The current native executable, AIR runtime, icons, communicator images, launcher artwork and fonts are retained. Game library, Loader and the full current clan module stream from the owner's fixed GitHub assets path.

Each launch resolves GitHub main to an immutable commit before loading socket configuration, Loader, library and clan module. This prevents the legacy AIR HTTP cache from keeping an older branch-URL library after a game update. A small public revision pointer in the writable application storage directory keeps the clan entry on the same commit; no game library is saved locally. Shared socket settings that name a local Loader or library are ignored by this streaming package. The resource/game endpoint is read from the public GitHub socket configuration. The package does not contain a private or localhost socket file, the main game library, caches, player logs, developer backups, server files or account data.

The original startup animation now tolerates unavailable gear bitmap data, and cleanup does not unregister absent callbacks. The current Prelauncher's window-resize callback accepts its Event argument. These changes preserve the existing UI and artwork. The package adds no updater screen or separate updater process.

The full game library is the current owner client library, including the Striker knockback and spawn-input fixes. The lightweight local clan entry retains initialize(bar, network, locale) and loads the full current module from assets/ClanAddon.swf.

The packaged executable/runtime are the existing current files. No certificate, installer, administrator setting or security-setting change is required by this build.

## Rebuild

Use the current client game folder as the template. Requires Python 3, Java, FFDec and the trusted AIR/Flex SDK already used for the client.

```powershell
python launcher/v1.3/build.py --template "C:/path/to/current-client/game" --ffdec C:/tools/ffdec.jar --sdk C:/tools/AIR --java C:/tools/Java/bin/java.exe --output out-v13
```

The build copies a fixed allowlist of native/runtime/image files, applies the supplied current launcher source, compiles the small clan entry and creates Tanki Era v1,3.zip. Use a fresh output directory. The ZIP contains the complete portable folder; extract it before launching Tanki Era.exe.

Native validation reached login/register and loaded the full clan module using the real GitHub/server endpoints without submitting credentials. A complete live login, garage and battle playthrough is not claimed by that startup check.
