#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RAW_DIR="$ROOT_DIR/scripts/generate-assets/output/raw"
MODELS_DIR="$ROOT_DIR/client/assets/models"
CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup_model.py"

if [ ! -d "$RAW_DIR" ]; then
    echo "No raw models found at $RAW_DIR"
    exit 0
fi

echo "Processing raw GLB models..."
for glb in "$RAW_DIR"/*.glb; do
    [ -f "$glb" ] || continue
    base=$(basename "$glb" .glb)

    if echo "$base" | grep -qE '^(hero|mob_)'; then
        out="$MODELS_DIR/characters/$base.glb"
        max_tris=8000
    elif echo "$base" | grep -qE '^floor_'; then
        out="$MODELS_DIR/floors/$base.glb"
        max_tris=500
    else
        zone=$(echo "$base" | grep -oE 'z[0-4]' | sed 's/z/zone_/')
        out="$MODELS_DIR/props/${zone:-zone_0}/$base.glb"
        max_tris=2000
    fi

    mkdir -p "$(dirname "$out")"
    echo "  $base.glb -> $out (max $max_tris tris)"
    blender --background --python "$CLEANUP_SCRIPT" -- \
        --input "$glb" \
        --output "$out" \
        --max-tris "$max_tris" \
        --center-origin
done
echo "Done."
