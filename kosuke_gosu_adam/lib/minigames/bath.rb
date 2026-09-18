# frozen_string_literal: true

require_relative 'base'

module Kosuke
  module Minigames
    class Bath < Base
      attr_reader :position, :inside_seconds

      def initialize(difficulty, **options)
        super
        @position = 0.5
        @inside_seconds = 0.0
      end

      def target
        0.5 + Math.sin(@time * 0.75) * [0.06, 0.1, 0.14][level]
      end

      def half_width
        [0.19, 0.15, 0.12][level]
      end

      def inside?
        (@position - target).abs <= half_width
      end

      def update(dt, left: false, right: false)
        return if done?
        # 小刻みに積分し、フレームレートで得点が変わりにくくする。
        left_over = [dt, remaining].min
        while left_over > 1e-9
          step = [left_over, 1.0 / 120.0].min
          control = (right ? 1 : 0) - (left ? 1 : 0)
          drift = (0.08 + Math.sin(@time * 1.45) * 0.21 + Math.cos(@time * 0.8) * 0.12) * (1 + level * 0.23)
          @position = (@position + (drift + control * 0.63) * step).clamp(0.0, 1.0)
          @time += step
          @inside_seconds += step if inside?
          left_over -= step
        end
        @feedback = inside? ? 'KEEP!' : 'ゾーンへ戻そう'
        @finished = @time >= Balance::MINI_SECONDS - 1e-8
      end

      def quality
        (@inside_seconds / Balance::MINI_SECONDS).clamp(0.0, 1.0)
      end
    end
  end
end
