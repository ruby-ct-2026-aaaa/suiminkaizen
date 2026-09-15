# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../lib/core/sleep_gauge"

class SleepGaugeTest < Minitest::Test
  def test_default_initial_value_is_zero
    gauge = SleepGauge.new
    assert_equal 0, gauge.value
  end

  def test_can_specify_initial_value
    gauge = SleepGauge.new(initial_value: 500)
    assert_equal 500, gauge.value
  end

  def test_apply_with_positive_delta_increases_value
    gauge = SleepGauge.new(initial_value: 100)
    gauge.apply(50)
    assert_equal 150, gauge.value
  end

  def test_apply_with_negative_delta_decreases_value
    gauge = SleepGauge.new(initial_value: 100)
    gauge.apply(-40)
    assert_equal 60, gauge.value
  end

  def test_apply_clamps_at_lower_bound_zero
    gauge = SleepGauge.new(initial_value: 10)
    gauge.apply(-999)
    assert_equal 0, gauge.value
  end

  def test_apply_reaching_1000_triggers_game_over
    gauge = SleepGauge.new(initial_value: 990)
    gauge.apply(10)
    assert gauge.game_over?
    assert_equal 1000, gauge.value
  end

  def test_apply_exceeding_1000_also_triggers_game_over_and_clamps_value
    gauge = SleepGauge.new(initial_value: 990)
    gauge.apply(500)
    assert gauge.game_over?
    assert_equal 1000, gauge.value
  end

  def test_value_is_frozen_after_game_over
    gauge = SleepGauge.new(initial_value: 990)
    gauge.apply(20)
    gauge.apply(-500)
    assert_equal 1000, gauge.value
    assert gauge.game_over?
  end

  def test_end_of_day_always_subtracts_30_regardless_of_current_value
    gauge = SleepGauge.new(initial_value: 5)
    gauge.end_of_day!
    assert_equal 0, gauge.value
  end

  def test_end_of_day_does_nothing_if_already_game_over
    gauge = SleepGauge.new(initial_value: 990)
    gauge.apply(50)
    gauge.end_of_day!
    assert_equal 1000, gauge.value
    assert gauge.game_over?
  end

  def test_end_of_day_before_day_seven_increments_day_and_does_not_clear
    gauge = SleepGauge.new(initial_value: 500)
    gauge.end_of_day!
    assert_equal 2, gauge.current_day
    refute gauge.cleared?
  end

  def test_end_of_day_on_day_seven_without_game_over_clears_the_game
    gauge = SleepGauge.new(initial_value: 100)
    6.times { gauge.end_of_day! }
    assert_equal 7, gauge.current_day
    refute gauge.cleared?

    gauge.end_of_day!
    assert gauge.cleared?
    refute gauge.game_over?
  end
end
