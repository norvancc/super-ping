#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-app.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
ARCH=universal
NAME="Super-Ping-${VERSION}-${ARCH}"
STAGING=$(mktemp -d "$PWD/dist/.package.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
if [ -n "${NOTARY_PROFILE:-}" ]; then
    if [ "${SIGNING_IDENTITY:--}" = "-" ]; then
        echo 'Notarization requires SIGNING_IDENTITY' >&2
        exit 1
    fi
    ditto -c -k --sequesterRsrc --keepParent "$PWD/dist/Super Ping.app" "$STAGING/notarization.zip"
    xcrun notarytool submit "$STAGING/notarization.zip" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$PWD/dist/Super Ping.app"
    xcrun stapler validate "$PWD/dist/Super Ping.app"
    spctl --assess --type execute --verbose=2 "$PWD/dist/Super Ping.app"
    if command -v syspolicy_check >/dev/null 2>&1; then
        syspolicy_check distribution "$PWD/dist/Super Ping.app" --verbose
    fi
    rm "$STAGING/notarization.zip"
fi
ditto "$PWD/dist/Super Ping.app" "$STAGING/Super Ping.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname 'Super Ping' -srcfolder "$STAGING" -format UDZO -ov "$PWD/dist/$NAME.dmg"
hdiutil verify "$PWD/dist/$NAME.dmg"
if [ -n "${NOTARY_PROFILE:-}" ]; then
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$PWD/dist/$NAME.dmg"
    xcrun notarytool submit "$PWD/dist/$NAME.dmg" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$PWD/dist/$NAME.dmg"
    xcrun stapler validate "$PWD/dist/$NAME.dmg"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$PWD/dist/$NAME.dmg"
fi
ditto -c -k --sequesterRsrc --keepParent "$PWD/dist/Super Ping.app" "$PWD/dist/$NAME.zip"
shasum -a 256 "$PWD/dist/$NAME.dmg" "$PWD/dist/$NAME.zip" > "$PWD/dist/$NAME.sha256"
printf 'Packaged: %s\n' "$PWD/dist/$NAME.dmg" "$PWD/dist/$NAME.zip"
