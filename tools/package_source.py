from pathlib import Path
import zipfile
root = Path(__file__).resolve().parents[1]
output = root / 'build' / 'AFewBuds-3D-Prototype-Source.zip'
output.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(root.rglob('*')):
        rel = path.relative_to(root)
        if not path.is_file() or any(p in {'.git', '.godot', 'build', '__pycache__'} for p in rel.parts) or path.suffix == '.log':
            continue
        archive.write(path, Path('AFewBuds-3D-Prototype') / rel)
print(output)
