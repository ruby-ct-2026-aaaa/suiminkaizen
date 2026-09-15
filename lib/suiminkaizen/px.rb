# frozen_string_literal: true

module Suiminkaizen
  # 論理ドット座標(320x240)で描画するための薄いラッパー。
  #
  # 座標をまず論理ドットの整数へ丸め、そのうえで Viewport の倍率をかけてから
  # 画面座標の整数へ落とす。両端を同じ手順で丸めるので、隣り合う矩形のあいだに
  # 隙間ができず、ウィンドウをどんな大きさにしてもドットの並びが崩れない。
  module Px
    module_function

    def rect(x, y, w, h, color, z = 0)
      x0 = x.round
      y0 = y.round
      x1 = (x + w).round
      y1 = (y + h).round
      return if x1 <= x0 || y1 <= y0

      sx = Viewport.screen_x(x0)
      sy = Viewport.screen_y(y0)
      Gosu.draw_rect(sx, sy, Viewport.screen_x(x1) - sx, Viewport.screen_y(y1) - sy,
                     color, z)
    end

    # 枠線だけの矩形。
    def frame(x, y, w, h, color, z = 0, thickness = 1)
      rect(x, y, w, thickness, color, z)
      rect(x, y + h - thickness, w, thickness, color, z)
      rect(x, y, thickness, h, color, z)
      rect(x + w - thickness, y, thickness, h, color, z)
    end

    # 任意四角形。頂点は (左上, 右上, 左下, 右下) の順。
    # 透視投影した床・壁・天井を描くのに使う。頂点ごとに色を変えられるので、
    # 奥の2点をフォグ色にするだけで奥行きのグラデーションになる。
    def quad(x1, y1, x2, y2, x3, y3, x4, y4, c1, c2 = c1, c3 = c1, c4 = c2, z = 0)
      Gosu.draw_quad(Viewport.screen_x(x1), Viewport.screen_y(y1), c1,
                     Viewport.screen_x(x2), Viewport.screen_y(y2), c2,
                     Viewport.screen_x(x3), Viewport.screen_y(y3), c3,
                     Viewport.screen_x(x4), Viewport.screen_y(y4), c4, z)
    end

    # ドットを1つずつ置いて描く円と線。時計の文字盤と針のような、
    # 曲線をドット絵らしく見せたい場面で使う。
    def circle(cx, cy, radius, color, z = 0, thickness = 1)
      return if radius <= 0

      steps = (radius * 6.5).ceil
      steps.times do |i|
        angle = Math::PI * 2 * i / steps
        rect(cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius,
             thickness, thickness, color, z)
      end
    end

    def ray(cx, cy, angle, length, color, z = 0, thickness = 1, from = 0)
      dx = Math.cos(angle)
      dy = Math.sin(angle)
      (from..length.round).each do |i|
        rect(cx + dx * i, cy + dy * i, thickness, thickness, color, z)
      end
    end

    def text(font, str, x, y, color, z = 200, align: :left, scale: 1.0)
      factor = scale * Viewport.text_scale
      width  = font.text_width(str) * factor
      dx = case align
           when :center then -width / 2.0
           when :right  then -width
           else 0.0
           end
      font.draw_text(str, (Viewport.screen_x(x) + dx).round, Viewport.screen_y(y),
                     z, factor, factor, color)
    end

    # 読みやすさのため1ドットぶんの影を落とす。
    def text_shadow(font, str, x, y, color, z = 200, align: :left, scale: 1.0,
                    shadow: Palette::INK)
      text(font, str, x + 1, y + 1, shadow, z, align: align, scale: scale)
      text(font, str, x, y, color, z + 0.5, align: align, scale: scale)
    end

    # 論理ドット単位での文字の幅。
    def text_width(font, str, scale: 1.0)
      font.text_width(str) * scale / Config::REFERENCE_SCALE.to_f
    end
  end
end
