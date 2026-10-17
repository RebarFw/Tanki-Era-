# Tanki Era portable launcher 3.1.0

The current download uses the original AIR SDK `CaptiveAppEntry.exe` bytes, named `Tanki Era.exe`, with the existing unpacked Adobe AIR runtime. Its executable sections match the earlier game entry point; the modified executable resource section and the custom .NET self-extracting wrapper are no longer shipped. The original valid Adobe signatures on the runtime DLLs are retained. The stock entry point is unsigned; no certificate trust changes or antivirus exclusions are used.

`src/TankiEraLauncher.as` and `src/tanki/updater/*.as` are the complete updater source. There is no encrypted payload, hidden executable, native-code patch, shell command or arbitrary executable download. Runtime filenames and SHA-256 hashes are fixed in `vendor-manifest.json` and `RuntimeManifest.as`.

The updater selects one GitHub commit, reads the eight fixed game asset names, bounds each response to 100 MiB, verifies Git SHA-1 blob identifiers, normalizes the public endpoint configuration, and builds a separate complete game directory. Runtime files are copied locally only after verifying the fixed vendor hashes. Local version receipts and files are checked with SHA-256 before reuse. An update failure falls back only to an independently verified saved generation. The native game starts in its own process using the original game descriptor and identity.

The game's SWFs and artwork are unchanged from the owner-tested October 17 build. Automated tests cover updater behavior, hashing, process lifetime and the offline screen; these tests do not substitute for a new player login/garage/battle playthrough in this packaging.

## Verification

- 30 digest checks, including SHA-1/SHA-256 boundary cases and the complete 50,239,295-byte game library.
- 40 updater checks with inert fixtures: first update, unchanged launch, metadata-only commits, changed-library update, verified offline fallback, corrupted download/cache/runtime, incomplete versions and unsafe endpoint/pointer rejection.
- 65 checks of the real package and real GitHub assets. The published library remains byte-identical to SHA-256 `6c2c9eb0856ee2cda3b0f5f3b43e4ae4475949a31054a047d23cf953074d36f4`.
- The actual portable updater prepared the current public GitHub release and passed game, Flash policy and resource connection checks.
- A stock-runtime child process continued after its updater parent exited.
- The exact updater UI classes displayed only `Server is offline` and `OK` against an isolated unavailable endpoint.
- Microsoft Defender scanned the package without remediation and reported no threats.

## Scan reports

- [Current ZIP: 0/64](https://www.virustotal.com/gui/file/00187bd529c643d7d5c221eb2aa920e6a1219d0b8af699ed83a912e1f55946d8)
- [Current updater SWF: 0/58](https://www.virustotal.com/gui/file/a752c3b351fa6b2f0a189057080a01e633748b9ac301207c4aa3cdb655bda6a8)
- [Stock native entry point](https://www.virustotal.com/gui/file/03e67b6cd84650a56d6ed8f9a8c04de14c5660ecd715dc5cd4c7e8cf04acf886)
- [Adobe AIR.dll](https://www.virustotal.com/gui/file/e5efca0b15127161f055826b89dbd115940f0748f025464cb94eaf0766b3a90e)
- [NPSWF32.dll](https://www.virustotal.com/gui/file/b99a91d965af4e4941a26ae785713e12bb86f010d1adc6079bdd3ffdc896a69d)
- [NPSWF64.dll](https://www.virustotal.com/gui/file/a6f05dc1f9e24e79dbdc87f35b57b9a49eab03b1ac057df0bae669a60fb24e60)
- [WebKit.dll](https://www.virustotal.com/gui/file/df04691727871b9b099a374cac70dd7e0808d992b6373b6fe6228107a5e224fb)
- [Unchanged game library: 0/61](https://www.virustotal.com/gui/file/6c2c9eb0856ee2cda3b0f5f3b43e4ae4475949a31054a047d23cf953074d36f4)

Scan results apply only to their exact hashes and analysis dates. VirusTotal warns that a multi-file archive above its extraction limits may not receive complete per-file inspection, so native binaries and the updater are reviewed individually as well. A zero-detection report is not proof that legacy AIR/Flash has no vulnerabilities. The retained runtime still needs a separate compatibility-tested upgrade before claiming modern runtime security support.

Previous 2.0.1 packages had unresolved detections. They are superseded by this release; their source and artifacts remain in Git history for auditability. No history has been rewritten, and no antivirus vendor report has been suppressed.

## Build

Use Python 3, Java and a trusted local AIR/Flex compiler SDK that provides `com.adobe.flash.compiler.clients.MXMLC` and `airglobal.swc`. The tested compiler classpath includes `guava-compiler.jar` and `commons-io-2.11.0.jar`; these developer tools are not distributed to players. Supply the current public release ZIP as the source of the byte-verified vendor runtime:

```powershell
python launcher/build.py --sdk C:/Tools/AIR --java C:/Tools/Java/bin/java.exe --base-zip downloads/Tanki-Era.zip --output out
```

The builder copies only fixed allowlisted vendor files, checks their hashes, compiles the supplied source, and writes `out/Tanki era.zip`. It does not run any extracted or downloaded executable. Use an empty output directory. A different compiler/SDK can produce a different SWF; scan and test that exact output before publishing.

A rebuild from the published source was also decompiled and compared with the scanned updater: all seven classes matched exactly. MXMLC can reorder scripts and constant pools when source paths differ, so this is a semantic source check rather than a promise of identical SWF file hashes. The download remains the exact scanned ZIP.
