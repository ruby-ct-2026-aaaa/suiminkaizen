# frozen_string_literal: true

module Kosuke
  class Hallucinations
    attr_reader :level, :time, :suppression, :cooldown, :flee

    def initialize
      @level = 0
      @time = @suppression = @cooldown = @flee = 0.0
    end

    def self.level_for(gauge)
      return 3 if gauge >= 900
      return 2 if gauge >= 750
      gauge >= 550 ? 1 : 0
    end

    def update(dt, gauge:)
      @level = self.class.level_for(gauge)
      @time += dt
      @suppression = [@suppression - dt, 0.0].max
      @cooldown = [@cooldown - dt, 0.0].max
      @flee = [@flee - dt, 0.0].max
    end

    def visible?
      @level.positive? && (@suppression.zero? || @flee.positive?)
    end

    # 演出だけを追い払う。睡眠ゲージや成績は変わらない。
    def repel
      return false unless visible? && @cooldown.zero?
      @flee = 0.8
      @suppression = 4.5
      @cooldown = 6.0
      true
    end
  end
end
