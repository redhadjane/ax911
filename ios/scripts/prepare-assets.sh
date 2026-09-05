#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
source_icon="$project_dir/Resources/AppIconSource.png"
output_icon="$project_dir/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
if [[ "$(uname -s)" != "Darwin" ]] || ! command -v sips >/dev/null 2>&1; then
    printf '%s\n' 'App icon preparation requires macOS sips (bundled with macOS).' >&2
    exit 2
fi
if [[ ! -f "$source_icon" ]]; then
    printf '%s\n' "Missing HOP brand source: $source_icon" >&2
    exit 2
fi
if [[ ! -f "$output_icon" || "$source_icon" -nt "$output_icon" || "$0" -nt "$output_icon" ]]; then
    # The web PNG has an alpha channel. Normalize it to opaque RGB for Apple's
    # app-icon requirements while leaving the original in-app HOPLogo intact.
    icon_temp="$(mktemp -d "${TMPDIR:-/tmp/}hop-icon.XXXXXX")"
    trap 'rm -rf "$icon_temp"' EXIT
    /usr/bin/sips -s format jpeg -s formatOptions 100 "$source_icon" --out "$icon_temp/opaque.jpg" >/dev/null
    /usr/bin/sips -s format png -z 1024 1024 "$icon_temp/opaque.jpg" --out "$output_icon" >/dev/null
fi
