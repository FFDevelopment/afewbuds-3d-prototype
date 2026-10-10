# Map update handoff — Visual Lab 01.7

Repository: `FFDevelopment/afewbuds-3d-prototype`

Branch: `map/visual-lab-wood-basement-20261010`

Integration base: `327b318b4b969e3fd5dd279ca74789e89c915408` (development main as fetched on 2026-10-10). The art preview originally used `2149be5b78e1eb17b88c595d54d127cb61059595`; these changes were merged onto the newer logic, preserving its phone and property updates.

## Revision 01.7

Added closed visual entrances 201 and 301 at the second- and third-floor fire-escape landings, with door frames, hardware, thresholds and unit plaques. Overlapping window pieces are hidden and masonry bands stop at the entrances. These doors do not open into new interiors. The wall-side support posts sit against the facade so they do not obscure the frames.

Both front planters moved 0.7 m toward the building and have solid pot collision. Removed the floating basement stair label; B still toggles basement lights. Player collision against both planters was verified and the door views rendered in Godot.

Packing-prop follow-up: the house’s two orphan green jars lost their semantic names when Godot assigned duplicate-node names. Cylinder props now keep `fit_part` metadata. All apartment bench-created props receive explicit packing ownership, including bag stacks, labels, pens and scissors, so moving/rotating/picking up the bench cannot leave them behind. A focused runtime test checks nine previously unowned apartment props and all three house jars.

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

## Visual Lab 01.8 — complete background stories and garage brick

Background RearBuilding, OppositeBuilding, OuterHouse and EastResidence shells now have three complete 3.5 m stories (10.5 m roofline), with three window rows on each facade. Footprints and closed decorative entrances remain unchanged. Apartment and house property IDs and playable interiors are preserved. Garage wall and roof meshes now have semantic names so the visual material pass consistently applies the updated brick and roof finishes.

Validation: Godot 4.6 import and runtime geometry assertions, plus street/garage render captures; not tested in Godot 4.7.2.

## Visual Lab 01.9 — parked vehicle models and placement

Original procedural sedan, pickup and black/white police variants replace the slab cars, using the supplied images as style references. Sloped cabin glazing, cut-out wheel arches, inset rims, bumpers, grille, lamps, mirrors and door details are generated by `prototype/parked_vehicle.gd`. No external meshes or textures are required. These remain static scenery, not drivable vehicles.

Both market cars are centered between the parking lines. Three curbside sedans sit parallel to the curbs with pedestrian and driving clearance. The rear-alley car has moved into a public parking bay. Patrol cars face their central aisle; the lightbars and door markings belong to each vehicle. A single collider per vehicle avoids snagging on small trim, and obstacle footprints follow vehicle rotation. Existing property IDs and gameplay saves are unchanged.

Validation: Godot 4.6 import; runtime checks of all 12 cars, their bay/curb bounds and physical colliders; four rendered views. Godot 4.7.2 and mobile export performance are not verified.

## Visual Lab 01.10 — grow equipment, wall mounting and stash placement

All four existing tent SKUs retain dimensions, plant-slot IDs and prices. The shared procedural visual module adds fabric panels, reflective liners, frame poles, zipped edges, trays, duct ports and suspended fixtures. Quality 1 uses a basic tube fixture; the existing $320 per-tent light-kit upgrade (quality 2) replaces it with LED bars. Existing quality saves and yield rules are preserved. Property-specific light switches control beam visibility and fixture emission, without hiding the fixture. One shadowless spotlight per tent avoids adding multiple overlapping real lights.

Auto Water Kit now has a reservoir, lid, gauge, pump, timer and manifold. Ventilation has a carbon-filter cylinder, fan, grille and controller. Both retain their catalog footprints and existing game effects. Floor placement remains supported. A Floor / Wall toggle in placement controls snaps utilities to actual solid wall faces, with mounting height following the aim point within bounded limits. Wall mounting includes brackets and persists through existing position/yaw save fields. Unsupported/floating mounts, doors/windows and invalid rooms are rejected. Basement walls explicitly identify their mounting surfaces. Moving and packing preserve item ownership and upgrades.

The apartment hidden stash previously tested a full-height box down to the floor, so baseboards blocked its placement. Placement and item-overlap checks now use its actual raised cabinet bounds (bottom 1.04 m), retaining collision checks for real furniture and structures.

Integration: include `scripts/grow_equipment_visuals.gd`, `equipment_world.gd`, `furniture_editor.gd`, `property_furniture.gd` and `visual_lab/basement.gd`. Merge the editor/model changes alongside newer phone/logic work; do not replace newer full files wholesale. Mobile adapters still require the corresponding mount-placement integration and export QA before promotion.

Validation: Godot 4.6 import; four sizes, basic-to-upgraded replacement on the selected tent, lights off, wall aiming and support rejection, moved/packed utilities, JSON height/quality retention, apartment stash/baseboard and self-collision checks; existing equipment regression suite. Screenshots are staged examples from an isolated test career. Not a Godot 4.7.2 or mobile performance certification.
