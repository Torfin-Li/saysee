#!/bin/zsh
set -euo pipefail
ROOT=${0:A:h:h}
cd "$ROOT"
# Build tools only; none of this runtime is bundled or needed by users.
uv venv --python 3.11 .tools/model-download
uv pip install --python .tools/model-download/bin/python 'huggingface-hub>=1.0,<2'
.tools/model-download/bin/python scripts/prepare-qwen.py
swift package resolve
if ! xcrun -sdk macosx metal --version >/dev/null 2>&1; then
 print 'Install the official Apple Metal build tools: xcodebuild -downloadComponent MetalToolchain'
 exit 1
fi
