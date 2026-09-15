# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../lib/core/day_cycle"
require_relative "../../lib/core/sleep_gauge"
require_relative "../../lib/minigames/dummy_minigame"

class DayCycleTest < Minitest::Test
  # succeeded?が問い合わせられた回数を数えるスタブ。
  # 「その行動が処理されたかどうか」を確認するために使う。
  class SpyMinigame
    attr_reader :queried_count

    def initialize
      @queried_count = 0
    end

    def succeeded?
      @queried_count += 1
      false
    end

    def gauge_reduction
      0
    end
  end

  # ゲージを増やす方向の行動を模したスタブ。
  # ゲージの自然増加ロジックがまだ未実装のため、「行動の途中で1000に到達する」
  # 状況を負のgauge_reductionで再現する。
  class GaugeRaisingAction
    def initialize(amount)
      @amount = amount
    end

    def succeeded?
      true
    end

    def gauge_reduction
      -@amount
    end
  end

  def setup
    @gauge = SleepGauge.new(initial_value: 500)
    @day_cycle = DayCycle.new(@gauge)
  end

  def waits
    Array.new(DayCycle::ACTIONS_PER_DAY, :wait)
  end

  def test_all_wait_actions_consume_the_day_and_end_of_day_reduction_is_applied
    assert @day_cycle.play_day(waits)

    assert_equal 500 - SleepGauge::DAY_END_FIXED_REDUCTION, @gauge.value
    assert_equal 2, @gauge.current_day
    refute @gauge.game_over?
  end

  def test_all_failed_minigames_leave_the_gauge_untouched_until_end_of_day
    actions = Array.new(DayCycle::ACTIONS_PER_DAY) do
      DummyMinigame.new(succeeds: false, gauge_reduction: 80)
    end

    assert @day_cycle.play_day(actions)

    assert_equal 500 - SleepGauge::DAY_END_FIXED_REDUCTION, @gauge.value
    assert_equal 2, @gauge.current_day
  end

  def test_missing_actions_are_treated_as_wait
    assert @day_cycle.play_day([])

    assert_equal 500 - SleepGauge::DAY_END_FIXED_REDUCTION, @gauge.value
    assert_equal 2, @gauge.current_day
  end

  def test_successful_minigame_reduction_is_applied_to_the_gauge
    assert @day_cycle.play_day([DummyMinigame.new(succeeds: true, gauge_reduction: 100)])

    assert_equal 500 - 100 - SleepGauge::DAY_END_FIXED_REDUCTION, @gauge.value
  end

  def test_multiple_successful_minigame_reductions_accumulate
    reductions = [100, 50, 20]
    actions = reductions.map { |amount| DummyMinigame.new(succeeds: true, gauge_reduction: amount) }
    expected_reduction = reductions.take(DayCycle::ACTIONS_PER_DAY).sum

    assert @day_cycle.play_day(actions)

    assert_equal 500 - expected_reduction - SleepGauge::DAY_END_FIXED_REDUCTION, @gauge.value
  end

  def test_only_successful_minigames_reduce_the_gauge
    actions = [
      DummyMinigame.new(succeeds: true, gauge_reduction: 100),
      DummyMinigame.new(succeeds: false, gauge_reduction: 999),
      :wait
    ]

    assert @day_cycle.play_day(actions)

    assert_equal 500 - 100 - SleepGauge::DAY_END_FIXED_REDUCTION, @gauge.value
  end

  def test_reaching_1000_midway_skips_the_remaining_actions_and_end_of_day
    gauge = SleepGauge.new(initial_value: 600)
    day_cycle = DayCycle.new(gauge)
    skipped = [SpyMinigame.new, SpyMinigame.new]

    refute day_cycle.play_day([GaugeRaisingAction.new(400), *skipped])

    assert gauge.game_over?
    assert_equal 1000, gauge.value
    # end_of_day!が呼ばれていないので日は進まず、-30の固定処理も走らない。
    assert_equal 1, gauge.current_day
    refute gauge.cleared?
    skipped.each { |minigame| assert_equal 0, minigame.queried_count }
  end

  def test_actions_beyond_actions_per_day_are_ignored
    spy = SpyMinigame.new

    assert @day_cycle.play_day(waits + [spy])

    assert_equal 0, spy.queried_count
    assert_equal 500 - SleepGauge::DAY_END_FIXED_REDUCTION, @gauge.value
  end

  def test_seven_days_without_game_over_clears_the_game
    SleepGauge::TOTAL_DAYS.times { assert @day_cycle.play_day(waits) }

    assert @gauge.cleared?
    refute @gauge.game_over?
    assert_equal SleepGauge::TOTAL_DAYS, @gauge.current_day
  end
end
