#!/bin/bash
set -e

APP_NAME="InYourFace"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

echo "Creating App Bundle Directory..."
mkdir -p "$MACOS_DIR"

echo "Writing Info.plist..."
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.antigravity.InYourFace</string>
    <key>CFBundleName</key>
    <string>InYourFace</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>InYourFace</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>In Your Face needs access to your calendars to show upcoming meetings and trigger alerts.</string>
</dict>
</plist>
EOF

echo "Compiling Swift source files..."
swiftc -O -sdk $(xcrun --show-sdk-path) -target arm64-apple-macosx14.0 -o "$MACOS_DIR/$APP_NAME" *.swift

echo "Success! ${APP_NAME}.app has been built in the current directory."
