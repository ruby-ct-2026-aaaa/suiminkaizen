# frozen_string_literal: true

class SleepGauge
  MIN_VALUE = 0
  MAX_VALUE = 1000
  TOTAL_DAYS = 7
  DAY_END_FIXED_REDUCTION = 30

  attr_reader :value, :current_day

  def initialize(initial_value: MIN_VALUE)
    @value = clamp(initial_value)
    @current_day = 1
    @game_over = false
    @cleared = false
  end

  def game_over?
    @game_over
  end

  def cleared?
    @cleared
  end

  def apply(delta)
    return if finished?

    new_value = @value + delta
    if new_value >= MAX_VALUE
      @value = MAX_VALUE
      @game_over = true
    else
      @value = clamp(new_value)
    end
  end

  def end_of_day!
    return if finished?

    @value = clamp(@value - DAY_END_FIXED_REDUCTION)

    if current_day == TOTAL_DAYS
      @cleared = true unless game_over?
    else
      @current_day += 1
    end
  end

  private

  def finished?
    game_over? || cleared?
  end

  def clamp(v)
    return MIN_VALUE if v < MIN_VALUE
    return MAX_VALUE if v > MAX_VALUE

    v
  end
end
