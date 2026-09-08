#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcodebuild archive -project HOPAcademy.xcodeproj -scheme HOPAcademy -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData -archivePath build/HOPAcademy.xcarchive CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM=""
app="$PWD/build/HOPAcademy.xcarchive/Products/Applications/HOPAcademy.app"
test -f "$app/HOPAcademy"
lipo -archs "$app/HOPAcademy" | grep -q arm64
mkdir -p build/package/Payload
ditto "$app" build/package/Payload/HOPAcademy.app
ditto -c -k --norsrc --keepParent build/package/Payload build/HOP-Academy-iPhone-iPad-1.0.0.ipa
unzip -t build/HOP-Academy-iPhone-iPad-1.0.0.ipa
python3 scripts/verify-ipa.py build/HOP-Academy-iPhone-iPad-1.0.0.ipa
