# frozen_string_literal: true

require_relative '../../config/balance'

module Kosuke
  module Minigames
    # input(:action/:one/...) と update(dt, left:, right:) が共通入口。
    # done? がtrueになったら quality をGameStateへ渡す。描画はWindow側。
    class Base
      attr_reader :difficulty, :time, :feedback, :event_serial, :last_event

      def initialize(difficulty, random: Random.new)
        @difficulty = difficulty
        @random = random
        @time = 0.0
        @finished = false
        @feedback = ''
        @event_serial = 0
        @last_event = nil
      end

      def level
        %i[easy normal hard].index(@difficulty) || 1
      end

      def update(dt, left: false, right: false)
        return if done?
        @time = [@time + dt, Balance::MINI_SECONDS].min
        @finished = true if @time >= Balance::MINI_SECONDS - 1e-8
      end

      def input(_action); end

      def emit(kind, **details)
        @event_serial += 1
        @last_event = { kind: kind, at: @time }.merge(details)
      end

      def done?
        @finished
      end

      def quality
        0.0
      end

      def remaining
        [Balance::MINI_SECONDS - @time, 0.0].max
      end
    end
  end
end
