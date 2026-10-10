# Map update handoff — Visual Lab 01.7

Repository: `FFDevelopment/afewbuds-3d-prototype`

Branch: `map/visual-lab-wood-basement-20261010`

Integration base: `327b318b4b969e3fd5dd279ca74789e89c915408` (development main as fetched on 2026-10-10). The art preview originally used `2149be5b78e1eb17b88c595d54d127cb61059595`; these changes were merged onto the newer logic, preserving its phone and property updates.

## Revision 01.7

Added closed visual entrances 201 and 301 at the second- and third-floor fire-escape landings, with door frames, hardware, thresholds and unit plaques. Overlapping window pieces are hidden and masonry bands stop at the entrances. These doors do not open into new interiors. The wall-side support posts sit against the facade so they do not obscure the frames.

Both front planters moved 0.7 m toward the building and have solid pot collision. Removed the floating basement stair label; B still toggles basement lights. Player collision against both planters was verified and the door views rendered in Godot.

## Included changes

- Consistent procedural brick, pavement, gravel, plaster, roof and matte wood surfaces. House/apartment floors and wooden doors share the new wood palette. Moving doors use local grain coordinates.
- Three-story apartment proportions, cornice/window alignment, house glazing and connected roof soffits; supported market details and crate collision.
- Complete fire escape, roof guards, continuous railing barriers and level stair crests. Edge climbing previously reproduced five snags; the corrected ten side-climbing cases pass.
- Walkable house basement with switchback stairs. Eight decorative grow benches removed. Main floor clear for player-placed tents; east stair/panel aisle and south service strip reserved.
- House system panel moved downstairs, using the apartment-style UI with house-specific status, lights and ventilation. Apartment controls remain separate.
- Basement furniture placement, saved Y coordinates, item/plant rendering, picking up and moving empty tents. Existing upstairs furniture is not moved automatically.
- Floor-aware room checks, rooftop door-alert suppression and a 16-light Compatibility rendering budget.

## Property and save contract

`apartment` and `house` are unchanged. Basement is the additive room `basement_grow` inside `house`, with grow use and vertical bounds, not a new property. Existing furniture IDs, plant slots, containers, purchases and utility state retain their ownership. Empty/unlock requirements for moving tents remain in effect.

Normal `game/project.godot` retains upstream login scene, AFBCloud autoload, version and save namespace. Its only change is the per-object light limit. `visual_lab/runtime.gd` installs map visuals without the preview's clock override, debug keys or HUD. No account or save migration to an offline namespace is included in normal gameplay.

## Changed integration scripts

| File | Purpose |
| --- | --- |
| `game/prototype/apartment.gd` | Install map adapter; house system UI; height-aware door alert |
| `game/prototype/neighborhood.gd` | Surface metadata and apartment height bounds |
| `game/prototype/house_controls.gd` | Downstairs panel location and interaction; basement room detection |
| `game/prototype/player.gd` | Permit the basement elevation before fall recovery |
| `game/scripts/property_furniture.gd` | Basement floor validation, vertical separation and saved item heights |
| `game/scripts/furniture_editor.gd` | Floor-relative placement, obstacle checks and selection |
| `game/scripts/equipment_world.gd` | Render items/plants and seat positions at saved heights |
| `game/visual_lab/*` | Map geometry/materials, runtime adapter, isolated preview and focused tests |
| `tools/make_visual_lab.py` | Produce a separate offline test project |

Merge/cherry-pick this branch's commit; resolve overlapping logic by combining changes rather than replacing whole scripts with older files. Procedural map assets and their script dependencies must travel together.

## Isolated preview

From the repository root:

```sh
python3 tools/make_visual_lab.py /absolute/path/to/a-new-preview-folder
```

Import that folder's `project.godot`. This generated copy uses its own offline adapter and local test career. Do not copy `visual_lab/project.preview.godot` over the normal repository project configuration.

In preview: F9 cycles viewpoints, E opens the downstairs house panel, B toggles basement ceiling lights. Use Backpack/Arrange to place owned equipment; the existing house ownership requirement still applies.

## Validation and remaining limits

Validated with Godot 4.6 stable, Compatibility renderer; not locally tested with 4.7.2. Test logs are in `docs/map-validation/`.

- Runtime adapter preserves game time/input and existing property IDs; basement room resolves on its own floor.
- House panel reachability, state isolation and closing without teleporting.
- Basement placement, plant height, saved-state reconstruction, overlaps, stair clearance, moving and packing.
- Existing equipment suite: 85 checks.
- House glazing, light budget, stair/roof traversal and basement round trip.
- Rail-edge climbing along both sides of three outdoor and two basement flights.

This is a desktop map integration branch, not a promoted tester release. Basement worker navigation, mobile mirroring of the changed shared furniture adapters, and full release/export gates are still pending. No tester repository or main branch is updated by this handoff.
