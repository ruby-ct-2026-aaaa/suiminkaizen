# frozen_string_literal: true

module Suiminkaizen
  module Scenes
    # 睡眠ゲージが 1000 に達した瞬間。峰小輔は気絶する。
    class GameOver < Scene
      def initialize(window, state)
        super
        @camera = Camera.new
      end

      def update(dt)
        super
        @camera.update(dt)
      end

      def button_down(id)
        case id
        when Gosu::KB_R, Gosu::KB_SPACE, Gosu::KB_RETURN, Gosu::KB_T
          window.reset!
        end
      end

      def draw
        Stage.draw(@camera, :bedroom, elapsed)
        # 倒れた峰小輔には、ミニゲームで沈んだときと同じ立ち絵を使う。
        sprite = Assets.portrait(:fail)
        if sprite
          sprite.draw3d(@camera, 1.5, Stage::FLOOR_Y, 3.0, 1.0,
                        fog: Stage.fog(:bedroom))
        else
          Sprites::KOSUKE_FAINT.draw3d(@camera, 1.7, Stage::FLOOR_Y, 2.9, 1.1,
                                       fog: Stage.fog(:bedroom))
        end

        Px.rect(0, 0, Config::W, Config::H, Palette.alpha(Palette::CRIMSON, 90), 100)
        Px.rect(0, 0, Config::W, Config::H,
                Palette.alpha(Palette::INK, [(elapsed * 120).round, 150].min), 101)

        Px.text_shadow(Assets.title, "気 絶", Config::W / 2, 30,
                       Palette::RED, 110, align: :center)
        Px.text_shadow(Assets.small, "睡眠ゲージが 1000 に達した。",
                       Config::W / 2, 84, Palette::WHITE, 110, align: :center)
        Px.text_shadow(Assets.tiny, "峰小輔は強制的に眠らされた。",
                       Config::W / 2, 100, Palette::BONE, 110, align: :center)

        draw_stats
        return if elapsed < 1.0

        Px.text_shadow(Assets.small, "R でもう一度はじめる",
                       Config::W / 2, 212,
                       Palette.alpha(Palette::YELLOW, blinking_alpha), 110, align: :center)
      end

      private

      def draw_stats
        results = state.all_results
        rows = [
          ["倒れた日", "DAY #{state.day} / #{Config::TOTAL_DAYS}"],
          ["こなした種目", "#{results.size} 本"],
          ["削った睡眠ゲージ", "#{results.sum(&:reward).round}"],
          ["ミスで増えた眠気", "+#{results.sum(&:penalty).round}"],
          ["平均達成率", "#{(state.average_performance * 100).round} %"]
        ]

        Px.rect(20, 112, 158, 90, Palette.alpha(Palette::INK, 225), 110)
        Px.frame(20, 112, 158, 90, Palette::CRIMSON, 111)
        rows.each_with_index do |(label, value), i|
          y = 119 + i * 16
          Px.text_shadow(Assets.tiny, label, 28, y, Palette::BONE, 112)
          Px.text_shadow(Assets.tiny, value, 170, y, Palette::WHITE, 112, align: :right)
        end
      end
    end
  end
end
