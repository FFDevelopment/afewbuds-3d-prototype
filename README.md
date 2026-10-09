# AFewBuds desktop — playable baseline

This repository's `main` branch tracks the tested gameplay source of **AFewBuds Desktop Beta 0.16.0-beta.9**.

- Release source commit: `4dfdb0d4d2bce60afdc18aa0b3d460d122a33d75`
- Public Windows/Linux downloads and launcher: https://github.com/FFDevelopment/AFewBuds-Desktop-Beta/releases
- `main` is the **playable source baseline**, not the universal-property experiment.
- Ongoing universal property/shared-core work: `feature/dynamic-property-registry-v1` (starts from this beta.9 gameplay source). Do not mistake its draft PR for a release.
- Pre-alignment baseline remains available at `archive/pre-beta9-main-baseline`.
- Every push to `main` builds and runs desktop Godot tests and produces Windows/Linux test artifacts. Public beta publishing is controlled by the separate distribution repository and its pinned source commit.

The desktop game retains Windows keyboard/mouse, controller and phone UI controls, login and cloud career, house and apartment inventory isolation, bills, furniture, equipment, and NPCs.

**Do not change an existing player's save directory, account ID, session, character progress, or cloud save to align repository baselines.** Shared gameplay systems belong in both development repositories and should be tested on both platforms before public promotion.
