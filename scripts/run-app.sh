#!/bin/zsh
set -euo pipefail
ROOT=${0:A:h:h}
if [[ ! -x "$ROOT/dist/Saysee.app/Contents/MacOS/Saysee" ]]; then "$ROOT/scripts/build-app.sh"; fi
# Launch the native app executable; credentials are managed in macOS Keychain.
exec "$ROOT/dist/Saysee.app/Contents/MacOS/Saysee" "$@"
