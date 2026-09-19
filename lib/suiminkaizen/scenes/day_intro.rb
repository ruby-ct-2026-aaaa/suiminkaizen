# frozen_string_literal: true

module Suiminkaizen
  module Scenes
    # 1日のはじまり。今日の予定と、いまの睡眠ゲージを確認する画面。
    #
    # ヘッドマッサージ師がいつ乱入してくるかは予定に載らない（？で伏せる）。
    class DayIntro < Scene
      AUTO_START = 4.0
      MIN_SHOW   = 3.6

      LABELS = { choice: "選ぶ", muscle: "筋トレ", bath: "お風呂",
                 supplement: "サプリ", massage: "？？？" }.freeze
      ICONS  = { choice: Palette::YELLOW, muscle: Palette::RED,
                 bath: Palette::CYAN, supplement: Palette::BLUE,
                 massage: Palette::SLATE }.freeze

      def initialize(window, state)
        super
        @camera = Camera.new
      end

      def update(dt)
        super
        @camera.update(dt)
        accumulate_idle(dt)
        start! if elapsed >= AUTO_START
      end

      def button_down(id)
        return unless confirm?(id) && elapsed >= MIN_SHOW

        Sound.play(:decide)
        start!
      end

      def draw
        Stage.draw(@camera, :bedroom, elapsed)

        Px.rect(8, 36, Config::W - 16, 172, Palette.alpha(Palette::INK, 232), 100)
        Px.frame(8, 36, Config::W - 16, 172, Palette::VIOLET, 101)

        draw_portrait
        Px.text_shadow(Assets.huge, "DAY #{state.day}", 20, 41, Palette::WHITE, 102)
        Px.text_shadow(Assets.small, "/ #{Config::TOTAL_DAYS}", 62, 57,
                       Palette::GRAY, 102)
        Px.text_shadow(Assets.small, headline, Config::W - 20, 44,
                       Palette::CYAN, 102, align: :right)

        draw_status
        draw_menu

        Px.text_shadow(Assets.small, "SPACE ではじめる", Config::W / 2, 212,
                       Palette.alpha(Palette::YELLOW, blinking_alpha), 102,
                       align: :center)
        Px.text_shadow(Assets.tiny, "#{(AUTO_START - elapsed).ceil}秒後に自動ではじまります",
                       Config::W / 2, 230, Palette::SLATE, 102, align: :center)

        Hud.draw(state, elapsed)
        Hud.draw_drowsiness(state)
      end

      private

      def start!
        return if @moved

        @moved = true
        # ゲーム開幕だけは、まず30分眠ってから1枠目へ。
        return goto(Sleep.new(window, state, opening: true)) if state.opening?

        goto(MinigameIntro.new(window, state, state.current_kind))
      end

      def draw_portrait
        sprite = Assets.portrait(:normal)
        return unless sprite

        sprite.draw_sized(280, 204, 118, 102)
      end

      def headline
        case state.day
        when 1 then "はじまりの月曜日"
        when 2 then "まだ火曜日"
        when 3 then "水曜日・折り返し"
        when 4 then "木曜日・体が重い"
        when 5 then "金曜日・視界が狭い"
        when 6 then "土曜日・あと少し"
        else        "最終日・日曜日"
        end
      end

      def draw_status
        gauge = state.gauge
        Px.text_shadow(Assets.tiny, "現在の睡眠ゲージ", 20, 70, Palette::BONE, 102)
        Px.text_shadow(Assets.large, gauge.to_i.to_s, 132, 64,
                       Palette.gauge_color(gauge.ratio), 102, align: :right)
        Px.text_shadow(Assets.tiny, "/ 1000", 136, 72, Palette::GRAY, 102)

        message =
          if gauge.ratio < 0.25 then "今日も冴えている。"
          elsif gauge.ratio < 0.5 then "あくびが出はじめた。"
          elsif gauge.ratio < 0.75 then "まぶたが重い。気を抜くな。"
          else "もう限界が近い。1回のミスが命取り。"
          end
        Px.text_shadow(Assets.tiny, message, 20, 86,
                       gauge.ratio < 0.5 ? Palette::BONE : Palette::RED, 102)
      end

      def draw_menu
        Px.text_shadow(Assets.tiny, "今日は #{Config::GAMES_PER_DAY} 枠", 20, 104,
                       Palette::BONE, 102)
        Px.text_shadow(Assets.tiny, "各枠で3つの中から選ぶ（何もしないのも可）",
                       210, 104, Palette::SLATE, 102, align: :center)
        Px.rect(20, 118, Config::W - 40, 1, Palette::SLATE, 102)

        width = (Config::W - 44) / Config::GAMES_PER_DAY
        state.schedule.each_with_index do |kind, i|
          x = 22 + i * width
          y = 126
          Px.rect(x, y, width - 6, 34, Palette.alpha(Palette::DUSK, 225), 102)
          Px.rect(x, y, 3, 34, ICONS.fetch(kind), 103)
          Px.text_shadow(Assets.tiny, "#{i + 1}. #{LABELS.fetch(kind)}", x + 7, y + 4,
                         kind == :massage ? Palette::SLATE : Palette::WHITE, 103)
          Px.text_shadow(Assets.tiny, Config.format_clock(Config.clock_minutes(i)),
                         x + 7, y + 20, Palette::CYAN, 103)
        end

        Px.text_shadow(Assets.tiny,
                       "1枠あたり最大 -#{Config.max_reward(state.day).round}",
                       Config::W - 22, 166, Palette::GREEN, 103, align: :right)
      end
    end
  end
end
