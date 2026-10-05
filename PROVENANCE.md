# Source provenance

Recovered from the user's existing `FFDevelopment/afewbuds-cloud-test` repository, pinned at commit `233bbbd1324c1397ea4ef1953e59b8f0600a4937`.

- Package: `index-cloudtest10.pck` (the filename is reused by the source project's runtime patches; it does not identify the content version).
- SHA-256: `c471ab6dd7be6778e8e4b31976e46840b11464edc98745bf85f5c7a6a2cc222a`.
- PCK header engine: Godot 4.7.2.
- Each entry was checked against its directory MD5 before extraction.
- Source scripts and the text scene/project were present in the package.
- Imported textures were decoded through Godot to editable PNG images. Recovered SVG icons are rasterized PNGs; the original vector source is not recoverable from this package.
- Raw branding, floor/rug art, and customer WebP files were retained.
- The door-knock sound remains its original Godot AudioStreamWAV `.sample` resource because the inherited compressed format cannot be written back as WAV by Godot's saver.
- Unused runtime import caches and binary exported scenes were discarded.

This is an isolated snapshot, not a promise to track later cloud-test changes automatically. The source recovery did not modify the production repository or account service.

## Simulation update: prototype 0.2

Simulation synchronized from cloud-test47 at `14698f4669d535fcaac8ea8aa5f68e9449dbe82b` (PCK SHA-256 `4c5abcdbafeed713abe43c4de6b5ee6433668b89408b36191be6009fed7daf1d`). Includes native dealer storage, legacy inventory migration, and expandable upgrade cards. Artwork recovery remains pinned to the original asset snapshot above. First-person integration and separate local saves are retained.

## Account preparation: prototype 0.3

The account UI and save abstraction are staged locally with a mock service for testing. Live transport is absent. No regular repository update is included. A temporary database save-function change made during integration work was restored to its previous definition; this release does not depend on it.

## Existing account service: prototype 0.4

Uses `afewbuds-beta/shared/config.js` and its existing RPC request contracts without changing that repository or the backend. The desktop upload flow uses the existing timestamp-based save API with a client-side comparison; it does not depend on the reverted revision guard.
