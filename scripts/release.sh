#!/bin/zsh
# Builds a release Sift.app, signs it with a Developer ID (hardened runtime, no
# sandbox), packages it as a DMG, notarizes and staples it.
#
# Usage:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="sift-notary" \
#   scripts/release.sh
#
# One-time setup for NOTARY_PROFILE (stores an app-specific password in the keychain):
#   xcrun notarytool store-credentials sift-notary --apple-id you@example.com --team-id TEAMID
#
# Without SIGN_IDENTITY the DMG holds the ad-hoc signed app: fine for your own
# Macs, but Gatekeeper will warn on any other Mac. Without NOTARY_PROFILE the
# DMG is signed but not notarized.
set -euo pipefail

root=${0:A:h:h}
cd "$root"

version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Support/Info.plist)
app="$root/build/Sift.app"
dmg="$root/build/Sift-$version.dmg"

scripts/build-app.sh release

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    echo "Signing with: $SIGN_IDENTITY"
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$app"
else
    echo "warning: SIGN_IDENTITY not set; the DMG will contain an ad-hoc signed app." >&2
fi
codesign --verify --strict --verbose=2 "$app"

# DMG: the app plus an Applications shortcut to drag it onto.
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
rm -f "$dmg"
hdiutil create -volname "Sift $version" -srcfolder "$staging" -fs HFS+ -format UDZO "$dmg" >/dev/null

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$dmg"
fi

if [[ -n "${SIGN_IDENTITY:-}" && -n "${NOTARY_PROFILE:-}" ]]; then
    echo "Notarizing (this can take a few minutes)…"
    xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$dmg"
    xcrun stapler validate "$dmg"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
    echo "Notarized: $dmg"
else
    echo "warning: not notarized (needs SIGN_IDENTITY and NOTARY_PROFILE)." >&2
    echo "Built: $dmg"
fi
