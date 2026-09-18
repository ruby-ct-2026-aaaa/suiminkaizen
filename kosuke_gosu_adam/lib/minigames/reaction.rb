# frozen_string_literal: true

require_relative 'base'

module Kosuke
  module Minigames
    # 出題時刻は固定。入力を連打しても次の問題を早送りできない。
    class Reaction < Base
      attr_reader :targets, :scores, :last_resolved_at

      def initialize(difficulty, **options)
        super
        @targets = Array.new(rounds) { @random.rand(target_count) }
        @scores = []
        @last_resolved_at = -2.0
        @feedback = '合図を待とう'
      end

      def starts_at(index = @scores.length)
        0.45 + index * interval
      end

      def active_target
        return nil if done? || @scores.length >= rounds || @time < starts_at
        @targets[@scores.length]
      end

      def urgency
        return 0.0 unless active_target
        ((@time - starts_at) / response_window).clamp(0.0, 1.0)
      end

      def resolve(score)
        @scores << score
        @last_resolved_at = @time
        @feedback = score.positive? ? 'CATCH!  ナイス反応' : 'MISS  次で取り返そう'
        emit(event_kind, score: score)
        @finished = true if @scores.length >= rounds
      end

      def input(action)
        target = active_target
        return unless target
        choice = actions.index(action)
        return unless choice
        score = choice == target ? (1.0 - urgency * 0.5).clamp(0.0, 1.0) : 0.0
        resolve(score)
      end

      def update(dt, **_options)
        return if done?
        @time = [@time + dt, Balance::MINI_SECONDS].min
        while @scores.length < rounds && @time >= starts_at + response_window
          resolve(0.0)
        end
        @finished = true if @time >= Balance::MINI_SECONDS - 1e-8
      end

      def quality
        @scores.sum / rounds.to_f
      end
    end
  end
end
