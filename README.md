# コエカキ — しゃべるだけでメモが書ける無料Macアプリ

しゃべるだけで文字が入る音声入力ツール(superwhisperの無料自作版)。

**ダウンロード**: [最新版 コエカキ.app(zip)](https://github.com/manabubannai/koekaki/releases/latest/download/Koekaki.zip) — 解凍してアプリケーションフォルダに入れるだけ。Apple公証済み。

このリポジトリには、自分用のメニューバー版(MBVoice)も含めた全バージョンのコードが入っています。

## バージョン一覧

| バージョン | 形 | 対象 | 中身 |
|---|---|---|---|
| v1 `dist/MBVoice.app` | Mac メニューバーアプリ | 自分用 | 完全ローカル(mlx-whisper)。右⌥を押している間だけ録音→離すと文字起こし→カーソル位置に貼り付け |
| v2 `dist/MBVoice AI.app` | Mac メニューバーアプリ | 自分用 | v1 + AI整形モード(claude CLI)。そのまま / 整形 / 箇条書き / メール文 |
| v3 `web/koe.html` | 単一HTMLファイル | メルマガ読者配布用 | ブラウザだけで動く音声入力メモ「コエカキ」。インストール不要・無料・サーバ不要 |
| v4 `dist/コエカキ.app` | Mac ウィンドウアプリ | メルマガ読者配布用 | v3のMacアプリ版。macOS標準の音声認識(SFSpeechRecognizer)を使うため外部依存ゼロで配布可。初回にマイクと音声認識の許可が必要 |

## 使い方(v1/v2)

1. `dist/MBVoice.app`(または `MBVoice AI.app`)をダブルクリックで起動(メニューバーにマイクアイコン)
2. 初回のみ許可が2つ必要:
   - **マイク**: 初回録音時にダイアログ
   - **アクセシビリティ**: システム設定→プライバシーとセキュリティ→アクセシビリティに MBVoice を追加(右⌥検知と自動貼り付けに必要)
3. 文字を入れたい場所にカーソルを置き、**右⌥(右option)を押しっぱなしで話す→離す**
4. 数秒でカーソル位置に文字が入る(クリップボードにも残る)

v1 と v2 は同時起動しない(右⌥を取り合うため)。

## 依存(v1/v2)

- mlx_whisper: `~/Documents/pipeline/.venv/bin/mlx_whisper` を使用(環境変数 `MBVOICE_WHISPER` で変更可)
- モデル: `mlx-community/whisper-large-v3-turbo`(pipelineで使用済み・キャッシュあり)
- v2 の AI整形: `claude` CLI(haiku、失敗時は整形なしのテキストをそのまま貼り付け)

## v3 の配布

`web/koe.html` を配るだけ(メール添付でもサーバ設置でも可)。Chrome/Edge/Safari で動作。
ブラウザ標準の音声認識APIを使うため、精度はブラウザ依存(Chromeが最良)。

## ビルド

```
./build.sh   # dist/ に2つの.appができる
```
