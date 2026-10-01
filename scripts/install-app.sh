#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
archive_path="$repo_root/dist/TouchGuard.app.zip"
target_app="/Applications/TouchGuard.app"
staging_path="$(mktemp -d /private/tmp/touchguard-install.XXXXXX)"

trap 'rm -rf "$staging_path"' EXIT

if [[ ! -f "$archive_path" ]]; then
    echo "Build TouchGuard before installing it." >&2
    exit 1
fi

ditto -x -k "$archive_path" "$staging_path"
source_app="$staging_path/TouchGuard.app"
codesign --verify --deep --strict --verbose=2 "$source_app"
osascript -e 'tell application id "dev.kolsha.TouchGuard" to quit' 2>/dev/null || true

for _ in {1..20}; do
    if ! pgrep -f '^/Applications/TouchGuard.app/Contents/MacOS/TouchGuard$' >/dev/null; then
        break
    fi
    sleep 0.25
done

rm -rf /Applications/TouchGuard.app
ditto --noextattr --noqtn "$source_app" "$target_app"
codesign --verify --deep --strict --verbose=2 "$target_app"
open "$target_app"

echo "$target_app"
