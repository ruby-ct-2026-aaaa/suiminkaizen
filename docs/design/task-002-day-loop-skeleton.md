# タスク002: ゲームループの骨組み（仮のミニゲームでの疎通確認）

Claude Codeにそのまま渡すための依頼。CLAUDE.mdと`lib/core/sleep_gauge.rb`（実装済み）を読み込んだ状態で、このタスクだけを渡す想定。

## 背景

企画側からミニゲーム（筋トレ／お風呂／サプリメント）の仕様書がまだ届いていない。ただし、ゲーム全体の骨組み（睡眠ゲージ管理・1日の行動ループ・7日間サイクル）は、ミニゲームが共通インターフェースさえ満たしていれば、中身がダミーでも動作確認ができる。このタスクでは、本物のミニゲームを待たずに、骨組み全体がフローチャート通りに動くことをターミナル上で確認できる状態を作る。

## 依頼内容

### 1. ダミーのミニゲーム

`lib/minigames/dummy_minigame.rb` に、CLAUDE.mdで定義した共通インターフェース（`update(dt)` / `draw` / `finished?` / `succeeded?` / `gauge_reduction`）を満たす `DummyMinigame` クラスを実装してください。本物の内容が決まるまでの仮実装です。

- `DummyMinigame.new(succeeds:, gauge_reduction:)` のように、成功するかどうかと成功時のゲージ減少量を外から指定できるようにする
- `update(dt)` は何もしなくてよい（引数を受け取るだけ）
- `draw` は何もしなくてよい（Gosuに依存させない。中身は空でよい）
- `finished?` は常に `true` を返してよい（1回の呼び出しで即座に結果が出る単純な仮実装でよい）
- `succeeded?` はコンストラクタで渡された `succeeds` の値を返す
- `gauge_reduction` は、成功時はコンストラクタで渡された値、失敗時は0を返す

### 2. 1日の行動ループ

`lib/core/day_cycle.rb` に、1日ぶんの行動ループを進めるクラス（例: `DayCycle`）を実装してください。`SleepGauge` のインスタンスと、その日プレイヤーが取る行動のリストを受け取り、フローチャート通りの分岐で1日を進めます。

- 1日は `ACTIONS_PER_DAY`（暫定的に3としてください。企画側で1日の行動回数の仕様が決まったら差し替える前提の**暫定値**であることをコードコメントに明記する）回の「行動」から成る
- 行動は次のいずれか
  - `:wait` — 何もしない（ゲージは変化しない）
  - ミニゲームのインスタンス（`succeeded?` と `gauge_reduction` を持つオブジェクト。今回は `DummyMinigame` を渡す想定）
- 行動を1つ処理するごとに、ミニゲームが渡されていて成功していれば `gauge_reduction` ぶんをマイナスにして `SleepGauge#apply` に渡す。失敗、または `:wait` の場合は何もしない
- 行動を1つ処理するたびに `SleepGauge#game_over?` を確認し、`true` になった時点でその日の残りの行動は処理せず中断する
- `ACTIONS_PER_DAY` 回の行動を（ゲームオーバーにならずに）すべて消化したら、最後に `SleepGauge#end_of_day!` を呼ぶ
- 渡された行動リストが `ACTIONS_PER_DAY` より少ない場合、残りは `:wait` として扱ってよい

### 3. CLIシミュレーター

`bin/simulate.rb` に、7日間ぶん `DayCycle` を回して結果を確認できる簡易シミュレーターを作成してください。

- 各日、`DummyMinigame` を（成功するかどうか・ゲージ減少量ともにランダムで。減少量は10〜80程度のランダムな整数でよい）`ACTIONS_PER_DAY` 回ぶん生成し、その日の行動リストとして `DayCycle` に渡す
- 1日終わるごとに `Day N終了: ゲージ=XXX` のように標準出力に表示する
- `SleepGauge#game_over?` が `true` になった時点で `Day Nで強制気絶... GAME OVER` と表示して終了する
- 7日間を `game_over?` にならずに終えたら `7日間生存！WIN` と表示する
- `ruby bin/simulate.rb` で実行できるようにする

### 4. テスト

`test/core/day_cycle_test.rb` に、`DayCycle` のロジックに対するMinitestのテストを書いてください。最低限、次を確認してください。

- 全ての行動が失敗（または `:wait`）の場合、`ACTIONS_PER_DAY` 回消化した後に `end_of_day!` が呼ばれ、ゲージが減っていること（`SleepGauge` 側の -30 固定処理が反映されていること）
- 行動の途中で `SleepGauge` が1000に到達した場合、それ以降の行動が処理されず、`end_of_day!` も呼ばれない（＝ `current_day` が進まない）こと
- 成功したミニゲームの `gauge_reduction` が正しく `SleepGauge` に反映されること

## スコープ外（このタスクではやらないこと）

- Gosuを使った実際の描画・入力は一切行わない（`bin/simulate.rb` は標準出力のみのCLIツールとする）
- 本物のミニゲーム（筋トレ／お風呂／サプリメント）の実装は行わない。あくまで共通インターフェースを満たすダミーでの疎通確認が目的
- `ACTIONS_PER_DAY` や、ゲージの自然増加ロジックなど、企画側の仕様がまだ確定していない部分は暫定値・未実装のままでよい。ただし暫定値であることをコードのコメントに明記すること

## 前提

- `lib/core/sleep_gauge.rb`（`SleepGauge` クラス）は実装済み。`require_relative` で利用する
- テストはMinitest。`ruby test/core/day_cycle_test.rb` で実行できること（`bundle install` は不要）
