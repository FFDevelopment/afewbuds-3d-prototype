# AFewBuds shared gameplay core — safe migration architecture

## Repository strategy
**Do not combine public releases or replace save identities.** Two public
distribution repositories remain intact:
- Mobile/web: `FFDevelopment/afewbuds-beta` (PWA, touch controls and updater)
- Desktop: `FFDevelopment/AFewBuds-Desktop-Beta` (Windows/Linux + launcher)

Development sources remain in `afewbuds-3d-prototype` and `afewbuds-cloud-test`.
The canonical shared property module currently lives at
`afewbuds-3d-prototype/game/scripts/property_registry.gd`; the mobile source
contains a byte-identical copy, checked against the pinned canonical commit by CI.

A future monorepo or dedicated `afewbuds-core` repository could hold all
shared simulation code, but moving source trees is **not required** to share
rules and risks breaking build and release paths.

## Migration contract (registry v1)
- Keep the original `apartment` and `house` save keys unchanged.
- The new `location_state.property_registry` key is additive. Existing
  `furniture_v1`, `container_inventory`, `property_utilities`,
  `staff_assignments`, `property_opportunity_state`, and
  `apartment_rent_state` continue to own the existing data.
- Stable IDs do not change when a property is renamed. New player-created IDs
  come from a monotonic serial; authored buildings may use explicit IDs.
- No implicit ownership of new buildings. Legacy apartment/house access rules
  and existing rent, lease and purchase behavior are retained.
- Metadata supports multiple rooms, per-room grow restrictions and nested units.
- Registry schema versions must never decrease on save reload.
- Do not promote a new feature to a public beta until old-career fixtures,
  restored saves, property-isolation tests and both export pipelines pass.
- Test import and cloud-save transactions without changing player accounts.
  Save migration should be idempotent; failed validation must not overwrite
  the last confirmed career. Existing updater and rollback paths stay intact.

## Scope of the current development milestone
Implemented: stable-ID registry, additive legacy registration, independent
property data buckets, name changes, nested units, valid-room mapping, property
access checks, and partial furniture placement integration.

Not complete: dynamic computer station registration, generalized utility
simulation, custom-property NPC navigation/worker scheduling, grow wall panels
in arbitrary buildings, all future delivery points, full item/NPC registries,
and a complete universal game-core extraction. These remain on legacy
apartment/house paths until converted and tested. **Do not publish this
development branch as a universal property system yet.**

## Verification
- Desktop: `python tools/test.py GODOT dynamic_property_test property_isolation_test equipment_test`
- Mobile candidate: `python tools/mobile_3d_movement/build.py --output-dir OUTPUT`
  then Godot imports the candidate and runs
  `tools/dynamic_property_v1/check.gd` and the property-isolation test.
- CI checks byte-level equality of the same Godot registry logic on desktop
  and mobile and prevents drift between platforms.

## Next shared modules
Convert future-property interactions systematically:
1. Registered door/room boundaries and entry/curb positions.
2. Property-scoped furniture and equipment catalog + placement.
3. Property-scoped inventory, computers, utilities, grow panels and workers.
4. Shared NPC rig/animation definitions and behavior.
5. Versioned save migration and end-to-end release tests for both platforms.

Never change public PWA/app storage keys, launcher data paths, account IDs,
career IDs, or recorded purchases just to consolidate repositories.
