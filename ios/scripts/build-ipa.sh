#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Darwin" ]] || ! command -v xcodebuild >/dev/null 2>&1; then
    printf '%s\n' 'BLOCKED: building a native iOS IPA requires a Mac with full Xcode. Windows cannot compile this SwiftUI/iPhoneOS target.' >&2
    exit 2
fi
xcrun --sdk iphoneos --show-sdk-path >/dev/null
xcodebuild -version
/bin/bash "$project_dir/scripts/prepare-assets.sh"
mkdir -p "$project_dir/build"
xcodebuild archive \
    -project "$project_dir/HOPEmployee.xcodeproj" \
    -scheme HOPEmployee \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$project_dir/build/DerivedData" \
    -archivePath "$project_dir/build/HOPEmployee.xcarchive" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM=""
archive_app="$project_dir/build/HOPEmployee.xcarchive/Products/Applications/HOPEmployee.app"
if [[ ! -d "$archive_app" ]]; then
    printf '%s\n' 'Archive did not contain HOPEmployee.app; no IPA was created.' >&2
    exit 3
fi
binary_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$archive_app/Info.plist")"
xcrun lipo -archs "$archive_app/$binary_name" | grep -q 'arm64'
package_dir="$(mktemp -d "${TMPDIR:-/tmp/}hop-ipa.XXXXXX")"
trap 'rm -rf "$package_dir"' EXIT
mkdir -p "$package_dir/Payload"
ditto "$archive_app" "$package_dir/Payload/HOPEmployee.app"
ipa_path="$project_dir/build/HOPEmployee-unsigned.ipa"
ditto -c -k --norsrc --keepParent "$package_dir/Payload" "$ipa_path"
unzip -t "$ipa_path"
shasum -a 256 "$ipa_path"
printf '\n%s\n' "Created $ipa_path" 'Unsigned IPA: install through SideStore so it is signed for your Apple account.'
