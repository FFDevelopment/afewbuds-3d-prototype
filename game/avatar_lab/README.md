# AFewBuds Player Avatar Creator — v1 development only

The editor is accessible from **Pause → Settings → Character & Wardrobe**. The editor has a live independently lit 3D preview, orbit/zoom and Idle/Walk animation previews. This first milestone does NOT enable third-person gameplay or replace existing NPC meshes.

**Shared source:** `scripts/avatar_catalog.gd`, `avatar_visual.gd`, `avatar_editor.gd` must be byte-identical to the mobile build's `tools/avatar_creator_v1/` files.

**Rig:** the approved `Mike.glb` character supplies the existing 56-bone AFewBuds skeleton and its idle/walk animations; its NPC mesh is hidden. The new player model uses independently replaceable cosmetic geometry attached to those bones. These are fitting-stage meshes, not production-quality Blender-skinned garments; no claim that they are fully deforming skinned meshes. Keep outfit proportions and bone contract stable before authoring new LOD and proper weighted clothing assets.

**Data:** only an explicit Save in the editor writes `location_state.player_avatar_v1`. It stores `schema:1`, `owner_kind:player_only`, `npc_spawn_allowed:false`, `sale_listing_allowed:false`, `created:true`, and sanitized `appearance` (13 separate equipment/body slots plus nine colors). Unknown career fields are untouched. Existing player careers do not open the editor automatically or reset anything. The existing `_save_game` / cloud session flow syncs the record with the career. Cancel is preview-only. Existing testers are unaffected.

**Not yet in v1:** body morphs, complete clothing asset sets, player-exclusive celebrity likeness ownership enforcement, first/third-person gameplay model, and a physical wardrobe furniture interaction. Those require further rigging and server-side permission validation. The optional player-only flag alone does not grant protected exclusive character ownership.

Test with `python tools/test.py /path/to/godot avatar_creator_test` then full `tools/test.py`, native export smoke, and the mirrored mobile tests. Use a test career until visual review is approved.
