#!/bin/bash
# Compile an owned Icon Composer document with Apple's tools, not a baked
# screenshot or Finder custom icon. Keep both modern CAR and legacy ICNS.
set -euo pipefail
[[ $# == 2 && "$1" = /* && "$2" = /* && "$1" = *.icon && ! -e "$2" ]] || exit 2
source_icon=$1
output=$2
[[ -f "$source_icon/icon.json" ]] || exit 2
name=$(basename "$source_icon" .icon)
mkdir -p "$output"
xcrun actool "$source_icon" --compile "$output" --app-icon "$name" --platform macosx \
    --minimum-deployment-target 14.0 --target-device mac --output-format human-readable-text \
    --output-partial-info-plist "$output/Icon-Info.plist" --warnings --errors
[[ -s "$output/Assets.car" && -s "$output/$name.icns" ]]
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$output/Icon-Info.plist") == "$name" ]]
echo 'PASS Apple asset compiler produced modern icon catalog and legacy ICNS'
echo 'PASS compiled icon name matches bundle metadata'
