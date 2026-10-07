# Cloud-test .97-police.2 → desktop 0.12.0

Pinned source: FFDevelopment/afewbuds-cloud-test at a77bb9eb81d9ec0320e3c78373e99fe61ebfd0cf.

Ported park seating (.96-east.3), police district (.97-police.1), and parking/entrance/window polish (.97-police.2). Source geometry and material shaders are retained. Existing apartment, house, corner market, park, trees and original roads remain; old east-boundary paving ends are shortened to join the new crossing street.

Desktop adaptations: station batches have explicit native static-body colliders; floors and a continuous stair collision ramp support the real player capsule. Native raycast interaction and door safety replace touch-only targeting. Door hulls keep cell bars solid. Park seating stores a safe return position and checks capsule clearance before standing. New pose height stays outside shared saves.

The desktop-only phone is wider but portrait. Controller events use viewport-local coordinates once, avoiding double window scaling. Rendered tests click the category center and both sides at 720p/800p/1080p/ultrawide. Routine cloud status no longer overwrites gameplay text; manual save notices and warning/conflict messages remain. Leaderboards additionally read the exact account’s public career profile, matching the web career-card endpoint, without local-counter substitution.

No changes to cloud-test, beta, database schema or single-session behavior. Police AI/arrest gameplay and controller hardware mapping still require their own work/playtesting.
