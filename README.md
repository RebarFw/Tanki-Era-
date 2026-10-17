# Tanki Era

[Download Tanki Era for Windows](https://github.com/RebarFw/Tanki-Era-/raw/refs/heads/main/downloads/Tanki-Era.zip)

Extract the complete **Tanki Era** folder and open **Tanki Era.exe**. The folder contains only the executable, Adobe AIR, icons, META-INF and mimetype. No installer or batch launcher is needed.

The original ERA screen opens with **Play** and **Exit**. Game updates come from this GitHub repository and prepare silently behind that screen. Click **Play** once to continue into the game. The launcher has no extra checking window, download bar, server-status probe or online/offline popup. A first launch still needs time to download the game files.

The existing ERA icon is included as standard Windows icon resources. The game library, gameplay, garage, supplies, battles and social links are unchanged. The public client has its own application identity so it does not collide with the host's development clients.

Current October 17, 2026 scan results: [ZIP: 0/66](https://www.virustotal.com/gui/file/296cf162e17b14e82998b241998576038862abae3e49e871c15911988fc96266), [executable: 0/71](https://www.virustotal.com/gui/file/8e5f12ae38573c60a39ae9f9aebd3ade3d5ec48a561f2b4598105118babef1fa), [bootstrap: 0/61](https://www.virustotal.com/gui/file/f25610084df6fbb52aa0fc791b646e96e038d8c29a23d2e5c4f1364246ea04ca). Scan scores describe the exact files and analysis dates, not a guarantee against every vulnerability. [Source and verification details](launcher/README.md).

## Game updates

Publish related changes together in `assets` on `main`:

- `library.swf`
- `Loader.swf`
- `Prelauncher.swf`
- `StandaloneLoader.swf`
- `ClanAddon.swf`
- `communicator-chat.png`
- `communicator-news.png`
- `socket.cfg` (public connection details only)

The client selects one immutable GitHub commit, downloads changed files, verifies their hashes and uses a complete version. A verified saved version can be used when GitHub is temporarily unavailable. Maps, textures and sounds continue to come from the game server and use the existing game resource cache.

Do not put server databases, private configuration, passwords, tokens or private keys in this public repository.
