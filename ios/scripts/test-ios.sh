#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Darwin" ]] || ! command -v xcodebuild >/dev/null 2>&1; then
    printf '%s\n' 'BLOCKED: iOS simulator tests require a Mac with full Xcode and an installed iOS simulator runtime.' >&2
    exit 2
fi
if [[ $# -lt 1 ]]; then
    printf '%s\n' 'Pass an available iPhone Simulator UUID: bash scripts/test-ios.sh <UUID>'
    xcrun simctl list devices available
    exit 2
fi
if [[ ! "$1" =~ ^[A-Fa-f0-9-]{36}$ ]]; then
    printf '%s\n' 'Expected a Simulator UUID from xcrun simctl list devices available.' >&2
    exit 2
fi
/bin/bash "$project_dir/scripts/prepare-assets.sh"
mkdir -p "$project_dir/build"
result_path="$project_dir/build/TestResults-$(date -u +%Y%m%dT%H%M%SZ).xcresult"
xcodebuild test \
    -project "$project_dir/HOPEmployee.xcodeproj" \
    -scheme HOPEmployee \
    -destination "platform=iOS Simulator,id=$1" \
    -derivedDataPath "$project_dir/build/DerivedData" \
    -resultBundlePath "$result_path" \
    CODE_SIGNING_ALLOWED=NO
printf '\n%s\n' "Test results: $result_path"
