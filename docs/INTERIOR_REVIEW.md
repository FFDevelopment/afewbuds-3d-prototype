# 0.9.4 interior preview review

## Authorized layout

The user supplied house and corner-shop cutaways, then explicitly requested both interiors be built on October 5, 2026. This is an integration-branch desktop preview for their review, not a merge to main or production deployment. No paid assets or services are used.

The native Godot builder is `game/prototype/interiors.gd`. It constructs both buildings in the same neighborhood coordinates, replacing the old solid boxes. Rectangular wall subtraction is evaluated by partitioning wall cells at all aperture boundaries and omitting interior cells; no solid wall remains behind glass or entrances. The runtime opening schedule is recorded as `interior_openings` metadata and exported by the capture script.

## Room brief and function

- House bounds: x25–45, z−14–3, ceiling 3.36 m; 20×17 m gross footprint. Central 3 m hall plus 2 m cross hall. Living/packing front, kitchen/bathroom/bedroom/grow rear. Asymmetry follows the supplied functional layout.
- Shop bounds: x12–22, z−2–6, ceiling 3.45 m. Right front door, two merchandise aisles, left checkout, rear coolers, east coffee counter. Stockroom has four complete walls and a separate hinged door behind checkout.
- Camera: existing player eye height 1.90 m, existing desktop FOV and input. No teleportation or separate interior scene.
- Door openings: shop 1.7 m, house 1.8 m, stockroom/bathroom 1.35/1.3 m, bedroom 1.4 m. Residential/shop doors deliberately use human-scale dimensions below the gallery skill's 2.4 m default. Minimum capsule diameter is 0.54 m.
- Furnishings: procedural tables/shelves/cabinets, rounded sofa and bedding, cylindrical jars/cups/planters; repeated small merchandise has no per-item physics. No new NPC or duplicate plant simulation.
- Lighting: 11 unshadowed local lights shared by runtime and review captures; only neighborhood layer 2 receives them. Existing apartment lighting remains independent. No paid generation, imported external assets, or texture-license dependencies.

## Verification

`tools/test.py` uses disposable guest data and mocked account HTTP fixtures. Interior tests exercise E to open the two exterior doors; blocked swing refusal; closed/open capsule collision both ways; all six house room routes; both store aisles; stockroom access; window collision. Existing gameplay, HUD, save and account suites remain included.

`prototype/capture.gd` captures all interiors at actual player eye height, shop glazing both ways, nighttime shop exterior and house view outside. Review-only overhead cutaways hide ceilings/roof after first-person captures; normal gameplay retains them. Opening masks are the exact Rect2 aperture schedule, not decorative window placement.

## Limits and review status

Built for a walkthrough preview. House ownership, moving the active business to the house, shop transactions and functional new production stations are not implemented. Equipment is explicitly visual preview furniture and creates no stock, money, or plants. Property-offer inspection remains at the sale sign. Door state resets on load; shared gameplay saves retain the same format.

Human form/runtime review remains pending on the downloadable preview. Main, beta, cloud-test and database are outside this change. No final production promotion is authorized by automated tests.

## Implementation lessons

The first runtime pass exposed overly solid shelving side panels. Replaced them with narrow corner uprights and retained an explicit shelf collision volume. Exterior brick walls now have a separate interior plaster face around the same evaluated apertures. Tested real capsule routes instead of assuming visible doors imply usable passage.
