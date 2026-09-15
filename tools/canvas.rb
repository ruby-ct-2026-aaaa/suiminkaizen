# frozen_string_literal: true

require "zlib"

# Gosu の描画呼び出しをピクセル配列へ焼いて PNG に落とすだけの、
# 確認用のごく素朴なソフトウェアラスタライザ。
# これで実機を起動しなくても、疑似3Dの部屋が意図どおり組み上がっているか見られる。
#
# 文字だけは本物のフォントを持たないので、位置と幅が分かる帯として描く。
class Canvas
  def initialize(width, height)
    @w = width
    @h = height
    @pixels = Array.new(width * height, [12, 10, 20])
    @queue = []
    @seq = 0
  end

  def push_rect(x, y, w, h, color, z)
    @queue << [z, @seq += 1, :rect, [x, y, w, h, color]]
  end

  def push_quad(x1, y1, c1, x2, y2, c2, x3, y3, c3, x4, y4, c4, z)
    @queue << [z, @seq += 1, :quad, [x1, y1, c1, x2, y2, c2, x3, y3, c3, x4, y4, c4]]
  end

  def push_text(text, x, y, height, width, color, z)
    @queue << [z, @seq += 1, :text, [text, x, y, height, width, color]]
  end

  # Gosu と同じく z の昇順、同じ z なら呼び出し順で重ねる。
  def flush!
    @queue.sort_by { |(z, seq, _, _)| [z, seq] }.each do |(_, _, kind, args)|
      case kind
      when :rect then raster_rect(*args)
      when :quad then raster_quad(*args)
      when :text then raster_text(*args)
      end
    end
    @queue.clear
  end

  def save(path)
    flush!
    File.binwrite(path, png_bytes)
    path
  end

  # 一部を切り出して整数倍に拡大したものを別ファイルへ。ドットの粗探し用。
  def save_crop(path, x, y, w, h, zoom)
    flush!
    zoomed = Canvas.new(w * zoom, h * zoom)
    h.times do |py|
      w.times do |px|
        src = @pixels[(y + py) * @w + (x + px)] || [0, 0, 0]
        zoom.times do |dy|
          row = (py * zoom + dy) * (w * zoom)
          zoom.times { |dx| zoomed.instance_variable_get(:@pixels)[row + px * zoom + dx] = src }
        end
      end
    end
    File.binwrite(path, zoomed.send(:png_bytes))
    path
  end

  private

  def blend(index, r, g, b, a)
    return if a <= 0

    old = @pixels[index]
    if a >= 255
      @pixels[index] = [r, g, b]
      return
    end
    t = a / 255.0
    @pixels[index] = [
      (old[0] + (r - old[0]) * t).round,
      (old[1] + (g - old[1]) * t).round,
      (old[2] + (b - old[2]) * t).round
    ]
  end

  def raster_rect(x, y, w, h, color)
    x0 = x.round.clamp(0, @w)
    y0 = y.round.clamp(0, @h)
    x1 = (x + w).round.clamp(0, @w)
    y1 = (y + h).round.clamp(0, @h)
    (y0...y1).each do |py|
      row = py * @w
      (x0...x1).each do |px|
        blend(row + px, color.red, color.green, color.blue, color.alpha)
      end
    end
  end

  # Gosu の draw_quad は (1,2,3) と (2,3,4) の2枚の三角形。
  def raster_quad(x1, y1, c1, x2, y2, c2, x3, y3, c3, x4, y4, c4)
    triangle(x1, y1, c1, x2, y2, c2, x3, y3, c3)
    triangle(x2, y2, c2, x3, y3, c3, x4, y4, c4)
  end

  def triangle(ax, ay, ca, bx, by, cb, cx, cy, cc)
    min_x = [ax, bx, cx].min.floor.clamp(0, @w - 1)
    max_x = [ax, bx, cx].max.ceil.clamp(0, @w - 1)
    min_y = [ay, by, cy].min.floor.clamp(0, @h - 1)
    max_y = [ay, by, cy].max.ceil.clamp(0, @h - 1)

    denom = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    return if denom.abs < 1e-9

    (min_y..max_y).each do |py|
      row = py * @w
      (min_x..max_x).each do |px|
        sx = px + 0.5
        sy = py + 0.5
        w0 = ((by - cy) * (sx - cx) + (cx - bx) * (sy - cy)) / denom
        w1 = ((cy - ay) * (sx - cx) + (ax - cx) * (sy - cy)) / denom
        w2 = 1.0 - w0 - w1
        next if w0 < -0.001 || w1 < -0.001 || w2 < -0.001

        blend(row + px,
              (ca.red * w0 + cb.red * w1 + cc.red * w2).round.clamp(0, 255),
              (ca.green * w0 + cb.green * w1 + cc.green * w2).round.clamp(0, 255),
              (ca.blue * w0 + cb.blue * w1 + cc.blue * w2).round.clamp(0, 255),
              (ca.alpha * w0 + cb.alpha * w1 + cc.alpha * w2).round.clamp(0, 255))
      end
    end
  end

  # 本物のフォントは持てないので、文字の並びを帯で示す。
  def raster_text(text, x, y, height, width, color)
    per = text.empty? ? 0 : width / text.length.to_f
    text.each_char.with_index do |ch, i|
      next if ch == " "

      cx = x + i * per
      raster_rect(cx + per * 0.12, y + height * 0.18,
                  per * 0.76, height * 0.62,
                  FakeColor.new((color.alpha * 0.72).round, color.red,
                                color.green, color.blue))
    end
  end

  FakeColor = Struct.new(:alpha, :red, :green, :blue)

  # --- PNG 書き出し（zlib のみ使用） -----------------------------------

  def png_bytes
    raw = +""
    @h.times do |y|
      raw << "\0"
      row = y * @w
      @w.times do |x|
        r, g, b = @pixels[row + x]
        raw << r.chr << g.chr << b.chr
      end
    end

    ihdr = [@w, @h].pack("NN") + [8, 2, 0, 0, 0].pack("C5")
    "\x89PNG\r\n\x1a\n".b +
      chunk("IHDR", ihdr) +
      chunk("IDAT", Zlib::Deflate.deflate(raw)) +
      chunk("IEND", "")
  end

  def chunk(type, data)
    [data.bytesize].pack("N") + type + data +
      [Zlib.crc32(type + data)].pack("N")
  end
end
