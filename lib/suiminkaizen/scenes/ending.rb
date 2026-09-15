# frozen_string_literal: true

module Suiminkaizen
  module Scenes
    # 7日間を気絶せずに走り切った。勝利。
    class Ending < Scene
      def initialize(window, state)
        super
        @camera = Camera.new
        @confetti = Array.new(48) do
          { x: rand * Config::W, y: -rand * Config::H,
            vy: 18.0 + rand * 42.0, vx: (rand - 0.5) * 16.0,
            color: [Palette::YELLOW, Palette::CYAN, Palette::PINK,
                    Palette::GREEN, Palette::WHITE].sample }
        end
      end

      def update(dt)
        super
        @camera.update(dt)
        @confetti.each do |c|
          c[:y] += c[:vy] * dt
          c[:x] += c[:vx] * dt + Math.sin(elapsed * 2.0 + c[:vy]) * 6.0 * dt
          next if c[:y] <= Config::H

          c[:y] = -4.0
          c[:x] = rand * Config::W
        end
      end

      def button_down(id)
        window.reset! if [Gosu::KB_R, Gosu::KB_SPACE, Gosu::KB_RETURN].include?(id)
      end

      def draw
        Stage.draw(@camera, :bedroom, elapsed)
        # 7日を走り切った峰小輔は、得意げな立ち絵で締める。
        sprite = Assets.portrait(:success)
        if sprite
          sprite.draw3d(@camera, 0.0, Stage::FLOOR_Y, 3.4, 1.35,
                        fog: Stage.fog(:bedroom))
        else
          Sprites::KOSUKE.draw3d(@camera, 0.0, Stage::FLOOR_Y, 3.2, 1.55,
                                 fog: Stage.fog(:bedroom))
        end
        draw_confetti

        Px.rect(0, 14, Config::W, 52, Palette.alpha(Palette::INK, 185), 100)
        Px.text_shadow(Assets.title, "生 存", Config::W / 2, 16,
                       Palette::YELLOW, 110, align: :center)
        Px.text_shadow(Assets.small, "7日間、峰小輔は一度も気絶しなかった。",
                       Config::W / 2, 50, Palette::WHITE, 110, align: :center)

        draw_stats
        draw_ranking

        Px.text_shadow(Assets.small, "R でもう一度はじめる", Config::W / 2, 216,
                       Palette.alpha(Palette::YELLOW, blinking_alpha), 110, align: :center)
      end

      private

      def draw_confetti
        @confetti.each do |c|
          Px.rect(c[:x], c[:y], 2, 3, c[:color], 90)
        end
      end

      def draw_stats
        results = state.all_results
        rows = [
          ["こなした種目", "#{results.size} 本"],
          ["削った睡眠ゲージ", "#{results.sum(&:reward).round}"],
          ["ミスで増えた眠気", "+#{results.sum(&:penalty).round}"],
          ["平均達成率", "#{(state.average_performance * 100).round} %"],
          ["最終の睡眠ゲージ", "#{state.gauge.to_i} / 1000"]
        ]

        Px.rect(12, 82, 122, 106, Palette.alpha(Palette::INK, 228), 110)
        Px.frame(12, 82, 122, 106, Palette::VIOLET, 111)
        rows.each_with_index do |(label, value), i|
          y = 89 + i * 19
          Px.text_shadow(Assets.tiny, label, 19, y, Palette::BONE, 112)
          Px.text_shadow(Assets.tiny, value, 127, y, Palette::WHITE, 112,
                         align: :right)
        end
      end

      def draw_ranking
        Px.rect(186, 82, 122, 106, Palette.alpha(Palette::INK, 228), 110)
        Px.frame(186, 82, 122, 106, Palette::VIOLET, 111)
        Px.text_shadow(Assets.tiny, "ランク内訳", 193, 88, Palette::BONE, 112)

        %w[S A B C D].each_with_index do |rank, i|
          y = 108 + i * 15
          color = MinigameResult::RANK_COLORS.fetch(rank)
          Px.text_shadow(Assets.tiny, rank, 195, y, color, 112)
          count = state.best_rank_count(rank)
          Px.rect(212, y + 3, [count * 4, 62].min, 4, color, 112)
          Px.text_shadow(Assets.tiny, count.to_s, 300, y, Palette::WHITE, 112,
                         align: :right)
        end
      end
    end
  end
end
