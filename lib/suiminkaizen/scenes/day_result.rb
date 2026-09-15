# frozen_string_literal: true

module Suiminkaizen
  module Scenes
    # 1日の締め。6本ぶんの成績を並べ、これから眠れることを告げる。
    class DayResult < Scene
      LABELS = { muscle: "筋トレ", bath: "お風呂", supplement: "サプリ" }.freeze

      def initialize(window, state)
        super
        @camera = Camera.new
      end

      def update(dt)
        super
        @camera.update(dt)
        accumulate_idle(dt)
      end

      def button_down(id)
        return unless confirm?(id) && elapsed >= 1.4

        goto(Sleep.new(window, state))
      end

      def draw
        Stage.draw(@camera, :bedroom, elapsed)
        Px.rect(0, 0, Config::W, Config::H, Palette.alpha(Palette::INK, 195), 100)

        Px.text_shadow(Assets.large, "DAY #{state.day} 終了", Config::W / 2, 36,
                       Palette::WHITE, 101, align: :center)
        Px.text_shadow(Assets.tiny, "気絶せずに1日を乗り切った。30分だけ眠れる。",
                       Config::W / 2, 60, Palette::CYAN, 101, align: :center)

        draw_table
        draw_totals

        Px.text_shadow(Assets.small, "SPACE で眠りにつく", Config::W / 2, 210,
                       Palette.alpha(Palette::YELLOW, blinking_alpha), 101, align: :center)

        Hud.draw(state, elapsed)
        Hud.draw_drowsiness(state)
      end

      private

      def draw_table
        Px.rect(20, 76, Config::W - 40, 96, Palette.alpha(Palette::DUSK, 220), 101)
        Px.frame(20, 76, Config::W - 40, 96, Palette::VIOLET, 102)

        state.day_results.each_with_index do |result, i|
          x = 26 + (i % 2) * 142
          y = 82 + (i / 2) * 30
          Px.text_shadow(Assets.tiny, "#{i + 1}. #{LABELS.fetch(result.kind)}",
                         x, y, Palette::BONE, 103)
          Px.text_shadow(Assets.small, result.rank, x + 60, y - 3,
                         MinigameResult::RANK_COLORS.fetch(result.rank, Palette::WHITE),
                         103, align: :center)
          Px.text_shadow(Assets.tiny, "-#{result.reward.round}", x + 128, y,
                         Palette::GREEN, 103, align: :right)
          Px.text_shadow(Assets.tiny, "ミス +#{result.penalty.round}", x, y + 12,
                         result.penalty >= 1 ? Palette::RED : Palette::SLATE, 103)
        end
      end

      def draw_totals
        reduced = state.day_results.sum(&:reward)
        penalty = state.day_results.sum(&:penalty)
        start_v = state.day_start_gauge
        now = state.gauge.value
        delta = now - start_v

        Px.text_shadow(Assets.tiny, "今日削った合計", 26, 178, Palette::BONE, 101)
        Px.text_shadow(Assets.small, "-#{reduced.round}", 118, 176,
                       Palette::GREEN, 101, align: :right)

        Px.text_shadow(Assets.tiny, "ミスで増えた分", 132, 178, Palette::BONE, 101)
        Px.text_shadow(Assets.small, "+#{penalty.round}", 214, 176,
                       Palette::RED, 101, align: :right)

        sign = delta >= 0 ? "+" : ""
        Px.text_shadow(Assets.tiny, "朝からの増減", 226, 178, Palette::BONE, 101)
        Px.text_shadow(Assets.small, "#{sign}#{delta.round}", Config::W - 26, 176,
                       delta >= 0 ? Palette::RED : Palette::CYAN, 101, align: :right)
      end
    end
  end
end
