# frozen_string_literal: true

module Suiminkaizen
  # ドット絵らしさを出すため、使う色をあらかじめ絞り込んだパレット。
  module Palette
    module_function

    def rgb(hex, alpha = 255)
      Gosu::Color.new(alpha, (hex >> 16) & 0xff, (hex >> 8) & 0xff, hex & 0xff)
    end

    # 2色を t(0..1) で混ぜる。奥行きフォグやゲージの色変化に使う。
    def mix(color_a, color_b, t)
      t = 0.0 if t < 0.0
      t = 1.0 if t > 1.0
      Gosu::Color.new(
        (color_a.alpha + (color_b.alpha - color_a.alpha) * t).round,
        (color_a.red   + (color_b.red   - color_a.red)   * t).round,
        (color_a.green + (color_b.green - color_a.green) * t).round,
        (color_a.blue  + (color_b.blue  - color_a.blue)  * t).round
      )
    end

    # 明度だけを掛ける（影・ハイライト用）。
    def shade(color, factor)
      clamp = ->(v) { v < 0 ? 0 : (v > 255 ? 255 : v.round) }
      Gosu::Color.new(color.alpha,
                      clamp.call(color.red * factor),
                      clamp.call(color.green * factor),
                      clamp.call(color.blue * factor))
    end

    def alpha(color, a)
      Gosu::Color.new(a.round, color.red, color.green, color.blue)
    end

    INK        = rgb(0x0b0a14)
    SHADOW     = rgb(0x171430)
    NIGHT      = rgb(0x1d1a3d)
    DUSK       = rgb(0x2e2757)
    VIOLET     = rgb(0x4b3d82)
    LILAC      = rgb(0x7a6ab5)

    WHITE      = rgb(0xf7f4e8)
    BONE       = rgb(0xd9d3c0)
    GRAY       = rgb(0x8d8ea6)
    SLATE      = rgb(0x5a5b78)
    STEEL      = rgb(0xa8b3c6)

    SKIN       = rgb(0xf3c9a2)
    SKIN_DARK  = rgb(0xc98f66)
    HAIR       = rgb(0x2b2440)
    HAIR_HI    = rgb(0x463c6b)

    RED        = rgb(0xe4453a)
    CRIMSON    = rgb(0x9c2430)
    ORANGE     = rgb(0xf0873c)
    YELLOW     = rgb(0xf7d94c)
    GOLD       = rgb(0xd9a02b)
    GREEN      = rgb(0x54c96a)
    MOSS       = rgb(0x2f7a45)
    CYAN       = rgb(0x49c6e0)
    AQUA       = rgb(0x8ae2f0)
    BLUE       = rgb(0x3b6fd4)
    DEEP_BLUE  = rgb(0x1f3c85)
    PINK       = rgb(0xef7fa5)
    BROWN      = rgb(0x7a4a2a)
    TAN        = rgb(0xbb8a55)

    TRANSPARENT = Gosu::Color.new(0, 0, 0, 0)
    # 画像を色で染めずにそのまま描くための白。
    FULL        = Gosu::Color.new(255, 255, 255, 255)

    # 睡眠ゲージの色。健康(緑)→注意(黄)→危険(橙)→限界(赤)。
    def gauge_color(ratio)
      case ratio
      when 0.0...0.35 then mix(GREEN, YELLOW, ratio / 0.35)
      when 0.35...0.65 then mix(YELLOW, ORANGE, (ratio - 0.35) / 0.30)
      when 0.65...0.85 then mix(ORANGE, RED, (ratio - 0.65) / 0.20)
      else mix(RED, CRIMSON, [(ratio - 0.85) / 0.15, 1.0].min)
      end
    end
  end
end
