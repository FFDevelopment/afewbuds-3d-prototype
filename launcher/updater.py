"""Verified, per-user Windows game updates. Never reads or writes game saves."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import tempfile
import urllib.request
import zipfile

REPO = 'FFDevelopment/AFewBuds-Desktop-Beta'
API = f'https://api.github.com/repos/{REPO}/releases?per_page=30'
ASSET = 'AFewBuds-Windows-Beta.zip'
EXE = 'AFewBuds-3D-Prototype.exe'
MAX_DOWNLOAD = 512 * 1024 * 1024
MAX_EXPANDED = 1536 * 1024 * 1024
TAG = re.compile(r'^v(\d+)\.(\d+)\.(\d+)(?:-beta\.(\d+))?$')

class UpdateError(Exception):
    pass

class AlreadyRunning(UpdateError):
    pass

class InstanceLock:
    def __init__(self, root: Path):
        root.mkdir(parents=True, exist_ok=True)
        self.file = (root / 'launcher.lock').open('a+b')
        try:
            if self.file.seek(0, 2) == 0:
                self.file.write(b'0'); self.file.flush()
            self.file.seek(0)
            if os.name == 'nt':
                import msvcrt
                msvcrt.locking(self.file.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            self.file.close()
            raise AlreadyRunning('AFewBuds is already open. Return to the running game.') from exc
    def close(self):
        self.file.close()


def version(tag):
    match = TAG.fullmatch(tag)
    if not match:
        raise UpdateError('Invalid release version.')
    a, b, c, beta = match.groups()
    return int(a), int(b), int(c), int(beta) if beta else 10**9


def release_candidate(releases):
    candidates = []
    for release in releases:
        tag = release.get('tag_name', '')
        assets = {a['name']: a for a in release.get('assets', []) if a.get('state') == 'uploaded'}
        if release.get('draft') or not TAG.fullmatch(tag) or not {ASSET, 'SHA256SUMS.txt'} <= assets.keys():
            continue
        for name in (ASSET, 'SHA256SUMS.txt'):
            expected = f'https://github.com/{REPO}/releases/download/{tag}/{name}'
            if assets[name].get('browser_download_url') != expected:
                raise UpdateError('Unexpected release download address.')
        candidates.append((version(tag), tag, assets))
    if not candidates:
        raise UpdateError('No complete Windows release is available yet.')
    return max(candidates, key=lambda entry: entry[0])


def fetch(url, destination=None, report=lambda *_: None, limit=MAX_DOWNLOAD):
    request = urllib.request.Request(url, headers={'User-Agent': 'AFewBuds-Launcher/1.0', 'Accept': 'application/vnd.github+json' if url == API else '*/*', 'Cache-Control': 'no-cache'})
    with urllib.request.urlopen(request, timeout=25) as response:
        total = int(response.headers.get('Content-Length', 0))
        if total > limit:
            raise UpdateError('Download is larger than expected.')
        stream = destination.open('wb') if destination else None
        chunks, received = [], 0
        try:
            while True:
                data = response.read(256 * 1024)
                if not data:
                    break
                received += len(data)
                if received > limit:
                    raise UpdateError('Download exceeded its size limit.')
                if stream:
                    stream.write(data)
                else:
                    chunks.append(data)
                report(f'Downloading update… {received // (1024*1024)} MB', received / total if total else 0)
            if total and received != total:
                raise UpdateError('The download was interrupted. Please retry.')
        finally:
            if stream:
                stream.close()
        return b''.join(chunks) if destination is None else None


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def checksum(text):
    matches = [line.split() for line in text.splitlines() if len(line.split()) == 2 and line.split()[1].lstrip('*') == ASSET]
    if len(matches) != 1 or not re.fullmatch('[0-9a-fA-F]{64}', matches[0][0]):
        raise UpdateError('The release is missing a valid Windows checksum.')
    return matches[0][0].lower()


def unpack(archive, target, tag):
    with zipfile.ZipFile(archive) as bundle:
        members = bundle.infolist()
        if len(members) > 1000 or sum(m.file_size for m in members) > MAX_EXPANDED:
            raise UpdateError('Unexpected update archive size.')
        names = set()
        for member in members:
            name = member.orig_filename
            path = PurePosixPath(name)
            # Windows drive paths, alternate streams, symlinks and aliases are forbidden.
            if not name or '\\' in name or ':' in name or path.is_absolute() or '..' in path.parts or any(p.rstrip(' .') != p or p.upper().split('.')[0] in {'CON','PRN','AUX','NUL',*[f'COM{i}' for i in range(1,10)],*[f'LPT{i}' for i in range(1,10)]} for p in path.parts):
                raise UpdateError('Unsafe path in update archive.')
            if stat.S_ISLNK(member.external_attr >> 16) or name.lower() in names:
                raise UpdateError('Unsafe or duplicate archive entry.')
            names.add(name.lower())
        if EXE.lower() not in names or 'build_version.txt' not in names:
            raise UpdateError('The archive does not contain the Windows game.')
        bundle.extractall(target)
    if not (target / EXE).is_file():
        raise UpdateError('The Windows executable is missing.')
    with (target / EXE).open('rb') as executable:
        if executable.read(2) != b'MZ':
            raise UpdateError('The Windows executable is invalid.')
    if not (target / 'BUILD_VERSION.txt').read_text(encoding='utf-8').startswith('AFewBuds Desktop ' + tag[1:] + '\n'):
        raise UpdateError('The packaged game version does not match the release.')
    return {str(p.relative_to(target)).replace('\\','/'): sha256(p) for p in target.rglob('*') if p.is_file()}


class Updater:
    def __init__(self, root, transport=fetch):
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)
        self.transport = transport
        self.state_path = self.root / 'installed.json'

    def state(self):
        try:
            return json.loads(self.state_path.read_text(encoding='utf-8'))
        except (OSError, ValueError):
            return {}

    def write_state(self, state):
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=self.root, delete=False) as f:
            json.dump(state, f); f.flush(); os.fsync(f.fileno()); temp = f.name
        os.replace(temp, self.state_path)

    def installed(self, record=None):
        record = self.state().get('active', {}) if record is None else record
        tag, files = record.get('tag', ''), record.get('files', {})
        if not TAG.fullmatch(tag) or EXE not in files:
            return None
        folder = self.root / 'versions' / tag
        try:
            for name, digest in files.items():
                path = folder / name
                if not path.resolve().is_relative_to(folder.resolve()) or sha256(path) != digest:
                    return None
            return folder / EXE
        except (OSError, ValueError):
            return None

    def prepare(self, report=lambda *_: None):
        report('Checking for updates…', 0)
        releases = json.loads(self.transport(API, limit=2 * 1024 * 1024))
        _, tag, assets = release_candidate(releases)
        state = self.state()
        current = self.installed()
        if current and version(state['active']['tag']) >= version(tag):
            return current
        report('Verifying release details…', 0)
        digest = checksum(self.transport(assets['SHA256SUMS.txt']['browser_download_url'], limit=64*1024).decode('utf-8'))
        with tempfile.TemporaryDirectory(prefix='update-', dir=self.root) as work:
            work = Path(work)
            archive, unpacked = work / 'game.zip', work / 'game'
            self.transport(assets[ASSET]['browser_download_url'], destination=archive, report=report)
            report('Verifying download…', 0.96)
            if sha256(archive) != digest:
                raise UpdateError('Download verification failed. Your installed game has not changed.')
            files = unpack(archive, unpacked, tag)
            final = self.root / 'versions' / tag
            final.parent.mkdir(exist_ok=True)
            if final.exists():
                # A damaged/interrupted copy can be rebuilt; the running version is locked.
                shutil.rmtree(final)
            os.replace(unpacked, final)
            record = {'tag': tag, 'archive_sha256': digest, 'files': files}
            self.write_state({'active': record, 'previous': state.get('active', {})})
        report('Starting AFewBuds ' + tag[1:] + '…', 1)
        return final / EXE

    def rollback(self):
        state = self.state()
        previous = state.get('previous', {})
        if self.installed(previous):
            self.write_state({'active': previous, 'previous': {}})
            return True
        return False
