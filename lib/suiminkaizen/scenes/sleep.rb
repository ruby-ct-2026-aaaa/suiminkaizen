# frozen_string_literal: true

module Suiminkaizen
  module Scenes
    # 1日の終わりに許された 30分の睡眠。
    # たった 30 しか減らないという事実を、時計の針でたっぷり見せる。
    class Sleep < Scene
      FALL  = 0.8 # まぶたが落ちるまで
      DOZE  = 2.2 # 眠っている時間
      WAKE  = 1.0 # 目覚ましが鳴ってから
      TOTAL = FALL + DOZE + WAKE

      CLOCK_X = 240
      CLOCK_Y = 96
      CLOCK_R = 26

      def initialize(window, state)
        super
        @camera = Camera.new
        @before = state.gauge.value
        @recovered = 0.0
      end

      def enter
        # 実際の減算はここで一度だけ。表示上はゆっくり減っていくよう見せる。
        @recovered = state.sleep!
      end

      def update(dt)
        super
        @camera.update(dt)
        finish! if elapsed >= TOTAL
      end

      def button_down(id)
        finish! if confirm?(id) && elapsed >= FALL + DOZE
      end

      def draw
        Stage.draw(@camera, :bedroom, elapsed)
        draw_kosuke
        darken
        Hud.draw_clock(state, elapsed, state.sleep_clock_text(progress))
        draw_clock
        draw_zzz if phase == :doze
        draw_gauge
        draw_caption
        draw_alarm if phase == :wake
      end

      private

      def phase
        return :fall if elapsed < FALL
        return :doze if elapsed < FALL + DOZE

        :wake
      end

      def draw_kosuke
        sprite = Assets.portrait(:sleep)
        if sprite
          sprite.draw3d(@camera, -1.2, Stage::FLOOR_Y - 0.5, 4.2, 0.72,
                        fog: Stage.fog(:bedroom))
        else
          Sprites::KOSUKE_SLEEP.draw3d(@camera, -1.35, Stage::FLOOR_Y - 0.53, 4.4, 1.05,
                                       fog: Stage.fog(:bedroom))
        end
      end

      # 眠りに落ちるほど画面が暗くなり、目覚ましで一気に戻る。
      def darken
        level =
          case phase
          when :fall then elapsed / FALL
          when :doze then 1.0
          else [1.0 - (elapsed - FALL - DOZE) / 0.4, 0.0].max
          end
        Px.rect(0, 0, Config::W, Config::H,
                Palette.alpha(Palette::INK, (level * 168).round), 100)
      end

      # 睡眠の進み具合（0.0 .. 1.0）
      def progress
        return 0.0 if elapsed < FALL

        [(elapsed - FALL) / DOZE, 1.0].min
      end

      def draw_clock
        minutes = Config::SLEEP_RECOVERY * progress
        Px.circle(CLOCK_X, CLOCK_Y, CLOCK_R + 2, Palette::INK, 110, 2)
        Px.circle(CLOCK_X, CLOCK_Y, CLOCK_R, Palette::BONE, 111)
        (0...12).each do |i|
          angle = Math::PI * 2 * i / 12 - Math::PI / 2
          Px.ray(CLOCK_X, CLOCK_Y, angle, CLOCK_R - 1, Palette::SLATE, 111, 1,
                 CLOCK_R - 4)
        end

        minute_angle = Math::PI * 2 * (minutes / 60.0) - Math::PI / 2
        hour_angle   = Math::PI * 2 * ((11.0 + minutes / 60.0) / 12.0) - Math::PI / 2
        Px.ray(CLOCK_X, CLOCK_Y, hour_angle, CLOCK_R * 0.5, Palette::WHITE, 112, 2)
        Px.ray(CLOCK_X, CLOCK_Y, minute_angle, CLOCK_R * 0.82, Palette::RED, 113, 1)
        Px.rect(CLOCK_X - 1, CLOCK_Y - 1, 3, 3, Palette::WHITE, 114)

        Px.text_shadow(Assets.tiny, "#{minutes.round}分経過",
                       CLOCK_X, CLOCK_Y + CLOCK_R + 8, Palette::BONE, 114,
                       align: :center)
      end

      def draw_zzz
        4.times do |i|
          cycle = (elapsed * 0.9 + i * 0.5) % 2.0
          alpha = (200 * (1.0 - cycle / 2.0)).round
          Px.text_shadow(Assets.small, "Z", 96 + i * 11, 116 - cycle * 26,
                         Palette.alpha(Palette::AQUA, alpha), 115,
                         scale: 1.0 + cycle * 0.5)
        end
      end

      def draw_gauge
        shown = @before - @recovered * progress

        Px.rect(30, 172, 260, 34, Palette.alpha(Palette::INK, 215), 110)
        Px.frame(30, 172, 260, 34, Palette::VIOLET, 111)
        Px.text_shadow(Assets.tiny, "睡眠ゲージ", 38, 176, Palette::BONE, 112)
        Px.text_shadow(Assets.small, shown.round.to_s, 160, 174,
                       Palette.gauge_color(shown / Config::MAX_GAUGE), 112,
                       align: :right)
        Px.text_shadow(Assets.tiny, "-#{(@recovered * progress).round}", 282, 176,
                       Palette::CYAN, 112, align: :right)

        ratio = shown / Config::MAX_GAUGE
        Px.rect(38, 192, 244, 7, Palette.rgb(0x241f42), 112)
        Px.rect(38, 192, (244 * ratio).round, 7, Palette.gauge_color(ratio), 113)
      end

      def draw_caption
        text, color =
          case phase
          when :fall then ["おやすみ、峰小輔。", Palette::BONE]
          when :doze then ["30分だけの睡眠…", Palette::AQUA]
          else [wake_message, Palette::RED]
          end
        Px.text_shadow(Assets.large, text, Config::W / 2, 42, color, 120, align: :center)

        return unless phase == :wake

        Px.text_shadow(Assets.tiny, "SPACE ですすむ", Config::W / 2, 216,
                       Palette.alpha(Palette::YELLOW, blinking_alpha), 120, align: :center)
      end

      def wake_message
        return "最終日を乗り切った…！" if state.last_day?

        "起きろ！ 残り#{Config::TOTAL_DAYS - state.day}日！"
      end

      # 目覚ましの点滅。
      def draw_alarm
        return unless Math.sin((elapsed - FALL - DOZE) * 26.0).positive?

        Px.rect(0, 0, Config::W, Config::H, Palette.alpha(Palette::RED, 45), 121)
      end

      def finish!
        return if @done

        @done = true
        if state.last_day?
          goto(Ending.new(window, state))
        else
          state.next_day!
          goto(DayIntro.new(window, state))
        end
      end
    end
  end
end
