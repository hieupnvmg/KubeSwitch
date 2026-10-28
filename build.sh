#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

SPARKLE_VERSION=2.10.1
SPARKLE_SHA256=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
mkdir -p .dependencies
ARCHIVE=".dependencies/Sparkle-$SPARKLE_VERSION.tar.xz"
if [ ! -f "$ARCHIVE" ]; then
    curl --fail --location --retry 3 "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" -o "$ARCHIVE"
fi
echo "$SPARKLE_SHA256  $ARCHIVE" | shasum -a 256 -c -
tar -xJf "$ARCHIVE" -C .dependencies
APP="KubeSwitch.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks" dist
cp Info.plist "$APP/Contents/Info.plist"
cp config.rb "$APP/Contents/Resources/config.rb"
cp .dependencies/LICENSE "$APP/Contents/Resources/Sparkle-LICENSE.txt"
rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
ditto .dependencies/Sparkle.framework "$APP/Contents/Frameworks/Sparkle.framework"
swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 main.swift -o "$APP/Contents/MacOS/KubeSwitch" -framework Cocoa -F .dependencies -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks
# Preserve Sparkle's signed helper services; sign only our outer application.
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"

STAGING=$(mktemp -d "${TMPDIR:-/tmp}/kubeswitch-dmg.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/KubeSwitch.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname KubeSwitch -srcfolder "$STAGING" -ov -format UDZO dist/KubeSwitch-macOS.dmg
ditto -c -k --sequesterRsrc --keepParent "$APP" dist/KubeSwitch-macOS.zip
echo "Built dist/KubeSwitch-macOS.dmg"
