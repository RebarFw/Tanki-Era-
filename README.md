# Tanki Era v1.4

[Download Tanki Era v1.4 for Windows](https://github.com/RebarFw/Tanki-Era-/raw/refs/heads/main/downloads/Tanki-Era-v1.4.zip)

Extract the **Tanki Era v1,4** folder and open **Tanki Era.exe**.

## What's new

- **FPS cap.** Use **Settings → Game** to choose 60–240 FPS in steps of 10 for hardware-accelerated battles. The HUD shows a one-second average of measured FPS.
- **Controls.** You can rebind **Show protections and alterations** directly below **Shoot**. Hold the assigned key to show the overlay. The number-row supply keys follow the bindings saved in Controls.
- **Clicker.** The settings use the standard gray panel style. Apply briefly shows **Applied**, and notifications identify the profile with **Started** or **Stopped**.
- **Launcher cache.** The compact launcher verifies the game library against the checksum for its pinned GitHub revision. It reuses the file whenever the checksum matches and keeps the current and one previous library.

## Resource downloads

The client supports a smaller login download with the matching progressive-cache server update. Maps, tank assets and garage previews then download when needed. The game server supplies the verified manifest, and the packages come from [GitHub Releases](https://github.com/RebarFw/Tanki-Era-/releases/tag/resource-cache-v1). Verified cached content is reused across launches and updates.

The launcher and game assets resolve to the same GitHub commit. Reopen the game to receive ordinary library updates. The portable v1.4 ZIP is the one-time update for the launcher cache.

[Previous v1.3 Windows ZIP](https://github.com/RebarFw/Tanki-Era-/raw/refs/heads/main/downloads/Tanki-Era-v1.3.zip) · [Resource publication and rollback](tools/resource-cache/README.md) · [Cache transport](client/resource-cache/README.md)
