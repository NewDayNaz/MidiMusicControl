#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${ROOT}/Resources/AppIcon-1024.png"
ICONSET="${ROOT}/Resources/AppIcon.iconset"
ICNS="${ROOT}/Resources/AppIcon.icns"

if [[ ! -f "$SOURCE" ]]; then
    echo "error: missing source icon at ${SOURCE}" >&2
    exit 1
fi

width="$(sips -g pixelWidth "$SOURCE" | awk '/pixelWidth/ { print $2 }')"
height="$(sips -g pixelHeight "$SOURCE" | awk '/pixelHeight/ { print $2 }')"
if [[ "$width" != "$height" ]]; then
    echo "error: source icon must be square (got ${width}x${height})" >&2
    exit 1
fi
if [[ "$width" -lt 1024 ]]; then
    echo "error: source icon must be at least 1024x1024 (got ${width}x${height})" >&2
    exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

make_icon() {
    local size="$1"
    local name="$2"
    sips -z "$size" "$size" "$SOURCE" --out "${ICONSET}/${name}" >/dev/null
}

make_icon 16  icon_16x16.png
make_icon 32  icon_16x16@2x.png
make_icon 32  icon_32x32.png
make_icon 64  icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
cp "$SOURCE" "${ICONSET}/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET"

echo "Generated: ${ICNS}"
