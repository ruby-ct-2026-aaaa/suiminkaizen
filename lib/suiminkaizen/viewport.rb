# frozen_string_literal: true

module Suiminkaizen
  # 論理解像度 320x240 を、実際のウィンドウの大きさへ当てはめる係数を持つ。
  #
  # ウィンドウは自由に伸縮でき全画面にもできるが、絵の縦横比は 4:3 に保つ。
  # はみ出したぶんは上下（または左右）の黒帯になる。
  # 描画側は論理座標だけを考えればよく、拡大率のことは Px がここから受け取る。
  module Viewport
    MIN_SCALE = 0.5

    module_function

    def fit!(window_width, window_height)
      return if window_width <= 0 || window_height <= 0
      return if window_width == @window_width && window_height == @window_height

      @window_width  = window_width
      @window_height = window_height

      @scale = [window_width / Config::W.to_f, window_height / Config::H.to_f].min
      @scale = MIN_SCALE if @scale < MIN_SCALE

      @offset_x = ((window_width - Config::W * @scale) / 2.0).round
      @offset_y = ((window_height - Config::H * @scale) / 2.0).round
    end

    def scale
      @scale || Config::REFERENCE_SCALE.to_f
    end

    def offset_x = @offset_x || 0
    def offset_y = @offset_y || 0

    def window_width  = @window_width  || Config::W * Config::REFERENCE_SCALE
    def window_height = @window_height || Config::H * Config::REFERENCE_SCALE

    # フォントは基準倍率のときの見た目で作ってあるので、その比で拡大する。
    def text_scale
      scale / Config::REFERENCE_SCALE
    end

    def screen_x(x) = (offset_x + x * scale).round
    def screen_y(y) = (offset_y + y * scale).round

    # 4:3 に収まらなかった余白。ここを塗りつぶして黒帯にする。
    def letterbox_bars
      bars = []
      if offset_y.positive?
        bars << [0, 0, window_width, offset_y]
        bars << [0, window_height - offset_y - 1, window_width, offset_y + 2]
      end
      if offset_x.positive?
        bars << [0, 0, offset_x, window_height]
        bars << [window_width - offset_x - 1, 0, offset_x + 2, window_height]
      end
      bars
    end
  end
end
