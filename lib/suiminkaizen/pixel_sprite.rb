# frozen_string_literal: true

module Suiminkaizen
  # 文字列の並びで定義するドット絵。画像ファイルを一切持たない。
  #
  # 横に同じ色が続く区間(span)へあらかじめ畳んでから矩形で描くので、
  # 拡大しても輪郭がにじまず、かつ描画命令の数も抑えられる。
  # 色は文字→色のパレットで解決するため、同じ形を色違いで使い回せる。
  class PixelSprite
    attr_reader :width, :height

    def initialize(rows, palette)
      widths = rows.map(&:length).uniq
      if widths.size != 1
        raise ArgumentError, "ドット絵の行の長さが揃っていません: #{widths.sort.inspect}"
      end

      @rows    = rows
      @height  = rows.size
      @width   = widths.first
      @palette = palette
      @spans   = build_spans
    end

    # cx: 中心X / by: 下端Y / ppu: ドット1つを何論理ドットで描くか
    def draw(cx, by, ppu, z = 0, palette: nil, tint: nil, flip: false)
      pal  = palette ? @palette.merge(palette) : @palette
      left = cx - @width * ppu / 2.0
      top  = by - @height * ppu

      @spans.each do |(y, x0, x1, ch)|
        color = pal[ch]
        next unless color

        color = Palette.mix(color, tint[0], tint[1]) if tint
        sx = flip ? left + (@width - x1) * ppu : left + x0 * ppu
        Px.rect(sx, top + y * ppu, (x1 - x0) * ppu, ppu, color, z)
      end
    end

    # 疑似3D空間へ置く。world_height は「世界座標で何単位の背丈か」。
    # カメラからの距離に応じて拡大率が決まり、遠いものは自動的に小さく霞む。
    def draw3d(camera, wx, wy_bottom, wz, world_height,
               palette: nil, tint: nil, flip: false, z: nil, fog: nil)
      sx, sy, scale = camera.project(wx, wy_bottom, wz)
      ppu = world_height * scale / @height
      return if ppu <= 0.02

      draw(sx, sy, ppu, z || Config.depth_z(wz),
           palette: palette, tint: tint || fog_tint(wz, fog), flip: flip)
    end

    private

    def build_spans
      spans = []
      @rows.each_with_index do |row, y|
        x = 0
        while x < row.length
          ch = row[x]
          if ch == "." || ch == " "
            x += 1
            next
          end

          tail = x
          tail += 1 while tail + 1 < row.length && row[tail + 1] == ch
          spans << [y, x, tail + 1, ch].freeze
          x = tail + 1
        end
      end
      spans.freeze
    end

    # 奥にあるものほど背景色へ沈ませる（空気遠近）。
    def fog_tint(wz, fog)
      return nil unless fog

      t = ((wz - Stage::NEAR_Z) / (Stage::FAR_Z - Stage::NEAR_Z)) * 0.65
      return nil if t <= 0.0

      [fog, t > 0.65 ? 0.65 : t]
    end
  end
end
