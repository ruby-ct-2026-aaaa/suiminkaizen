# frozen_string_literal: true

require_relative 'base'

module Kosuke
  module Minigames
    class Supplement < Base
      attr_reader :sequence, :answers

      def initialize(difficulty, **options)
        super
        @sequence = Array.new([3, 4, 5][level]) { @random.rand(4) }
        @answers = []
        @feedback = '順番を覚えよう'
      end

      def beat
        [0.75, 0.60, 0.48][level]
      end

      def reveal_end
        0.55 + @sequence.length * beat + 0.3
      end

      def revealing?
        @time < reveal_end
      end

      def lit_index
        t = @time - 0.55
        return nil if t.negative? || t >= @sequence.length * beat
        return nil if t % beat >= beat * 0.72
        @sequence[(t / beat).floor]
      end

      def input(action)
        return if done? || revealing?
        index = %i[one two three four].index(action)
        return unless index
        @answers << index
        emit(:memory_answer, correct: index == @sequence[@answers.length - 1])
        @feedback = "入力 #{@answers.length} / #{@sequence.length}"
        @finished = true if @answers.length >= @sequence.length
      end

      def update(dt, **options)
        super
        @feedback = '同じ順番で選ぼう' if !revealing? && @answers.empty?
      end

      def quality
        @answers.each_with_index.count { |value, index| value == @sequence[index] }.to_f / @sequence.length
      end
    end
  end
end
