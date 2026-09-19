# frozen_string_literal: true

module Suiminkaizen
  # Gosu のウィンドウ。シーンの切り替え、ポーズ、画面サイズの面倒をみる。
  #
  # ウィンドウは自由に伸縮でき、F11（または Alt+Enter）で全画面になる。
  # 絵の縦横比は 4:3 に保ち、あまったぶんは黒帯にする。
  class Window < Gosu::Window
    MAX_DT = 0.05 # 処理落ちしても一気に時間を進めない

    attr_reader :state, :scene

    def initialize
      width, height = default_size
      begin
        super(width, height, resizable: true)
      rescue ArgumentError, TypeError
        # 古い Gosu では伸縮できないので、固定サイズで開く
        super(width, height)
      end

      self.caption = Config::CAPTION
      @paused  = false
      @last_ms = Gosu.milliseconds
      Viewport.fit!(self.width, self.height)
      Sound.play_bgm # メインBGM。ここから最後までループで流しつづける
      reset!
    end

    # 画面の 8 割におさまる 4:3 を既定の大きさにする。
    def default_size
      screen_w = Gosu.screen_width
      screen_h = Gosu.screen_height
      scale = [screen_w * 0.85 / Config::W, screen_h * 0.80 / Config::H].min
      scale = 2.0 if scale < 2.0
      [(Config::W * scale).round, (Config::H * scale).round]
    rescue StandardError
      [Config::W * Config::REFERENCE_SCALE, Config::H * Config::REFERENCE_SCALE]
    end

    def reset!
      @state      = GameState.new
      @next_scene = nil
      @scene      = Scenes::Title.new(self, @state)
      @scene.enter
    end

    # 難易度が決まったところで、その設定を持った状態を作り直して始める。
    def begin_game!(difficulty)
      @state = GameState.new(difficulty)
      goto(Scenes::DayIntro.new(self, @state))
    end

    def goto(scene)
      @next_scene = scene
    end

    def update
      Sound.update # 台詞が終わったら BGM の音量を戻す
      Viewport.fit!(width, height)

      now = Gosu.milliseconds
      dt  = (now - @last_ms) / 1000.0
      @last_ms = now
      dt = MAX_DT if dt > MAX_DT
      dt = 0.0 if dt.negative?

      return if @paused

      if @next_scene
        @scene = @next_scene
        @next_scene = nil
        @scene.enter
      end

      @state.update_effects(dt)
      @scene.update(dt)
    end

    def draw
      @scene.draw
      draw_letterbox
      draw_pause if @paused
    end

    def button_down(id)
      case id
      when Gosu::KB_F11
        toggle_fullscreen
        return
      when Gosu::KB_RETURN, Gosu::KB_ENTER
        if Gosu.button_down?(Gosu::KB_LEFT_ALT) || Gosu.button_down?(Gosu::KB_RIGHT_ALT)
          toggle_fullscreen
          return
        end
      when Gosu::KB_ESCAPE
        @paused = !@paused
        return
      end

      if @paused
        case id
        when Gosu::KB_T
          @paused = false
          reset!
        when Gosu::KB_Q
          close
        end
        return
      end

      @scene.button_down(id)
    end

    def needs_cursor?
      false
    end

    private

    def toggle_fullscreen
      self.fullscreen = !fullscreen?
    rescue StandardError
      nil
    end

    # 4:3 に収まらなかった余白を塗りつぶす。
    def draw_letterbox
      Viewport.letterbox_bars.each do |(x, y, w, h)|
        Gosu.draw_rect(x, y, w, h, Palette::INK, 400)
      end
    end

    def draw_pause
      Px.rect(0, 0, Config::W, Config::H, Palette.alpha(Palette::INK, 200), 300)
      Px.text_shadow(Assets.large, "P A U S E", Config::W / 2, 74,
                     Palette::WHITE, 301, align: :center)
      [
        "ESC   ゲームへ戻る",
        "F11   全画面の切り替え（Alt+Enter でも可）",
        "T     タイトルへ戻る（最初からやり直し）",
        "Q     ゲームを終了する",
        "",
        "ウィンドウの端をドラッグすれば好きな大きさにできます"
      ].each_with_index do |line, i|
        Px.text_shadow(Assets.tiny, line, Config::W / 2, 114 + i * 16,
                       i == 5 ? Palette::SLATE : Palette::BONE, 301, align: :center)
      end
    end
  end
end
