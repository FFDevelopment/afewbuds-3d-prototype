# AFewBuds — first-person apartment prototype

An experimental PC version of the **actual AFewBuds apartment**, with first-person movement connected to the existing game simulation. Version **0.7.0**.

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
