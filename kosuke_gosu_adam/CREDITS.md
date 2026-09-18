# 素材・依存ライブラリ

- 主人公の肖像：ユーザー提供 `IMG_7051.jpeg`。`assets/kosuke_reference.jpeg` として原画像を同梱。
- ミニゲームの人物：追加で提供された同じ人物の `IMG_7051(1).jpeg` を参照し、画像生成で描き起こした20コマ。`assets/action_sprites.png`。
- クイヤ：ネット上の「9が嫌いな架空の動物」というネタから、本ゲーム用に画像生成した独自の見た目。`assets/kuiya_sprites.png`。
- 生成画像を使用。生成時の指示とファイル仕様は `ASSET_PROMPTS.md` に記録。
- 部屋・家具・歩行用仮ドット：本試作用にRubyの描画コードで作成。
- 配信UIとコメント：本ゲーム向けに作成。『NEEDY GIRL OVERDOSE』を雰囲気の参考とし、同作の画像・音楽・台詞は収録していない。
- 配信中の出来事の参考：[週刊アスキー](https://weekly.ascii.jp/elem/000/004/434/4434756/)（2026-09-15）。ゲームへの置き換えは `DESIGN.md` に記載。
- クイヤの参考：[由来・特徴の解説](https://www.thebyan.com/post/kuiya)（参照2026-09-16）。幻覚演出は本ゲームの創作。
- 日本語フォント：Noto Sans JP。Google Fonts公開版からweight=400の静的フォントを生成。
  - 配布元：[google/fonts — Noto Sans JP](https://github.com/google/fonts/tree/main/ofl/notosansjp)
  - ライセンス：SIL Open Font License 1.1。原文を `assets/OFL.txt` に同梱。
- ゲームライブラリ：Gosu 1.4.6。gemで別途インストールする。
  - [Gosu公式](https://www.libgosu.org/)
