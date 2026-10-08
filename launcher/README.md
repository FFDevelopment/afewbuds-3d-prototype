# AFewBuds Windows launcher

Open **AFewBuds.exe** from the Windows ZIP, or download the standalone **AFewBuds-Launcher.exe**. Keep using that launcher (or a shortcut to it) instead of the older AFewBuds-3D-Prototype.exe.

The launcher checks the official desktop beta releases each time it opens, downloads a newer complete Windows build, verifies SHA-256, installs it, and starts the game. No Python installation or administrator access is needed. The first launch requires internet access. If an update cannot be checked or downloaded, Retry update and Play installed are available; Play installed requires a previously verified build.

Installed versions live in `%LOCALAPPDATA%\AFewBudsLauncher`. Existing Godot career and account files remain in their original application directory and are never copied, cleared, or migrated by the launcher. Old versions remain available for rollback. A launcher lock prevents two launcher-managed games or updates running together. Updates happen before play, never while a launcher-managed game is running.

The current launcher protocol updates the game, not the small bootstrap executable itself. Future bootstrap changes may require a new launcher download. Linux continues to use the separate manual ZIP download.

## Validation and packaging

Run `python -m unittest discover -s launcher -v` on Windows and Linux. Build on Windows with Python 3.12 and PyInstaller 6.22.3: `python -m PyInstaller --noconfirm --clean --onefile --windowed --name AFewBuds --paths launcher launcher/main.py`. Run `dist/AFewBuds.exe --ui-smoke` to validate the bundled Tk UI without downloading or launching a game. The release workflow does both before publishing and embeds the launcher in the Windows ZIP.
