# AFewBuds equipment beta source

Public desktop build: 0.16.0-beta.1. Distribution: FFDevelopment/AFewBuds-Desktop-Beta.

Combines tested owned furniture/equipment, Chapter 5, physical packing and grow-shelf access repairs with the Desktop Beta session/save hotfix. Public builds use shared cloud careers; isolated test branches retain their separate career copies.

Existing account cache keys and application save directory are preserved. Run tools/test.py with Godot 4.7.2 to validate the release. The distribution workflow pins this source commit and checks Windows/Linux exports before publishing.

## Automatic Windows updates

Open AFewBuds.exe from the Windows download, or the standalone AFewBuds-Launcher.exe. It checks and installs verified desktop beta updates before launch. Existing saves and account files are preserved. See [launcher/README.md](launcher/README.md).
