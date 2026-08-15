#!/bin/zsh
# Koe.app (v1) / Koe AI.app (v2) / Koekaki.app をビルドして dist/ に作成する (Apple Silicon)
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

make_app() {
    local app="$1" exe="$2" plist="$3"
    rm -rf "$app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cp ".build/release/$exe" "$app/Contents/MacOS/$exe"
    cp "$plist" "$app/Contents/Info.plist"
    cp "Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
    codesign --force --sign - "$app"
    echo "完成: $app"
}

make_app "dist/Koe.app"     "MBVoiceV1" "Resources/InfoV1.plist"
make_app "dist/Koe AI.app"  "MBVoiceV2" "Resources/InfoV2.plist"
make_app "dist/Koekaki.app" "Koekaki"   "Resources/InfoKoekaki.plist"

# Koekaki v2: whisperモデルを同梱 (Resources/models/ に無ければ
# https://huggingface.co/ggerganov/whisper.cpp から q5_0 をダウンロードしておく)
# vendor/whisper/ は whisper.cpp v1.9.2 を cmake (BUILD_SHARED_LIBS=OFF,
# GGML_METAL_EMBED_LIBRARY=ON) でビルドした静的ライブラリ+ヘッダ
cp "Resources/models/ggml-large-v3-turbo-q5_0.bin" "dist/Koekaki.app/Contents/Resources/"
codesign --force --sign - "dist/Koekaki.app"
echo "モデル同梱: dist/Koekaki.app"
