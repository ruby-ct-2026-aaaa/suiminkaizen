# frozen_string_literal: true

require_relative 'base'

module Kosuke
  module Minigames
    class Training < Base
      ROUNDS = 5
      attr_reader :scores, :last_hit

      def initialize(difficulty, **options)
        super
        @scores = []
        @last_hit = -1.0
        @offset = @random.rand * Math::PI
      end

      def marker
        0.5 + 0.46 * Math.sin(@time * [3.1, 4.0, 4.9][level] + @offset)
      end

      def half_width
        [0.24, 0.19, 0.15][level]
      end

      def input(action)
        return if done? || action != :action || @time - @last_hit < 0.35
        score = (1.0 - (marker - 0.5).abs / half_width).clamp(0.0, 1.0)
        @scores << score
        @last_hit = @time
        @feedback = score >= 0.85 ? 'PERFECT!' : (score >= 0.55 ? 'GOOD' : 'MISS')
        emit(:training_hit, score: score)
        @finished = true if @scores.length >= ROUNDS
      end

      def quality
        @scores.sum / ROUNDS.to_f
      end
    end
  end
end
