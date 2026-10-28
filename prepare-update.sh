#!/bin/bash
# Build the archives and generate a signed feed. Publishing is a separate step.
set -euo pipefail
cd "$(dirname "$0")"
bash build.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
ACCOUNT=hieupnvmg.KubeSwitch
EXPECTED_KEY=$(/usr/libexec/PlistBuddy -c 'Print SUPublicEDKey' Info.plist)
ACTUAL_KEY=$(.dependencies/bin/generate_keys --account "$ACCOUNT" -p)
if [ "$EXPECTED_KEY" != "$ACTUAL_KEY" ]; then
    echo "Signing key does not match Info.plist. Restore the original Keychain key." >&2
    exit 1
fi
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/kubeswitch-appcast.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
cp dist/KubeSwitch-macOS.zip "$STAGING/"
.dependencies/bin/generate_appcast --account "$ACCOUNT" --maximum-deltas 0 \
    --download-url-prefix "https://github.com/hieupnvmg/KubeSwitch/releases/download/v$VERSION/" \
    --link https://github.com/hieupnvmg/KubeSwitch \
    -o "$PWD/appcast.xml" "$STAGING"
.dependencies/bin/sign_update --account "$ACCOUNT" --verify appcast.xml
echo "Signed appcast.xml for v$VERSION. Publish the release archives before pushing this feed."
