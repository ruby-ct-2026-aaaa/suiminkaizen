# frozen_string_literal: true

module Suiminkaizen
  # 疑似3D用の、ごく単純な1点透視カメラ。
  #
  # 世界座標は x:右が正 / y:下が正 / z:奥が正。カメラは原点にあり +z を向く。
  # 投影は screen = center + world / z * focal だけ。
  # この「距離で割る」一行が、ドット絵に奥行きを与える全部である。
  class Camera
    attr_accessor :focal, :cx, :cy

    def initialize(cx: Config::W / 2.0, cy: Config::H * 0.44, focal: 150.0)
      @cx = cx
      @cy = cy
      @focal = focal
      @shake = 0.0
      @phase = 0.0
    end

    def update(dt)
      @shake -= dt * 2.6
      @shake = 0.0 if @shake.negative?
      @phase += dt * 47.0
    end

    # ミスしたときなどに画面を揺らす。
    def kick(amount)
      @shake = [@shake + amount, 1.0].min
    end

    def shaking? = @shake.positive?

    # [screen_x, screen_y, scale] を返す。scale は世界1単位あたりの画面ドット数。
    def project(x, y, z)
      z = 0.2 if z < 0.2
      scale = @focal / z
      [@cx + x * scale + shake_x, @cy + y * scale + shake_y, scale]
    end

    def scale_at(z)
      z = 0.2 if z < 0.2
      @focal / z
    end

    private

    def shake_x = Math.sin(@phase) * @shake * 3.0
    def shake_y = Math.cos(@phase * 1.7) * @shake * 2.0
  end
end
