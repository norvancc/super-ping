#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
swift build -c release --arch arm64 --disable-sandbox
swift build -c release --arch x86_64 --disable-sandbox
ARM_BIN=$(swift build -c release --arch arm64 --show-bin-path)
INTEL_BIN=$(swift build -c release --arch x86_64 --show-bin-path)
bash scripts/build-icon.sh
mkdir -p "$PWD/dist"
STAGING=$(mktemp -d "$PWD/dist/.staging.XXXXXX")
APP="$STAGING/Super Ping.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$ARM_BIN/PingAgent" "$INTEL_BIN/PingAgent" -output "$APP/Contents/MacOS/PingAgent"
cp .build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Info.plist "$APP/Contents/Info.plist"
cp -R "$ARM_BIN/PingAgent_PingAgent.bundle" "$APP/Contents/Resources/"
cp THIRD_PARTY_NOTICES.txt "$APP/Contents/Resources/"
if [ "${SIGNING_IDENTITY:--}" = "-" ]; then
    codesign --force --deep --sign - "$APP"
else
    codesign --force --deep --options runtime --timestamp --entitlements Release.entitlements --sign "$SIGNING_IDENTITY" "$APP"
fi
codesign --verify --deep --strict "$APP"
# Do not overwrite a running executable: macOS may kill it when its signature changes.
if [ -d "$PWD/dist/Super Ping.app" ]; then
    mv "$PWD/dist/Super Ping.app" "$STAGING/Previous.app"
fi
mv "$APP" "$PWD/dist/Super Ping.app"
printf 'Built: %s\n' "$PWD/dist/Super Ping.app"
