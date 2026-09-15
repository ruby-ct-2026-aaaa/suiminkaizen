# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../lib/minigames/dummy_minigame"

class DummyMinigameTest < Minitest::Test
  def test_implements_the_common_minigame_interface
    minigame = DummyMinigame.new(succeeds: true, gauge_reduction: 40)

    %i[update draw finished? succeeded? gauge_reduction].each do |method|
      assert_respond_to minigame, method
    end
  end

  def test_is_finished_immediately
    assert DummyMinigame.new(succeeds: false, gauge_reduction: 0).finished?
  end

  def test_succeeded_returns_the_given_result
    assert DummyMinigame.new(succeeds: true, gauge_reduction: 0).succeeded?
    refute DummyMinigame.new(succeeds: false, gauge_reduction: 0).succeeded?
  end

  def test_gauge_reduction_is_returned_only_on_success
    assert_equal 40, DummyMinigame.new(succeeds: true, gauge_reduction: 40).gauge_reduction
    assert_equal 0, DummyMinigame.new(succeeds: false, gauge_reduction: 40).gauge_reduction
  end

  def test_update_accepts_a_delta_time_and_does_nothing
    minigame = DummyMinigame.new(succeeds: true, gauge_reduction: 40)

    assert_nil minigame.update(0.016)
    assert_equal 40, minigame.gauge_reduction
  end
end
