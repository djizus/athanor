#!/usr/bin/env bash
set -euo pipefail

GODOT_CEF_VERSION="v1.13.0"
GODOT_CEF_URL="https://github.com/dsh0416/godot-cef/releases/download/${GODOT_CEF_VERSION}/godot_cef-${GODOT_CEF_VERSION}.zip"

GODOT_DOJO_VERSION="v0.7.4"
GODOT_DOJO_URL="https://github.com/lonewolftechnology/godot-dojo/releases/download/${GODOT_DOJO_VERSION}/dojo-starter-godot-project.zip"

CLIENT_DIR="$(cd "$(dirname "$0")/client" && pwd)"
ADDONS_DIR="${CLIENT_DIR}/addons"
TMP_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "=== Athanor Addon Setup ==="
echo ""

if [ -f "${ADDONS_DIR}/godot_cef/godot_cef.gdextension" ]; then
    echo "[godot-cef] Already installed, skipping."
else
    echo "[godot-cef] Downloading ${GODOT_CEF_VERSION}..."
    curl -fSL "$GODOT_CEF_URL" -o "${TMP_DIR}/godot_cef.zip"
    mkdir -p "${ADDONS_DIR}"
    unzip -q "${TMP_DIR}/godot_cef.zip" "dist/addons/godot_cef/*" -d "${TMP_DIR}/extract_cef"
    mv "${TMP_DIR}/extract_cef/dist/addons/godot_cef" "${ADDONS_DIR}/godot_cef"
    echo "[godot-cef] Installed."
fi

if [ -f "${ADDONS_DIR}/godot-dojo/godot-dojo.gdextension" ]; then
    echo "[godot-dojo] Already installed, skipping."
else
    echo "[godot-dojo] Downloading ${GODOT_DOJO_VERSION}..."
    curl -fSL "$GODOT_DOJO_URL" -o "${TMP_DIR}/godot_dojo.zip"
    mkdir -p "${ADDONS_DIR}"
    unzip -q "${TMP_DIR}/godot_dojo.zip" -d "${TMP_DIR}/extract_dojo"

    DOJO_SRC="${TMP_DIR}/extract_dojo/addons/godot-dojo"
    if [ ! -d "$DOJO_SRC" ]; then
        DOJO_SRC=$(find "${TMP_DIR}/extract_dojo" -name "godot-dojo.gdextension" -exec dirname {} \; | head -1)
    fi

    if [ -z "$DOJO_SRC" ] || [ ! -d "$DOJO_SRC" ]; then
        echo "[godot-dojo] ERROR: Could not find godot-dojo addon in zip. Install manually."
    else
        cp -r "$DOJO_SRC" "${ADDONS_DIR}/godot-dojo"
        echo "[godot-dojo] Installed."
    fi
fi

echo ""
echo "Done. Open the project in Godot to verify."
