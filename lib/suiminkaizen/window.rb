# frozen_string_literal: true

module Suiminkaizen
  # Gosu のウィンドウ。シーンの切り替えとポーズだけを面倒みる。
  class Window < Gosu::Window
    MAX_DT = 0.05 # 処理落ちしても一気に時間を進めない

    attr_reader :state, :scene

    def initialize
      super(Config::SCREEN_W, Config::SCREEN_H)
      self.caption = Config::CAPTION
      @paused  = false
      @last_ms = Gosu.milliseconds
      reset!
    end

    def reset!
      @state      = GameState.new
      @next_scene = nil
      @scene      = Scenes::Title.new(self, @state)
      @scene.enter
    end

    def goto(scene)
      @next_scene = scene
    end

    def update
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
      draw_pause if @paused
    end

    def button_down(id)
      if id == Gosu::KB_ESCAPE
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

    def draw_pause
      Px.rect(0, 0, Config::W, Config::H, Palette.alpha(Palette::INK, 200), 300)
      Px.text_shadow(Assets.large, "P A U S E", Config::W / 2, 86,
                     Palette::WHITE, 301, align: :center)
      [
        "ESC   ゲームへ戻る",
        "T     タイトルへ戻る（最初からやり直し）",
        "Q     ゲームを終了する"
      ].each_with_index do |line, i|
        Px.text_shadow(Assets.small, line, Config::W / 2, 126 + i * 16,
                       Palette::BONE, 301, align: :center)
      end
    end
  end
end
