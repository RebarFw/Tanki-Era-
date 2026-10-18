# Tanki Era resource cache releases

Public bundles live in the `RebarFw/Tanki-Era-` GitHub Releases, separate from the
v1.3 launcher/library Git history. Each `.tpk` asset is named by its SHA-256 and
is never overwritten. New manifests reference existing assets for unchanged
bundles. Releases roll over before the 1,000-asset limit; older assets remain
available for old manifests and rollback.

The game server serves a small immutable control manifest and its active digest.
The game client keeps its original cache namespace, object hashes, receipts,
package verification, and local resource URLs. Package `url` fields select
GitHub; unchanged `path` fields remain the original server fallback. The client
tries the fallback only after primary transfer/integrity failure and cancels a
stalled stream after 45 seconds without progress. Original global fallback
limits remain two public streams at 256 KiB/s each.

## Automatic publication on this host

Once enabled after validation, `Start-Watch.ps1` starts a hidden, single-instance
publisher with below-normal CPU priority whenever the ordinary server launcher
starts. The publisher checks public resource/index metadata every 10 seconds,
waits for 20 seconds of stability, and then:

1. Rebuilds only affected registered resource buckets, including newly added
   texture files in those resources. Explicit feature/map resource registration
   remains authoritative; arbitrary unregistered files are not exposed or
   invented as common resources.
2. Validates all indexed resources, package and file hashes, common resources,
   and every map reference.
3. Uploads only missing hash assets, with two upload workers sharing a 2 MiB/s
   upload budget. Existing Git credentials are used in memory; none are embedded
   in game files or receipts.
4. Verifies new public downloads without credentials, publishes a hash-named
   manifest/checksum, installs immutable local snapshots and fallback files,
   and only then atomically replaces `active-release.sha256`.

The developer's `Distribution/Tools/Publish-Game-Update.ps1` also runs this stage
before publishing a game library. Resource-only updates do not require a client
ZIP or a server restart. Already loaded battle scenes are not broadcast a reload.

This publisher runs on the host that owns the source resources. It does not use
paid runners and cannot observe edits while that PC is off. Already published
bundles are independently downloadable from GitHub. Publisher failures retain the
previous active generation and retry after five minutes. See
`Server/Runtime/resource-publication/state.json` and timestamped watcher logs.

For an immediate explicit build/publication:

```powershell
python Server/Runtime/tools/resource-cache/auto_publish.py --runtime Server/Runtime --once
```

Automatic publication refuses global `cacheVersionBump` changes because those
require a coordinated decoder/session deployment. This does not prevent normal
resource-byte, new registered resource, or map updates.

## Rollback

Disable `resource-publication/enabled.json` first. To roll back a resource release,
atomically restore a previous known digest to `active-release.sha256` in both
`src/main/resources/data/assets/resource-cache/v1` and `build/data/assets/resource-cache/v1`.
Keep its `manifest-<digest>.json` and referenced hash bundles. Existing clients
can continue their current generation; reconnects receive the restored one.
No database, account, or gameplay setting is involved.

The original mutable `manifest.json` / `manifest.sha256` remain the authoring
interface for existing feature scripts. They are not the active-generation
pointer, so an unfinished local edit cannot expose a partially uploaded release.

## Tests

`python Server/Runtime/tools/resource-cache/test_pipeline.py -v` tests changed-only
rebuilds, unchanged reuse, registration boundaries, integrity failures, atomic
activation, and rollback snapshots. Real native AIR and full game test evidence
is in the implementation's development folder.
