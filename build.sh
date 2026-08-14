#!/bin/zsh
# MBVoice.app (v1) と MBVoice AI.app (v2) をビルドして dist/ に作成する (Apple Silicon)
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

make_app() {
    local app="$1" exe="$2" plist="$3"
    rm -rf "$app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cp ".build/release/$exe" "$app/Contents/MacOS/$exe"
    cp "$plist" "$app/Contents/Info.plist"
    codesign --force --sign - "$app"
    echo "完成: $app"
}

make_app "dist/MBVoice.app"    "MBVoiceV1" "Resources/InfoV1.plist"
make_app "dist/MBVoice AI.app" "MBVoiceV2" "Resources/InfoV2.plist"
make_app "dist/コエカキ.app"     "Koekaki"   "Resources/InfoKoekaki.plist"
