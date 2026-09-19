# frozen_string_literal: true

# 画面を開かずにゲームを走らせるための、Gosu の最小スタブ。
#   ruby -Itools/stub tools/smoke.rb
# のように $LOAD_PATH の先頭へ置いて `require "gosu"` を横取りする。
#
# 描画呼び出しは数を数えるだけだが、座標や色が nil / NaN になっていたら
# その場で落とすので、本物の画面を開かずに描画まわりの事故を拾える。
module Gosu
  KB_A = 4
  KB_D = 7
  KB_N = 17
  KB_P = 19
  KB_Q = 20
  KB_R = 21
  KB_S = 22
  KB_T = 23
  KB_W = 26
  KB_X = 27
  KB_9 = 38
  KB_NUMPAD_9 = 97
  KB_RETURN = 40
  KB_ESCAPE = 41
  KB_SPACE = 44
  KB_F11 = 68
  KB_RIGHT = 79
  KB_LEFT = 80
  KB_DOWN = 81
  KB_UP = 82
  KB_ENTER = 88
  KB_LEFT_ALT = 226
  KB_RIGHT_ALT = 230

  class Color
    attr_reader :alpha, :red, :green, :blue

    def initialize(alpha, red = nil, green = nil, blue = nil)
      if red.nil?
        argb = alpha
        @alpha = (argb >> 24) & 0xff
        @red   = (argb >> 16) & 0xff
        @green = (argb >> 8) & 0xff
        @blue  = argb & 0xff
      else
        @alpha = check(alpha)
        @red   = check(red)
        @green = check(green)
        @blue  = check(blue)
      end
    end

    def self.rgba(r, g, b, a) = new(a, r, g, b)

    private

    def check(v)
      raise ArgumentError, "bad color component: #{v.inspect}" unless v.is_a?(Integer)
      raise ArgumentError, "color component out of range: #{v}" if v.negative? || v > 255

      v
    end

    public

    WHITE = new(255, 255, 255, 255)
    BLACK = new(255, 0, 0, 0)
  end

  class Font
    attr_reader :height, :name

    def initialize(height, name: nil, **_opts)
      @height = height
      @name = name
    end

    def text_width(text, scale = 1.0)
      text.to_s.each_char.sum { |ch| ch.bytesize > 1 ? @height : @height * 0.5 } * scale
    end

    def markup_width(text, scale = 1.0) = text_width(text, scale)

    def draw_text(text, x, y, z, sx = 1.0, sy = 1.0, color = Color::WHITE, _mode = :default)
      Gosu.note_draw!
      Gosu.check_numbers!("draw_text", x, y, z, sx, sy)
      raise ArgumentError, "text must be a String, got #{text.inspect}" unless text.is_a?(String)
      raise ArgumentError, "bad color #{color.inspect}" unless color.is_a?(Color)

      Gosu.canvas&.push_text(text, x, y, @height * sy, text_width(text, sx), color, z)
    end

    def draw_text_rel(text, x, y, z, *rest)
      draw_text(text, x, y, z, 1.0, 1.0, rest.last.is_a?(Color) ? rest.last : Color::WHITE)
    end
  end

  # 画像は復号しない。PNG のヘッダから大きさだけ読み、
  # 描画は「そこに何かが居る」ことが分かる矩形として扱う。
  class Image
    attr_reader :width, :height

    def initialize(source, **_opts)
      if source.is_a?(String) && File.exist?(source)
        @width, @height = Image.png_size(source)
      else
        @width = 64
        @height = 64
      end
    end

    def self.png_size(path)
      head = File.binread(path, 24).to_s
      return [64, 64] unless head.bytesize >= 24 && head.byteslice(12, 4) == "IHDR"

      head.byteslice(16, 8).unpack("N2")
    rescue StandardError
      [64, 64]
    end

    def self.from_blob(width, height, _blob = nil, **_opts)
      image = allocate
      image.instance_variable_set(:@width, width)
      image.instance_variable_set(:@height, height)
      image
    end

    def to_blob = "\0" * (@width * @height * 4)

    def save(_path) = true

    def draw(x, y, z, scale_x = 1.0, scale_y = 1.0, color = Color::WHITE, _mode = :default)
      Gosu.note_draw!
      Gosu.check_numbers!("Image#draw", x, y, z, scale_x, scale_y)
      raise ArgumentError, "Image#draw: bad color #{color.inspect}" unless color.is_a?(Color)

      Gosu.canvas&.push_rect(x, y, @width * scale_x, @height * scale_y, color, z)
    end
  end

  # 音は鳴らさない。どのファイルが何回鳴らされたかだけ数えて、
  # テストから「この場面でこの音が鳴ったか」を確かめられるようにする。
  class Sample
    attr_reader :name

    def initialize(path)
      raise Errno::ENOENT, path unless File.exist?(path)

      @name = File.basename(path)
    end

    def play(_volume = 1.0, *_rest)
      Gosu.note_sound!(:sample, @name)
      self
    end
  end

  class Song
    attr_accessor :volume

    def initialize(path)
      raise Errno::ENOENT, path unless File.exist?(path)

      @volume  = 1.0
      @playing = false
    end

    def play(looping = false)
      @playing = true
      Gosu.note_sound!(:song, looping)
      self
    end

    def stop
      @playing = false
    end

    def playing? = @playing
  end

  class Window
    attr_accessor :caption
    attr_reader :width, :height

    def initialize(width, height, **opts)
      raise ArgumentError, "unknown option" if opts.key?(:not_a_real_option)

      @width = width
      @height = height
      @closed = false
      @fullscreen = opts.fetch(:fullscreen, false)
    end

    def fullscreen? = @fullscreen

    def fullscreen=(value)
      @fullscreen = value
    end

    def show; end

    def close
      @closed = true
    end

    def closed? = @closed

    def needs_cursor? = false

    def update; end

    def draw; end

    def button_down(_id); end
  end

  class << self
    # canvas を差すと、描画呼び出しがそこへ転送されて PNG に焼ける
    # （tools/render.rb が使う）。差さなければ回数を数えるだけ。
    attr_accessor :fake_ms, :held, :draw_calls, :canvas

    def milliseconds = (@fake_ms ||= 0)

    def button_down?(id)
      (@held ||= []).include?(id)
    end

    def default_font_name = "stub"

    def screen_width  = 1536
    def screen_height = 864

    def note_draw!
      @draw_calls = (@draw_calls || 0) + 1
    end

    def check_numbers!(where, *values)
      values.each do |v|
        raise ArgumentError, "#{where}: nil coordinate" if v.nil?
        raise ArgumentError, "#{where}: #{v.inspect} is not numeric" unless v.is_a?(Numeric)
        raise ArgumentError, "#{where}: NaN" if v.respond_to?(:nan?) && v.nan?
        raise ArgumentError, "#{where}: infinite" if v.respond_to?(:infinite?) && v.infinite?
      end
    end

    def draw_rect(x, y, w, h, color, z = 0, _mode = :default)
      note_draw!
      check_numbers!("draw_rect", x, y, w, h, z)
      raise ArgumentError, "draw_rect: bad color #{color.inspect}" unless color.is_a?(Color)

      @canvas&.push_rect(x, y, w, h, color, z)
    end

    def draw_quad(x1, y1, c1, x2, y2, c2, x3, y3, c3, x4, y4, c4, z = 0, _mode = :default)
      note_draw!
      check_numbers!("draw_quad", x1, y1, x2, y2, x3, y3, x4, y4, z)
      [c1, c2, c3, c4].each do |c|
        raise ArgumentError, "draw_quad: bad color #{c.inspect}" unless c.is_a?(Color)
      end

      @canvas&.push_quad(x1, y1, c1, x2, y2, c2, x3, y3, c3, x4, y4, c4, z)
    end

    def draw_line(x1, y1, c1, x2, y2, c2, z = 0, _mode = :default)
      note_draw!
      check_numbers!("draw_line", x1, y1, x2, y2, z)
    end

    # 鳴らされた音の記録。テストが「鳴ったか」を確かめるのに使う。
    def sound_log
      @sound_log ||= []
    end

    def note_sound!(kind, arg)
      sound_log << [kind, arg]
    end
  end
end
