#!/bin/bash
set -euo pipefail
[[ $# -ge 1 && $# -le 2 ]] || { echo 'Usage: build.sh NEW_ABSOLUTE_OUTPUT [APPLE_DEVELOPMENT_IDENTITY]' >&2; exit 2; }
project_dir=$(cd "$(dirname "$0")/.." && pwd)
source_dir="$project_dir/Sources"
resource_dir="$project_dir/Resources"
config_dir="$project_dir/Configuration"
output=$1
sign_identity=${2:--}
[[ "$output" = /* && ! -e "$output" ]] || exit 2
if [[ "$sign_identity" != - ]]; then
    [[ "$sign_identity" == 'Apple Development: '* ]] || exit 2
    security find-identity -v -p codesigning | /usr/bin/grep -Fq -- "\"$sign_identity\"" || exit 1
fi
app="$output/WizNotePlus Web Clipper.app"
extension="$app/Contents/PlugIns/WizNotePlusShare.appex"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$extension/Contents/MacOS" "$extension/Contents/Resources"
cp "$config_dir/Host-Info.plist" "$app/Contents/Info.plist"
cp "$config_dir/Extension-Info.plist" "$extension/Contents/Info.plist"
cp "$resource_dir/ClipPage.js" "$extension/Contents/Resources/ClipPage.js"
cp "$resource_dir/ClipPage.js" "$app/Contents/Resources/ClipPage.js"
cp "$project_dir/licenses/WizNotePlus-NOTICE.txt" "$app/Contents/Resources/LICENSE.txt"
cp "$project_dir/LICENSE" "$app/Contents/Resources/GPL-3.0.txt"
cp "$project_dir/README.md" "$app/Contents/Resources/README.md"
if [[ -d "$resource_dir/AppIcon.icon" ]]; then
    bash "$project_dir/scripts/compile-icon.sh" "$resource_dir/AppIcon.icon" "$output/CompiledIcon"
    cp "$output/CompiledIcon/Assets.car" "$app/Contents/Resources/Assets.car"
    # New systems use the native catalog's ORIGINAL layers, not a glass PNG.
    # The approved static A export is only a high-resolution legacy fallback.
    if [[ -f "$resource_dir/AppIcon-final.icns" ]]; then
        cp "$resource_dir/AppIcon-final.icns" "$app/Contents/Resources/AppIcon.icns"
    else
        cp "$output/CompiledIcon/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
    fi
    /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Add :CFBundleIconName string AppIcon' "$app/Contents/Info.plist"
elif [[ -f "$resource_dir/AppIcon-final.icns" ]]; then
    cp "$resource_dir/AppIcon-final.icns" "$app/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$app/Contents/Info.plist"
elif [[ -f "$resource_dir/AppIcon.icns" ]]; then
    xcrun swift "$project_dir/scripts/prepare-icon.swift" "$resource_dir/AppIcon.icns" "$output/AppIcon.iconset"
    iconutil -c icns "$output/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$app/Contents/Info.plist"
fi
# macOS share extensions need their own icon resource/declaration. Do not rely
# on iOS's automatic host-icon inheritance or on Finder custom-icon metadata.
if [[ -f "$app/Contents/Resources/AppIcon.icns" ]]; then
    cp "$app/Contents/Resources/AppIcon.icns" "$extension/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$extension/Contents/Info.plist"
    if [[ -f "$app/Contents/Resources/Assets.car" ]]; then
        cp "$app/Contents/Resources/Assets.car" "$extension/Contents/Resources/Assets.car"
        /usr/libexec/PlistBuddy -c 'Add :CFBundleIconName string AppIcon' "$extension/Contents/Info.plist"
    fi
fi
xcrun swift "$project_dir/scripts/check-bundle-icons.swift" "$app"
sdk=$(xcrun --sdk macosx --show-sdk-path)
common=("$source_dir/ClipInput.swift" "$source_dir/ClipCredentialStore.swift" "$source_dir/CloudClipClient.swift" "$source_dir/ClipResources.swift" "$source_dir/CloudClipSubmission.swift")
xcrun swiftc -sdk "$sdk" -target arm64-apple-macos14.0 -framework AppKit -framework Foundation -framework Security \
    -framework WebKit -framework UniformTypeIdentifiers "${common[@]}" "$source_dir/ShareViewController.swift" "$source_dir/ClipperSelfTests.swift" "$source_dir/main.swift" -o "$app/Contents/MacOS/WizNotePlusClipper"
xcrun swiftc -sdk "$sdk" -target arm64-apple-macos14.0 -framework AppKit -framework Foundation -framework Security -framework UniformTypeIdentifiers \
    -application-extension -parse-as-library -emit-executable -module-name WizNotePlusShare \
    -Xlinker -e -Xlinker _NSExtensionMain "${common[@]}" "$source_dir/ShareViewController.swift" \
    -o "$extension/Contents/MacOS/WizNotePlusShare"
codesign --force --sign "$sign_identity" --timestamp=none --entitlements "$config_dir/Extension.entitlements" "$extension"
codesign --force --sign "$sign_identity" --timestamp=none "$app"
codesign --verify --deep --strict "$app"
lipo "$app/Contents/MacOS/WizNotePlusClipper" -verify_arch arm64
lipo "$extension/Contents/MacOS/WizNotePlusShare" -verify_arch arm64
"$app/Contents/MacOS/WizNotePlusClipper" --input-self-test
"$app/Contents/MacOS/WizNotePlusClipper" --cloud-self-test
"$app/Contents/MacOS/WizNotePlusClipper" --session-self-test
"$app/Contents/MacOS/WizNotePlusClipper" --submission-self-test
printf '%s\n' 'Native clipping candidate built. Safari load and multi-Mac signing still require verification.'
