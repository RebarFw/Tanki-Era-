# Tanki Era

[Download Tanki Era for Windows](https://github.com/RebarFw/Tanki-Era-/raw/refs/heads/main/downloads/Tanki-Era.zip)

Extract the entire ZIP, open the **Tanki Era** folder, and run **Tanki Era.exe**. Keep its runtime folders beside it. No installer, administrator access or batch launcher is needed.

The launcher checks this repository when it opens. It downloads only changed game files, verifies them at one immutable GitHub commit, and activates a complete version. Updates apply on the next launch. If GitHub is temporarily unavailable, a previously verified version can still start.

The game server must be online to play. When the required game connections are unavailable, the launcher shows **Server is offline** and one **OK** button. Technical details stay in the local launcher log. Initial downloads and integrity checks can take a little time.

Maps, textures and sounds still come from the game server and stay in the existing resource cache. Updater files are stored in `%LOCALAPPDATA%\TankiEraPlayer\air`. Previously downloaded game blobs can be reused after verification.

The October 17, 2026 portable release replaces the custom .NET self-extracting wrapper with the unmodified AIR SDK entry point and a small source-visible AIR updater. The game assets and the owner-tested `library.swf` are unchanged. [Source, verification details and scan reports](launcher/README.md).

Current release checks: [ZIP: 0/64](https://www.virustotal.com/gui/file/00187bd529c643d7d5c221eb2aa920e6a1219d0b8af699ed83a912e1f55946d8), [updater SWF: 0/58](https://www.virustotal.com/gui/file/a752c3b351fa6b2f0a189057080a01e633748b9ac301207c4aa3cdb655bda6a8), [game library: 0/61](https://www.virustotal.com/gui/file/6c2c9eb0856ee2cda3b0f5f3b43e4ae4475949a31054a047d23cf953074d36f4). These are point-in-time scan results, not a guarantee against every security issue. Runtime binaries are also checked separately because archive scanning has limitations.

## Publishing game updates

Update the required files in `assets` on `main`:

- `library.swf`
- `Loader.swf`
- `Prelauncher.swf`
- `StandaloneLoader.swf`
- `ClanAddon.swf`
- `communicator-chat.png`
- `communicator-news.png`
- `socket.cfg` (public game endpoint only)

Players receive changed assets when they reopen Tanki Era. Keep related files in one commit. The updater allows only these names, verifies Git blob hashes and local SHA-256 receipts, and stages the complete game before activation. Incomplete or corrupted updates cannot replace a verified saved version. It never downloads a native executable from the network.

The repository contains public client files only. Do not upload server databases, admin configuration, passwords, tokens or private keys.
