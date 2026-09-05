#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
[[ "$(uname -s)" == "Darwin" ]] || { printf '%s\n' 'IPA compilation requires macOS/Xcode.' >&2; exit 2; }
[[ -f Sources/ClubApp.swift && -f Resources/hop-logo.png ]] || { printf '%s\n' 'Missing native source or brand resource.' >&2; exit 2; }
icon_temp="$(mktemp -d "${TMPDIR:-/tmp/}hop-club-icon.XXXXXX")"
trap 'rm -rf "$icon_temp"' EXIT
sips -s format jpeg -s formatOptions 100 Resources/hop-logo.png --out "$icon_temp/icon.jpg" >/dev/null
sips -s format png -z 1024 1024 "$icon_temp/icon.jpg" --out Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png >/dev/null
xcodebuild archive -project HOPClub.xcodeproj -scheme HOPClub -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData -archivePath build/HOPClub.xcarchive CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM=""
app="$project_dir/build/HOPClub.xcarchive/Products/Applications/HOPClub.app"
[[ -d "$app" ]] || { printf '%s\n' 'The iPhone archive did not contain the application.' >&2; exit 1; }
lipo -archs "$app/HOPClub" | grep -q arm64
[[ "$(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily:0' "$app/Info.plist")" == '1' ]]
[[ ! -d "$app/Web" ]] || { printf '%s\n' 'Native target must not bundle the web workspace.' >&2; exit 1; }
mkdir -p "$icon_temp/Payload"
ditto "$app" "$icon_temp/Payload/HOPClub.app"
ditto -c -k --norsrc --keepParent "$icon_temp/Payload" "$project_dir/build/HOPClub-unsigned.ipa"
unzip -t build/HOPClub-unsigned.ipa
shasum -a 256 build/HOPClub-unsigned.ipa
