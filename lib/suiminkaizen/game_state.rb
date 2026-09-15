# frozen_string_literal: true

module Suiminkaizen
  # ミニゲーム1本の成績。
  Result = Struct.new(:kind, :title, :score, :target, :performance, :reward, :rank,
                      :max_combo, :level, :penalty, keyword_init: true) do
    # 上限で頭打ちにする前の、素の達成率。バランス調整の目安に使う。
    def raw_performance
      target.positive? ? score / target : 0.0
    end
  end

  # 1日ぶんの記録。
  DayRecord = Struct.new(:day, :start_gauge, :end_gauge, :results, keyword_init: true)

  # セーブデータに相当する、ゲーム全体の進行状態。
  class GameState
    attr_reader :day, :gauge, :schedule, :slot, :day_results, :days, :blink

    def initialize
      @gauge = SleepGauge.new
      @day   = 1
      @days  = []
      @blink = 0.0
      @blink_timer = 5.0
      @clock = 0.0
      start_day!
    end

    # --- 1日の進行 --------------------------------------------------------

    def start_day!
      @slot = 0
      @schedule = build_schedule
      @day_results = []
      @day_start_gauge = @gauge.value
    end

    def current_kind
      @schedule[@slot]
    end

    def record(result)
      @day_results << result
    end

    def advance_slot!
      @slot += 1
    end

    def day_finished?
      @slot >= Config::GAMES_PER_DAY
    end

    def last_day?
      @day >= Config::TOTAL_DAYS
    end

    # 1日の終わりに30分だけ眠る。減るのはたったの30。
    def sleep!
      actually = @gauge.reduce(Config::SLEEP_RECOVERY)
      @days << DayRecord.new(day: @day, start_gauge: @day_start_gauge,
                             end_gauge: @gauge.value, results: @day_results.dup)
      actually
    end

    def next_day!
      @day += 1
      start_day!
    end

    def day_start_gauge
      @day_start_gauge
    end

    # --- 集計 -------------------------------------------------------------

    def total_reduced
      @days.sum { |d| d.results.sum(&:reward) } +
        @day_results.sum(&:reward)
    end

    def all_results
      @days.flat_map(&:results) + @day_results
    end

    def average_performance
      list = all_results
      return 0.0 if list.empty?

      list.sum(&:performance) / list.size
    end

    def best_rank_count(rank)
      all_results.count { |r| r.rank == rank }
    end

    # --- まばたき演出 -----------------------------------------------------
    # ゲージが溜まるほど「まばたき」が長く・頻繁になる。
    # 画面が暗転しかけるので、数字を見ていなくても眠気が体感できる。

    def update_effects(dt)
      @clock += dt
      r = @gauge.ratio

      if @blink.positive?
        @blink -= dt * 3.0
        @blink = 0.0 if @blink.negative?
      else
        @blink_timer -= dt
        if @blink_timer <= 0.0
          @blink = 1.0 if r > 0.4
          @blink_timer = r > 0.4 ? (7.5 - 5.5 * r) + rand * 1.2 : 4.0 + rand * 3.0
        end
      end
    end

    # 0.0(開いている) .. 1.0(閉じきっている)
    def eyelid_closure
      return 0.0 if @blink <= 0.0

      Math.sin(Math::PI * @blink) * [@gauge.ratio * 1.15, 1.0].min
    end

    def clock
      @clock
    end

    private

    # 1日は6本。3種類を2回ずつこなす。
    # 同じ種目が連続しないように並べ、締めは必ず「夜のお風呂」にする。
    def build_schedule
      pool = Minigames::ALL_KINDS * 2
      pool.delete_at(pool.index(:bath))

      20.times do
        list = pool.shuffle + [:bath]
        return list unless list.each_cons(2).any? { |a, b| a == b }
      end
      pool.shuffle + [:bath]
    end
  end
end
