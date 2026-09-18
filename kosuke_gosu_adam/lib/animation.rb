# frozen_string_literal: true

module Kosuke
  module CroppedImage
    # 画像の可視部分だけを描く。通常画面とrender-to-textureで同じ結果にする。
    def self.draw(image, x, y, scale, z, color, clip = nil)
      return image.draw(x, y, z, scale, scale, color) unless clip
      cx, cy, cw, ch = clip
      left = [((cx - x) / scale).ceil, 0].max
      top = [((cy - y) / scale).ceil, 0].max
      right = [((cx + cw - x) / scale).floor, image.width].min
      bottom = [((cy + ch - y) / scale).floor, image.height].min
      return if right <= left || bottom <= top
      image.subimage(left, top, right - left, bottom - top).draw(x + left * scale, y + top * scale, z, scale, scale, color)
    end
  end

  module Animation
    ROWS = { training: 0, bath: 1, supplement: 2, massage: 3, camera: 4 }.freeze

    def self.frame(kind, game)
      event = game.last_event
      recent = event && game.time - event[:at] < 0.65
      case kind
      when :training
        recent ? (event[:score] >= 0.55 ? 2 + ((game.time * 9).floor % 2) : 1) : (game.time * 2).floor % 2
      when :bath
        (game.time * (game.inside? ? 4 : 7)).floor % 4
      when :supplement
        recent ? (event[:correct] ? 2 + ((game.time * 7).floor % 2) : 0) : (game.time * 3).floor % 2
      when :massage
        recent ? (event[:score].positive? ? 2 + ((game.time * 8).floor % 2) : 1) : (game.active_target ? 1 : 3)
      when :camera
        recent ? (event[:score].positive? ? 2 + ((game.time * 7).floor % 2) : 1) : (game.active_target ? 1 : 0)
      else 0
      end
    end
  end

  class SpriteAtlas
    def initialize(path, columns:, rows:, rect_adjustments: {})
      image = Gosu::Image.new(path, retro: true)
      @frames = Array.new(rows) do |row|
        Array.new(columns) do |col|
          x0, x1 = [(col * image.width.to_f / columns).round, ((col + 1) * image.width.to_f / columns).round]
          y0, y1 = [(row * image.height.to_f / rows).round, ((row + 1) * image.height.to_f / rows).round]
          left, top, right, bottom = rect_adjustments.fetch([row, col], [0, 0, 0, 0])
          tile = image.subimage(x0 + left, y0 + top, x1 - x0 + right - left, y1 - y0 + bottom - top)
          { image: tile, width: x1 - x0, height: y1 - y0, left: left, top: top }
        end
      end
    end

    def draw(row, frame, x, y, size, z, color = 0xff_ffffff, clip: nil)
      tile = @frames.fetch(row).fetch(frame)
      scale = size.to_f / [tile[:width], tile[:height]].max
      CroppedImage.draw(tile[:image], x - tile[:width] * scale / 2 + tile[:left] * scale,
                        y - tile[:height] * scale / 2 + tile[:top] * scale, scale, z, color, clip)
    end
  end
end
