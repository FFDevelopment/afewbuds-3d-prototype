# Friend character review

Open `review.tscn` and run the current scene (F6). Select a friend and session partner to inspect lighting, smoking and shared passes. The gameplay NPC factory uses the same approved models for all nine existing contacts.

The session controller is a preview, not yet connected to gameplay inventory, social requests or multiplayer. Character appearance integration retains current save/contact IDs. The source assets and hashes are recorded in `assets/characters/friends_manifest.json`.

Validated locally: all nine rig/atlas/scale/seating checks, worker and visitor identity switching, dealer/crew regression checks, and mobile character import and movement.

Review 08 checks actual right-thumb direction during reaching and passing. Run `--headless --path game --script character_lab/check_session.gd` to validate the shared session.
