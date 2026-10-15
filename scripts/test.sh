#!/bin/bash
# Only a named local synthetic fixture, with WebKit network access blocked.
set -euo pipefail
[[ $# == 1 && "$1" = /* ]] || { echo 'Usage: test.sh ABSOLUTE_APP_PATH' >&2; exit 2; }
project_dir=$(cd "$(dirname "$0")/.." && pwd)
app=$1
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist") == io.github.defenceforce1.wiznoteplus.clipper.mac ]] || exit 1
codesign --verify --deep --strict "$app"
"$app/Contents/MacOS/WizNotePlusClipper" --share-ui-self-test
"$app/Contents/MacOS/WizNotePlusClipper" --capture-self-test "$project_dir/tests/fixtures/clipper-cloud-page.html"
