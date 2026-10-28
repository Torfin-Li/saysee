#!/bin/zsh
set -euo pipefail
ROOT=${0:A:h:h}
cd "$ROOT"
MODEL=${SAYSEE_MODEL_DIR:-"$ROOT/.tools/models/qwen3-asr-1.7b-6bit"}
if [[ ! -f "$MODEL/model.safetensors" ]]; then
 print -u2 'Qwen model missing. Run scripts/bootstrap.sh first.'; exit 1
fi
python3 scripts/prepare-qwen.py --model-dir "$MODEL"
# SwiftPM embeds a literal resource fallback path. Keep release scratch paths
# outside a personal home directory; require a private, non-symlink cache.
BUILD_DIR=$(python3 - "$ROOT" <<'PYBUILD'
import hashlib,os,stat,sys
from pathlib import Path
name='saysee-release-%s-%s' % (os.getuid(),hashlib.sha256(sys.argv[1].encode()).hexdigest()[:12])
p=Path('/tmp')/name
try:p.mkdir(mode=0o700)
except FileExistsError:pass
s=p.lstat()
if not stat.S_ISDIR(s.st_mode) or s.st_uid!=os.getuid() or stat.S_IMODE(s.st_mode)!=0o700:
 raise SystemExit('Unsafe release build cache; expected a private directory owned by this user.')
print(p)
PYBUILD
)
# Sanitize compiler/debug paths in public binaries, including C/C++ dependencies.
swift build --scratch-path "$BUILD_DIR" -c release \
 -Xswiftc -file-prefix-map -Xswiftc "$ROOT=/Saysee" \
 -Xswiftc -debug-prefix-map -Xswiftc "$ROOT=/Saysee" \
 -Xcc "-ffile-prefix-map=$ROOT=/Saysee"
SAYSEE_SWIFT_BUILD_DIR="$BUILD_DIR" ./scripts/build-metal.sh
mkdir -p "$ROOT/dist"
STAGE=$(mktemp -d "$ROOT/dist/.build-app.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/Saysee.app"
# Only explicit resources enter a new app; existing bundles are never overlaid.
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Models/qwen3-asr-1.7b-6bit" "$APP/Contents/Resources/Licenses"
cp "$BUILD_DIR/release/Saysee" "$APP/Contents/MacOS/Saysee"
cp "$BUILD_DIR/saysee-metal/mlx.metallib" "$APP/Contents/MacOS/mlx.metallib"
for file in config.json model.safetensors tokenizer.json tokenizer_config.json preprocessor_config.json saysee-model.json; do
 cp "$MODEL/$file" "$APP/Contents/Resources/Models/qwen3-asr-1.7b-6bit/$file"
done
# Swift tokenizer defaults/privacy declarations are SwiftPM resource bundles.
for bundle in "$BUILD_DIR"/release/*.bundle(N); do
 rm -rf "$APP/Contents/Resources/${bundle:t}"
 cp -R "$bundle" "$APP/Contents/Resources/"
done
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/Licenses/"
python3 scripts/collect-licenses.py --build-dir "$BUILD_DIR" --output "$APP/Contents/Resources/Licenses"
cp Resources/Licenses/Qwen3-ASR-LICENSE.txt "$APP/Contents/Resources/Licenses/"
cp "$MODEL/README.md" "$APP/Contents/Resources/Licenses/Qwen-Model-README.md"
strip -S "$APP/Contents/MacOS/Saysee"
codesign --force --sign - "$APP/Contents/MacOS/mlx.metallib"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
OUTPUT="$ROOT/dist/Saysee.app"
if [[ -e "$OUTPUT" ]]; then mv "$OUTPUT" "$STAGE/previous.app"; fi
if ! mv "$APP" "$OUTPUT"; then
 [[ ! -e "$STAGE/previous.app" ]] || mv "$STAGE/previous.app" "$OUTPUT"
 exit 1
fi
print "Built: $OUTPUT"
