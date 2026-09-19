# frozen_string_literal: true

module Suiminkaizen
  # ゲームバランスに関わる数値をここ一箇所に集約している。
  # 難易度調整はこのファイルだけを触れば済むようにしてある。
  module Config
    # --- 画面 -------------------------------------------------------------
    # 論理解像度 320x240 のドット絵を、ウィンドウの大きさに合わせて拡大する。
    # REFERENCE_SCALE は「文字の大きさを決めたときの基準倍率」で、
    # 実際の倍率は Viewport が毎フレーム計算する。
    W               = 320
    H               = 240
    REFERENCE_SCALE = 3
    ASPECT          = W.to_f / H
    CAPTION         = "睡眠改善プロジェクト 〜ショートスリーパー峰小輔の一週間〜"

    # --- 睡眠ゲージ -------------------------------------------------------
    MAX_GAUGE      = 1000.0 # ここまで貯まると気絶（ゲームオーバー）
    START_GAUGE    =    0.0 # 0 が通常＝健康
    SLEEP_RECOVERY =   30.0 # 1日の終わりの「30分睡眠」で減る量
    TOTAL_DAYS     =      7

    # --- 1日の構成 --------------------------------------------------------
    # 1日は4枠＝ミニゲームを合計4回プレイできる。うち1枠はヘッドマッサージ師の
    # 乱入で、残り3枠は3つの選択肢から自分で種目を選ぶ（何もしないのも選べる）。
    # 4枠 x (選択 3s + 本編 15s + リザルト 2s) + 朝夕の演出 ＝ ちょうど 90秒/日。
    # 7日クリアで 630秒 ＝ 10分30秒。
    GAMES_PER_DAY    = 4
    MASSAGE_PER_DAY  = 1
    MINIGAME_SECONDS = 15.0

    # 達成率の上限。目標スコアを超えた分もある程度ボーナスになる。
    MAX_PERFORMANCE = 1.2

    # --- 難易度 -----------------------------------------------------------
    # 眠気の進む速さだけを段階で切り替える。1.0 が設計の基準。
    # 「基準の速さは普通と初心者の中間」という手応えに合わせて、
    # 普通を 1.25、初心者を 0.75 とその両側に置いてある。
    DIFFICULTIES = [
      { key: :baby,   label: "赤ちゃん", scale: 0.45, kuiya: 0,
        note: "眠気はほとんど進まない。まず一周したい人へ" },
      { key: :rookie, label: "初心者",   scale: 0.80, kuiya: 0,
        note: "何枠か捨ててもまだ取り返しがきく" },
      { key: :normal, label: "普通",     scale: 1.15, kuiya: 1,
        note: "丁寧にこなして、ようやく釣り合う" },
      { key: :hard,   label: "上級者",   scale: 1.50, kuiya: 2,
        note: "1枠でも捨てると、もう後がない" },
      { key: :pro,    label: "プロ",     scale: 1.85, kuiya: 3,
        note: "ショートスリーパーの本気。ミスは許されない" }
    ].freeze

    DEFAULT_DIFFICULTY = 2 # 普通

    # --- クイヤ -----------------------------------------------------------
    # 睡眠ゲージがここを超えると、クイヤが乱入してくる（普通以上の難易度だけ）。
    # 居座られているあいだ、眠気の進みが 1匹につき 5% 速くなる。
    KUIYA_THRESHOLD  = 500.0
    KUIYA_RATE_BONUS = 0.05

    module_function

    def difficulty_at(index)
      DIFFICULTIES[index.clamp(0, DIFFICULTIES.size - 1)]
    end

    def default_difficulty
      DIFFICULTIES[DEFAULT_DIFFICULTY]
    end

    # --- 24時間時計 -------------------------------------------------------
    # 1日は 00:30 に始まり、4枠を消化して 00:00 に終わる（23時間30分）。
    # 就寝はその 00:00 ちょうどから。30分眠って 00:30 ＝ 翌日の始まりに戻る。
    # ショートスリーパーの24時間がぴったり一周する。
    DAY_START_MINUTES = 30
    DAY_SPAN_MINUTES  = 23 * 60 + 30

    # 1秒あたりに溜まる眠気。1日目はちょうど 10/秒。
    # 日が進むほど身体は限界に近づき、7日目には 1.51 倍まで速くなる。
    #   day1: 10.00/s ... day7: 15.11/s
    DAY1_DROWSINESS = 10.0

    def drowsiness_rate(day)
      DAY1_DROWSINESS * (1.0 + 0.0852 * (day - 1))
    end

    # ミニゲーム外（説明・リザルト・朝夕の演出）はゆるやかに溜まる。
    def idle_rate(day)
      drowsiness_rate(day) * 0.6
    end

    # ミニゲーム1本を完璧にこなしたときに削れるゲージの上限。
    #   day1: 306 ... day7: 444
    # 1日4枠しかないぶん、1枠あたりの重みは大きい。
    def max_reward(day)
      306.0 * (1.0 + 0.075 * (day - 1))
    end

    # ミニゲームの速度・判定の厳しさ倍率。
    def difficulty(day)
      1.0 + 0.12 * (day - 1)
    end

    # 世界座標の奥行きから描画順(z)を決める。手前ほど大きい値＝後から描かれる。
    def depth_z(world_z)
      60.0 - world_z * 2.0
    end

    # 何枠目まで進んだかを 24時間表記の分に直す。
    def clock_minutes(progress)
      DAY_START_MINUTES + progress / GAMES_PER_DAY.to_f * DAY_SPAN_MINUTES
    end

    def format_clock(minutes)
      total = minutes.round
      format("%02d:%02d", (total / 60) % 24, total % 60)
    end
  end
end
