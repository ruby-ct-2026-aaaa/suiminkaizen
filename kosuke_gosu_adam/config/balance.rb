# frozen_string_literal: true

module Kosuke
  # 調整する数字はここへ集約。現実の睡眠・健康を表す数値ではありません。
  module Balance
    MAX_GAUGE = 1_000.0
    DAYS = 7
    DAY_SECONDS = 90.0          # 現実90秒 = ゲーム内23時間30分
    AWAKE_MINUTES = 23 * 60 + 30
    NAP_MINUTES = 30
    NAP_REDUCTION = 30.0
    GAUGE_SPEED_MULTIPLIER = 1.5
    BASE_DAILY_GAIN = [650, 700, 750, 800, 850, 900, 950].freeze
    DAILY_GAIN = BASE_DAILY_GAIN.map { |gain| (gain * GAUGE_SPEED_MULTIPLIER).round }.freeze
    MINI_SECONDS = 8.0
    COOLDOWN_SECONDS = 12.0     # 同じ設備の再使用待ち。プレイ時間だけ進む。

    DIFFICULTIES = {
      easy:   { label: 'やさしい', min: 80,  max: 120, threshold: 0.55 },
      normal: { label: 'ふつう',   min: 140, max: 200, threshold: 0.65 },
      hard:   { label: 'むずかしい', min: 210, max: 300, threshold: 0.75 }
    }.freeze

    ACTIVITIES = {
      training: { label: '筋トレ', title: 'リズム・リフト', color: 0xff_eead79,
                  instructions: ['バーが中央に来たら SPACE またはボタン！',
                                 '8秒以内に5回。中央に近いほど高得点。'] },
      bath: { label: 'お風呂', title: 'バブル・バランス', color: 0xff_80cbcf,
              instructions: ['← → または A / D を押して泡を動かそう。',
                             '光るゾーンに泡を保てた時間で採点。'] },
      supplement: { label: 'サプリメント', title: '星粒メモリー', color: 0xff_b9a3ed,
                    instructions: ['光る順番を覚えて、同じ順番で選ぼう。',
                                   '1〜4キー または4つのボタンで入力。'] },
      massage: { label: '整体', title: '整体・まぶた防衛', color: 0xff_f2a8ce,
                 instructions: ['矢印が出たら、その方向を ← → / A・D で押そう！',
                                'イスの誘惑に対抗。素早い反応ほど高得点。'] },
      camera: { label: 'カメラ救出', title: '配信カメラ救出', color: 0xff_bab4fc,
                instructions: ['光ったカメラをクリック、または1〜6キーでキャッチ！',
                               '倒れる前に救出。外したら待機画面へ。'] }
    }.freeze
  end
end
