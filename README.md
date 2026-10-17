# Tanki Era

[Download Tanki Era for Windows](https://github.com/RebarFw/Tanki-Era-/raw/refs/heads/main/downloads/Tanki-Era.zip)

Extract the ZIP and open **Tanki Era.exe**. The download contains one executable; the AIR runtime is built in. No installer, batch launcher, or separate runtime ZIP is needed.

The launcher checks this repository each time it opens. It downloads only changed game files, verifies them, then starts the complete game version. Updates apply on the next launch. A verified saved version can be used if GitHub is temporarily unavailable.

The game server must be online to play. Maps, textures and sounds come from the game server and stay in the local game cache. Launcher files are stored in `%LOCALAPPDATA%\TankiEraPlayer`; player resources remain in `%LOCALAPPDATA%\TankiEra\cache`.

Launcher 2.0.1 displays **Server is offline** with one OK button when the required game connections are unavailable. Connection details stay in the local launcher log.

The October 17, 2026 library update was tested in-game by the project owner and scanned at [0/61 on VirusTotal](https://www.virustotal.com/gui/file/6c2c9eb0856ee2cda3b0f5f3b43e4ae4475949a31054a047d23cf953074d36f4). This result applies to `library.swf`, not to the launcher executable or the complete ZIP; see [launcher review notes](launcher/README.md).

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

Players receive changed assets automatically when they reopen Tanki Era. Keep related files in one commit when they depend on each other. The launcher pins each update to one GitHub commit and activates it only after all required files pass verification.

The repository contains public client files only. Do not upload server databases, admin configuration, passwords, tokens, or private keys.
