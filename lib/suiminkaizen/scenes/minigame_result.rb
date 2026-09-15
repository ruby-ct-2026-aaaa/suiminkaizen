# frozen_string_literal: true

module Suiminkaizen
  module Scenes
    # ミニゲーム1本ぶんの結果。削れた睡眠ゲージを見せる。
    class MinigameResult < Scene
      AUTO_NEXT = 5.0
      MIN_SHOW  = 1.4

      RANK_COLORS = {
        "S" => Palette::YELLOW, "A" => Palette::CYAN, "B" => Palette::GREEN,
        "C" => Palette::ORANGE, "D" => Palette::RED
      }.freeze

      RANK_WORDS = {
        "S" => "完璧だ。眠気が吹き飛んだ。",
        "A" => "いい動きだった。",
        "B" => "まずまず。だが物足りない。",
        "C" => "身が入っていない。",
        "D" => "これでは眠気に勝てない。"
      }.freeze

      def initialize(window, state, result)
        super(window, state)
        @result = result
        @camera = Camera.new
      end

      def enter
        state.advance_slot!
      end

      def update(dt)
        super
        @camera.update(dt)
        accumulate_idle(dt)
        continue! if elapsed >= AUTO_NEXT
      end

      def button_down(id)
        continue! if confirm?(id) && elapsed >= MIN_SHOW
      end

      def draw
        Stage.draw(@camera, Minigames.klass(@result.kind).theme, elapsed)
        Px.rect(0, 0, Config::W, Config::H, Palette.alpha(Palette::INK, 190), 100)

        Px.rect(22, 44, Config::W - 44, 150, Palette.alpha(Palette::DUSK, 225), 101)
        Px.frame(22, 44, Config::W - 44, 150, Palette::VIOLET, 102)

        Px.text_shadow(Assets.small, @result.title, 36, 52, Palette::BONE, 103)

        rank_color = RANK_COLORS.fetch(@result.rank, Palette::WHITE)
        pop = [1.0 + (0.5 - elapsed) * 1.4, 1.0].max
        Px.text_shadow(Assets.title, @result.rank, 62, 66, rank_color, 103,
                       align: :center, scale: pop)
        Px.text_shadow(Assets.tiny, RANK_WORDS.fetch(@result.rank, ""), 62, 116,
                       Palette::BONE, 103, align: :center)

        draw_numbers(rank_color)

        Px.text_shadow(Assets.small, next_label, Config::W / 2, 206,
                       Palette.alpha(Palette::YELLOW, blinking_alpha), 103,
                       align: :center)

        Hud.draw(state, elapsed)
        Hud.draw_drowsiness(state)
      end

      private

      # 数字はゆっくり伸ばしたほうが「削った」実感が出る。
      def reveal
        [elapsed / 0.9, 1.0].min
      end

      def draw_numbers(rank_color)
        x = 118
        Px.text_shadow(Assets.tiny, "達成率", x, 60, Palette::BONE, 103)
        Px.text_shadow(Assets.large,
                       "#{(@result.performance * 100 * reveal).round} %",
                       x + 62, 54, rank_color, 103, align: :right)

        Px.text_shadow(Assets.tiny, "睡眠ゲージ削減", x, 84, Palette::BONE, 103)
        Px.text_shadow(Assets.huge, "-#{(@result.reward * reveal).round}",
                       x + 108, 76, Palette::GREEN, 103, align: :right)

        rows = [
          ["到達レベル", "Lv.#{@result.level}"],
          ["最大コンボ", "#{@result.max_combo}"],
          ["ミスで増えた眠気", "+#{@result.penalty.round}"]
        ]
        rows.each_with_index do |(label, value), i|
          y = 112 + i * 14
          Px.text_shadow(Assets.tiny, label, x, y, Palette::BONE, 103)
          tone = i == 2 && @result.penalty >= 1 ? Palette::RED : Palette::WHITE
          Px.text_shadow(Assets.tiny, value, x + 160, y, tone, 103, align: :right)
        end

        Px.rect(x, 158, 160, 1, Palette::SLATE, 103)
        Px.text_shadow(Assets.tiny, "現在の睡眠ゲージ", x, 164, Palette::BONE, 103)
        Px.text_shadow(Assets.small, "#{state.gauge.to_i} / 1000", x + 160, 162,
                       Palette.gauge_color(state.gauge.ratio), 103, align: :right)
      end

      def next_label
        state.day_finished? ? "SPACE で1日を終える" : "SPACE でつぎの種目へ"
      end

      def continue!
        return if @moved

        @moved = true
        if state.day_finished?
          goto(DayResult.new(window, state))
        else
          goto(MinigameIntro.new(window, state, state.current_kind))
        end
      end
    end
  end
end
