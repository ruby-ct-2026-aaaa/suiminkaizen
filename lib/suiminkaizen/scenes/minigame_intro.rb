# frozen_string_literal: true

module Suiminkaizen
  module Scenes
    # ミニゲーム直前の説明。ルールと操作を6秒かけて読ませる。
    #
    # ここで「やる」か「何もしない」かを選べる。
    # 何もしなければミスもしないが、削減もゼロのまま時間だけが過ぎる。
    # ただしヘッドマッサージ師の乱入だけは断れない。
    class MinigameIntro < Scene
      READ_TIME = 6.0 # 何も押さなければここで自動的に始まる
      MIN_READ  = 0.8 # ここまでは選択を受け付けない（誤操作よけ）

      SKIP_KEYS = [Gosu::KB_N, Gosu::KB_X].freeze

      def initialize(window, state, kind)
        super(window, state)
        @kind   = kind
        @klass  = Minigames.klass(kind)
        @camera = Camera.new
        @forced = kind == :massage
      end

      def update(dt)
        super
        @camera.update(dt)
        accumulate_idle(dt)
        start! if elapsed >= READ_TIME
      end

      def button_down(id)
        return if elapsed < MIN_READ

        if confirm?(id)
          start!
        elsif SKIP_KEYS.include?(id) && !@forced
          skip!
        end
      end

      def draw
        Stage.draw(@camera, @klass.theme, elapsed)
        Px.rect(0, 0, Config::W, Config::H, Palette.alpha(Palette::INK, 205), 100)

        draw_portrait
        draw_heading
        draw_rules
        draw_choice
        draw_countdown

        Hud.draw(state, elapsed)
        Hud.draw_drowsiness(state)
      end

      private

      def draw_portrait
        sprite = Assets.portrait(:normal)
        return unless sprite

        sprite.draw_sized(284, 190, 88, 101)
      end

      def draw_heading
        if @forced
          pulse = (Math.sin(elapsed * 8.0) + 1.0) * 0.5
          Px.text_shadow(Assets.small, "乱 入 ！", Config::W / 2, 38,
                         Palette.mix(Palette::RED, Palette::YELLOW, pulse), 101,
                         align: :center)
        else
          Px.text_shadow(Assets.tiny,
                         "#{state.slot + 1} / #{Config::GAMES_PER_DAY} 枠目",
                         Config::W / 2, 40, Palette::CYAN, 101, align: :center)
        end

        Px.text_shadow(Assets.huge, @klass.title, Config::W / 2, 52,
                       Palette::WHITE, 101, align: :center)
        Px.text_shadow(Assets.small, @klass.subtitle, Config::W / 2, 76,
                       Palette::BONE, 101, align: :center)
      end

      def draw_rules
        @klass.rules.each_with_index do |line, i|
          Px.text_shadow(Assets.tiny, line, 12, 96 + i * 13, Palette::BONE, 101)
        end

        y = 96 + @klass.rules.size * 13 + 4
        Px.rect(12, y - 3, 200, @klass.controls.size * 13 + 6,
                Palette.alpha(Palette::DUSK, 225), 101)
        @klass.controls.each_with_index do |line, i|
          Px.text_shadow(Assets.tiny, line, 18, y + i * 13, Palette::YELLOW, 102)
        end
      end

      def draw_choice
        if @forced
          Px.text_shadow(Assets.small, "断れない。覚悟を決めろ。", Config::W / 2, 196,
                         Palette.alpha(Palette::RED, blinking_alpha), 102, align: :center)
          return
        end

        Px.text_shadow(Assets.small, "SPACE ではじめる", Config::W / 2, 190,
                       Palette.alpha(Palette::YELLOW, blinking_alpha), 102,
                       align: :center)
        Px.text_shadow(Assets.tiny, "N ... 何もしない", 120, 210,
                       Palette::SLATE, 102, align: :center)
        Px.text_shadow(Assets.tiny, "ミスはしないが、削減もゼロ", 120, 222,
                       Palette::SLATE, 102, align: :center)
      end

      def draw_countdown
        remain = READ_TIME - elapsed
        count  = remain.ceil
        return if count <= 0

        Px.text_shadow(Assets.small, count.to_s, 14, 196,
                       Palette.alpha(Palette::WHITE, 190), 102)
      end

      def start!
        return if @moved

        @moved = true
        goto(Minigames.build(@kind, window, state))
      end

      def skip!
        return if @moved

        @moved = true
        goto(MinigameResult.new(window, state, state.record_skip(@kind)))
      end
    end
  end
end
