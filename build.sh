#!/bin/sh
# Builds build/ClaudeBar.app (release, arm64, ad-hoc signed).
#
# Runs xcodebuild directly with a single architecture: Flutter 3.29's own
# `flutter build macos` fails its universal-binary check with Xcode 27's lipo.
set -eu
cd "$(dirname "$0")"

flutter pub get
flutter build macos --release --config-only
(cd macos && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release \
    -derivedDataPath ../build/macos ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build -quiet)

APP=build/ClaudeBar.app
rm -rf "$APP"
cp -R build/macos/Build/Products/Release/ClaudeBar.app "$APP"

echo "Built $APP"
