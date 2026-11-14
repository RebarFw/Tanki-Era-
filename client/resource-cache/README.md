# GitHub Release cache transport

The existing v1.3 launcher resolves a GitHub commit on each Play launch and loads
`assets/library.swf` from that commit. No replacement player ZIP is required for
this transport update. Loader, launcher, fonts, artwork, and clan entry are retained.

`ReleaseTransport.as` is merged into the original cache ABC. `PatchTransport.java`
changes three cache-only methods (package transfer, manifest transfer, and cache
origin selection); it retains the original cache
identity, object/package SHA-256 checks, extraction, and warm-cache behavior.
Use the previous published baseline `8ec63fd6fb004214923cd48fe17f41fab55037a7`
when reproducing the patch. Run the Java source with FFDec 26.2.1 on the classpath,
passing the baseline library and a work folder containing `ReleaseTransport.as`.
Replace only the DoABC payload identified by its generated `abc-verification.json`.
The build refuses unexpected download-call patterns and preserves other method
bodies and SWF tags. Do not replace the library with a different source checkout.

Both the control manifest and packages download exclusively from GitHub Releases.
The game server sends a GitHub manifest URL with a local-only cache-origin fragment;
the client strips the fragment before HTTP and retains the original cache namespace.
HTTP, timeout, or integrity failure never triggers a game-server cache fallback.
Published legacy cache endpoints return empty redirects; unknown cache paths return
empty 404 responses. Local server source bytes remain for publishing and rollback.

The progress label says "Getting things ready! First launch may take a few minutes. Next time will be faster!" followed by the live count. `UpdateLoadingText.java` applies this wording to the published GitHub-only library without modifying any method bodies. `PatchTransport.java` also retains the wording in future transport rebuilds.

## Parallel cache downloads

The login cache queues up to five transfers. The original package locks
coordinate background downloads with foreground requests. The cache still
checks the same package and resource SHA-256 hashes, and installs and decodes
resources in their existing order.

An optional `zlib` entry in the verified manifest identifies the compressed
GitHub asset. The client verifies the compressed file, expands it, and verifies
the original package before unpacking it. If the compressed transfer fails,
the client tries the original GitHub asset. Both transports use the same
cache path and checksum.

To rebuild, put `CacheTransfers.as` and `PackageQueue.as` in the
`tanki/cache/` subfolder beside `CacheCompiler.as`. Compile `CacheCompiler.as`
with AIR's MXMLC (target player 11.3 and SWF version 16). Run
`PatchPackageQueue.java` on the FFDec 26.2.1 classpath with the input library,
compiled helper SWF and output library as arguments. Only the cache ABC
is changed.
