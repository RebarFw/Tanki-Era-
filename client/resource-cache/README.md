# GitHub Release cache transport

The existing v1.3 launcher resolves a GitHub commit on each Play launch and loads
`assets/library.swf` from that commit. No replacement player ZIP is required for
this transport update. Loader, launcher, fonts, artwork, and clan entry are retained.

`ReleaseTransport.as` is merged into the original cache ABC. `PatchTransport.java`
changes only the package-download call site; it retains the original cache
identity, object/package SHA-256 checks, extraction, and warm-cache behavior.
Use the previous published baseline `8ec63fd6fb004214923cd48fe17f41fab55037a7`
when reproducing the patch. Run the Java source with FFDec 26.2.1 on the classpath,
passing the baseline library and a work folder containing `ReleaseTransport.as`.
Replace only the DoABC payload identified by its generated `abc-verification.json`.
The build refuses unexpected download-call patterns and preserves other method
bodies and SWF tags. Do not replace the library with a different source checkout.

The small control manifest remains on the game server so its original cache
namespace survives. Each package's `url` selects an immutable GitHub release
asset; `path` retains the globally rate-limited original-server fallback.
