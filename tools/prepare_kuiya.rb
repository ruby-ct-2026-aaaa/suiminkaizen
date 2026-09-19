# frozen_string_literal: true

# クイヤのスプライトシート（assets/kuiya/sheet.jpg）を、
# 1コマずつ背景を抜いた PNG に切り出す。
#
#   ruby tools/prepare_kuiya.rb
#
# シートは JPG で透過を持たないので、切り出した矩形の外周から
# 地色につながっている領域だけを塗りつぶしで探して透明にする。
# 中にある暗い画素（輪郭線や目）は外周から到達できないので残る。
# 最後に中身の外接矩形へ切り詰める。

require "gosu"
require "fileutils"

ROOT   = File.expand_path("../assets/kuiya", __dir__)
SHEET  = File.join(ROOT, "sheet.jpg")

# シート上のコマの位置（左, 上, 右, 下）。
# tools/ の解析で拾った外接矩形に、少し余白を足したもの。
REGIONS = {
  # 歩く（6コマ）
  "walk1" => [49, 502, 179, 574],
  "walk2" => [190, 491, 314, 573],
  "walk3" => [325, 495, 459, 573],
  "walk4" => [469, 491, 596, 568],
  "walk5" => [598, 489, 731, 573],
  "walk6" => [740, 488, 878, 562],
  # 走る（4コマ）
  "run1" => [954, 504, 1074, 573],
  "run2" => [1092, 500, 1219, 573],
  "run3" => [1232, 504, 1359, 567],
  "run4" => [1365, 501, 1489, 567],
  # 待機
  "front" => [76, 696, 158, 814],  # 正面
  "back"  => [218, 692, 298, 814], # 後ろ姿
  "idle"  => [338, 696, 557, 815], # 横向きの待機
  # そのほか
  "surprised" => [684, 721, 790, 839],
  "eat"       => [922, 716, 1115, 819],
  "sleep"     => [1230, 712, 1430, 833]
}.freeze

PAD = 5 # 切り出すときの余白

# 地色。パネルの中身とページの地色の両方を見る。
BACKGROUNDS = [[29, 28, 42], [33, 29, 47], [38, 33, 54]].freeze
TOLERANCE = 30

class Preparer < Gosu::Window
  def initialize
    super(320, 120)
    self.caption = "クイヤのスプライトを切り出し中..."
    @done = false
  end

  def update
    return if @done

    @done = true
    run
    close
  end

  def draw; end

  private

  def run
    abort "シートが見つからない: #{SHEET}" unless File.exist?(SHEET)

    sheet = Gosu::Image.new(SHEET, retro: true)
    @sw = sheet.width
    @sh = sheet.height
    @sp = sheet.to_blob

    puts "シート: #{@sw} x #{@sh}"
    REGIONS.each { |name, box| cut(name, box) }
    puts "完了 -> #{ROOT}"
  end

  def cut(name, (x0, y0, x1, y1))
    x0 = [x0 - PAD, 0].max
    y0 = [y0 - PAD, 0].max
    x1 = [x1 + PAD, @sw - 1].min
    y1 = [y1 + PAD, @sh - 1].min
    w = x1 - x0 + 1
    h = y1 - y0 + 1

    pixels = crop(x0, y0, w, h)
    erase_background!(pixels, w, h)
    pixels, w, h = trim(pixels, w, h)

    if w.zero? || h.zero?
      warn "  #{name}: 中身が残らなかった"
      return
    end

    path = File.join(ROOT, "#{name}.png")
    Gosu::Image.from_blob(w, h, pixels).save(path)
    puts format("  %-10s %3d x %3d", name, w, h)
  end

  def crop(x0, y0, w, h)
    out = String.new(capacity: w * h * 4)
    h.times do |y|
      row = ((y0 + y) * @sw + x0) * 4
      out << @sp.byteslice(row, w * 4)
    end
    out
  end

  # 外周から地色でつながっている領域だけを透明にする。
  def erase_background!(pixels, w, h)
    seen = Array.new(w * h, false)
    stack = []

    (0...w).each do |x|
      [0, h - 1].each do |y|
        i = y * w + x
        stack << i if !seen[i] && background?(pixels, i)
        seen[i] = true if stack.last == i
      end
    end
    (0...h).each do |y|
      [0, w - 1].each do |x|
        i = y * w + x
        next if seen[i] || !background?(pixels, i)

        seen[i] = true
        stack << i
      end
    end

    until stack.empty?
      i = stack.pop
      # 透明にするときは色も落とす。色を残したままだと、
      # 描画時にその色がにじみ出て画面全体が白っぽくなってしまう。
      pixels.setbyte(i * 4, 0)
      pixels.setbyte(i * 4 + 1, 0)
      pixels.setbyte(i * 4 + 2, 0)
      pixels.setbyte(i * 4 + 3, 0)

      ix = i % w
      iy = i / w
      [[-1, 0], [1, 0], [0, -1], [0, 1]].each do |(dx, dy)|
        nx = ix + dx
        ny = iy + dy
        next if nx.negative? || ny.negative? || nx >= w || ny >= h

        j = ny * w + nx
        next if seen[j] || !background?(pixels, j)

        seen[j] = true
        stack << j
      end
    end
  end

  def background?(pixels, i)
    r = pixels.getbyte(i * 4)
    g = pixels.getbyte(i * 4 + 1)
    b = pixels.getbyte(i * 4 + 2)
    BACKGROUNDS.any? do |bg|
      (r - bg[0]).abs <= TOLERANCE &&
        (g - bg[1]).abs <= TOLERANCE &&
        (b - bg[2]).abs <= TOLERANCE
    end
  end

  # 透明でないところの外接矩形へ切り詰める。
  def trim(pixels, w, h)
    x0 = w
    y0 = h
    x1 = -1
    y1 = -1

    (0...h).each do |y|
      (0...w).each do |x|
        next if pixels.getbyte((y * w + x) * 4 + 3).zero?

        x0 = x if x < x0
        x1 = x if x > x1
        y0 = y if y < y0
        y1 = y if y > y1
      end
    end
    return ["", 0, 0] if x1.negative?

    nw = x1 - x0 + 1
    nh = y1 - y0 + 1
    out = String.new(capacity: nw * nh * 4)
    (y0..y1).each do |y|
      out << pixels.byteslice((y * w + x0) * 4, nw * 4)
    end
    [out, nw, nh]
  end
end

FileUtils.mkdir_p(ROOT)
Preparer.new.show
