# frozen_string_literal: true

module Suiminkaizen
  module Scenes
    # ミニゲーム直前の説明。ルールと操作を読ませてからカウントダウンに入る。
    class MinigameIntro < Scene
      READ_TIME = 4.2  # 自動で始まるまで
      MIN_READ  = 2.2  # ここまではスキップさせない（ルールを読む時間）

      def initialize(window, state, kind)
        super(window, state)
        @kind   = kind
        @klass  = Minigames.klass(kind)
        @camera = Camera.new
        @skipped = false
      end

      def update(dt)
        super
        @camera.update(dt)
        accumulate_idle(dt)
        start! if elapsed >= READ_TIME
      end

      def button_down(id)
        return unless confirm?(id) && elapsed >= MIN_READ

        @skipped = true
        start!
      end

      def draw
        Stage.draw(@camera, @klass.theme, elapsed)
        Px.rect(0, 0, Config::W, Config::H, Palette.alpha(Palette::INK, 170), 100)

        Px.text_shadow(Assets.tiny,
                       "#{state.slot + 1} / #{Config::GAMES_PER_DAY} 本目",
                       Config::W / 2, 44, Palette::CYAN, 101, align: :center)
        Px.text_shadow(Assets.huge, @klass.title, Config::W / 2, 56,
                       Palette::WHITE, 101, align: :center)
        Px.text_shadow(Assets.small, @klass.subtitle, Config::W / 2, 82,
                       Palette::BONE, 101, align: :center)

        @klass.rules.each_with_index do |line, i|
          Px.text_shadow(Assets.tiny, line, Config::W / 2, 104 + i * 13,
                         Palette::BONE, 101, align: :center)
        end

        y = 104 + @klass.rules.size * 13 + 10
        Px.rect(60, y - 4, Config::W - 120, @klass.controls.size * 13 + 8,
                Palette.alpha(Palette::DUSK, 220), 101)
        @klass.controls.each_with_index do |line, i|
          Px.text_shadow(Assets.tiny, line, Config::W / 2, y + i * 13,
                         Palette::YELLOW, 102, align: :center)
        end

        draw_countdown

        Hud.draw(state, elapsed)
        Hud.draw_drowsiness(state)
      end

      private

      def start!
        return if @started

        @started = true
        goto(Minigames.build(@kind, window, state))
      end

      def draw_countdown
        remain = READ_TIME - elapsed
        count  = remain.ceil
        return if count <= 0

        scale = 1.0 + (count - remain) * 0.6
        Px.text_shadow(Assets.huge, count.to_s, Config::W / 2, 196,
                       Palette.alpha(Palette::WHITE, 200), 102,
                       align: :center, scale: scale)
        return if elapsed < MIN_READ

        Px.text_shadow(Assets.tiny, "SPACE でスキップ", Config::W / 2, 226,
                       Palette::SLATE, 102, align: :center)
      end
    end
  end
end
