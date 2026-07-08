#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${ROOT}/Resources/AppIconTransparent.png"
OUT_DIR="${ROOT}/Resources"
SPM_RESOURCES="${ROOT}/Sources/MidiSpotifyControl/Resources"

if [[ ! -f "$SOURCE" ]]; then
    echo "error: missing transparent app icon at ${SOURCE}" >&2
    exit 1
fi

swift "${ROOT}/scripts/render-menu-bar-icon.swift" "$SOURCE" "$OUT_DIR"

mkdir -p "$SPM_RESOURCES"
cp "${OUT_DIR}/MenuBarIcon.png" "${OUT_DIR}/MenuBarIcon@2x.png" "$SPM_RESOURCES/"

echo "Generated: ${OUT_DIR}/MenuBarIcon.png"
echo "Generated: ${OUT_DIR}/MenuBarIcon@2x.png"
