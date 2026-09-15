# frozen_string_literal: true

# ドット絵そのものを大きく並べて確認するツール。
#
#   ruby tools/sprite_sheet.rb [出力パス]

$LOAD_PATH.unshift(File.expand_path("stub", __dir__))
require_relative "canvas"
require_relative "../lib/suiminkaizen"
require "fileutils"

include Suiminkaizen # rubocop:disable Style/MixinUsage

OUT = ARGV[0] || File.expand_path("../tmp/shots/sprites.png", __dir__)
FileUtils.mkdir_p(File.dirname(OUT))

ZOOM = 6
GAP  = 10

entries = Sprites::ALL.to_a
# サプリは色違いも並べる
entries << [:tablet_caffeine, Sprites::TABLET]
entries << [:capsule_sleep, Sprites::CAPSULE]

PALETTES = {
  tablet_caffeine: { "A" => Palette::ORANGE, "B" => Palette.shade(Palette::ORANGE, 0.6) },
  capsule_sleep: { "A" => Palette::BLUE, "B" => Palette::DEEP_BLUE }
}.freeze

cell_w = entries.map { |(_, s)| s.width }.max * ZOOM + GAP
cell_h = entries.map { |(_, s)| s.height }.max * ZOOM + GAP + 10
cols = 6
rows = (entries.size / cols.to_f).ceil

canvas = Canvas.new(cell_w * cols, cell_h * rows)
Gosu.canvas = canvas

entries.each_with_index do |(name, sprite), i|
  col = i % cols
  row = i / cols
  # Px は論理座標を SCALE 倍するので、逆算して置く
  cx = (col * cell_w + cell_w / 2) / Config::REFERENCE_SCALE.to_f
  by = (row * cell_h + cell_h - GAP) / Config::REFERENCE_SCALE.to_f
  ppu = ZOOM / Config::REFERENCE_SCALE.to_f

  # 市松模様の下敷き（透明部分が分かるように）
  left = cx - sprite.width * ppu / 2
  top  = by - sprite.height * ppu
  (0...sprite.height).each do |y|
    (0...sprite.width).each do |x|
      tone = (x + y).even? ? 0x3a3a46 : 0x2c2c36
      Px.rect(left + x * ppu, top + y * ppu, ppu, ppu, Palette.rgb(tone), 0)
    end
  end

  sprite.draw(cx, by, ppu, 1, palette: PALETTES[name])
  puts format("%-16s %2d x %2d", name, sprite.width, sprite.height)
end

canvas.save(OUT)
Gosu.canvas = nil
puts "-> #{OUT}"
