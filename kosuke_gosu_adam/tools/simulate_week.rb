# frozen_string_literal: true

# 実際の移動、出題、入力、採点を通す自動プレイヤー。GUIやGosuは不要。
require 'json'
require_relative '../lib/game_state'
require_relative '../lib/minigames'
require_relative '../lib/world'

module Kosuke
  class WeekSimulation
    DT = 1.0 / 120

    def run
      state = GameState.new.tap(&:start)
      world = World.new
      records = []
      used = Hash.new(0)
      cursor = 0
      peak = 0.0
      while state.phase != :victory
        raise "Simulation lost on day #{state.day}" if state.phase == :game_over
        if state.phase == :day_clear
          records << { day: state.day, before_nap: state.gauge.round(2), successes: state.successes }
          state.complete_day
          next
        end
        if state.remaining <= Balance::MINI_SECONDS + 0.01
          state.advance(state.remaining)
          peak = [peak, state.gauge].max
          next
        end
        activity = Balance::ACTIVITIES.keys[cursor % 5]
        cursor += 1
        next unless state.available?(activity)
        world.go_to_station(activity)
        reached = nil
        2400.times do
          step = state.advance(DT)
          peak = [peak, state.gauge].max
          break unless state.phase == :room
          reached = world.update(step)
          raise 'Walked through furniture' unless world.walkable?(world.x, world.y)
          break if reached
        end
        next unless state.phase == :room && state.choose_activity(activity)
        raise 'Failed to arrive at station' unless reached == activity
        state.begin_minigame(:normal)
        game = Minigames::REGISTRY.fetch(activity).new(:normal, random: Random.new(41 + cursor))
        until game.done? || state.phase != :mini
          step = state.advance([DT, game.remaining].min)
          peak = [peak, state.gauge].max
          break unless state.phase == :mini
          if game.is_a?(Minigames::Bath)
            game.update(step, left: game.position > game.target + 0.012, right: game.position < game.target - 0.012)
          else
            game.update(step)
          end
          case game
          when Minigames::Training
            game.input(:action) if (game.marker - 0.5).abs < 0.01
          when Minigames::Supplement
            unless game.revealing? || game.done?
              choice = game.sequence[game.answers.length]
              game.input(%i[one two three four][choice])
            end
          when Minigames::Reaction
            target = game.active_target
            game.input(game.actions[target]) if target && game.time >= game.starts_at + 0.14
          end
        end
        state.finish_minigame(game.quality)
        used[activity] += 1
        raise "Failed #{activity}" unless state.last_result && state.last_result[:reward].positive?
        state.return_to_room
      end
      { result: state.phase, days: records, games: used, successes: state.successes,
        naps: state.nap_count, peak_gauge: peak.round(2), ending_gauge: state.gauge.round(2),
        note: '全5種類をふつうで巡回。移動と採点を通し、反応ゲームは約0.14秒で入力する自動プレイヤー。人間の難易度評価ではありません。' }
    end
  end
end

puts JSON.pretty_generate(Kosuke::WeekSimulation.new.run) if $PROGRAM_NAME == __FILE__
