#!/bin/bash
set -euo pipefail
studio_dir="$(cd "$(dirname "$0")/.." && pwd)"
architecture=universal
for option in "$@"; do
    case "$option" in
        --sync) python3 "$studio_dir/Tools/sync-library.py" ;;
        --native) architecture="$(uname -m)" ;;
        --universal) architecture=universal ;;
        *) printf 'Unknown option: %s (use --native, --universal, or --sync)\n' "$option" >&2; exit 1 ;;
    esac
done
if [[ ! -f "$studio_dir/Sources/ZenWaveStudio/Resources/BreathVoice/manifest.json" ]]; then
    printf '%s\n' 'Generate the OpenAI breathing voice pack first: python3 ContentStudio/Tools/generate-breath-voice.py' >&2
    exit 1
fi
stage_dir="$(python3 "$studio_dir/Tools/stage-build.py")"
architectures=("$architecture")
if [[ "$architecture" == universal ]]; then architectures=(arm64 x86_64); fi
binaries=()
for cpu in "${architectures[@]}"; do
    scratch="$stage_dir/.build/$cpu"
    swift build --package-path "$stage_dir" --build-system native -c release --arch "$cpu" --scratch-path "$scratch"
    binary_dir="$(swift build --package-path "$stage_dir" --build-system native -c release --arch "$cpu" --scratch-path "$scratch" --show-bin-path)"
    binaries+=("$binary_dir/ZenWaveStudio")
done
# Sign outside synced Documents so File Provider cannot reattach Finder metadata mid-sign.
app_dir="$(dirname "$stage_dir")/App/ZenWave Content Studio.app"
distribution_dir="$studio_dir/dist/ZenWave Content Studio.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
if [[ "$architecture" == universal ]]; then
    lipo -create "${binaries[@]}" -output "$app_dir/Contents/MacOS/ZenWaveStudio"
else
    cp "${binaries[0]}" "$app_dir/Contents/MacOS/ZenWaveStudio"
fi
included_architectures=" $(lipo -archs "$app_dir/Contents/MacOS/ZenWaveStudio") "
for cpu in "${architectures[@]}"; do
    if [[ "$included_architectures" != *" $cpu "* ]]; then
        printf 'Packaged binary is missing %s\n' "$cpu" >&2; exit 1
    fi
done
# The app carries its own catalog, shader, and audio; it never depends on the repository at runtime.
rsync -a --delete "$stage_dir/Sources/ZenWaveStudio/Resources/" "$app_dir/Contents/Resources/StudioResources/"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ZenWaveStudio</string>
<key>CFBundleIdentifier</key><string>com.zenwave.contentstudio</string>
<key>CFBundleName</key><string>ZenWave Content Studio</string>
<key>CFBundleDisplayName</key><string>ZenWave Content Studio</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.12.1</string>
<key>CFBundleVersion</key><string>16</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>StudioIcon</string>
</dict></plist>
PLIST
icon_source="$stage_dir/Sources/ZenWaveStudio/Resources/Brand/ZenWaveLogo.png"
if [[ -f "$icon_source" ]]; then
    icon_set="$(dirname "$stage_dir")/StudioIcon.iconset"
    mkdir -p "$icon_set"
    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" "$icon_source" --out "$icon_set/icon_${size}x${size}.png" >/dev/null
        double=$((size * 2))
        sips -z "$double" "$double" "$icon_source" --out "$icon_set/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$icon_set" -o "$app_dir/Contents/Resources/StudioIcon.icns"
fi
xattr -cr "$app_dir"
codesign --force --deep --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
mkdir -p "$studio_dir/dist"
ditto --norsrc --noextattr "$app_dir" "$distribution_dir"
xattr -cr "$distribution_dir"
codesign --verify --deep --strict "$distribution_dir"
archive="$studio_dir/dist/ZenWave-Content-Studio-Mac.zip"
ditto -c -k --keepParent --norsrc --noextattr "$app_dir" "$archive"
(cd "$studio_dir/dist" && shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256")
printf '\nBuilt: %s\n' "$distribution_dir"
printf 'Package (%s): %s\n' "$architecture" "$archive"
