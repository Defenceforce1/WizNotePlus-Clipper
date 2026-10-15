#!/bin/bash
# Only a named local synthetic fixture, with WebKit network access blocked.
set -euo pipefail
[[ $# == 1 && "$1" = /* ]] || { echo 'Usage: test.sh ABSOLUTE_APP_PATH' >&2; exit 2; }
project_dir=$(cd "$(dirname "$0")/.." && pwd)
app=$1
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist") == io.github.defenceforce1.wiznoteplus.clipper.mac ]] || exit 1
codesign --verify --deep --strict "$app"
checks="$(dirname "$app")/Tests/ClipperChecks.app/Contents/MacOS/ClipperChecks"
[[ -x "$checks" ]] || { echo 'Build-time check runner is missing; it is deliberately not shipped in the App.' >&2; exit 1; }
codesign --verify --strict "$(dirname "$(dirname "$(dirname "$checks")")")"
"$checks" --share-ui-self-test
"$checks" --capture-self-test "$project_dir/tests/fixtures/clipper-cloud-page.html"
