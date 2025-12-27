#!/bin/bash
set -e

# Configuration
APP_NAME="Hotdock"
VERSION="${1:-1.0.0}"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_DIR="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

echo "Building $APP_NAME v$VERSION..."

# Build release binary
echo "Compiling..."
cd "$PROJECT_DIR"
swift build -c release

# Create .app bundle structure
echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BUILD_DIR/release/$APP_NAME" "$MACOS_DIR/"

# Copy Info.plist and update version
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"

# Copy app icon
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Create DMG
echo "Creating DMG..."
rm -rf "$DMG_DIR"
rm -f "$DMG_PATH"
mkdir -p "$DMG_DIR"

cp -r "$APP_DIR" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_DIR"

# Get SHA256
SHA256=$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)

echo ""
echo "Build complete!"
echo ""
echo "  DMG: $DMG_PATH"
echo "  SHA256: $SHA256"
