#!/bin/bash
# Read-only release checks, also valid for ad-hoc public source builds.
set -euo pipefail
[[ $# == 1 && "$1" = /* && -d "$1" ]] || exit 2
app=$1
extension="$app/Contents/PlugIns/WizNotePlusShare.appex"
get() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist"; }
[[ $(get "$app" CFBundleIdentifier) == io.github.defenceforce1.wiznoteplus.clipper.mac ]]
[[ $(get "$extension" CFBundleIdentifier) == io.github.defenceforce1.wiznoteplus.clipper.mac.share ]]
echo 'PASS stable host and extension identities'
[[ $(get "$extension" CFBundleName) == 为知笔记 && $(get "$extension" CFBundleDisplayName) == 为知笔记 ]]
[[ $(get "$app" CFBundleDisplayName) == 为知笔记网页剪藏 ]]
echo 'PASS release display names match the requested share menu label'
for bundle in "$app" "$extension"; do
    [[ $(get "$bundle" CFBundleShortVersionString) == 1.0.0 && $(get "$bundle" CFBundleVersion) == 17 ]]
done
echo 'PASS host and extension release versions agree'
[[ $(get "$app" LSUIElement) == true ]]
[[ $(get "$extension" NSExtension:NSExtensionPointIdentifier) == com.apple.share-services ]]
echo 'PASS windowless host and system Share Extension retained'
codesign --verify --strict "$extension"
codesign --verify --deep --strict "$app"
echo 'PASS strict nested code signatures'
host_team=$(codesign -dv "$app" 2>&1 | sed -n 's/^TeamIdentifier=//p')
extension_team=$(codesign -dv "$extension" 2>&1 | sed -n 's/^TeamIdentifier=//p')
[[ -n "$host_team" && "$host_team" == "$extension_team" ]]
echo 'PASS host and extension signing teams agree (ad-hoc permitted for source checks)'
permissions=$(codesign -d --entitlements :- "$extension" 2>/dev/null)
[[ $(printf '%s' "$permissions" | plutil -extract 'com\.apple\.security\.app-sandbox' raw -) == true ]]
[[ $(printf '%s' "$permissions" | plutil -extract 'com\.apple\.security\.network\.client' raw -) == true ]]
echo 'PASS share extension retains sandbox and outgoing-network permissions'
lipo "$app/Contents/MacOS/WizNotePlusClipper" -verify_arch arm64
lipo "$extension/Contents/MacOS/WizNotePlusShare" -verify_arch arm64
echo 'PASS native arm64 host and share extension'
[[ -s "$app/Contents/Resources/README.md" && -s "$app/Contents/Resources/LICENSE.txt" && -s "$app/Contents/Resources/GPL-3.0.txt" ]]
[[ ! -e "$app/Contents/Tests" && ! -e "$app/Contents/Resources/ClipPage.js" && ! -e "$app/Contents/Resources/AGENTS.md" ]]
echo 'PASS user guide and notices retained; test and development resources excluded'
