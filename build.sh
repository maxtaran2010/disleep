#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Disleep.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -parse-as-library -swift-version 5 -target arm64-apple-macos13.0 \
    Sources/*.swift \
    -o build/Disleep-arm64
swiftc -O -parse-as-library -swift-version 5 -target x86_64-apple-macos13.0 \
    Sources/*.swift \
    -o build/Disleep-x86_64
lipo -create build/Disleep-arm64 build/Disleep-x86_64 \
    -output "$APP/Contents/MacOS/Disleep"
rm build/Disleep-arm64 build/Disleep-x86_64

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

echo "Built $APP"
