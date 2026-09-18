# frozen_string_literal: true

require_relative 'reaction'

module Kosuke
  module Minigames
    class Massage < Reaction
      def rounds
        [5, 6, 7][level]
      end

      def target_count
        2
      end

      def interval
        [1.35, 1.05, 0.88][level]
      end

      def response_window
        [0.95, 0.8, 0.65][level]
      end

      def actions
        %i[left right]
      end

      def event_kind
        :massage_reaction
      end
    end
  end
end
