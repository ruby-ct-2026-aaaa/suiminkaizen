# frozen_string_literal: true

module Suiminkaizen
  module Scenes
    # 枠のはじまりに出る選択画面。
    #
    # 3つの選択肢（筋トレ／お風呂／サプリメント）が並び、左右キーで選ぶ。
    # 選んでいる種目のルールがその場に出るので、説明もここで読む。
    # 「何もしない」を選べばミスもしないが、削減もゼロのまま時間だけが過ぎる。
    # ただしヘッドマッサージ師の乱入だけは断れないし、選ぶこともできない。
    class MinigameIntro < Scene
      READ_TIME = 10.0 # ここまで迷えるが、超えたらランダムで強制的に始まる
      MIN_READ  = 0.0  # 切り替わった瞬間の SPACE から受け付ける

      SKIP_KEYS = [Gosu::KB_N, Gosu::KB_X].freeze
      LEFT_KEYS  = [Gosu::KB_LEFT,  Gosu::KB_A].freeze
      RIGHT_KEYS = [Gosu::KB_RIGHT, Gosu::KB_D].freeze

      CARD_W = 96
      CARD_H = 46
      CARD_Y = 42

      ACCENT = { muscle: Palette::RED, bath: Palette::CYAN,
                 supplement: Palette::BLUE }.freeze

      def initialize(window, state, kind)
        super(window, state)
        @forced  = kind == :massage
        @choices = @forced ? [:massage] : Minigames::BASE_KINDS.dup
        # 種目を名指しで渡されたらそれを選んだ状態から始める（:choice なら適当に）。
        @index   = @choices.index(kind) || rand(@choices.size)
        @camera  = Camera.new
      end

      # いま選んでいる種目。
      def kind = @choices[@index]

      def klass = Minigames.klass(kind)

      # 時計が止まっている画面なので、睡眠ゲージも進めない。
      # （accumulate_idle を呼ばない ＝ ここでは眠くならない）
      def update(dt)
        super
        @camera.update(dt)
        force_start! if elapsed >= READ_TIME
      end

      def button_down(id)
        unless @forced
          return move(-1) if LEFT_KEYS.include?(id)
          return move(1)  if RIGHT_KEYS.include?(id)
        end

        if confirm?(id)
          start!
        elsif SKIP_KEYS.include?(id) && !@forced
          skip!
        end
      end

      def draw
        Stage.draw(@camera, klass.theme, elapsed)
        Px.rect(0, 0, Config::W, Config::H, Palette.alpha(Palette::INK, 205), 100)

        if @forced
          draw_forced_heading
        else
          draw_slot_heading
          draw_cards
        end

        draw_rules
        draw_choice
        draw_countdown

        Hud.draw(state, elapsed)
        Hud.draw_drowsiness(state)
      end

      private

      def move(step)
        size = @choices.size
        @index = (@index + step) % size
        Sound.play(:select)
      end

      def draw_slot_heading
        Px.text_shadow(Assets.tiny,
                       "#{state.slot + 1} / #{Config::GAMES_PER_DAY} 枠目　何をする？",
                       Config::W / 2, 34, Palette::CYAN, 101, align: :center)
      end

      def draw_forced_heading
        pulse = (Math.sin(elapsed * 8.0) + 1.0) * 0.5
        Px.text_shadow(Assets.small, "乱 入 ！", Config::W / 2, 36,
                       Palette.mix(Palette::RED, Palette::YELLOW, pulse), 101,
                       align: :center)
        Px.text_shadow(Assets.huge, klass.title, Config::W / 2, 50,
                       Palette::WHITE, 101, align: :center)
        Px.text_shadow(Assets.small, klass.subtitle, Config::W / 2, 74,
                       Palette::BONE, 101, align: :center)
      end

      # 3つの選択肢を横に並べる。選んでいるものだけ枠が光る。
      def draw_cards
        gap = (Config::W - CARD_W * 3) / 4
        @choices.each_with_index do |choice, i|
          x = gap + i * (CARD_W + gap)
          selected = i == @index
          accent = ACCENT.fetch(choice)
          klass = Minigames.klass(choice)

          body = selected ? Palette.alpha(Palette::DUSK, 250) : Palette.alpha(Palette::INK, 220)
          Px.rect(x, CARD_Y, CARD_W, CARD_H, body, 101)
          Px.rect(x, CARD_Y, CARD_W, 3, accent, 102)

          if selected
            Px.frame(x - 2, CARD_Y - 2, CARD_W + 4, CARD_H + 4,
                     Palette.alpha(Palette::YELLOW, blinking_alpha(6.0)), 103, 2)
          end

          Px.text_shadow(Assets.small, klass.title, x + CARD_W / 2, CARD_Y + 9,
                         selected ? Palette::WHITE : Palette::GRAY, 104, align: :center)
          Px.text_shadow(Assets.tiny, klass.subtitle, x + CARD_W / 2, CARD_Y + 26,
                         selected ? Palette::BONE : Palette::SLATE, 104, align: :center)
          Px.text_shadow(Assets.tiny, "#{i + 1}", x + 5, CARD_Y + 6,
                         selected ? accent : Palette::SLATE, 104)
        end

        Px.text_shadow(Assets.tiny, "← →  で選ぶ", Config::W / 2, CARD_Y + CARD_H + 5,
                       Palette::SLATE, 104, align: :center)
      end

      def draw_rules
        top = @forced ? 96 : CARD_Y + CARD_H + 19
        klass.rules.each_with_index do |line, i|
          Px.text_shadow(Assets.tiny, line, 12, top + i * 11, Palette::BONE, 101)
        end

        y = top + klass.rules.size * 11 + 3
        Px.rect(12, y - 3, 214, klass.controls.size * 11 + 6,
                Palette.alpha(Palette::DUSK, 225), 101)
        klass.controls.each_with_index do |line, i|
          Px.text_shadow(Assets.tiny, line, 18, y + i * 11, Palette::YELLOW, 102)
        end
      end

      def draw_choice
        if @forced
          Px.text_shadow(Assets.small, "断れない。覚悟を決めろ。", Config::W / 2, 200,
                         Palette.alpha(Palette::RED, blinking_alpha), 102, align: :center)
          return
        end

        Px.text_shadow(Assets.small, "SPACE ではじめる", Config::W / 2, 208,
                       Palette.alpha(Palette::YELLOW, blinking_alpha), 102,
                       align: :center)
        Px.text_shadow(Assets.tiny,
                       "N ... 何もしない　　迷っていると10秒でランダムに決まる",
                       Config::W / 2, 228, Palette::SLATE, 102, align: :center)
      end

      def draw_countdown
        remain = READ_TIME - elapsed
        count  = remain.ceil
        return if count <= 0

        Px.text_shadow(Assets.small, count.to_s, 14, 206,
                       Palette.alpha(Palette::WHITE, 190), 102)
      end

      # 時間切れ。選びそこねたぶん、種目はこちらで勝手に決める。
      def force_start!
        return if @moved

        @index = rand(@choices.size) unless @forced
        start!
      end

      def start!
        return if @moved

        @moved = true
        Sound.play(:decide)
        goto(Minigames.build(kind, window, state))
      end

      def skip!
        return if @moved

        @moved = true
        Sound.play(:decide)
        goto(MinigameResult.new(window, state, state.record_skip(kind)))
      end
    end
  end
end
