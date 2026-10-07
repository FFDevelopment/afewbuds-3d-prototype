# AFewBuds — first-person apartment prototype

An experimental PC version of the **actual AFewBuds apartment**, with first-person movement connected to the existing game simulation. Version **0.12.1 preview** (cloud-test .98-kobi.1 characters and police/park repairs, desktop controls, wider portrait phone, quiet background saves, and ranked-total precedence).

## Play the Windows build

1. Open this repository's **Actions** tab.
2. Open the latest successful **Build prototype** run.
3. Under **Artifacts**, download **AFewBuds-3D-Prototype-Windows**.
4. Extract the ZIP and launch `AFewBuds-3D-Prototype.exe`.

GitHub requires you to be signed in to download artifacts from this repository. The executable is an unsigned development build. No Godot installation is required to play.

## Controls

| Control | Action |
| --- | --- |
| WASD | Walk |
| Mouse | Look |
| Shift | Move faster |
| E | Use the plant, workstation, shelf, switch, or door under the crosshair |
| P | Open/close the existing phone |
| Esc | Close the current panel, or pause/resume |
| F5 | Save local progress |

Sign in with your existing AFewBuds account, or choose **CONTINUE LOCAL CAREER** to play as a guest. Then click **RESUME GAME**. Look for the green crosshair and `[ E ]` prompt. Walk through the open doorway into the grow room; no camera transition is required. Menus release the cursor and stop player movement.

## Desktop settings

Press **Escape → Controls & Display Settings** for key rebinding, mouse/controller look sensitivity, inverted vertical look, window resolutions (960×600 through 3840×2160), and fullscreen at your display resolution. Escape remains available if you change a binding. Preferences stay on this computer, outside your shared career save.

Controller: left stick walks, right stick looks, A/Cross interacts, Y/Triangle opens the phone, X/Square checks visitors, L3 sprints, and Start pauses. In menus, left stick moves the pointer, A/Cross clicks or holds to drag, right stick scrolls, and B/Circle returns. Keyboard input is still needed for account credentials and key rebinding. Hardware/controller mapping needs a Windows playtest.

The phone uses a wider 0.64:1 portrait shell, with wrapping app content and a compact dock. Leaderboards show the signed-in username and select your exact account-ID row from the server. Report failures are visible instead of silently ignored. The shared career card also uses cloud-test’s public profile endpoint; if no matching ranked row is returned, lifetime totals come from that account’s server profile. A profile response never replaces a matching ranked total or rank. Weekly ranking values remain weekly, with lifetime career totals labeled separately. A signed-in playtest is still needed to confirm the reported discrepancy on your computer.

## First test route

- Walk around the living room and through the grow-room doorway.
- Approach the ready **Purple Dream** plant and press E.
- Harvest it using the plant panel.
- Walk to the packaging bench on the right side of the living room and press E.
- Use the existing trim / bag / store pipeline.
- Walk to product storage on the opposite wall and inspect the stock.
- Inspect seeds and fertilizer at the grow-room supply shelf; use the wall system panel for lighting controls.
- Open the phone, save, close the game, and reopen it.

The prototype skips the old fixed-view tutorial. It retains the normal starting plants and money; it is not a cheat save with every upgrade unlocked.

## What this version implements

- First-person capsule controller, mouse look, walk/run, gravity, and room/furniture collision.
- Walkable passage between the existing apartment and grow room.
- Interaction raycast with a 2.6-unit maximum reach and wall occlusion.
- Existing plant-care, harvest, packaging, storage, supply, lighting, phone, and peephole menus reached from the world.
- Dedicated local save, including player position and look direction.
- Desktop landscape presentation and pause/cursor handling.

## Scope and known limitations

This is **Apartment 2.0 groundwork**, not the complete larger-world redesign. Packaging still uses the existing menu/minigame; there is no grab-and-place object system yet. Customers still use the existing peephole flow. NPC pathfinding, new animations, an open city, larger properties, and mobile touch movement are future work. Current worker visuals and gameplay logic are inherited; this does not claim a new navigation system.

The native dealer locker is available through E, with four capacity tiers and transfer controls. The inherited phone and simulation still contain unfinished legacy features. They are not all covered by this prototype's test suite. Close menus with their buttons or Esc; sales and daily closeouts require their explicit choices.

The desktop build uses the same existing AFewBuds account APIs as `afewbuds-beta`: sign-in, registration, remembered sessions, account settings, cloud career loading/saving, and global leaderboard access. This update changes only the 3D repository. It requires no database schema/function changes and no regular-game code changes.

**Save and close one version before switching to the other.** The existing service is timestamp-based and does not offer an atomic conditional save. The desktop checks the last loaded cloud snapshot before uploading and stops when it detects another version's changes, but simultaneous play in both versions is not supported. A conflict keeps the desktop copy locally and offers to back it up before loading cloud progress.

Guest progress remains separate from signed-in careers. Existing 0.2/0.3 prototype progress is retained as the local guest career, not automatically uploaded to an account. Saves stay in `%APPDATA%/AFewBuds-3D-Prototype/`; per-career files hold gameplay and separate `desktop_*.json` files hold camera position. Remember me stores the session token, never your password. Sign out through Phone → Account → Save and return to sign-in.

Local guest resets work normally. Shared account resets are unavailable in this prototype. Newer save schema versions are rejected rather than loaded into an incompatible build. Unknown top-level and runtime fields are retained; inventory dictionaries and arrays remain authoritative replacements.

## Edit the project

Use **Godot 4.7.2 stable**, matching the recovered runtime. Open `game/project.godot` and press F6 on `prototype/apartment.tscn`, or F5 to run the project. The first automated build recovers and commits the artwork from the pinned AFewBuds snapshot. Once that build completes, all scripts and recovered texture images are included. If checking out the initial source commit before assets arrive, run `python tools/recover_assets.py /path/to/godot` first.

- `game/prototype/player.gd`: movement and mouse look.
- `game/prototype/apartment.gd`: first-person adapter and interaction/UI integration.
- `game/scripts/main.gd`: inherited AFewBuds simulation.
- `game/assets/`: recovered original game artwork/textures.
- `game/prototype/smoke_test.gd`: engine-level integration checks.
- `tools/test.py`: disposable test project and save isolation.
- `.github/workflows/build.yml`: tested Windows/Linux exports and source ZIP.

The first-person layer subclasses the existing game script. The baseline script only has compatibility fixes, recovered image-path changes, a prototype save filename, and export-safe floor/rug texture loading. See `PROVENANCE.md` for the exact source snapshot.

## Validate locally

```sh
godot --headless --path game --editor --import --quit
python tools/test.py /path/to/godot
```

The smoke test exercises collision, the doorway, raycast reach/occlusion, plant harvest, station opening, phone movement blocking, menu closure without teleporting, and local save/reload. It uses a temporary project and separate QA save directory.

## Next milestones

1. Playtest room scale, collision, reach, menu layout, and control feel on Windows.
2. Add visible pickup/carry/place interactions at one workstation.
3. Give one worker real navigation between stations.
4. Add a customer standing at the door and direct interaction.
5. Expand into a second property only after the apartment loop is solid.

## Prototype 0.2

Synchronized cloud-test47 dealer storage and sequential upgrade cards. Walk to the locker and press E to transfer product using +1 / +5 / MAX and -1 / -5 / ALL. Buy locker capacity tiers from Phone → Business → Upgrades. The viewpoint is raised from 1.64 to 1.90 world units, with a matching taller collision body. Existing prototype saves remain supported.

## Prototype 0.3

Adds the disconnected account entry screen, isolated career slots, separate desktop camera settings, and local save migration. The higher viewpoint, locker controls, and gameplay from 0.2 remain. Development is limited to this repository.

## Prototype 0.4

Enables the native account connection with the regular game's existing public API configuration. Removed the staged revision protocol; save checks now work with the unchanged get/save endpoints. Tests cover the native HTTP request/response flow with a local fixture, remembered sessions, account isolation, save conflicts, rejected uploads, and guest migration. The live service was checked for invalid-login rejection and public leaderboard availability; a successful sign-in with a real player's credentials requires the player to sign in.

## Prototype 0.5

Synchronizes the full cloud-test53 simulation: Bagging Bench III and continuous 1–4g bagging, premium double-door dealer locker from tier III, relocated locker/bench/kitchen, and updated upgrade cards. First-person targets and collision follow the furniture, including purchases made during play. Locker doors animate before its menu opens; pause/resume preserves the locker menu without moving the camera. The 1.90-unit viewpoint and existing account integration remain. Integration tests cover purchases, inventory conservation, continuous bagging, premium visuals/collision, and interrupted locker opening.

## Prototype 0.6

Synchronizes cloud-test57: player-facing compact scale, wall-fitted hidden stash, shelves and complete bench shifted toward the front door, modern kitchen clear of the grow doorway, and scrollable planting choices for every owned seed. Vault position is unchanged. First-person seed scrolling is connected and stash-opening animations block movement and cancel safely on pause.

## Prototype 0.7

Synchronizes cloud-test58: removes the three dark window placeholder boxes and moves the Hidden Wall Stash another 0.12 units toward the left wall (total X offset -0.36). Vault anchor and along-wall positions remain unchanged. Existing gameplay, native accounts, and first-person controls are retained.

## Prototype 0.8

Desktop UI proportions: portrait phone (up to 460 × 680), smaller header typography, and compact visitor notification fixed at the top above the phone. Workstation panels retain their wider layout. Camera height and gameplay are unchanged.


## Prototype 0.8.1

Rewards/Advancements no longer expands the portrait desktop phone. Long labels and buttons wrap inside the fixed phone width, horizontal scrolling stays disabled, and a smoke test verifies the phone width remains unchanged when Rewards opens.


## Prototype 0.9 preview — cloud-test .64 integration

This branch ports the complete .64 Godot gameplay runtime: 95 milestone rewards with progression lanes, water utilities/billing, Chapter 4 story and persistent property-offer unlock, softer door knock and text notification audio. Bench III, premium Dealer Storage, moved furniture, native accounts/cloud saves and the 0.8.1 portrait Rewards fix remain in place.

The existing neighborhood is positioned directly outside the apartment. **E opens/closes the front door; WASD walks through; R at the door checks the peephole/answers visitors.** Open/close works from either side. Stand clear of the swing before operating the door. The same character capsule handles indoor and outdoor collisions; no fade, teleport or second movement controller is used. Eye height remains 1.90.

The house exterior reflects Rod's property-offer state. House tours, buying/renting and a house interior are not implemented in cloud-test .64 and are not invented by this integration. Neighborhood props retain the early cloud-test art style.

Source: `FFDevelopment/afewbuds-cloud-test@9a9c8015df45b4b527fe20238a59bd6cebee5d6e`. Its .64 delta was reconstructed and SHA-256 verified before extracting scripts/audio. The source `scripts/neighborhood.gd` is preserved behind a prototype subclass; only export-safe audio resource loading is adjusted. Main's local save path, recovered PNG paths and neighborhood class selection remain prototype-specific. Other source scripts were compared; existing export-safe room textures were retained.

The main prototype branch, cloud-test, beta and database are unchanged. CI on this branch has read-only repository permissions. This preview awaits desktop playtesting before any merge into main. Save and close one version before switching careers; the existing backend still has no atomic compare-and-swap conflict protection.

Validation: Godot import, real-capsule door/street/boundary tests, visitor control, house story gating, water billing/save reload, all existing workstation and portrait-phone regressions, mocked cloud conflicts/account isolation and local HTTP login fixtures. No live account or database writes were made for QA.


## Prototype 0.9.1 — door and neighborhood correction

Addresses the October 5 desktop video: the door leaf now fills the opening with recessed jambs, head stop and threshold. It swings inward. Collision prevention samples the actual door sweep rather than blocking an entire circle around the hinge. A refused operation creates no tween or queued action; opening/closing status is updated when the animation completes.

The exterior layout now follows the supplied top-down reference: starter apartment on the left, shop centrally with parking behind, house and fenced lawn to the right, side streets and rear alley. Background buildings sit beyond the rear alley, outside the entire apartment/grow-room volume. Exterior room detection uses the apartment footprint rather than only the front-door Z coordinate. The house inspection target and local position limits follow the revised layout.

Brick, concrete, asphalt, lawn and roof surfaces use prototype procedural materials, without treating the supplied materials collage as tileable texture maps. A hip roof replaces the stacked-slab house roof. This is still a prototype art pass, not a reproduction of the reference image's finished detail.

QA includes delayed-blocked-door checks, both-direction traversal, actual exterior mesh bounds against the entire apartment, lawn bounds, existing gameplay/account fixture tests, and runtime captures of closed/open door, grow room, street, house yard and top-down layout. Changes are limited to the prototype integration branch.


## Prototype 0.9.2 — grounded outer block and future road corridors

Extends continuous ground and the fence perimeter around all outer building lots. Rear and opposite buildings are set back from the alley/street and avoid both side-road corridors. Side roads now join the front street and rear alley and extend unobstructed to the border for future expansion. Sidewalks stop at junctions; asphalt pieces meet without coplanar overlap. Foundation skirts connect outer buildings to the ground.

The apartment lower exterior uses the exact same world-scaled brick material as its upper floors, with separate exterior surfaces preserving interior finishes, the doorway and its existing interaction. A matching exterior window face sits opposite the original interior window.

Checks cover building footprints inside the fence, clear roadway reservations, actual capsule traversal through intersections, physical ground at outer lots/road ends, matching facade material, and previous door/gameplay/account regressions. Only the prototype integration branch is changed.


## Prototype 0.9.3 — windows, entrances and sidewalk continuity

Background buildings now have windows and sills on all exposed elevations. Street-facing entrances include door frames, glass panels, handles, canopies and short paths joining sidewalks. Opposite-row entrances face the main street; outer-house entrances face their side roads. Corner-shop and house entrance detailing uses their existing facade positions. These are closed exterior buildings; this update does not unlock additional interiors.

Sidewalks continue along both sides of the extended side roads and wrap into front/rear cross streets. The rear alley keeps a clear four-metre roadway while gaining an inner sidewalk; parking and rear-yard pavement stop at that sidewalk. Road corridors remain unobstructed.

Verified in Godot runtime captures and the existing collision, road, door, game and account fixture suites. Prototype integration branch only.

The house footprint is enlarged from 16 × 11 m to 20 × 17 m (340 m² gross), about twice the starter apartment footprint. Its roof, lawn and side boundaries follow the larger shell. The rear alley, sidewalk, background row and north fence move back four metres to maintain clearance. This reserves space for a later house interior; ownership and the interior are not added here. The eastward road remains reserved for the supplied future expansion concept.


## Prototype 0.9.4 — walkable house and corner-market interiors

Both buildings now contain furnished interiors in the same continuous neighborhood. Press E on an entrance door to open or close it, then walk through. Windows have real apertures and transparent, collidable glass. Door swings refuse while the player stands in their swept path.

The house has living, kitchen/dining, bathroom, bedroom, packing and grow rooms connected by halls. The corner market has a right-side entrance, checkout, two stocked aisles, coolers, coffee counter and enclosed stockroom with a working door. The house sale sign retains the story-gated offer text; preview tours are available without purchasing.

These are **walkthrough interiors**: house ownership, shop sales and operating the new house equipment are not implemented. Existing apartment gameplay continues normally. See `docs/INTERIOR_REVIEW.md` for scope and verification.


## Prototype 0.9.5 — cloud-test .72 account compatibility

Added **Forgot password?** on native sign-in. Request a recovery email using your username or full saved email (up to 254 characters). Shared recovery emails require the username. The existing Brevo-backed service sends the link; complete it in your browser and return to desktop sign-in. Delivery failures are shown clearly, and short-window account screens scroll.

The cloud-test .64–.72 comparison found presentation/control changes and recovery fixes, with no additional economy/progression updates. The prototype keeps its newer interiors/map, native movement and desktop phone. Full disposition and tests: `docs/CLOUDTEST_72_SYNC.md`. No backend deployment or database change is included.


## Prototype 0.9.6 — cloud-test .82

Cloud-test updates through `b0664c1` are adapted to desktop: exterior materials,
real apartment window, sealed door headers, recessed tree beds, Central Market,
room and market lights, operable saved blinds, and animated day/night sky.
Aim at a nearby switch or window covering and press **E**. The house entrance
requires Rod’s Chapter 4 property offer. House grow equipment starts empty.
Away customers text instead of knocking; reply to schedule their return.
The existing account/login and shared career connection are unchanged.
Single-session enforcement is deferred.

See [the synchronization notes](docs/CLOUDTEST_82_SYNC.md) for source scope and tests.


## Prototype 0.9.7 — cloud-test .83 and tree bark

Tree trunks now use a separate brown bark shader instead of the ground gravel tile.
Rod’s existing property offer unlocks a desktop property-details panel: press E at
the sale sign or closed house entrance, then Tour House. Walk through the six rooms
and spend two active seconds in each to save inspection progress. Press T while
touring to review the property, or Escape to close details/end the tour.
Purchasing, payments, relocation and single-session enforcement remain deferred.
See [the .83 synchronization notes](docs/CLOUDTEST_83_SYNC.md).


## Prototype 0.9.8 — doors open away from you

Apartment, house, market, stockroom, bathroom and bedroom doors choose their
opening direction from the side of the closed doorway where you stand. Closing
uses that same hinge path, even if you have walked to the other side. A player
standing directly in the closing sweep still blocks it; step clear and press E.
Repeated input during a swing never queues a second movement.

The shared hinge calculation works in each door's local frame. Regression checks
cover both opening sides, a rotated hinge, closing clearance, repeat input,
original door alignment and the existing capsule routes through the entrances.
No changes to cloud-test, beta, database, account/session behavior or house gates.


## 0.10.0 — Cloud-test .96-east.2 parity

Matches cloud-test through commit `024c607`: market orders/pickup, carried
supplies, property computers, rent, crew contacts and door dealer service,
Malik/Rod models, fitted furniture and the east residential expansion.
Use **E** at computers, checkout, couch, doors and switches. Move to stand up.
The player eye height is 2.16 and walking speed is 3.4 to match the new scale.
Doors open away and allow safe pass-through while moving, restoring collision
once clear. The leaderboard pins your own server total and handles filter
changes and pending sync correctly. See `docs/CLOUDTEST_96_SYNC.md`.

0.11.1: widened the portrait phone and fixed controller pointer coordinates being scaled twice at non-default window sizes. Category hit tests cover centers and both sides at 720p, 800p, 1080p and ultrawide.

Routine background cloud saves no longer replace the gameplay status text. Manual save confirmations, cloud conflicts and failed-sync warnings remain visible; saving and shared progress are unchanged.

## 0.12 police district

Cloud-test map source: `a77bb9eb81d9ec0320e3c78373e99fe61ebfd0cf` / `.97-police.2`. Walk east beyond the preserved park to reach the two-floor station, rear patrol parking, public parking, crossing road and four opposite houses. The station has 14 usable doors, including two cell doors, and continuous physical stairs. Native colliders replace the web camera collision checks. These are explorable interiors; upstream has not added police NPCs, arrests or evidence gameplay.

All three park benches can be used with Interact; move to stand. Bench and couch eyes now match the shared seated rig. The east fence is at x=201; upstairs desktop positions are saved locally with height.
