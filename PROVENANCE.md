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

## Simulation update: prototype 0.5

Full main simulation synchronized from release `0.7.9-beta.19-cloudtest.53`, commit `a646dc568a7e9bea08d6a2e1cd0d3dd4acc46121`. PCK SHA-256: `c171f3d8b8c20fc9a6ca034c50f2fb12fb4933a71300ed80786a54f4e671633c`. All eight packaged scripts were compared; the other gameplay scripts were unchanged. Retains export-safe room texture loading, recovered PNG/sample paths, and the prototype local-save filename. Asset entry hashes matched the prior package. Only the prototype repository is changed; no database or beta changes.

## Simulation update: prototype 0.6

Reviewed cloud-test54–57 commits and synchronized the runtime at `e0a132fcbd4749a066f8a88fcece17266a2a04c2` (cloudtest57). PCK SHA-256 `017c8e40687a7ad3d1ff069e62bfed17cdcd2a0495b3029f71f691d018068dc4`. Compared all packaged scripts; only main.gd changed since cloudtest53. All 83 advancement definitions and advancement/task functions match. Preserves native account adapter, export texture fixes, and desktop save isolation. No source repository or backend changes.

## Visual update: prototype 0.7

Ports the exact main.gd transformations from cloud-test58 preparation commit `d3568348816ee711ce3a9a52b8b996f5e4c1d88a`, deployed at `f702bb7357809a92952bc5802a07293560b89600`: remove WindowBuildingA/B/C and change Hidden Wall Stash X offset from -0.24 to -0.36. No other simulation or asset changes. Engine integration checks verify the new stash position, unchanged vault anchor, and removal of placeholders while retaining the window.
