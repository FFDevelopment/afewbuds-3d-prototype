# Equipment items experiment

See [equipment preview instructions](EQUIPMENT_PREVIEW.md) for the paired cloud and desktop test builds. The older baseline notes below describe production/main.

# Inventory test build

This branch is an isolated inventory experiment. See [preview instructions and save behavior](INVENTORY_PREVIEW.md).

# AFewBuds — desktop 3D baseline

`main` is the canonical desktop game. Baseline: **0.13.2-preview**, paired with [mobile 3D v12](https://github.com/FFDevelopment/afewbuds-cloud-test).

## Download and play

Open [Actions → Build desktop baseline](https://github.com/FFDevelopment/afewbuds-3d-prototype/actions/workflows/build.yml), choose the latest successful **main** run, and download its version-labelled **Windows** or **Linux** artifact. Extract the ZIP and launch the executable. `BUILD_VERSION.txt` identifies the version and source commit. No Godot installation is required.

Use your existing AFewBuds account or continue locally as a guest. Save and close one version before switching to the other. Desktop 0.13.2 fixes integer formatting in cloud uploads so leaderboard counters remain correct; save or open Leaderboard to report the corrected counters.

## Included

Physics movement, working doors/stairs, sprint stamina, Bongchester district HUD, newest-first messages, Chapter 4 property finale, house agreements and relocation, Real Estate, apartment release safeguards, per-property utilities, and preserved purchased upgrades.

Chapter 5 begins with **Building an Operation**, but its full mission chain and finale are not implemented. Interactive furniture editing and further phone reorganization remain pending.

## Controls

| Input | Action |
| --- | --- |
| WASD / mouse | Walk / look |
| Shift + forward | Sprint using stamina |
| E | Interact |
| P | Phone |
| Escape | Back / pause / settings |
| F5 | Save |

Controls & Display Settings supports rebinding, sensitivity and display options. Desktop input/settings stay separate from shared career progression.

## Development

Godot **4.7.2** project: `game/project.godot`. Import with `godot --headless --path game --editor --import --quit`. Run `python tools/test.py <godot-executable>` for isolated integration tests. Pushes to `main` run the full suite, export Windows/Linux, smoke-test the exported game and publish version-labelled packages.

See `AGENTS.md` for paired-release rules, `DISTRICTS.md` for district boundaries, `PROVENANCE.md` for source history, and `docs/HISTORICAL_README.md` for archived development notes.
