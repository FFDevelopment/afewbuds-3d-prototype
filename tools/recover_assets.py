"""One-time recovery of owned assets from the pinned AFewBuds runtime snapshot.
No game scripts are overwritten. Subsequent builds use the committed assets.
"""
from pathlib import Path, PurePosixPath
import hashlib, shutil, struct, subprocess, sys, tempfile, urllib.request

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'game' / 'assets'
COMMIT = '233bbbd1324c1397ea4ef1953e59b8f0600a4937'
DIGEST = 'c471ab6dd7be6778e8e4b31976e46840b11464edc98745bf85f5c7a6a2cc222a'
URL = f'https://raw.githubusercontent.com/FFDevelopment/afewbuds-cloud-test/{COMMIT}/index-cloudtest10.pck'
GODOT = str(Path(sys.argv[1]).resolve()) if len(sys.argv) > 1 else 'godot'

RECOVER = r'''extends SceneTree
func _initialize() -> void:
    var failures: Array[String] = []
    for file_path: String in walk("res://assets"):
        if not file_path.ends_with(".import"):
            continue
        var config := ConfigFile.new()
        var bytes := FileAccess.get_file_as_bytes(file_path)
        while not bytes.is_empty() and bytes[-1] == 0:
            bytes.resize(bytes.size() - 1)
        if config.parse(bytes.get_string_from_utf8()) != OK:
            failures.append(file_path)
            continue
        var source := file_path.trim_suffix(".import")
        if FileAccess.file_exists(source):
            continue
        var resource_path: String = config.get_value("remap", "path", "")
        if source.ends_with(".wav"):
            if DirAccess.copy_absolute(resource_path, source.trim_suffix(".wav") + ".sample") != OK:
                failures.append(source)
            continue
        var item: Resource = load(resource_path)
        if item is Texture2D:
            var img: Image = item.get_image()
            if img.is_compressed():
                img.decompress()
            if source.ends_with(".svg"):
                source = source.trim_suffix(".svg") + ".png"
            if img.save_png(source) != OK:
                failures.append(source)
        else:
            failures.append(resource_path)
    print("ASSET_RECOVERY: ", "PASS" if failures.is_empty() else str(failures))
    quit(0 if failures.is_empty() else 1)
func walk(path: String) -> Array[String]:
    var result: Array[String] = []
    for file: String in DirAccess.get_files_at(path):
        result.append(path.path_join(file))
    for sub: String in DirAccess.get_directories_at(path):
        result.append_array(walk(path.path_join(sub)))
    return result
'''

def extract(blob, directory):
    if blob[:4] != b'GDPC':
        raise ValueError('Not a Godot PCK')
    base, offset = struct.unpack_from('<QQ', blob, 24)
    count = struct.unpack_from('<I', blob, offset)[0]
    pos = offset + 4
    for _ in range(count):
        length = struct.unpack_from('<I', blob, pos)[0]; pos += 4
        name = blob[pos:pos+length].rstrip(b'\0').decode().removeprefix('res://'); pos += length
        start, size = struct.unpack_from('<QQ', blob, pos); pos += 16
        md5 = blob[pos:pos+16]; pos += 16
        flags = struct.unpack_from('<I', blob, pos)[0]; pos += 4
        relative = PurePosixPath(name)
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError('Unsafe package path')
        data = blob[base+start:base+start+size]
        if len(data) != size or hashlib.md5(data).digest() != md5:
            raise ValueError('Corrupt package entry: ' + name)
        if not (name.startswith('assets/') or name.startswith('.godot/imported/')):
            continue
        path = directory / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

with tempfile.TemporaryDirectory(prefix='afb-asset-recovery-') as temporary:
    temp = Path(temporary)
    request = urllib.request.Request(URL, headers={'User-Agent': 'AFewBuds-prototype-asset-recovery'})
    with urllib.request.urlopen(request, timeout=120) as response:
        blob = response.read()
    if hashlib.sha256(blob).hexdigest() != DIGEST:
        raise ValueError('Pinned source package checksum mismatch')
    extract(blob, temp)
    (temp / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="AFB Asset Recovery"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    (temp / 'recover.gd').write_text(RECOVER)
    result = subprocess.run([GODOT, '--headless', '--path', str(temp), '--script', 'recover.gd'], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
    print(result.stdout)
    if result.returncode or 'ASSET_RECOVERY: PASS' not in result.stdout or 'SCRIPT ERROR' in result.stdout:
        raise RuntimeError('Asset recovery failed')
    for path in (temp / 'assets').rglob('*'):
        if not path.is_file() or path.suffix == '.import':
            continue
        dest = DEST / path.relative_to(temp / 'assets')
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, dest)
    if len([p for p in DEST.rglob('*') if p.is_file() and p.suffix != '.import']) < 95:
        raise ValueError('Recovered asset count too small')
    (DEST / '.recovered-source').write_text(f'{COMMIT}\n{DIGEST}\n')
print('Pinned AFewBuds assets recovered successfully.')
