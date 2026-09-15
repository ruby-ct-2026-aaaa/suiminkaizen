# frozen_string_literal: true

module Suiminkaizen
  # フォントの読み込み。日本語が出せる書体を順に試し、
  # どれも駄目ならGosuの既定フォントへ落とす。
  module Assets
    CANDIDATES = [
      "C:/Windows/Fonts/meiryo.ttc",
      "C:/Windows/Fonts/YuGothM.ttc",
      "C:/Windows/Fonts/YuGothR.ttc",
      "C:/Windows/Fonts/msgothic.ttc",
      "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
      "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
      "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf",
      "Meiryo",
      "Yu Gothic",
      "MS Gothic",
      "Hiragino Sans",
      "Noto Sans CJK JP"
    ].freeze

    module_function

    def font(size)
      @fonts ||= {}
      @fonts[size] ||= build_font(size)
    end

    # サイズは実画面ピクセル。論理解像度 320x240 を SCALE(=3) 倍しているので、
    # tiny=20px はドット絵換算で 7 ドットぶんの高さにあたる。
    def tiny   = font(20)
    def small  = font(25)
    def normal = font(30)
    def large  = font(40)
    def huge   = font(52)
    def title  = font(72)

    def build_font(size)
      available.each do |name|
        begin
          return Gosu::Font.new(size, name: name)
        rescue StandardError
          next
        end
      end
      Gosu::Font.new(size)
    end

    def available
      @available ||= CANDIDATES.select { |name| !name.include?("/") || File.exist?(name) }
    end
  end
end
