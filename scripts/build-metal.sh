#!/bin/zsh
set -euo pipefail
ROOT=${0:A:h:h}
cd "$ROOT"
BUILD_DIR=${SAYSEE_SWIFT_BUILD_DIR:-"$ROOT/.build"}
SOURCE="$BUILD_DIR/checkouts/mlx-swift/Source/Cmlx/mlx-generated/metal"
OUTPUT="$BUILD_DIR/saysee-metal"
# Cache shaders by the exact MLX source revision and installed compiler.
KEY="$(git -C "$BUILD_DIR/checkouts/mlx-swift" rev-parse HEAD)-$(xcrun -sdk macosx metal --version | shasum | cut -d ' ' -f 1)"
if [[ -f "$OUTPUT/key" && "$(cat "$OUTPUT/key")" == "$KEY" && -f "$OUTPUT/mlx.metallib" ]]; then exit 0; fi
mkdir -p "$OUTPUT"
air=()
for source in "$SOURCE"/**/*.metal(N); do
 name=${${source#$SOURCE/}//\//_}
 target="$OUTPUT/${name%.metal}.air"
 xcrun -sdk macosx metal -std=metal3.1 -mmacosx-version-min=14.0 -fno-fast-math -I "$SOURCE" -c "$source" -o "$target"
 air+=("$target")
done
if (( ${#air} == 0 )); then print -u2 'No MLX Metal kernels found'; exit 1; fi
xcrun -sdk macosx metal -mmacosx-version-min=14.0 "${air[@]}" -o "$OUTPUT/mlx.metallib"
print -r -- "$KEY" > "$OUTPUT/key"
