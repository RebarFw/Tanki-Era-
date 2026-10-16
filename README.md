# Tanki Era

[Download Tanki Era for Windows](https://github.com/RebarFw/Tanki-Era-/raw/refs/heads/main/downloads/Tanki-Era-GitHub-Client.zip)

Extract the ZIP and open **Tanki Era.exe**. The download contains one executable; the AIR runtime is built in. No installer, batch launcher, or separate runtime ZIP is needed.

The launcher checks this repository each time it opens. It downloads only changed game files, verifies them, then starts the complete game version. Updates apply on the next launch. A verified saved version can be used if GitHub is temporarily unavailable.

The game server must be online to play. Maps, textures and sounds come from the game server and stay in the local game cache. Launcher files are stored in `%LOCALAPPDATA%\TankiEraPlayer`; player resources remain in `%LOCALAPPDATA%\TankiEra\cache`.

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
