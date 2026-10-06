# Cloud-test .82 adaptation — prototype 0.9.6

Source reviewed: FFDevelopment/afewbuds-cloud-test at
`b0664c121cfc75b6c0b2eb556d4bef03405a7f7e` (2026-10-06).
Reviewed the .76–.82 commit notes, neighborhood81 README, .82 pack builder,
interiors/neighborhood sources, controls, weather and client-visit checks.
Previous prototype 0.9.5 already included .72 password recovery compatibility.

## Adopted

- .76–.77 interior refinements: bathroom aperture trim, brick/plaster shop walls,
  furniture clearances, house porch, market roof, and parked vehicles. House entry
  retains `property_offer_unlocked` (Chapter 4); interiors remain preview tours.
- .78 Central Market naming and away-client texts. Reply now (10 game minutes),
  one hour, two hours, or another time. Appointments persist in phone messages;
  home arrivals use existing sales, patience and knock logic. Official visits
  defer until the player returns. The obsolete Go to Door button stays hidden.
- .79–.80 saved house/market light circuits, all ten house window coverings,
  apartment blind, grow-room service panel and separate house equipment state.
  House tents start at zero independently of apartment upgrades. No house purchase
  or upgrade economy is introduced by this synchronization.
- Real transparent apartment window replaces painted sky/sun props; original
  interior painted surfaces and curtains remain. Window collision is retained.
- Animated sky, east-to-west sun, moon/clouds, continuous ambient transitions,
  shadowed room lights and night street lamps.
- Cloud-test exterior texture atlas/shader; matching apartment upper/lower brick.
- .81–.82 recessed tree soil, exterior window/entry trim and sealed door headers.

## Native adaptations

First-person capsule, 1.90 m eye height, 76 degree FOV, existing map/fence footprint,
portrait desktop phone, compact alert, packaging/locker upgrades and account flow
remain. Physical controls use E with close aiming, room checks and wall occlusion.
Doors retain swept-capsule clearance for both opening and closing. A career saved
inside the previous unrestricted house tour can still exit before Chapter 4. Mobile joystick,
double-tap input and web pack loader are not copied. A parked car now occupies the
upstream curbside location; the road crossing regression test uses a clear lane.

`house_control_state` is included in the existing career JSON. Appointments remain
inside `phone_text_messages`, matching upstream. Camera/settings remain desktop-only.
No backend, schema, account endpoint, playtime or single-session changes are made.
The intervening backend leaderboard/admin SQL updates are not applied by this repo.

## Validation

Isolated Godot tests cover existing movement/doors/bench/locker/progression,
E-operated room/market circuits and coverings, outside/through-wall rejection,
empty house grow room, real career save/reload, sky direction/night lamps,
away/home appointment flow and timing, pause, decline, repeat suppression,
missed appointments, deferred official visits, shared-save merge/conflict handling,
and mock-HTTP login/password recovery. No live account or recovery email is used.

Renderer captures review the actual apartment, streets, house and shop geometry.
GitHub Actions additionally imports assets, runs the tests, exports Windows/Linux,
and starts the exported Linux binary to check packaged resources.
