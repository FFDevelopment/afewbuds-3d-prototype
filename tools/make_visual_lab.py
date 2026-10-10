#!/usr/bin/env python3
"""Build an isolated offline preview without changing the repository project."""
from pathlib import Path
import shutil,sys
repo=Path(__file__).resolve().parents[1]
destination=Path(sys.argv[1]).resolve()
if destination.exists():raise SystemExit("Choose a new destination directory.")
shutil.copytree(repo/"game",destination,ignore=shutil.ignore_patterns(".godot",".git"))
shutil.copyfile(destination/"visual_lab/project.preview.godot",destination/"project.godot")
shutil.copyfile(destination/"visual_lab/START-HERE.txt",destination/"START-HERE.txt")
print(destination/"project.godot")
