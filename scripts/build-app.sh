#!/bin/zsh
# Builds Sift.app from the SwiftPM executable and ad-hoc signs it.
# Usage: scripts/build-app.sh [debug|release]   (default: release)
set -euo pipefail

config=${1:-release}
root=${0:A:h:h}
cd "$root"

swift build -c "$config" --product Sift
bin_dir=$(swift build -c "$config" --show-bin-path)

app="$root/build/Sift.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/Sift" "$app/Contents/MacOS/Sift"
cp "$root/Support/Info.plist" "$app/Contents/Info.plist"
cp "$root/Support/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"

# Ad-hoc signature for local runs. scripts/release.sh re-signs with a Developer ID.
codesign --force --sign - --options runtime "$app"

echo "Built $app"
