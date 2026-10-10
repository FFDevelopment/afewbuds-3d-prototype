# AFewBuds 3D Prototype — Windows development test

This is the **desktop development build** (`FFDevelopment/afewbuds-3d-prototype`), not the public Windows tester beta. Its underlying game version is `0.16.0-beta.9`, based on the public beta.9 gameplay, with shared Property and Item Registries.

**Development download:** https://github.com/FFDevelopment/afewbuds-3d-prototype/releases (prereleases tagged `dev-shared-core-...`). Download `AFewBuds-Windows-Development-Test.zip`, extract the entire ZIP, and run `AFewBuds-3D-Prototype.exe`. This standalone test **does not use the public auto-update launcher** and its Windows title reads `AFewBuds Desktop Development`.

## Save and account protection
Both phone and desktop use the same Supabase `afb_begin_play` / `afb_save_career` server session and revision protocol. The desktop **can load and write the regular account career**. Before testing, save and close the phone game; avoid running both simultaneously. Back up important saves and use a separate account for destructive testing. The desktop preserves its current custom Godot user-data directory `AFewBuds-Inventory-Preview`, so a new window title does not migrate player files.

The desktop fixture test `game/account/career_parity_test.gd` validates phone-to-desktop tent placement and packing, named dealer/production workers, property-separated stock, unknown fields, session handoff, and stale revision rejection using **fictional local data only**. It is part of the normal `tools/test.py` regression suite, followed by verified Windows and Linux exports and an exported-world smoke test.

The current core registry does not yet make arbitrary future properties fully functional. Computers, utilities, grow systems, and workers for unknown new buildings still require adapters.

