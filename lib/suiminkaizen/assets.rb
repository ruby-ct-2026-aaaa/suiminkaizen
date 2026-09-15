# frozen_string_literal: true

module Suiminkaizen
  # フォントと、峰小輔の立ち絵の読み込み。
  #
  # 立ち絵は 4 種類あり、場面によって使い分ける。
  #   normal  ふだんの峰小輔（タイトル・1日の導入・説明画面）
  #   success ミニゲームで A 以上を出したとき
  #   fail    ミニゲームで C 以下だったとき、そして気絶したとき
  #   sleep   1日の終わりの30分睡眠
  module Assets
    ROOT = File.expand_path("../../assets", __dir__)

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

    PORTRAITS = %i[normal success fail sleep].freeze

    module_function

    # --- フォント ---------------------------------------------------------
    # サイズは Config::REFERENCE_SCALE のときの実画面ピクセル。
    # ウィンドウを伸縮しても見た目が変わらないよう、Px が比率をかけて描く。

    def font(size)
      @fonts ||= {}
      @fonts[size] ||= build_font(size)
    end

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

    # --- 立ち絵 -----------------------------------------------------------
    # ウィンドウ（＝OpenGL のコンテキスト）が出来てからでないと読めないので、
    # 最初に必要になった時点で読み込む。

    def portrait(name)
      @portraits ||= {}
      return @portraits[name] if @portraits.key?(name)

      @portraits[name] = ImageSprite.load(File.join(ROOT, "kosuke", "#{name}.png"))
    end

    # ミニゲームの成績に応じた表情を選ぶ。
    #   A 以上 → success / C 以下 → fail / それ以外 → normal
    def portrait_for_rank(rank)
      case rank
      when "S", "A" then portrait(:success) || portrait(:normal)
      when "C", "D" then portrait(:fail) || portrait(:normal)
      else portrait(:normal)
      end
    end

    def portraits_available?
      PORTRAITS.all? { |name| portrait(name) }
    end
  end
end
