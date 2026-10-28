"""Regression tests for publication boundaries; no real credentials are used."""
import json
import os
import secrets
import shutil
import subprocess
import tempfile
from unittest.mock import patch
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from audit_public import app_allowed, entry_issues, scan

class PublicAuditTests(unittest.TestCase):
    def test_source_and_placeholder_config_are_allowed(self):
        self.assertEqual(entry_issues('Sources/SayseeApp/Keychain.swift', '100644', b'let key = token'), [])
        self.assertEqual(entry_issues('.env.example', '100644', b'# configure a credential outside the repository'), [])

    def test_private_and_generated_paths_are_rejected(self):
        for path in ['.env', 'experiments/results.txt', 'docs/internal/notes.md', 'dist/Saysee.app/app', 'Resources/service-account.json']:
            self.assertTrue(entry_issues(path, '100644', b'{}'), path)

    def test_symlinks_and_large_blobs_are_rejected(self):
        self.assertTrue(entry_issues('Resources/link', '120000', b'/outside'))
        self.assertTrue(entry_issues('Resources/blob', '100644', b'x' * 2_000_001))

    def test_private_key_and_service_account_json_are_rejected(self):
        marker = ('-' * 5 + 'BEGIN PRIVATE KEY' + '-' * 5).encode()
        self.assertIn('private-key material', entry_issues('Resources/data.txt', '100644', marker))
        data = json.dumps({'type': 'service_account', 'private_key': 'synthetic'}).encode()
        self.assertIn('credential JSON', entry_issues('Resources/config.json', '100644', data))

    def test_personal_paths_are_rejected(self):
        data = ('/' + 'Users' + '/developer/private/file').encode()
        self.assertIn('personal absolute path', entry_issues('docs/development.md', '100644', data))

    def test_bundle_rejects_stale_payloads_but_accepts_known_resources(self):
        self.assertTrue(app_allowed('Contents/MacOS/Saysee'))
        self.assertTrue(app_allowed('Contents/Resources/Models/qwen3-asr-1.7b-6bit/config.json'))
        self.assertFalse(app_allowed('Contents/Resources/credentials.json'))
        self.assertFalse(app_allowed('Contents/Resources/Models/qwen3-asr-1.7b-6bit/extra.json'))
        self.assertFalse(app_allowed('Contents/MacOS/old-server'))
        self.assertFalse(app_allowed('Contents/Resources/example.bundle/credentials.json'))
        self.assertFalse(app_allowed('Contents/Resources/Licenses/private.pem'))

    @unittest.skipUnless(shutil.which('gitleaks'), 'gitleaks is required for the scanner integration check')
    def test_scanner_rejects_synthetic_pattern_despite_external_config_and_allow_comment(self):
        with tempfile.TemporaryDirectory(prefix='saysee-scan-test-') as directory:
            p = Path(directory); source = p / 'source'; source.mkdir()
            pattern = 'gh' + 'p_' + secrets.token_hex(18)
            (source / 'synthetic.txt').write_text('test_token = "' + pattern + '" # gitleaks:allow\n')
            report = p / 'report.json'
            with patch.dict(os.environ, {'GITLEAKS_CONFIG': '/nonexistent-saysee-test-config'}):
                with self.assertRaises(subprocess.CalledProcessError):
                    scan(source, report)
            findings = json.loads(report.read_text())
            self.assertTrue(findings)
            self.assertTrue(all(item['Secret'] == 'REDACTED' for item in findings))

if __name__ == '__main__':
    unittest.main()
