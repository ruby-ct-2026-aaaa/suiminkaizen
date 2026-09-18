# frozen_string_literal: true

module Kosuke
  # ゲーム内で作る架空の視聴者コメント。外部サービスへの接続はしない。
  class StreamFeed
    AUTHORS = %w[夜更かし豆 まぶた係 毛布ボット 見守り隊 アヒル推し].freeze
    AMBIENT = ['本日も見守ります', '部屋かわいい', 'アヒルも配信見てる', '次なにする？', '休憩ボタンもあるよ'].freeze
    LINES = {
      start: ['配信きた！', '7日間、見守るぞ'],
      training: ['筋トレ始まった', 'ダンベルよりまぶたが重い'],
      training_hit: ['キレッキレで草', '腕だけ元気すぎる'],
      training_miss: ['いま空気を鍛えた？', 'ダンベルとすれ違ったｗ'],
      bath: ['アヒルが見守ってる', '泡そっちｗ'],
      bath_keep: ['泡の操縦うまい', 'アヒルが拍手してる'],
      bath_miss: ['泡が脱走した', 'アヒル「こっち！」'],
      supplement: ['星食べてて草', '記憶力の出番だ'],
      memory_ok: ['おぼえてる！', '星が光った'],
      memory_miss: ['その星じゃないｗ', '記憶が迷子'],
      massage: ['そのイスは強敵', 'まぶたの防衛戦'],
      massage_ok: ['起きたｗ', 'イスに勝った！'],
      massage_miss: ['イスが優秀すぎる', 'まぶた閉店しかけた'],
      camera: ['カメラ係出動！', '配信を守れ'],
      camera_ok: ['ギリギリで救出', 'カメラ係仕事した'],
      camera_miss: ['待機画面たすかる', 'カメラそっちー！'],
      clear: ['ナイス！', 'ゲージ減ったぞ'],
      miss: ['次で取り返そう', '見守ってるぞ'],
      sleepy: ['後ろに何かいる', 'クイヤおるって'],
      danger: ['9！9！9！', 'お前らにも見える？'],
      repel: ['数字で退勤してて草', 'クイヤ帰宅'],
      day_clear: ['今日も乗り切った！', '仮眠の時間です'],
      nap: ['おやすみ30分', 'アヒルも休憩'],
      game_over: ['配信、おつかれさま', '強制おやすみタイム'],
      victory: ['7日間完走！', '見届けたぞーー！']
    }.freeze

    attr_reader :active, :history, :pending, :clock, :width

    def initialize(random: Random.new)
      @random = random
      @active, @pending, @history = [], [], []
      @clock, @ambient_at, @width = 0.0, 3.0, 760.0
      @last_events = {}
      @serial = 0
      emit(:start)
    end

    def emit(event, throttle: 0.0)
      return false if @clock - @last_events.fetch(event, -100.0) < throttle
      @last_events[event] = @clock
      (LINES[event] || [event.to_s]).each { |line| enqueue(line, event) }
      true
    end

    def begin_activity(kind)
      # 次の競技に前の競技の実況を持ち越さない。右側の履歴は残す。
      @pending.clear
      @active.clear
      emit(kind)
    end

    def enqueue(line, event = :ambient)
      entry = { text: line, author: AUTHORS[@serial % AUTHORS.length], event: event }
      @serial += 1
      @history << entry
      @history.shift while @history.length > 16
      @pending << entry
      @pending.shift while @pending.length > 20
    end

    def viewport(width)
      return if width == @width
      @width = width.to_f
      @active.clear
    end

    def update(dt, ambient: true)
      @clock += dt
      @active.each { |c| c[:x] -= 108.0 * dt }
      @active.reject! { |c| c[:x] + c[:width] < 0 }
      if ambient && @clock >= @ambient_at
        enqueue(AMBIENT[@random.rand(AMBIENT.length)])
        @ambient_at = @clock + 3.4
      end
      4.times do |lane|
        break if @pending.empty? || @active.length >= 12
        next if @active.any? { |c| c[:lane] == lane && c[:x] + c[:width] > @width - 42 }
        entry = @pending.shift
        @active << entry.merge(x: @width + 8, lane: lane, width: entry[:text].length * 22.0)
      end
    end
  end
end
