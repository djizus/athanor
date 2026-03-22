#!/usr/bin/env bash
set -euo pipefail

# Athanor — addon setup script
# Downloads and extracts Godot addons that are gitignored (too large for repo).
# Run once after cloning, or when addon versions change.

GODOT_CEF_VERSION="v1.13.0"
GODOT_CEF_URL="https://github.com/dsh0416/godot-cef/releases/download/${GODOT_CEF_VERSION}/godot_cef-${GODOT_CEF_VERSION}.zip"

CLIENT_DIR="$(cd "$(dirname "$0")/client" && pwd)"
ADDONS_DIR="${CLIENT_DIR}/addons"
TMP_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "=== Athanor Addon Setup ==="
echo ""

# --- godot-cef ---
if [ -f "${ADDONS_DIR}/godot_cef/godot_cef.gdextension" ]; then
    echo "[godot-cef] Already installed, skipping. Delete client/addons/godot_cef/ to reinstall."
else
    echo "[godot-cef] Downloading ${GODOT_CEF_VERSION}..."
    curl -fSL "$GODOT_CEF_URL" -o "${TMP_DIR}/godot_cef.zip"

    echo "[godot-cef] Extracting to ${ADDONS_DIR}/godot_cef/..."
    mkdir -p "${ADDONS_DIR}"
    unzip -q "${TMP_DIR}/godot_cef.zip" "dist/addons/godot_cef/*" -d "${TMP_DIR}/extract"
    mv "${TMP_DIR}/extract/dist/addons/godot_cef" "${ADDONS_DIR}/godot_cef"

    echo "[godot-cef] Installed (all platforms: Linux, macOS, Windows)."
fi

echo ""
echo "Done. Open the project in Godot to verify."
