#!/usr/bin/env python3
"""Audit the staged public snapshot, not ignored local research or credentials.

Requires git and gitleaks. Reports are redacted and written beneath ignored dist/.
No upload, commit, credential reads, or network calls are performed by this script.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ROOT_FILES = {
    '.env.example', '.gitattributes', '.gitignore', 'Package.swift',
    'Package.resolved', 'README.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md',
    'SECURITY.md', 'CONTRIBUTING.md', 'CHANGELOG.md',
}
PREFIXES = ('Sources/', 'Tests/', 'Resources/', 'scripts/', 'docs/', '.github/')
MODEL_FILES = {
    'config.json', 'model.safetensors', 'tokenizer.json', 'tokenizer_config.json',
    'preprocessor_config.json', 'saysee-model.json',
}

def content_issues(path, data):
    issues = []
    if re.search(rb'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----', data):
        issues.append('private-key material')
    if re.search(rb'/(?:Users|home)/[^/\s"\x00]+/', data):
        issues.append('personal absolute path')
    if path.lower().endswith('.json'):
        try:
            obj = json.loads(data)
        except (ValueError, UnicodeError):
            obj = None
        if isinstance(obj, dict) and (obj.get('type') == 'service_account' or obj.get('private_key')):
            issues.append('credential JSON')
    return issues

def entry_issues(path, mode, data):
    issues = []
    parts = PurePosixPath(path).parts
    if path not in ROOT_FILES and not path.startswith(PREFIXES):
        issues.append('outside the public source allowlist')
    if '..' in parts or PurePosixPath(path).is_absolute() or path.startswith('docs/internal/'):
        issues.append('nonpublic path')
    if mode not in ('100644', '100755'):
        issues.append('symlink, submodule, or unsupported file mode')
    name = PurePosixPath(path).name.lower()
    if name != '.env.example' and (name.startswith('.env') or
        name.endswith(('.pem', '.key', '.p12', '.pfx', '.log', '.jsonl', '.wav', '.aiff', '.mp3', '.m4a', '.safetensors', '.onnx', '.dmg')) or
        re.search(r'(?:service[-_]?account|credentials|secrets).*\.json$', name)):
        issues.append('credential, runtime data, or generated artifact filename')
    if len(data) > 2_000_000:
        issues.append('source file exceeds 2 MB')
    issues.extend(content_issues(path, data))
    return issues

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def app_allowed(path):
    name = PurePosixPath(path).name.lower()
    if name.startswith('.env') or name.endswith(('.pem', '.key', '.p12', '.pfx', '.mobileprovision', '.keychain', '.log', '.jsonl')) or re.search(r'(?:service[-_]?account|credentials|secrets).*\.json$', name):
        return False
    if path in {'Contents/Info.plist', 'Contents/MacOS/Saysee', 'Contents/MacOS/mlx.metallib', 'Contents/_CodeSignature/CodeResources'}:
        return True
    if path.startswith('Contents/Resources/Licenses/'):
        return True
    model = 'Contents/Resources/Models/qwen3-asr-1.7b-6bit/'
    if path.startswith(model):
        return path[len(model):] in MODEL_FILES
    relative = PurePosixPath(path).parts
    return len(relative) > 3 and relative[:2] == ('Contents', 'Resources') and relative[2].endswith('.bundle')

def audit_app(app, output):
    if not app.is_dir():
        raise SystemExit('App bundle not found.')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    issues = []
    manifest = []
    text_export = output / 'app-text'
    for path in sorted(app.rglob('*')):
        relative = path.relative_to(app).as_posix()
        if path.is_symlink():
            issues.append(f'{relative}: symbolic link is not allowed')
            continue
        if not path.is_file():
            continue
        if not app_allowed(relative):
            issues.append(f'{relative}: unexpected bundle payload')
        size = path.stat().st_size
        # Source, metadata and native executable are inspected; 2 GB tensor data
        # is not a text secret-scan target and is restricted to the model path.
        if relative != 'Contents/Resources/Models/qwen3-asr-1.7b-6bit/model.safetensors':
            data = path.read_bytes()
            issues.extend(f'{relative}: {item}' for item in content_issues(relative, data))
            if size < 8_000_000 and b'\x00' not in data[:8192]:
                target = text_export / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
        manifest.append({'path': relative, 'bytes': size})
    if issues:
        raise SystemExit('\n'.join(issues))
    if text_export.exists():
        scan(text_export, output / 'app-gitleaks.json')
    return manifest

def scan(source, report):
    subprocess.run([
        'gitleaks', 'dir', '--redact', '--no-banner', '--ignore-gitleaks-allow', '--max-target-megabytes', '8',
        '--report-format', 'json', '--report-path', str(report), str(source),
    ], check=True, cwd=source, env={k:v for k,v in os.environ.items() if not k.startswith('GITLEAKS_')})

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--app', type=Path, help='also audit a built app bundle')
    args = p.parse_args()
    if not shutil.which('gitleaks'):
        raise SystemExit('Install gitleaks first (macOS: brew install gitleaks).')
    records = git('ls-files', '--stage', '-z').split(b'\x00')
    entries, issues = [], []
    for record in records:
        if not record:
            continue
        metadata, raw_path = record.split(b'\t', 1)
        mode, sha, stage = metadata.decode().split()
        path = raw_path.decode('utf-8')
        if stage != '0':
            issues.append(f'{path}: unresolved index conflict')
            continue
        preflight = entry_issues(path, mode, b'')
        if preflight:
            issues.extend(f'{path}: {item}' for item in preflight)
            continue
        if int(git('cat-file', '-s', sha)) > 2_000_000:
            issues.append(f'{path}: source file exceeds 2 MB')
            continue
        data = git('cat-file', 'blob', sha)
        issues.extend(f'{path}: {item}' for item in entry_issues(path, mode, data))
        entries.append((path, mode, data))
    if not entries:
        issues.append('Stage the intended public files before auditing.')
    if issues:
        raise SystemExit('\n'.join(issues))
    os.umask(0o077)
    parent = ROOT / 'dist' / 'public-audit'
    parent.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix='snapshot-', dir=parent))
    source = output / 'source'
    manifest = []
    for path, mode, data in entries:
        target = source / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        if mode == '100755':
            target.chmod(0o700)
        manifest.append({'path': path, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
    scan(source, output / 'source-gitleaks.json')
    result = {'source_files': manifest, 'source_bytes': sum(x['bytes'] for x in manifest)}
    if args.app:
        result['app_files'] = audit_app(args.app.resolve(), output)
    (output / 'manifest.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(f'Audit passed: {len(manifest)} staged source files. Local report: {output}')
    print('No files were committed or uploaded. Model tensor contents were not text-scanned.')

if __name__ == '__main__':
    main()
