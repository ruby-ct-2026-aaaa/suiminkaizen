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
    # 1日は6枠。うち2枠はヘッドマッサージ師の乱入で、残り4枠は
    # 筋トレ／お風呂／サプリメントから選ばれる（やるか、やらないか選べる）。
    # 6枠 x (説明 6s + 本編 22s + リザルト 3s) + 朝夕の演出 ≒ 3分/日。
    # 7日クリアでおよそ 20〜22 分。
    GAMES_PER_DAY    = 6
    MASSAGE_PER_DAY  = 2
    MINIGAME_SECONDS = 22.0

    # 達成率の上限。目標スコアを超えた分もある程度ボーナスになる。
    MAX_PERFORMANCE = 1.2

    # --- 24時間時計 -------------------------------------------------------
    # 1日は 08:00 に始まり、6枠を消化して 23:00 に終わる。
    # そのあと30分だけ眠って 23:30。
    DAY_START_MINUTES = 8 * 60
    DAY_SPAN_MINUTES  = 15 * 60

    module_function

    # 1秒あたりに溜まる眠気。日が進むほど身体は限界に近づく。
    #   day1: 4.05/s ... day7: 6.12/s
    # 「簡単すぎる」というフィードバックを受けて、従来の3倍にしてある。
    DROWSINESS_MULTIPLIER = 3.0

    def drowsiness_rate(day)
      (1.35 + 0.115 * (day - 1)) * DROWSINESS_MULTIPLIER
    end

    # ミニゲーム外（説明・リザルト・朝夕の演出）はゆるやかに溜まる。
    def idle_rate(day)
      drowsiness_rate(day) * 0.6
    end

    # ミニゲーム1本を完璧にこなしたときに削れるゲージの上限。
    #   day1: 150 ... day7: 230
    # ミスをしなければ達成率0.75あたりで1日の増減が釣り合う。
    def max_reward(day)
      150.0 * (1.0 + 0.089 * (day - 1))
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
