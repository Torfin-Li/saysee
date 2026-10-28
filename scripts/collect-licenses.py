"""Copy license/notice texts from the exact resolved Swift dependency checkouts."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--output', type=Path, required=True)
p.add_argument('--build-dir', type=Path, default=ROOT / '.build')
args = p.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
pins = json.loads((ROOT / 'Package.resolved').read_text())['pins']
checkouts = {p.name.lower(): p for p in (args.build_dir / 'checkouts').iterdir() if p.is_dir()}
for pin in pins:
    identity = pin['identity']
    checkout = checkouts.get(identity.lower(), args.build_dir / 'checkouts' / identity)
    if not checkout.is_dir():
        raise SystemExit(f'Missing dependency checkout: {identity}')
    copied = 0
    for source in sorted(checkout.rglob('*')):
        relative = source.relative_to(checkout)
        if '.git' in relative.parts or source.is_symlink() or not source.is_file():
            continue
        name = source.name.upper()
        if not (name.startswith(('LICENSE', 'NOTICE', 'COPYING')) or 'THIRDPARTYNOTICE' in name):
            continue
        if source.stat().st_size > 2_000_000:
            raise SystemExit(f'Unexpectedly large license text: {identity}/{relative}')
        target = args.output / identity / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(source.read_bytes())
        copied += 1
    if not copied:
        raise SystemExit(f'No license text found: {identity}')
(args.output / 'Package.resolved').write_bytes((ROOT / 'Package.resolved').read_bytes())
