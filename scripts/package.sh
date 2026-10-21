#!/bin/bash
# Package a previously verified, signed app. Does not install or register it.
set -euo pipefail
[[ $# == 2 && "$1" = /* && "$2" = /* && ! -e "$2" ]] || exit 2
app=$1
output=$2
project_dir=$(cd "$(dirname "$0")/.." && pwd)
bash "$project_dir/scripts/check-release.sh" "$app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 2
mkdir -p "$output/Staging"
ditto "$app" "$output/Staging/WizNotePlus Clipper.app"
cp "$project_dir/docs/USER_GUIDE.md" "$output/Staging/安装与使用.md"
ln -s /Applications "$output/Staging/Applications"
ditto -c -k --sequesterRsrc --keepParent "$app" "$output/WizNotePlus-Clipper-$version-macOS-arm64.zip"
hdiutil create -volname "WizNotePlus Clipper $version" -srcfolder "$output/Staging" -format UDZO "$output/WizNotePlus-Clipper-$version-macOS-arm64.dmg"
hdiutil verify "$output/WizNotePlus-Clipper-$version-macOS-arm64.dmg"
shasum -a 256 "$output/WizNotePlus-Clipper-$version-macOS-arm64.zip" "$output/WizNotePlus-Clipper-$version-macOS-arm64.dmg"
echo 'PASS packages created without installation or extension registration'
