#!/bin/bash
# Experimental full macOS AppIcon catalog, not an ordinary imageset.
# Only resample existing approved ICNS art; no new visual treatment.
set -euo pipefail
[[ $# == 2 && "$1" = /* && "$2" = /* && ! -e "$2" ]] || exit 2
source_icon=$1
output=$2
project_dir=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$output/ShareAssets.xcassets" "$output/Compiled"
xcrun swift "$project_dir/scripts/prepare-share-icon.swift" "$source_icon" "$output/ShareIcon.iconset" --full
xcrun swift "$project_dir/scripts/share-appicon-manifest.swift" "$output/ShareIcon.iconset" "$output/ShareAssets.xcassets"
xcrun actool "$output/ShareAssets.xcassets" --compile "$output/Compiled" --app-icon ShareIcon \
    --platform macosx --minimum-deployment-target 14.0 --target-device mac \
    --output-format human-readable-text --output-partial-info-plist "$output/Compiled/Icon-Info.plist" --warnings --errors
[[ -s "$output/Compiled/ShareIcon.icns" && -s "$output/Compiled/Assets.car" ]]
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$output/Compiled/Icon-Info.plist") == ShareIcon ]]
echo 'PASS complete macOS appiconset compiled with matching metadata'
