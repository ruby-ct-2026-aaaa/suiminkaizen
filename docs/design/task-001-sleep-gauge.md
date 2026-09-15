# タスク001: 睡眠ゲージ管理コアロジックの実装

Claude Codeにそのまま渡すための最初の実装依頼。CLAUDE.mdを読み込んだ状態で、このタスクだけを渡す想定。

## 依頼内容

`lib/core/sleep_gauge.rb` に、Gosuやその他の描画・入力処理に一切依存しない、純粋なRubyクラス `SleepGauge` を実装してください。あわせて `spec/core/sleep_gauge_spec.rb` にRSpecのテストを書いてください。

## 仕様

- 初期値は `SleepGauge.new(initial_value: 0)` のように外から指定できるようにする（省略時は0）
- 内部状態として `value`（現在のゲージ値）、`current_day`（現在の日、1始まり）、`game_over?`、`cleared?` を持つ
- ゲージの変更は必ず1つのメソッド経由で行う。例として `apply(delta)` のような形で、正の値も負の値も渡せるようにする（内部で加算・減算どちらも処理する）
- `apply(delta)` の内部で以下を必ず行う
  - 値を更新する
  - 更新後の値が0未満なら0にクランプする
  - 更新後の値が1000以上になった場合、`game_over?` をtrueにする（一度trueになったら`apply`を呼んでも状態は変わらない＝ゲームオーバー後の操作は無視する）
- `end_of_day!` というメソッドを用意し、呼び出されたときに次を行う
  - すでに `game_over?` がtrueなら何もしない
  - そうでなければ、現在のゲージ値がいくつであっても無条件で30を減算する（0未満はクランプ）
  - `current_day` が7の状態でこの処理を実行し、かつ `game_over?` がfalseのままなら `cleared?` をtrueにする
  - `cleared?` がfalseかつ `game_over?` がfalseなら `current_day` を1増やす
- `game_over?` と `cleared?` は同時にtrueにならない
- ゲージの上限1000・下限0を超えた値が外部から読み取れることはない（`value`は常に0〜1000の範囲）

## テストしてほしいケース（RSpec）

- 初期値0で生成できること、`initial_value`を指定できること
- `apply`で正の値を渡すとゲージが増えること
- `apply`で負の値を渡すとゲージが減ること
- `apply`後にゲージが0未満になる場合は0にクランプされること
- `apply`でゲージが1000ちょうど、または1000を超えた場合に`game_over?`がtrueになること
- `game_over?`がtrueになった後に`apply`を呼んでも`value`が変化しないこと
- `end_of_day!`を呼ぶと、ゲージの現在値に関わらず30減算されること（例: 現在値5でも30減算後は0にクランプされ、マイナスにならないこと）
- `end_of_day!`を呼んでも`game_over?`がtrueなら何も変化しないこと
- `current_day`が1〜6の間で`end_of_day!`を呼ぶと、`current_day`が1増え、`cleared?`はfalseのままであること
- `current_day`が7の状態で`end_of_day!`を呼び、その時点で`game_over?`がfalseなら`cleared?`がtrueになること

## スコープ外（このタスクではやらないこと）

- ミニゲームの実装、描画、Gosuとの連携は一切含めない
- ゲージの自然増加ロジック（時間経過での増加など）はまだ仕様が確定していないため実装しない。将来`apply`経由で外部から増加させる想定でよい
