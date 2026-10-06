# Cloud-test .96-east.2 → desktop 0.10.0

Pinned upstream: `024c60729d796d9580130cd97b3b7915b846493c`.
Previous gameplay baseline: .83. Reviewed every intervening commit (.84–.96,
character/furniture fit, east expansion and corrected tree planting).

## Gameplay parity

- Central Market checkout, seed and fertilizer pickup, finite carried supplies,
  apartment deposits, prepaid equipment delivery and computer installation.
- Apartment rent: $600 every 14 active game days, initial 14-day grace,
  original payment and overdue rules. No database changes.
- Property computers, streamlined Illegal Businesses/Store/Contacts/Messages
  phone navigation; inventory, genetics, staff and upgrades at the computer.
- Crew threads, property assignments, remote storefront commands, apartment
  door dealer, shared packaged stock and inverse action buttons.
- Supplied Malik/Rod rigs with idle, walk and sit clips; fitted couch,
  idle crew seating and player seating (E; movement stands).
- Furniture proportions and 2.16 eye height match the new 2.35-unit characters.
  Walking speed 3.4; mouse look, sprint and FOV 76 remain desktop controls.
- East streets, nineteen residential exteriors, five garages and pocket park.
  Decorative properties stay non-enterable. Tree soil/cutouts align with trunks;
  dedicated desktop bark material retained.
- Away-opening doors retain opening direction when closing; moving leaves
  temporarily stop colliding and become solid only after the player clears them.

## Desktop adaptations

Native E raycasts replace mobile tap/stick actions for computers, checkout,
seating, lights and doors. Geometry uses physical player collisions, not the
browser's camera collision grid. Existing apartment/house/shop remain walkable.
Computer panels release the pointer and block walking; Escape closes them.
Desktop camera/settings remain separate from shared career state.

The native leaderboard now renders the server's `me.value`, including players
outside the top 25, and covers all eight browser metrics. Pending save/report
work finishes before refresh. In-flight filter changes request the latest filter
instead of labeling an old response with a new period. Missing values show
Unavailable, not zero. Offline/conflict status stays visible. No live account
statistics were changed or fabricated; account validation uses HTTP fixtures.

## Scope

Only the prototype integration branch changes. Cloud-test, beta, production
schema and account service remain unchanged. Single-session enforcement remains
separate work. Existing characters/assets retain their original scales and bytes.

## Validation

Ten isolated suites pass: native movement/interactions, all door directions,
property inspection, world controls, appointments, commerce/rent/deposits and
paid installation, door dealer accounting, model rigs/animations/couch fit,
shared cloud-save conflicts, and HTTP login/recovery/leaderboard contracts.
Native E tests cover both computers and checkout; capsule tests cross the old
east boundary and new junction, check ground and the relocated fence.
Desktop render review covers the east district, couch/characters, house and
computer UI. Exported-world smoke explicitly loads both character rigs.
