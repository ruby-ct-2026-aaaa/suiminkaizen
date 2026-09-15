# frozen_string_literal: true

module Suiminkaizen
  module Scenes
    class Title < Scene
      def initialize(window, state)
        super
        @camera = Camera.new
      end

      def update(dt)
        super
        @camera.update(dt)
      end

      def button_down(id)
        goto(DayIntro.new(window, state)) if confirm?(id)
      end

      def draw
        Stage.draw(@camera, :bedroom, elapsed)
        draw_kosuke
        draw_zzz

        Px.rect(0, 14, Config::W, 48, Palette.alpha(Palette::INK, 175), 100)
        Px.text_shadow(Assets.huge, "睡眠改善プロジェクト", Config::W / 2, 18,
                       Palette::WHITE, 101, align: :center)
        Px.text_shadow(Assets.small, "〜 ショートスリーパー峰小輔の一週間 〜",
                       Config::W / 2, 44, Palette::CYAN, 101, align: :center)

        Px.rect(0, 150, Config::W, 90, Palette.alpha(Palette::INK, 190), 100)
        Px.text_shadow(Assets.large, "SPACE ではじめる", Config::W / 2, 154,
                       Palette.alpha(Palette::YELLOW, blinking_alpha), 101, align: :center)

        [
          "睡眠ゲージが 1000 に達したら気絶＝ゲームオーバー。",
          "1日6枠。筋トレ／お風呂／サプリでゲージを削り、夜に30分眠って30回復。",
          "各枠は「やる／何もしない」を選べるが、ヘッドマッサージ師の乱入は断れない。",
          "7日間しのげば勝ち。1日およそ3分。",
          "ESC ポーズ　　F11 全画面　　ウィンドウは自由に伸縮できます"
        ].each_with_index do |line, i|
          Px.text_shadow(Assets.tiny, line, Config::W / 2, 180 + i * 12,
                         i == 4 ? Palette::SLATE : Palette::BONE, 101, align: :center)
        end
      end

      private

      def draw_kosuke
        sprite = Assets.portrait(:normal)
        if sprite
          sprite.draw3d(@camera, 0.0, Stage::FLOOR_Y, 5.0, 1.6,
                        fog: Stage.fog(:bedroom))
        else
          Sprites::KOSUKE.draw3d(@camera, 0.0, Stage::FLOOR_Y, 5.0, 1.55,
                                 fog: Stage.fog(:bedroom))
        end
      end

      def draw_zzz
        3.times do |i|
          phase = elapsed * 0.8 + i * 0.6
          next if Math.sin(phase).negative?

          cycle = phase % 2.0
          alpha = (180 * (1.0 - cycle / 2.0)).round
          Px.text_shadow(Assets.small, "Z", 196 + i * 9, 112 - cycle * 18,
                         Palette.alpha(Palette::AQUA, alpha), 90)
        end
      end
    end
  end
end
