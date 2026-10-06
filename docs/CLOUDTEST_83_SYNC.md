# Prototype 0.9.7 — cloud-test .83 and tree bark

Compared prototype 0.9.6 (`cbfa21180b90354735106a0b101479b89c827f99`)
with cloud-test .83 (`25ca654a130ded9fde46d61dc9d53111ea64ba1b`).
Reviewed the commit, .83 README, pack-builder changes, neighborhood diff,
property-opportunity implementation and upstream inspection test.

The new gameplay delta is Rod's property opportunity: gated property details,
a physical six-room inspection, two active seconds per room, and persistent
`property_opportunity_state` in the existing career JSON. This does not purchase
the property, charge money, transfer stock/equipment, or complete a chapter.
There are no new account/database changes in this upstream commit.

Native adaptation: E at the sign/house entrance opens details; the panel releases
the cursor and blocks movement. Tour restores walking and opens the physical door
only when nearby. From the sale sign, walk to the entrance and use E. T reviews
progress during a tour; Escape or End Tour closes it. Door sweep refusals retain
their guidance, and older saves inside a locked house can still exit.
The modal and pause state suspend room-inspection progress.

Tree trunks were incorrectly mapped to exterior tile 5, the generic gravel/soil
surface. A dedicated procedural bark shader now supplies brown vertical ridges;
ground and tree-bed materials are unchanged. No external texture dependency.

Validation: six isolated suites pass (existing gameplay; property gate/details,
physical entrance/no teleport, six rooms, actual career serialization/reload,
invalid/duplicate room IDs, pause, T/Escape controls and unchanged cash/equipment;
room controls/sky; client appointments; cloud-save merge; mock login/recovery).
Rendered bark, details at 1280x800 and 900x600, and tour progress in the house.
CI imports and exports Windows/Linux, then starts the packaged world in its
isolated headless check. No live account or email test is used.

Only the prototype integration branch changes. Beta, cloud-test, the database,
and prototype main remain untouched. Single-session enforcement remains deferred.
