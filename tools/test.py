"""Run engine integration tests in an isolated, disposable save directory."""
from pathlib import Path
import os, subprocess, sys, tempfile, json, threading, shutil
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
root = Path(__file__).resolve().parents[1]
game = root / 'game'
godot = str(Path(sys.argv[1]).resolve()) if len(sys.argv) > 1 else 'godot'
class FixtureAPI(BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_POST(self):
        payload = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        valid_key = self.headers.get('apikey', '').startswith('sb_publishable_')
        status = 200
        if self.path == '/functions/v1/afb-password-reset':
            identifier = payload.get('username', '')
            if not valid_key or payload.get('return_url') != 'https://ffdevelopment.github.io/afewbuds-cloud-test/' or identifier != identifier.strip():
                status, data = 400, {'error': 'fixture_contract_mismatch'}
            elif identifier in ('send-failed', 'not-configured', 'unavailable'):
                status, data = 503, {'error': {'send-failed': 'recovery_email_send_failed', 'not-configured': 'recovery_email_not_configured', 'unavailable': 'recovery_service_unavailable'}[identifier]}
            elif identifier == 'malformed':
                data = {}
            elif identifier == 'false-success':
                data = {'ok': False}
            elif identifier == 'long-email' or len(identifier) > 254:
                status, data = 400, {'error': 'fixture_identifier_invalid'}
            else:
                data = {'ok': True, 'message': 'If that AFewBuds account has a recovery email, a reset link has been sent.'}
        elif self.path == '/rest/v1/rpc/fixture_save_numbers':
            # Match the deployed leaderboard SQL: ->> text must be an integer,
            # so 98765.0 is rejected even though its numeric value is integral.
            import re
            save = payload['p_save_json']
            def counter(value):
                text = json.dumps(value, separators=(',', ':'))
                return int(text) if re.fullmatch(r'-?[0-9]+', text) else 0
            data = {'revenue': counter(save['lifetime_revenue']),
                    'sales': counter(save['advancement_stats']['sales']),
                    'harvests': counter(save['advancement_stats']['harvests']),
                    'fraction': save['runtime']['fraction'],
                    'array_counter': counter(save['runtime']['items'][0]['count']),
                    'label': save['runtime']['label'],
                    'active': save['runtime']['active']}
        elif self.path == '/rest/v1/rpc/afb_leaderboard_get':
            import time
            time.sleep(.08)
            weekly = payload.get('p_range') == 'weekly'
            me = {'rank': 31, 'username': 'fixture', 'account_id': 'fixture-id', 'value': 1250 if weekly else 98765}
            data = {'metric': payload.get('p_metric'), 'range': payload.get('p_range'), 'top': [{'rank': 1, 'username': 'other', 'account_id': 'other-id', 'value': 999999}], 'me': me if payload.get('p_session_token') == 'fixture-session' and payload.get('p_metric') != 'sales' else None}
        elif self.path == '/rest/v1/rpc/afb_leaderboard_profile':
            data = {'account_id':'fixture-id','username':'fixture','lifetime_revenue':0,'sales':321,'harvests':42}
        elif self.path == '/rest/v1/rpc/afb_login'  and valid_key and payload.get('p_password') == 'fixture-password':
            data = [{'value': {'account_id': 'fixture-id', 'username': 'fixture', 'session_token': 'fixture-session'}}]
        elif self.path == '/rest/v1/rpc/afb_validate_session' and payload.get('p_session_token') == 'fixture-session':
            data = {'account_id': 'fixture-id', 'username': 'fixture'}
        else:
            status, data = 400, {'message': 'invalid_username_or_password'}
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

server = ThreadingHTTPServer(('127.0.0.1', 0), FixtureAPI)
threading.Thread(target=server.serve_forever, daemon=True).start()
with tempfile.TemporaryDirectory(prefix='afb-prototype-test-') as temp:
    fixture = Path(temp)
    for entry in game.iterdir():
        if entry.name != 'project.godot':
            if os.name == 'nt':
                if entry.is_dir(): shutil.copytree(entry, fixture / entry.name)
                else: shutil.copy2(entry, fixture / entry.name)
            else:
                (fixture / entry.name).symlink_to(entry, target_is_directory=entry.is_dir())
    (fixture / 'project.godot').write_text((game / 'project.godot').read_text().replace('custom_user_dir_name="AFewBuds-Inventory-Preview"', 'custom_user_dir_name="AFewBuds-3D-Prototype-QA"'))
    env = dict(os.environ, XDG_DATA_HOME=str(fixture / 'userdata'), AFB_TEST_HTTP_PORT=str(server.server_port))
    if os.name == 'nt':
        env.update(APPDATA=str(fixture / 'userdata'), LOCALAPPDATA=str(fixture / 'localdata'))
        (fixture / 'userdata').mkdir()
        (fixture / 'localdata').mkdir()
    for script, marker in [("prototype/property_isolation_test.gd", "PROPERTY_ISOLATION_RESULT: PASS"), ("account/preview_test.gd", "PREVIEW_TEST_RESULT: PASS"), ("prototype/equipment_test.gd", "EQUIPMENT_V2_RESULT: PASS"), ("prototype/expansion_test.gd", "EXPANSION_TEST_RESULT: PASS"), ("prototype/session_ui_test.gd", "SESSION_UI_TEST_RESULT: PASS"), ("prototype/tutorial_market_test.gd", "TUTORIAL_MARKET_TEST_RESULT: PASS"), ('prototype/release_readiness_test.gd', 'RELEASE_READINESS_TEST_RESULT: PASS'), ('prototype/controller_ui_test.gd', 'CONTROLLER_UI_TEST_RESULT: PASS'), ('prototype/station_inventory_test.gd', 'STATION_INVENTORY_TEST_RESULT: PASS'), ('prototype/shop_inventory_test.gd', 'SHOP_INVENTORY_TEST_RESULT: PASS'), ('prototype/inventory_test.gd', 'INVENTORY_TEST_RESULT: PASS'), ('prototype/smoke_test.gd', 'PROTOTYPE_TEST_RESULT: PASS'), ('prototype/desktop_test.gd', 'DESKTOP_TEST_RESULT: PASS'), ('prototype/police_test.gd', 'POLICE_TEST_RESULT: PASS'), ('prototype/doors_test.gd', 'DOORS_TEST_RESULT: PASS'), ('prototype/property_test.gd', 'PROPERTY_TEST_RESULT: PASS'), ('prototype/progression_test.gd', 'PROGRESSION_TEST_RESULT: PASS'), ('prototype/updates_test.gd', 'UPDATES_TEST_RESULT: PASS'), ('prototype/visits_test.gd', 'VISITS_TEST_RESULT: PASS'), ('prototype/commerce_test.gd', 'COMMERCE_TEST_RESULT: PASS'), ('prototype/crew_test.gd', 'CREW_TEST_RESULT: PASS'), ('prototype/assets_test.gd', 'ASSETS_TEST_RESULT: PASS'), ('account/cloud_test.gd', 'CLOUD_TEST_RESULT: PASS'), ('account/http_test.gd', 'HTTP_TEST_RESULT: PASS')]:
        if len(sys.argv)>2 and Path(script).stem not in sys.argv[2:]:continue
        # Each suite starts its own career; property/message fixtures must not
        # change the initial inventory or progression of subsequent suites.
        suite_data = fixture / ('userdata-' + Path(script).stem)
        suite_data.mkdir()
        env['XDG_DATA_HOME'] = str(suite_data)
        if os.name == 'nt':
            env.update(APPDATA=str(suite_data), LOCALAPPDATA=str(suite_data))
        try:
            run = subprocess.run([godot, '--headless', *(['--verbose'] if script in ['prototype/visits_test.gd','prototype/progression_test.gd'] else []), '--path', str(fixture), '--script', script], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90)
        except subprocess.TimeoutExpired as exc:
            print(exc.stdout or exc.output or '')
            print(f'TEST_TIMEOUT: {script}', flush=True)
            raise
        print(run.stdout)
        if run.returncode or marker not in run.stdout or 'SCRIPT ERROR' in run.stdout or 'ERROR:' in run.stdout:
            sys.exit(1)

server.shutdown()
