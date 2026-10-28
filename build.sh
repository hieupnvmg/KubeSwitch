#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="KubeSwitch.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist
cp Info.plist "$APP/Contents/Info.plist"
cp config.rb "$APP/Contents/Resources/config.rb"
swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 main.swift -o "$APP/Contents/MacOS/KubeSwitch" -framework Cocoa
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

STAGING=$(mktemp -d "${TMPDIR:-/tmp}/kubeswitch-dmg.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/KubeSwitch.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname KubeSwitch -srcfolder "$STAGING" -ov -format UDZO dist/KubeSwitch-macOS.dmg
ditto -c -k --sequesterRsrc --keepParent "$APP" dist/KubeSwitch-macOS.zip
echo "Built dist/KubeSwitch-macOS.dmg"
