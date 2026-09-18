# frozen_string_literal: true

require_relative 'reaction'

module Kosuke
  module Minigames
    class Camera < Reaction
      def rounds
        [4, 5, 6][level]
      end

      def target_count
        6
      end

      def interval
        [1.6, 1.3, 1.1][level]
      end

      def response_window
        [1.15, 0.92, 0.7][level]
      end

      def actions
        %i[one two three four five six]
      end

      def event_kind
        :camera_catch
      end
    end
  end
end
