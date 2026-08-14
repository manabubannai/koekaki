# MBVoice

superwhisper の無料自作版。Swift/SPM のメニューバーアプリ2種(v1ローカル / v2 AI整形付き) + 読者配布用の単一HTML(web/koe.html)。

重要な制約:
- CGEventTapコールバック内で同期的にキー送出するとmacOS 26で入力システムがデッドロックする。送出・ハンドラ呼び出しは必ず非同期で(eikanaの知見)
- v1/v2 は右⌥を取り合うので同時起動しない
- mlx_whisper は pipeline の venv (`~/Documents/pipeline/.venv/bin/mlx_whisper`) に相乗り。pipeline の venv を作り直したらここも動かなくなる点に注意

## ポートフォリオ連携

- 全プロジェクトの俯瞰: `~/Documents/portfolio-brain/INDEX.md`
- このプロジェクトの1枚メモ: `~/Documents/portfolio-brain/apps/mbvoice.md`
- 大きな変更(バージョンアップ・公開状況の変化)をしたら上記1枚メモも更新すること
