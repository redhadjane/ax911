#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
[[ "$(uname -s)" == "Darwin" ]] || { printf '%s\n' 'IPA compilation requires macOS/Xcode.' >&2; exit 2; }
[[ -f Web/index.html && -f Web/native.js ]] || { printf '%s\n' 'Missing approved frontend snapshot.' >&2; exit 2; }
icon_temp="$(mktemp -d "${TMPDIR:-/tmp/}hop-command-icon.XXXXXX")"
trap 'rm -rf "$icon_temp"' EXIT
sips -s format jpeg -s formatOptions 100 Web/assets/official-hop-logo.png --out "$icon_temp/icon.jpg" >/dev/null
sips -s format png -z 1024 1024 "$icon_temp/icon.jpg" --out Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png >/dev/null
xcodebuild archive -project HOPCommand.xcodeproj -scheme HOPCommand -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData -archivePath build/HOPCommand.xcarchive CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM=""
app="$project_dir/build/HOPCommand.xcarchive/Products/Applications/HOPCommand.app"
[[ -d "$app" ]] || { printf '%s\n' 'The iPad archive did not contain the application.' >&2; exit 1; }
lipo -archs "$app/HOPCommand" | grep -q arm64
[[ "$(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily:0' "$app/Info.plist")" == '2' ]]
mkdir -p "$icon_temp/Payload"
ditto "$app" "$icon_temp/Payload/HOPCommand.app"
ditto -c -k --norsrc --keepParent "$icon_temp/Payload" "$project_dir/build/HOPCommand-unsigned.ipa"
unzip -t build/HOPCommand-unsigned.ipa
shasum -a 256 build/HOPCommand-unsigned.ipa
