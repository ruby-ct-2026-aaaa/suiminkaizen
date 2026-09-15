# frozen_string_literal: true

module Suiminkaizen
  # 睡眠（気絶）ゲージ。
  #
  #   0     : 通常。健康そのもの。
  #   1000  : 気絶。ゲームオーバー。
  #
  # ゲームの緊張感はこの一本の数値だけが握っているので、
  # 加算・減算の入口をここへ集約し、範囲外に出ないことを保証する。
  class SleepGauge
    MAX = Config::MAX_GAUGE

    attr_reader :value, :peak

    def initialize(value = Config::START_GAUGE)
      @value = clamp(value.to_f)
      @peak  = @value
    end

    # 眠気が溜まる。実際に増えた量を返す。
    def add(amount)
      return 0.0 if amount <= 0.0

      before = @value
      @value = clamp(@value + amount)
      @peak = @value if @value > @peak
      @value - before
    end

    # ミニゲームの成功や睡眠で眠気が抜ける。実際に減った量を返す。
    def reduce(amount)
      return 0.0 if amount <= 0.0

      before = @value
      @value = clamp(@value - amount)
      before - @value
    end

    def ratio
      @value / MAX
    end

    def fainted?
      @value >= MAX
    end

    # 表示用。小数はプレイヤーには見せない。
    def to_i
      @value.round
    end

    def remaining
      MAX - @value
    end

    private

    def clamp(v)
      return 0.0 if v < 0.0
      return MAX if v > MAX

      v
    end
  end
end
