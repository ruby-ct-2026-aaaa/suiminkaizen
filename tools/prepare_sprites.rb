# frozen_string_literal: true

# 峰小輔のスプライト（JPG・白背景）を、背景を抜いた PNG に変換する。
#
#   ruby tools/prepare_sprites.rb
#
# JPG には透過が無いので、外周から白につながっている領域だけを塗りつぶしで
# 探して透明にする。単純に「白い画素を消す」やり方だと、目の白や肌のハイライト
# まで穴が空いてしまうため、外周から到達できるかどうかで判断している。
# 最後に中身の外接矩形へ切り詰めて、余白のぶんだけ描画が軽くなるようにする。

require "gosu"

SOURCE_DIR = File.expand_path("../assets/kosuke", __dir__)
NAMES      = %w[normal success fail sleep].freeze

BACKGROUND_LEVEL = 232 # これ以上明るければ背景候補
HALO_LEVEL       = 246 # 縁に残った JPEG のにじみを追加で削る閾値

class Preparer < Gosu::Window
  def initialize
    super(320, 120)
    self.caption = "スプライト変換中..."
    @done = false
  end

  def update
    return if @done

    @done = true
    NAMES.each { |name| convert(name) }
    close
  end

  def draw; end

  private

  def convert(name)
    path = File.join(SOURCE_DIR, "#{name}.jpg")
    unless File.exist?(path)
      warn "  #{name}.jpg が見つかりません"
      return
    end

    image = Gosu::Image.new(path, retro: true)
    w = image.width
    h = image.height
    pixels = image.to_blob.dup

    removed = flood_background(pixels, w, h)
    removed += shave_halo(pixels, w, h)
    removed += keep_largest_blob(pixels, w, h)
    box = bounding_box(pixels, w, h)

    unless box
      warn "  #{name}: 中身が残りませんでした（閾値を見直してください）"
      return
    end

    cropped, cw, ch = crop(pixels, w, h, box)
    out = File.join(SOURCE_DIR, "#{name}.png")
    Gosu::Image.from_blob(cw, ch, cropped).save(out)

    puts format("  %-8s %4dx%-4d -> %4dx%-4d  背景 %6d px を透過  %s",
                name, w, h, cw, ch, removed, File.basename(out))
  end

  def light?(pixels, index, level)
    base = index * 4
    pixels.getbyte(base) >= level &&
      pixels.getbyte(base + 1) >= level &&
      pixels.getbyte(base + 2) >= level
  end

  def clear!(pixels, index)
    pixels.setbyte(index * 4 + 3, 0)
  end

  def transparent?(pixels, index)
    pixels.getbyte(index * 4 + 3).zero?
  end

  # 画像の外周から、明るい画素をたどって塗りつぶす。
  def flood_background(pixels, w, h)
    seen = Array.new(w * h, false)
    queue = []

    (0...w).each do |x|
      [0, h - 1].each { |y| queue << (y * w + x) }
    end
    (0...h).each do |y|
      [0, w - 1].each { |x| queue << (y * w + x) }
    end

    removed = 0
    until queue.empty?
      index = queue.pop
      next if seen[index]

      seen[index] = true
      next unless light?(pixels, index, BACKGROUND_LEVEL)

      clear!(pixels, index)
      removed += 1

      x = index % w
      y = index / w
      queue << (index - 1) if x > 0
      queue << (index + 1) if x < w - 1
      queue << (index - w) if y > 0
      queue << (index + w) if y < h - 1
    end
    removed
  end

  # 透明になった領域の縁に残る、JPEG のにじみを1周ぶんだけ削る。
  def shave_halo(pixels, w, h)
    doomed = []
    (0...h).each do |y|
      (0...w).each do |x|
        index = y * w + x
        next if transparent?(pixels, index)
        next unless light?(pixels, index, HALO_LEVEL)

        neighbours = []
        neighbours << (index - 1) if x > 0
        neighbours << (index + 1) if x < w - 1
        neighbours << (index - w) if y > 0
        neighbours << (index + w) if y < h - 1
        doomed << index if neighbours.any? { |n| transparent?(pixels, n) }
      end
    end
    doomed.each { |index| clear!(pixels, index) }
    doomed.size
  end

  # 元画像に別カットの切れ端が写り込んでいることがあるので、
  # 残った不透明領域のうち一番大きな塊だけを採用する。
  def keep_largest_blob(pixels, w, h)
    label = Array.new(w * h, 0)
    sizes = [0]

    (0...h).each do |y|
      (0...w).each do |x|
        start = y * w + x
        next if transparent?(pixels, start) || label[start].positive?

        id = sizes.size
        count = 0
        queue = [start]
        label[start] = id
        until queue.empty?
          index = queue.pop
          count += 1
          px = index % w
          py = index / w
          neighbours = []
          neighbours << (index - 1) if px > 0
          neighbours << (index + 1) if px < w - 1
          neighbours << (index - w) if py > 0
          neighbours << (index + w) if py < h - 1
          neighbours.each do |n|
            next if label[n].positive? || transparent?(pixels, n)

            label[n] = id
            queue << n
          end
        end
        sizes << count
      end
    end

    biggest = sizes.each_with_index.max_by { |count, _| count }&.last
    return 0 unless biggest

    removed = 0
    label.each_with_index do |id, index|
      next if id.zero? || id == biggest

      clear!(pixels, index)
      removed += 1
    end
    removed
  end

  def bounding_box(pixels, w, h)
    min_x = w
    min_y = h
    max_x = -1
    max_y = -1

    (0...h).each do |y|
      (0...w).each do |x|
        index = y * w + x
        next if transparent?(pixels, index)

        min_x = x if x < min_x
        max_x = x if x > max_x
        min_y = y if y < min_y
        max_y = y if y > max_y
      end
    end
    return nil if max_x.negative?

    [min_x, min_y, max_x, max_y]
  end

  def crop(pixels, w, _h, box)
    min_x, min_y, max_x, max_y = box
    cw = max_x - min_x + 1
    ch = max_y - min_y + 1
    out = String.new(capacity: cw * ch * 4)

    (min_y..max_y).each do |y|
      start = (y * w + min_x) * 4
      out << pixels.byteslice(start, cw * 4)
    end
    [out, cw, ch]
  end
end

puts "白背景を透過させて PNG に変換します -> #{SOURCE_DIR}"
Preparer.new.show
puts "完了"
