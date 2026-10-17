# Tanki Era

[Download Tanki Era for Windows](https://github.com/RebarFw/Tanki-Era-/raw/refs/heads/main/downloads/Tanki-Era.zip)

Extract the complete folder and open **Tanki Era.exe**.

This client is based on the original **Tanki Era v1.2**: the same native EXE, ERA icon, AIR runtime and launcher design. It opens the original Play/Exit screen. There is no extra updater window, file-check screen, download bar or server online/offline check.

`Loader.swf`, `library.swf` and the full clan module load from this repository when needed. Players receive the latest game library when they reopen the game. The client ZIP does not contain the game library. Maps, textures and sounds continue to come from the game server.

A tiny local `ClanAddon.swf` entry keeps the existing clan feature connected to the full GitHub module. Do not replace **assets/ClanAddon.swf** with that tiny local entry; the asset in this repository is the full game module.

## Publishing game updates

Update `assets/library.swf`, `assets/Loader.swf`, the full `assets/ClanAddon.swf`, and `assets/socket.cfg` as needed. Keep related updates in one commit. Public connection settings only; never upload server databases, passwords, tokens or admin configuration.

[Launcher source and rebuild instructions](launcher/README.md).
