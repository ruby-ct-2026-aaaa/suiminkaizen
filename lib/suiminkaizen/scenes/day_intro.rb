# frozen_string_literal: true

module Suiminkaizen
  module Scenes
    # 1日のはじまり。今日のメニューと、いまの睡眠ゲージを確認する画面。
    class DayIntro < Scene
      AUTO_START = 10.0
      MIN_SHOW   = 1.6

      LABELS = { muscle: "筋トレ", bath: "お風呂", supplement: "サプリ" }.freeze
      ICONS  = { muscle: Palette::RED, bath: Palette::CYAN,
                 supplement: Palette::YELLOW }.freeze

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
        start! if confirm?(id) && elapsed >= MIN_SHOW
      end

      def draw
        Stage.draw(@camera, :bedroom, elapsed)
        Sprites::KOSUKE.draw3d(@camera, 2.3, Stage::FLOOR_Y, 5.6, 1.55,
                               fog: Stage.fog(:bedroom))

        Px.rect(10, 34, Config::W - 20, 168, Palette.alpha(Palette::INK, 232), 100)
        Px.frame(10, 34, Config::W - 20, 168, Palette::VIOLET, 101)

        Px.text_shadow(Assets.huge, "DAY #{state.day}", 24, 40, Palette::WHITE, 102)
        Px.text_shadow(Assets.small, "/ #{Config::TOTAL_DAYS}", 66, 56,
                       Palette::GRAY, 102)
        Px.text_shadow(Assets.small, headline, Config::W - 24, 44,
                       Palette::CYAN, 102, align: :right)

        draw_status
        draw_menu
        Px.text_shadow(Assets.small, "SPACE ではじめる",
                       Config::W / 2, 208,
                       Palette.alpha(Palette::YELLOW, blinking_alpha), 102, align: :center)
        Px.text_shadow(Assets.tiny, "#{(AUTO_START - elapsed).ceil}秒後に自動ではじまります",
                       Config::W / 2, 226, Palette::SLATE, 102, align: :center)

        Hud.draw(state, elapsed)
        Hud.draw_drowsiness(state)
      end

      private

      def start!
        goto(MinigameIntro.new(window, state, state.current_kind))
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
        Px.text_shadow(Assets.small, "現在の睡眠ゲージ", 24, 72, Palette::BONE, 102)
        Px.text_shadow(Assets.large, "#{gauge.to_i}", 150, 66,
                       Palette.gauge_color(gauge.ratio), 102, align: :right)
        Px.text_shadow(Assets.tiny, "/ 1000", 154, 76, Palette::GRAY, 102)

        message =
          if gauge.ratio < 0.25 then "今日も冴えている。"
          elsif gauge.ratio < 0.5 then "あくびが出はじめた。"
          elsif gauge.ratio < 0.75 then "まぶたが重い。気を抜くな。"
          else "もう限界が近い。1回のミスが命取り。"
          end
        Px.text_shadow(Assets.tiny, message, 200, 74,
                       gauge.ratio < 0.5 ? Palette::BONE : Palette::RED, 102,
                       align: :center)
      end

      def draw_menu
        Px.text_shadow(Assets.small, "今日のメニュー", 24, 100, Palette::BONE, 102)
        Px.rect(24, 116, Config::W - 48, 1, Palette::SLATE, 102)

        state.schedule.each_with_index do |kind, i|
          x = 30 + (i % 3) * 90
          y = 124 + (i / 3) * 34
          Px.rect(x, y, 80, 26, Palette.alpha(Palette::DUSK, 220), 102)
          Px.rect(x, y, 4, 26, ICONS.fetch(kind), 103)
          Px.text_shadow(Assets.tiny, "#{i + 1}. #{LABELS.fetch(kind)}", x + 10, y + 4,
                         Palette::WHITE, 103)
          Px.text_shadow(Assets.tiny, "最大 -#{Config.max_reward(state.day).round}",
                         x + 10, y + 15, Palette::GREEN, 103)
        end
      end
    end
  end
end
