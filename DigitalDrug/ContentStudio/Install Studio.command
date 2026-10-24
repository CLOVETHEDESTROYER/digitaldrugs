#!/bin/bash
# Double-click in Finder after pulling the content-studio branch.
set -euo pipefail
trap 'result=$?; if [[ $result -ne 0 ]]; then printf "\nSetup stopped. Review the error above. Press Return to close.\n"; read -r; fi' EXIT
studio_dir="$(cd "$(dirname "$0")" && pwd)"
major="$(sw_vers -productVersion | cut -d. -f1)"
if (( major < 14 )); then
    printf '%s\n' 'ZenWave Content Studio requires macOS 14 Sonoma or newer.' >&2
    exit 1
fi
if ! xcrun --find swift >/dev/null 2>&1; then
    printf '%s\n' 'Install Xcode with Swift 5.10 or newer, open it once, then run this installer again. Alternatively use the ready-built ZIP from GitHub Releases.' >&2
    exit 1
fi
if pgrep -x ZenWaveStudio >/dev/null; then
    printf '%s\n' 'Close ZenWave Content Studio before installing this update.' >&2
    exit 1
fi
"$studio_dir/Tools/build-app.sh" --native
destination="$HOME/Applications/ZenWave Content Studio.app"
mkdir -p "$HOME/Applications"
ditto --norsrc --noextattr "$studio_dir/dist/ZenWave Content Studio.app" "$destination"
xattr -cr "$destination"
codesign --verify --deep --strict "$destination"
open "$destination"
printf '\nInstalled: %s\n' "$destination"
