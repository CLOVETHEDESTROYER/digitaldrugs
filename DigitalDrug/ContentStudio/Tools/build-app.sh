#!/bin/bash
set -euo pipefail
studio_dir="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${1:-}" == "--sync" ]]; then
    python3 "$studio_dir/Tools/sync-library.py"
fi
swift build --package-path "$studio_dir" -c release
binary_dir="$(swift build --package-path "$studio_dir" -c release --show-bin-path)"
app_dir="$studio_dir/dist/ZenWave Content Studio.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/ZenWaveStudio" "$app_dir/Contents/MacOS/ZenWaveStudio"
# The app carries its own catalog, shader, and audio; it never depends on the repository at runtime.
rsync -a --delete "$studio_dir/Sources/ZenWaveStudio/Resources/" "$app_dir/Contents/Resources/StudioResources/"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ZenWaveStudio</string>
<key>CFBundleIdentifier</key><string>com.zenwave.contentstudio</string>
<key>CFBundleName</key><string>ZenWave Content Studio</string>
<key>CFBundleDisplayName</key><string>ZenWave Content Studio</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>StudioIcon</string>
</dict></plist>
PLIST
icon_source="$studio_dir/../DigitalDrug/Assets.xcassets/ZenWaveBrandMark.imageset/ZenWaveBrandMark.png"
if [[ -f "$icon_source" ]]; then
    icon_set="$studio_dir/.build/StudioIcon.iconset"
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
printf '\nBuilt: %s\n' "$app_dir"
