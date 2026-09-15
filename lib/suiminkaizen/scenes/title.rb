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
        Sprites::KOSUKE.draw3d(@camera, 0.0, Stage::FLOOR_Y, 5.0, 1.55,
                               fog: Stage.fog(:bedroom))
        draw_zzz

        Px.rect(0, 16, Config::W, 46, Palette.alpha(Palette::INK, 165), 100)
        Px.text_shadow(Assets.huge, "睡眠改善プロジェクト", Config::W / 2, 20,
                       Palette::WHITE, 101, align: :center)
        Px.text_shadow(Assets.small, "〜 ショートスリーパー峰小輔の一週間 〜",
                       Config::W / 2, 46, Palette::CYAN, 101, align: :center)

        Px.rect(0, 158, Config::W, 82, Palette.alpha(Palette::INK, 185), 100)
        Px.text_shadow(Assets.large, "SPACE ではじめる", Config::W / 2, 162,
                       Palette.alpha(Palette::YELLOW, blinking_alpha), 101, align: :center)

        [
          "睡眠ゲージが 1000 に達したら気絶＝ゲームオーバー。",
          "1日6本のミニゲーム（筋トレ／お風呂／サプリ）でゲージを削り、",
          "夜に 30分だけ眠って 30 回復。それを7日間しのげば勝ち。",
          "ESC ... ポーズ　　1日あたり およそ5分"
        ].each_with_index do |line, i|
          Px.text_shadow(Assets.tiny, line, Config::W / 2, 190 + i * 12,
                         i == 3 ? Palette::SLATE : Palette::BONE, 101, align: :center)
        end
      end

      private

      def draw_zzz
        3.times do |i|
          phase = elapsed * 0.8 + i * 0.6
          next if Math.sin(phase).negative?

          cycle = phase % 2.0
          alpha = (180 * (1.0 - cycle / 2.0)).round
          Px.text_shadow(Assets.small, "Z", 182 + i * 9, 116 - cycle * 18,
                         Palette.alpha(Palette::AQUA, alpha), 90)
        end
      end
    end
  end
end
