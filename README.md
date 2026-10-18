# Tanki Era v1.3

[Download Tanki Era v1.3 for Windows](https://github.com/RebarFw/Tanki-Era-/raw/refs/heads/main/downloads/Tanki-Era-v1.3.zip)

Extract the complete **Tanki Era v1,3** folder and open **Tanki Era.exe**.

This testing release uses the current Tanki Era client, including the current full game library and clan module. The v1.2 package was used only as a reference for keeping the player folder small. The current executable, AIR runtime, icons and launcher artwork are retained. The library includes the latest Striker impact and spawn-input fixes.

Each launch resolves the latest GitHub commit and loads the game Loader, library and full clan module from that same revision. Players receive new game versions when they reopen the game; they do not need a replacement ZIP for ordinary game-library updates. Maps, textures and sounds continue to load from the game server. The main game library is not bundled in the ZIP.

The small local ClanAddon.swf forwards the existing game interface to the full GitHub module. **assets/ClanAddon.swf must remain the full module**, not the small local entry.

To publish game updates, update **assets/library.swf**, **assets/Loader.swf**, the full **assets/ClanAddon.swf**, and public **assets/socket.cfg** as needed. Keep related updates in one commit. Do not upload local connection settings, server databases, account records, passwords or admin configuration.

The v1.3 bootstrap files are included in the ZIP. The older bootstrap assets and v1.2 rebuild source remain available for compatibility with earlier packages.

[v1.3 launcher source and rebuild instructions](launcher/v1.3/README.md).

## Resource cache downloads

The client downloads verified resource bundles from [GitHub Releases](https://github.com/RebarFw/Tanki-Era-/releases/tag/resource-cache-v1).
Bundles are content-addressed and players reuse local verified files, downloading
only missing or changed content. A bounded original-server fallback remains for
release-hosting failures. The game server supplies immutable control manifests;
accounts and battle traffic stay on the game connection.

See [resource publication](tools/resource-cache/README.md) and
[v1.3 cache transport](client/resource-cache/README.md) for publishing and rollback.
