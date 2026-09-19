# frozen_string_literal: true

module Suiminkaizen
  # 画面（タイトル／1日の導入／ミニゲーム／リザルト…）の共通の土台。
  class Scene
    attr_reader :window, :state, :elapsed

    def initialize(window, state)
      @window  = window
      @state   = state
      @elapsed = 0.0
    end

    # シーンが実際に前面へ出た瞬間に一度だけ呼ばれる。
    def enter; end

    def update(dt)
      @elapsed += dt
    end

    def draw; end

    def button_down(_id); end

    def goto(scene)
      window.goto(scene)
    end

    # ミニゲームの合間も、峰小輔は少しずつ眠くなっていく。
    # ここで気絶したら即ゲームオーバー。
    def accumulate_idle(dt)
      state.gauge.add(state.idle_rate * dt)
      goto(Scenes::GameOver.new(window, state)) if state.gauge.fainted?
    end

    # 「SPACE でつぎへ」のような決定キー。
    def confirm?(id)
      [Gosu::KB_SPACE, Gosu::KB_RETURN, Gosu::KB_ENTER].include?(id)
    end

    # ゆっくり点滅させる案内表示。
    def blinking_alpha(speed = 4.0, floor = 70)
      floor + ((Math.sin(@elapsed * speed) + 1.0) * 0.5 * (255 - floor)).round
    end
  end
end
