#!/bin/bash
# Compila BarManager como binario universal, lo empaqueta como .app y genera
# el zip del release con su sha256 (el que va en el cask de Homebrew).
#
# Uso: ./Scripts/release.sh 1.0.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Uso: release.sh <version>}"

# Una compilación por arquitectura + lipo: funciona también con solo las
# Command Line Tools (el modo --arch x2 exige Xcode completo).
swift build -c release --triple arm64-apple-macosx
swift build -c release --triple x86_64-apple-macosx

APP="build/BarManager.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
lipo -create \
    .build/arm64-apple-macosx/release/BarManager \
    .build/x86_64-apple-macosx/release/BarManager \
    -output "$APP/Contents/MacOS/BarManager"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"

# Firma ad-hoc. Para distribuir sin fricción de Gatekeeper hay que firmar con
# Developer ID y notarizar; hasta entonces, instalar con --no-quarantine.
codesign --force --sign - "$APP"

ZIP="build/BarManager-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo ""
echo "Release listo: $ZIP"
shasum -a 256 "$ZIP"
