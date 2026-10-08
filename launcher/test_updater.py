import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
from updater import ASSET, EXE, REPO, API, InstanceLock, AlreadyRunning, Updater, UpdateError, release_candidate, unpack


def archive(tag, extra=None):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w') as z:
        def write(name, value):
            info = zipfile.ZipInfo('fixture', date_time=(2020, 1, 1, 0, 0, 0))
            # Preserve hostile names literally: Windows ZipInfo normally normalizes backslashes.
            info.filename = name
            z.writestr(info, value)
        write(EXE, b'MZ' + tag.encode())
        if 'BUILD_VERSION.txt' not in (extra or {}): write('BUILD_VERSION.txt', 'AFewBuds Desktop ' + tag[1:] + '\nSource: fixture\n')
        for name, value in (extra or {}).items(): write(name, value)
    return buffer.getvalue()


def release(tag):
    return {'tag_name': tag, 'prerelease': True, 'draft': False, 'assets': [{'name': n, 'state': 'uploaded', 'browser_download_url': f'https://github.com/{REPO}/releases/download/{tag}/{n}'} for n in [ASSET, 'SHA256SUMS.txt']]}


class Server:
    def __init__(self):
        self.tag = 'v0.16.0-beta.4'
        self.bad_hash = False
        self.offline = False
        self.extra = {}
        self.calls = []
    def __call__(self, url, destination=None, report=lambda *_: None, limit=None):
        self.calls.append(url)
        if self.offline: raise OSError('Offline')
        data = archive(self.tag, self.extra)
        if url == API: return json.dumps([release(self.tag)]).encode()
        if url.endswith('SHA256SUMS.txt'):
            digest = '0'*64 if self.bad_hash else hashlib.sha256(data).hexdigest()
            return f'{digest}  {ASSET}\n'.encode()
        destination.write_bytes(data); report('fixture download', 1)


class Updates(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.server = Server()
        self.updater = Updater(self.root / 'launcher', self.server)
        self.save = self.root / 'Godot' / 'app_userdata' / 'AFewBuds-Inventory-Preview' / 'career.json'
        self.save.parent.mkdir(parents=True); self.save.write_text('valuable career and login')
    def tearDown(self): self.temp.cleanup()
    def test_install_update_and_rollback_preserve_saves(self):
        first = self.updater.prepare()
        self.assertTrue(first.is_file())
        self.server.tag = 'v0.16.0-beta.5'
        second = self.updater.prepare()
        self.assertNotEqual(first, second)
        self.assertTrue(first.is_file())
        self.assertTrue(self.updater.rollback())
        self.assertEqual(self.updater.installed(), first)
        self.assertEqual(self.save.read_text(), 'valuable career and login')
    def test_no_download_when_current_or_remote_older(self):
        self.updater.prepare(); self.server.calls.clear()
        self.updater.prepare()
        self.assertEqual(self.server.calls, [API])
        self.server.tag = 'v0.16.0-beta.3'
        self.updater.prepare()
        self.assertEqual(self.updater.state()['active']['tag'], 'v0.16.0-beta.4')
    def test_failed_verification_keeps_previous_active(self):
        first = self.updater.prepare(); before = self.updater.state_path.read_bytes()
        self.server.tag = 'v0.16.0-beta.5'; self.server.bad_hash = True
        with self.assertRaises(UpdateError): self.updater.prepare()
        self.assertEqual(self.updater.state_path.read_bytes(), before)
        self.assertEqual(self.updater.installed(), first)
    def test_offline_keeps_installed_build_available(self):
        first = self.updater.prepare(); self.server.offline = True
        with self.assertRaises(OSError): self.updater.prepare()
        self.assertEqual(self.updater.installed(), first)
    def test_damaged_build_is_not_launched_and_can_be_repaired(self):
        exe = self.updater.prepare(); exe.write_bytes(b'damaged')
        self.assertIsNone(self.updater.installed())
        self.assertEqual(self.updater.prepare(), exe)
        self.assertIsNotNone(self.updater.installed())
    def test_no_previous_version_does_not_corrupt_state(self):
        self.updater.prepare(); before = self.updater.state()
        self.assertFalse(self.updater.rollback())
        self.assertEqual(self.updater.state(), before)
    def test_complete_beta_selection_ignores_drafts_and_partial_uploads(self):
        draft = release('v9.0.0-beta.1'); draft['draft'] = True
        partial = release('v8.0.0-beta.1'); partial['assets'].pop()
        self.assertEqual(release_candidate([release('v0.16.0-beta.9'), release('v0.16.0-beta.10'), draft, partial])[1], 'v0.16.0-beta.10')
    def test_untrusted_asset_url_is_rejected(self):
        bad = release('v0.16.0-beta.4'); bad['assets'][0]['browser_download_url'] = 'https://example.org/game.zip'
        with self.assertRaises(UpdateError): release_candidate([bad])
    def test_archive_traversal_and_windows_aliases_rejected(self):
        for name in ['../escape.exe', '/absolute', 'C:/escape', 'folder\\escape', 'game.exe:stream', 'CON', 'file.', 'file ', EXE.upper()]:
            with self.subTest(name=name):
                self.server.extra = {name: b'bad'}
                with self.assertRaises(UpdateError): self.updater.prepare()
        self.assertFalse((self.updater.root / 'escape.exe').exists())
    def test_wrong_packaged_version_is_rejected(self):
        self.server.extra = {'BUILD_VERSION.txt': 'AFewBuds Desktop 0.1.0\n'}
        with self.assertRaises(UpdateError): self.updater.prepare()
    def test_single_instance_lock(self):
        lock = InstanceLock(self.updater.root)
        try:
            with self.assertRaises(AlreadyRunning): InstanceLock(self.updater.root)
        finally: lock.close()
        second = InstanceLock(self.updater.root); second.close()
    def test_symlink_rejected(self):
        zpath = self.root / 'symlink.zip'
        with zipfile.ZipFile(zpath, 'w') as z:
            info = zipfile.ZipInfo('link'); info.create_system = 3; info.external_attr = (0o120777 << 16)
            z.writestr(info, '../save')
        with self.assertRaises(UpdateError): unpack(zpath, self.root / 'out', self.server.tag)

if __name__ == '__main__': unittest.main()
