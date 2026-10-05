"""Run engine integration tests in an isolated, disposable save directory."""
from pathlib import Path
import os, subprocess, sys, tempfile
root = Path(__file__).resolve().parents[1]
game = root / 'game'
godot = str(Path(sys.argv[1]).resolve()) if len(sys.argv) > 1 else 'godot'
with tempfile.TemporaryDirectory(prefix='afb-prototype-test-') as temp:
    fixture = Path(temp)
    for entry in game.iterdir():
        if entry.name != 'project.godot':
            (fixture / entry.name).symlink_to(entry, target_is_directory=entry.is_dir())
    (fixture / 'project.godot').write_text((game / 'project.godot').read_text().replace('custom_user_dir_name="AFewBuds-3D-Prototype"', 'custom_user_dir_name="AFewBuds-3D-Prototype-QA"'))
    env = dict(os.environ, XDG_DATA_HOME=str(fixture / 'userdata'))
    run = subprocess.run([godot, '--headless', '--path', str(fixture), '--script', 'prototype/smoke_test.gd'], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90)
    print(run.stdout)
    if run.returncode or 'PROTOTYPE_TEST_RESULT: PASS' not in run.stdout or 'SCRIPT ERROR' in run.stdout or 'ERROR:' in run.stdout:
        sys.exit(1)
