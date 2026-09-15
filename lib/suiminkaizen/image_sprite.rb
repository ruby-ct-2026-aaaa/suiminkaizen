# frozen_string_literal: true

module Suiminkaizen
  # 画像ファイルのスプライト（峰小輔の立ち絵）を、
  # PixelSprite と同じ感覚で疑似3D空間に置けるようにする薄い包み。
  #
  # 拡大は nearest-neighbor（retro: true）で読み込んでいるので、
  # ウィンドウを大きくしてもドット絵の質感が保たれる。
  class ImageSprite
    attr_reader :width, :height

    def self.load(path)
      return nil unless File.exist?(path)

      new(Gosu::Image.new(path, retro: true))
    rescue StandardError => e
      warn "スプライトを読み込めませんでした: #{path} (#{e.class})"
      nil
    end

    def initialize(image)
      @image  = image
      @width  = image.width
      @height = image.height
    end

    # cx: 中心X / by: 足元Y（いずれも論理座標）
    # ppu: 画像1ピクセルを何論理ドットで描くか
    def draw(cx, by, ppu, z = 0, color: nil)
      screen_scale = ppu * Viewport.scale
      return if screen_scale <= 0.0

      sw = @width * screen_scale
      sh = @height * screen_scale
      @image.draw(Viewport.screen_x(cx) - sw / 2.0,
                  Viewport.screen_y(by) - sh,
                  z, screen_scale, screen_scale, color || Palette::FULL)
    end

    # 画面上の高さ（論理ドット）を指定して描く。UI で使う。
    def draw_sized(cx, by, logical_height, z = 0, color: nil)
      draw(cx, by, logical_height.to_f / @height, z, color: color)
    end

    # 疑似3D空間へ置く。world_height は「世界座標で何単位の背丈か」。
    def draw3d(camera, wx, wy_bottom, wz, world_height, z: nil, fog: nil)
      sx, sy, scale = camera.project(wx, wy_bottom, wz)
      ppu = world_height * scale / @height
      return if ppu <= 0.001

      draw(sx, sy, ppu, z || Config.depth_z(wz), color: depth_color(wz, fog))
    end

    private

    # 画像は色を掛け算でしか染められないので、遠いものは暗く沈ませる。
    def depth_color(wz, fog)
      return nil unless fog

      t = (wz - Stage::NEAR_Z) / (Stage::FAR_Z - Stage::NEAR_Z)
      t = 0.0 if t.negative?
      t = 1.0 if t > 1.0
      level = (255 * (1.0 - t * 0.45)).round
      Gosu::Color.new(255, level, level, level)
    end
  end
end
