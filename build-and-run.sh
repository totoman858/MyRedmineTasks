#!/bin/bash
set -e

# -----------------------------
# CONFIGURATION
# -----------------------------
APP_NAME="RedmineApp"
BINARY_NAME="redmine-mac-swift-app"
BUILD_DIR=".build/release"
APP_DIR="$PWD/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
ICONSET_DIR="$PWD/AppIcon.iconset"
ICON_FILE="$PWD/$APP_NAME.icns"
DMG_FILE="$PWD/$APP_NAME.dmg"
BG_COLOR="#FF0000"

# -----------------------------
# COMPILATION SWIFT
# -----------------------------
echo "🔨 Compilation SwiftPM en Release..."
swift build -c release

# -----------------------------
# CREATION DU BUNDLE .app
# -----------------------------
echo "📦 Création du bundle .app..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$BUILD_DIR/$BINARY_NAME" "$MACOS_DIR/"
chmod +x "$MACOS_DIR/$BINARY_NAME"

# -----------------------------
# GENERATION DE L'ICONE
# -----------------------------
echo "🖼️  Génération de l'icône..."
mkdir -p "$ICONSET_DIR"

for SIZE in 16 32 64 128 256 512 1024; do
    magick -size ${SIZE}x${SIZE} xc:"$BG_COLOR" \
        -gravity center -pointsize $((SIZE/5)) -fill white \
        -annotate 0 "REDMINE" \
        \( -size ${SIZE}x${SIZE} xc:none \
           -draw "roundrectangle 0,0 $((SIZE-1)),$((SIZE-1)) $((SIZE/5)),$((SIZE/5))" \
        \) -alpha set -compose dstin -composite \
        "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png"
done

iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"
rm -rf "$ICONSET_DIR"

# -----------------------------
# CREATION DU INFO.PLIST
# -----------------------------
mkdir -p "$CONTENTS_DIR"
cat > "$CONTENTS_DIR/Info.plist" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>fr.osupytheas.$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>$BINARY_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>$APP_NAME</string>
</dict>
</plist>
EOL

# Copie de l’icône dans le bundle
mkdir -p "$CONTENTS_DIR/Resources"
cp "$ICON_FILE" "$CONTENTS_DIR/Resources"

# -----------------------------
# CREATION DU DMG
# -----------------------------
echo "💿 Création du DMG..."
rm -f "$DMG_FILE"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_DIR" -ov -format UDZO "$DMG_FILE"

echo "✅ Bundle .app et DMG générés avec succès !"
open "$APP_DIR"
