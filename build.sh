#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Disleep.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -parse-as-library -swift-version 5 \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/Disleep"

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

echo "Built $APP"
