# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/game_state'
require_relative '../lib/minigames'
require_relative '../lib/world'
require_relative '../lib/stream_feed'
require_relative '../lib/hallucinations'
require_relative '../lib/animation'
require_relative '../tools/simulate_week'

class GameRulesTest < Minitest::Test
  def new_game
    Kosuke::GameState.new.tap(&:start)
  end

  def play(state, activity = :training, difficulty = :normal, quality = 1.0)
    assert state.choose_activity(activity)
    assert state.begin_minigame(difficulty)
    state.advance(8)
    assert state.finish_minigame(quality)
    state.return_to_room
  end

  def test_initial_and_clock
    state = new_game
    assert_equal 0, state.gauge
    assert_equal '00:00', state.clock
    state.advance(45)
    assert_equal '11:45', state.clock
    assert_in_delta 487.5, state.gauge
  end

  def test_daily_nap_is_30_and_cannot_be_repeated
    state = new_game
    refute state.complete_day
    state.advance(90)
    assert_equal :day_clear, state.phase
    assert_equal '23:30', state.clock
    assert state.complete_day(nap: true)
    assert_equal 2, state.day
    assert_in_delta 945, state.gauge
    refute state.complete_day
    assert_equal 1, state.nap_count
  end

  def test_nap_can_be_skipped
    state = new_game
    state.advance(90)
    state.complete_day(nap: false)
    assert_in_delta 975, state.gauge
    assert_equal 0, state.nap_count
  end

  def test_inaction_loses_on_day_two_and_time_stops
    state = new_game
    state.advance(90)
    state.complete_day
    state.advance(90)
    assert_equal :game_over, state.phase
    assert_equal 1000, state.gauge
    assert_in_delta 55.0 / (1050.0 / 90), state.elapsed
    elapsed = state.elapsed
    state.advance(100)
    assert_equal elapsed, state.elapsed
    refute state.finish_minigame(1)
    refute state.complete_day
  end

  def test_faint_wins_over_simultaneous_day_clear_and_reward
    state = new_game
    state.instance_variable_set(:@gauge, 25.0)
    state.advance(90)
    assert_equal :game_over, state.phase
    state = new_game
    state.instance_variable_set(:@gauge, 999.0)
    state.choose_activity(:training)
    state.begin_minigame(:hard)
    state.advance(0.2)
    refute state.finish_minigame(1)
    assert_equal :game_over, state.phase
  end

  def test_reduction_stays_at_zero_and_requires_success
    state = new_game
    play(state, :training, :hard, 1)
    assert_equal 0, state.gauge
    assert_equal 300, state.last_result[:reward]
    assert_operator state.last_result[:actual], :<, 300
    state.advance(1)
    before = state.gauge
    play(state, :bath, :hard, 0)
    assert_operator state.gauge, :>, before
    assert_equal 0, state.last_result[:reward]
    assert_equal 1, state.successes
  end

  def test_rewards_follow_difficulty_and_quality
    rules = Kosuke::Balance::DIFFICULTIES
    rules.each do |level, rule|
      assert_equal 0, Kosuke::GameState.reward_for(level, rule[:threshold] - 0.01)
      assert_equal rule[:min], Kosuke::GameState.reward_for(level, rule[:threshold])
      assert_equal rule[:max], Kosuke::GameState.reward_for(level, 1)
      assert_equal 0, Kosuke::GameState.reward_for(level, Float::NAN)
    end
    rewards = rules.keys.map { |level| Kosuke::GameState.reward_for(level, 0.9) }
    assert_equal rewards.sort, rewards
    assert_equal 3, rewards.uniq.length
  end

  def test_menus_and_pause_do_not_advance_gauge_or_cooldowns
    state = new_game
    state.choose_activity(:training)
    state.advance(100)
    assert_equal 0, state.elapsed
    state.begin_minigame(:easy)
    state.advance(2)
    state.pause
    gauge = state.gauge
    state.advance(100)
    assert_equal gauge, state.gauge
    state.resume
    assert_equal :mini, state.phase
    state.finish_minigame(1)
    waiting = state.cooldown(:training)
    state.advance(100)
    assert_equal waiting, state.cooldown(:training)
    state.return_to_room
    refute state.choose_activity(:training)
    state.advance(waiting)
    assert state.choose_activity(:training)
  end

  def test_last_eight_seconds_cannot_start_an_unfinishable_game
    state = new_game
    state.advance(82)
    refute state.choose_activity(:training)
    state.advance(8)
    assert_equal :day_clear, state.phase
  end

  def test_time_is_independent_of_frame_rate
    whole = new_game
    pieces = new_game
    whole.advance(60)
    3600.times { pieces.advance(1.0 / 60) }
    assert_in_delta whole.gauge, pieces.gauge, 1e-6
    assert_in_delta whole.elapsed, pieces.elapsed, 1e-6
  end

  def test_full_week_is_winnable_and_ends_only_after_day_seven
    state = new_game
    7.times do |day|
      7.times do |i|
        state.advance(3.5)
        play(state, Kosuke::Balance::ACTIVITIES.keys[i % 5])
      end
      state.advance(state.remaining)
      assert_equal :day_clear, state.phase
      state.complete_day
      assert_equal(day == 6 ? :victory : :room, state.phase)
    end
    assert_equal 7, state.day
    assert_equal 7, state.history.length
    assert_equal '24:00', state.clock
    assert_equal 7, state.nap_count
    refute state.complete_day
    assert_equal 49, state.successes
  end

  def test_nap_has_zero_floor
    state = new_game
    state.advance(90)
    state.instance_variable_set(:@gauge, 12.0)
    state.complete_day
    assert_equal 0, state.gauge
  end

  def test_real_games_with_travel_can_survive_a_week
    result = Kosuke::WeekSimulation.new.run
    assert_equal :victory, result[:result]
    assert_equal 7, result[:days].size
    assert_equal 7, result[:naps]
    assert_equal Kosuke::Balance::ACTIVITIES.keys.sort, result[:games].keys.sort
    assert_operator result[:peak_gauge], :<, 1000
  end
end

class MinigamesTest < Minitest::Test
  def test_training_perfect_timing_can_clear_each_difficulty
    %i[easy normal hard].each do |level|
      game = Kosuke::Minigames::Training.new(level, random: Random.new(9))
      until game.done?
        game.input(:action) if (game.marker - 0.5).abs < 0.008
        game.update(1.0 / 240)
      end
      assert_equal 5, game.scores.length
      assert_operator game.quality, :>, 0.92
    end
  end

  def test_training_cannot_be_cleared_by_one_instantaneous_burst
    game = Kosuke::Minigames::Training.new(:easy, random: Random.new(1))
    100.times { game.input(:action) }
    assert_equal 1, game.scores.length
    game.update(8)
    assert game.done?
    assert_operator game.quality, :<=, 0.2
  end

  def test_bath_can_be_controlled_and_is_not_a_free_clear
    %i[easy normal hard].each do |level|
      game = Kosuke::Minigames::Bath.new(level)
      idle = Kosuke::Minigames::Bath.new(level)
      until game.done?
        game.update(1.0 / 120, left: game.position > game.target + 0.012,
                    right: game.position < game.target - 0.012)
        idle.update(1.0 / 120)
      end
      assert_operator game.quality, :>, 0.95
      assert_operator idle.quality, :<, Kosuke::Balance::DIFFICULTIES[level][:threshold]
      assert game.position.between?(0, 1)
    end
  end

  def test_memory_ignores_input_during_reveal_and_scores_the_order
    %i[easy normal hard].each do |level|
      game = Kosuke::Minigames::Supplement.new(level, random: Random.new(11))
      game.input(:one)
      assert_empty game.answers
      game.update(game.reveal_end + 0.01)
      game.sequence.each { |item| game.input(%i[one two three four][item]) }
      assert game.done?
      assert_equal 1.0, game.quality
      game = Kosuke::Minigames::Supplement.new(level, random: Random.new(11))
      game.update(game.reveal_end + 0.01)
      game.sequence.each { |item| game.input(%i[one two three four][(item + 1) % 4]) }
      assert_equal 0.0, game.quality
    end
  end

  def test_all_minigames_time_out
    Kosuke::Minigames::REGISTRY.each_value do |klass|
      game = klass.new(:normal)
      game.update(8)
      assert game.done?
      assert game.quality.between?(0, 1)
    end
  end

  def test_reaction_games_reward_quick_correct_answers_at_all_levels
    [Kosuke::Minigames::Massage, Kosuke::Minigames::Camera].each do |klass|
      %i[easy normal hard].each do |difficulty|
        game = klass.new(difficulty, random: Random.new(17))
        until game.done?
          game.update(1.0 / 120)
          target = game.active_target
          game.input(game.actions[target]) if target && game.time >= game.starts_at + 0.12
        end
        assert_equal game.rounds, game.scores.length
        assert_operator game.quality, :>, 0.89
        assert_operator Kosuke::GameState.reward_for(difficulty, game.quality), :>, 0
        assert_operator game.time, :<, Kosuke::Balance::MINI_SECONDS
      end
    end
  end

  def test_reaction_games_reject_early_spam_and_wrong_answers
    [Kosuke::Minigames::Massage, Kosuke::Minigames::Camera].each do |klass|
      game = klass.new(:normal, random: Random.new(22))
      20.times { game.actions.each { |action| game.input(action) } }
      assert_empty game.scores
      game.update(0.46)
      target = game.active_target
      game.input(game.actions[(target + 1) % game.target_count])
      20.times { game.actions.each { |action| game.input(action) } }
      assert_equal [0.0], game.scores
      game.update(8)
      assert game.done?
      assert_equal game.rounds, game.scores.length
      assert_equal 0.0, game.quality
    end
  end
end

class WorldTest < Minitest::Test
  def test_projection_round_trip
    [[0, 0], [3.2, 1.7], [9.5, 8.5]].each do |x, y|
      rx, ry = Kosuke::World.unproject(*Kosuke::World.project(x, y))
      assert_in_delta x, rx
      assert_in_delta y, ry
    end
  end

  def test_all_equipment_is_reachable_without_crossing_furniture
    world = Kosuke::World.new
    %i[training bath supplement massage camera training].each do |id|
      world.go_to_station(id)
      reached = nil
      1800.times do
        reached = world.update(1.0 / 60)
        assert world.walkable?(world.x, world.y)
        break if reached
      end
      assert_equal id, reached
      assert_equal id, world.nearby
    end
  end

  def test_invalid_destination_does_not_pass_through_obstacles
    world = Kosuke::World.new
    refute world.go_to(1.5, 1.5)
    300.times { world.update(1.0 / 60, horizontal: -1, vertical: -1) }
    assert world.walkable?(world.x, world.y)
  end
end

class StreamPresentationTest < Minitest::Test
  def test_comment_flow_moves_and_queues_stay_bounded
    feed = Kosuke::StreamFeed.new(random: Random.new(1))
    feed.update(0)
    first = feed.active.first
    x = first[:x]
    feed.update(0.5)
    assert_operator first[:x], :<, x
    80.times { feed.emit(:training_hit) }
    assert_operator feed.pending.size, :<=, 20
    assert_operator feed.history.size, :<=, 16
    100.times do
      feed.update(0.1)
      assert_operator feed.active.size, :<=, 12
      feed.active.group_by { |c| c[:lane] }.each_value do |lane|
        lane.sort_by { |c| c[:x] }.each_cons(2) do |a, b|
          assert_operator a[:x] + a[:width], :<, b[:x]
        end
      end
    end
    feed.viewport(290)
    assert_empty feed.active
    feed.update(0)
    assert feed.active.all? { |c| c[:x] == 298 }
  end

  def test_events_have_different_success_and_miss_responses
    feed = Kosuke::StreamFeed.new
    feed.emit(:camera_ok)
    assert_equal 'カメラ係仕事した', feed.history.last[:text]
    feed.emit(:camera_miss)
    assert_equal :camera_miss, feed.history.last[:event]
    refute_equal 'カメラ係仕事した', feed.history.last[:text]
    refute feed.emit(:camera_miss, throttle: 1)
    feed.begin_activity(:massage)
    assert feed.pending.all? { |entry| entry[:event] == :massage }
    assert_empty feed.active
  end

  def test_kuiya_thresholds_recovery_and_number_nine
    ghosts = Kosuke::Hallucinations.new
    [[0, 0], [549.99, 0], [550, 1], [749.99, 1], [750, 2], [900, 3]].each do |gauge, level|
      ghosts.update(0, gauge: gauge)
      assert_equal level, ghosts.level
    end
    assert ghosts.visible?
    assert ghosts.repel
    refute ghosts.repel
    ghosts.update(1, gauge: 910)
    refute ghosts.visible?
    ghosts.update(3.6, gauge: 920)
    assert ghosts.visible?
    refute ghosts.repel
    ghosts.update(1.4, gauge: 930)
    assert ghosts.repel
    ghosts.update(0, gauge: 300)
    refute ghosts.visible?
  end

  def test_sprite_frames_follow_action_events
    game = Kosuke::Minigames::Training.new(:normal)
    game.instance_variable_set(:@time, 0.1)
    game.emit(:training_hit, score: 1)
    assert_includes [2, 3], Kosuke::Animation.frame(:training, game)
    game.emit(:training_hit, score: 0)
    assert_equal 1, Kosuke::Animation.frame(:training, game)
    game = Kosuke::Minigames::Bath.new(:normal)
    frames = 30.times.map do
      game.update(0.05)
      Kosuke::Animation.frame(:bath, game)
    end
    assert_equal [0, 1, 2, 3], frames.uniq.sort
    %i[massage camera].each do |kind|
      game = Kosuke::Minigames::REGISTRY[kind].new(:normal)
      game.update(0.46)
      assert_equal 1, Kosuke::Animation.frame(kind, game)
      game.input(game.actions[game.active_target])
      assert_includes [2, 3], Kosuke::Animation.frame(kind, game)
    end
  end
end
