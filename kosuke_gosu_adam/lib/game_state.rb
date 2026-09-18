# frozen_string_literal: true

require_relative '../config/balance'

module Kosuke
  # Gosuに依存しない進行ルール。画面やミニゲームはゲージを直接書き換えない。
  class GameState
    EPSILON = 1e-8
    attr_reader :phase, :day, :elapsed, :gauge, :active_seconds, :cooldowns,
                :activity, :difficulty, :last_result, :history, :successes,
                :attempts, :nap_count, :total_reduction, :resume_phase

    def initialize
      @phase = :title
      @day = 1
      @elapsed = @gauge = @active_seconds = @total_reduction = 0.0
      @cooldowns = Hash.new(0.0)
      @history = []
      @successes = @attempts = @nap_count = 0
      @daily_successes = 0
      @activity = @difficulty = @last_result = @resume_phase = nil
    end

    def start
      return false unless @phase == :title
      @phase = :room
      true
    end

    def running?
      %i[room mini].include?(@phase)
    end

    def remaining
      [Balance::DAY_SECONDS - @elapsed, 0.0].max
    end

    def rate
      Balance::DAILY_GAIN.fetch(@day - 1).to_f / Balance::DAY_SECONDS
    end

    def cooldown(id)
      [@cooldowns[id] - @active_seconds, 0.0].max
    end

    def available?(id)
      Balance::ACTIVITIES.key?(id) && cooldown(id) <= EPSILON &&
        remaining > Balance::MINI_SECONDS + EPSILON
    end

    # 戻り値は実際に経過した秒数。1000到達と日付境界を超えて処理しない。
    def advance(seconds)
      return 0.0 unless running?
      return 0.0 unless seconds.is_a?(Numeric) && seconds.finite? && seconds.positive?

      to_faint = [(Balance::MAX_GAUGE - @gauge) / rate, 0.0].max
      step = [seconds, remaining, to_faint].min
      @elapsed += step
      @active_seconds += step
      @gauge = [@gauge + rate * step, Balance::MAX_GAUGE].min

      # 同時なら必ず強制睡眠を優先。直後の成功報酬で蘇生させない。
      if @gauge >= Balance::MAX_GAUGE - EPSILON
        @gauge = Balance::MAX_GAUGE
        @phase = :game_over
      elsif @elapsed >= Balance::DAY_SECONDS - EPSILON
        @elapsed = Balance::DAY_SECONDS
        @phase = :day_clear
      end
      step
    end

    def choose_activity(id)
      return false unless @phase == :room && available?(id)
      @activity = id
      @phase = :choose
      true
    end

    def cancel_choice
      return false unless @phase == :choose
      @phase = :room
      true
    end

    def begin_minigame(difficulty)
      return false unless @phase == :choose && available?(@activity)
      return false unless Balance::DIFFICULTIES.key?(difficulty)
      @difficulty = difficulty
      @phase = :mini
      @attempts += 1
      true
    end

    def self.reward_for(difficulty, quality)
      rule = Balance::DIFFICULTIES.fetch(difficulty)
      quality = quality.is_a?(Numeric) && quality.finite? ? quality.clamp(0.0, 1.0) : 0.0
      return 0 if quality + EPSILON < rule[:threshold]
      ratio = ((quality - rule[:threshold]) / (1.0 - rule[:threshold])).clamp(0.0, 1.0)
      (rule[:min] + (rule[:max] - rule[:min]) * ratio).round
    end

    def finish_minigame(quality)
      return false unless @phase == :mini
      quality = quality.is_a?(Numeric) && quality.finite? ? quality.clamp(0.0, 1.0) : 0.0
      reward = self.class.reward_for(@difficulty, quality)
      actual = [@gauge, reward].min
      @gauge = [@gauge - reward, 0.0].max
      @total_reduction += actual
      if reward.positive?
        @successes += 1
        @daily_successes += 1
      end
      grade = if reward.zero? then 'MISS'
              elsif quality >= 0.92 then 'S'
              elsif quality >= 0.8 then 'A'
              else 'B'
              end
      @last_result = { quality: quality, reward: reward, actual: actual, grade: grade }
      @cooldowns[@activity] = @active_seconds + Balance::COOLDOWN_SECONDS
      @phase = :result
      true
    end

    def return_to_room
      return false unless @phase == :result
      @phase = :room
      true
    end

    def pause
      return false unless running?
      @resume_phase = @phase
      @phase = :paused
      true
    end

    def resume
      return false unless @phase == :paused
      @phase = @resume_phase
      @resume_phase = nil
      true
    end

    # 仮眠は1日の終了後に1回だけ。スキップも選べる。
    def complete_day(nap: true)
      return false unless @phase == :day_clear
      before = @gauge
      if nap
        @gauge = [@gauge - Balance::NAP_REDUCTION, 0.0].max
        @nap_count += 1
      end
      @history << { day: @day, before_nap: before, gauge: @gauge,
                    nap: nap, successes: @daily_successes }
      if @day == Balance::DAYS
        @phase = :victory
      else
        @day += 1
        @elapsed = 0.0
        @daily_successes = 0
        @cooldowns.clear
        @phase = :room
      end
      true
    end

    def clock
      return '24:00' if @phase == :victory
      minutes = (@elapsed / Balance::DAY_SECONDS * Balance::AWAKE_MINUTES).floor
      format('%02d:%02d', minutes / 60, minutes % 60)
    end
  end
end
