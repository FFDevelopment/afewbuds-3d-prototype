# Source provenance

## Desktop 0.13.0 / mobile 3D v11 paired update

Ports the Chapter 4/5, property agreement, Real Estate, utility ledger, release/re-rental, equipment-preservation, Heat and branching-task changes from mobile 3D v10 (`9766974`) using the upstream progression transformation. Includes v11 newest-first messages from `a80c08b`, preserving saved-message order and reply indexes. Desktop movement, door collision, camera/mouse capture, native accounts and ranked-total precedence remain intact. The existing shared stamina controller is covered by depletion, recovery-delay, exhaustion-threshold and HUD checks, plus an exported-runtime check. Property/message tests run against the desktop scene, with independent disposable saves per test suite. No backend schema changes.

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

## Desktop 0.12.1 preview

Ports police frame/floor joins, parking access and park exit/sidewalk repairs from cloud-test commits `e3997cb8baaf7b839235f585e6f98c677a4fd056` and `6addda9c7fad6316f74ea3c4de1100cef592f606`. Native capsule collision, stairs and E-key door interaction are retained. Kobi model and atlas come from `ec056a58874df82750275bc539c90e1a778a6b1c`; SHA-256, original user-art provenance and shared 56-bone validation are retained in `game/assets/characters/Kobi.receipt.json`. The upstream five character-selection changes are applied to the desktop crew adapter. Matching server ranked rows now take precedence over conflicting career profiles. No backend or save-schema changes.

## Desktop 0.13.2 leaderboard wire-format repair

Reproduced using the real HTTPRequest path after JSON.parse_string: Godot serializes reloaded integral floats as `98765.0`; the existing afb_leaderboard_int / nested_int SQL readers accept only `^-?[0-9]+$`, yielding zero. The web client's JSON.stringify encodes those same values as `98765`. Normalize finite safe integral floats to integer Variants at the desktop HTTP boundary; retain fractional values and preserve save contents. A regression fixture exercises the deployed integer-reading contract on transmitted bytes, including nested counters and arrays. No server schema or mobile gameplay change is required.
