#!/bin/bash
# Compila BarManager y lo empaqueta como .app en build/BarManager.app
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/BarManager.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/BarManager "$APP/Contents/MacOS/BarManager"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Firma ad-hoc: suficiente para uso local (SMAppService la requiere).
codesign --force --sign - "$APP"

echo "Listo: $APP"
echo "Ábrelo con: open $APP"
