# frozen_string_literal: true

module Suiminkaizen
  module Scenes
    # 1日の締め。4枠ぶんの結果を並べ、これから眠れることを告げる。
    class DayResult < Scene
      AUTO_NEXT = 3.0
      MIN_SHOW  = 2.6

      LABELS = { muscle: "筋トレ", bath: "お風呂", supplement: "サプリ",
                 massage: "マッサージ" }.freeze

      def initialize(window, state)
        super
        @camera = Camera.new
      end

      def update(dt)
        super
        @camera.update(dt)
        accumulate_idle(dt)
        sleep! if elapsed >= AUTO_NEXT
      end

      def button_down(id)
        sleep! if confirm?(id) && elapsed >= MIN_SHOW
      end

      def draw
        Stage.draw(@camera, :bedroom, elapsed)
        Px.rect(0, 0, Config::W, Config::H, Palette.alpha(Palette::INK, 198), 100)

        Px.text_shadow(Assets.large, "DAY #{state.day} 終了", Config::W / 2, 38,
                       Palette::WHITE, 101, align: :center)
        Px.text_shadow(Assets.tiny, "気絶せずに1日を乗り切った。30分だけ眠れる。",
                       Config::W / 2, 60, Palette::CYAN, 101, align: :center)

        draw_table
        draw_totals

        Px.text_shadow(Assets.small, "SPACE で眠りにつく", Config::W / 2, 214,
                       Palette.alpha(Palette::YELLOW, blinking_alpha), 101,
                       align: :center)

        Hud.draw(state, elapsed)
        Hud.draw_drowsiness(state)
      end

      private

      def sleep!
        return if @moved

        @moved = true
        goto(Sleep.new(window, state))
      end

      def draw_table
        Px.rect(16, 76, Config::W - 32, 96, Palette.alpha(Palette::DUSK, 225), 101)
        Px.frame(16, 76, Config::W - 32, 96, Palette::VIOLET, 102)

        state.day_results.each_with_index do |result, i|
          x = 22 + (i % 2) * 144
          y = 82 + (i / 2) * 30
          label = "#{i + 1}. #{LABELS.fetch(result.kind, '？')}"
          Px.text_shadow(Assets.tiny, label, x, y, Palette::BONE, 103)
          Px.text_shadow(Assets.small, result.rank, x + 74, y - 3,
                         MinigameResult::RANK_COLORS.fetch(result.rank, Palette::WHITE),
                         103, align: :center)

          if result.skipped
            Px.text_shadow(Assets.tiny, "見送り", x + 132, y, Palette::SLATE, 103,
                           align: :right)
          else
            Px.text_shadow(Assets.tiny, "-#{result.reward.round}", x + 132, y,
                           Palette::GREEN, 103, align: :right)
            Px.text_shadow(Assets.tiny, "ミス +#{result.penalty.round}", x, y + 12,
                           result.penalty >= 1 ? Palette::RED : Palette::SLATE, 103)
          end
        end
      end

      def draw_totals
        reduced = state.day_results.sum(&:reward)
        penalty = state.day_results.sum(&:penalty)
        skipped = state.day_results.count(&:skipped)
        delta   = state.gauge.value - state.day_start_gauge

        Px.text_shadow(Assets.tiny, "今日削った合計", 22, 180, Palette::BONE, 101)
        Px.text_shadow(Assets.small, "-#{reduced.round}", 110, 178,
                       Palette::GREEN, 101, align: :right)

        Px.text_shadow(Assets.tiny, "ミスで増えた分", 124, 180, Palette::BONE, 101)
        Px.text_shadow(Assets.small, "+#{penalty.round}", 206, 178,
                       Palette::RED, 101, align: :right)

        sign = delta >= 0 ? "+" : ""
        Px.text_shadow(Assets.tiny, "朝からの増減", 218, 180, Palette::BONE, 101)
        Px.text_shadow(Assets.small, "#{sign}#{delta.round}", Config::W - 22, 178,
                       delta >= 0 ? Palette::RED : Palette::CYAN, 101, align: :right)

        return if skipped.zero?

        Px.text_shadow(Assets.tiny, "見送った枠 #{skipped}", 22, 196,
                       Palette::SLATE, 101)
      end
    end
  end
end
