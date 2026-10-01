#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
configuration="${CONFIGURATION:-release}"
signing_identity="${CODE_SIGN_IDENTITY:--}"
dist_path="$repo_root/dist"
archive_path="$dist_path/TouchGuard.app.zip"
staging_path="$(mktemp -d /private/tmp/touchguard-build.XXXXXX)"
verification_path="$(mktemp -d /private/tmp/touchguard-verify.XXXXXX)"
app_path="$staging_path/TouchGuard.app"

trap 'rm -rf "$staging_path" "$verification_path"' EXIT

cd "$repo_root"
swift build --configuration "$configuration"
binary_path="$(swift build --configuration "$configuration" --show-bin-path)/TouchGuard"

rm -rf "$dist_path"
mkdir -p "$dist_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
ditto "$binary_path" "$app_path/Contents/MacOS/TouchGuard"
ditto "$repo_root/Support/Info.plist" "$app_path/Contents/Info.plist"

xattr -cr "$app_path"
codesign --force --options runtime --timestamp=none --sign "$signing_identity" "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"

ditto -c -k --keepParent "$app_path" "$archive_path"
ditto -x -k "$archive_path" "$verification_path"
codesign --verify --deep --strict --verbose=2 "$verification_path/TouchGuard.app"

echo "$archive_path"
