# frozen_string_literal: true

module Suiminkaizen
  # ミニゲーム1本の成績。skipped が真なら「やらなかった」枠。
  Result = Struct.new(:kind, :title, :score, :target, :performance, :reward, :rank,
                      :max_combo, :level, :penalty, :skipped, keyword_init: true) do
    # 上限で頭打ちにする前の、素の達成率。バランス調整の目安に使う。
    def raw_performance
      target.to_f.positive? ? score / target : 0.0
    end

    def played? = !skipped
  end

  # 1日ぶんの記録。
  DayRecord = Struct.new(:day, :start_gauge, :end_gauge, :results, keyword_init: true)

  # セーブデータに相当する、ゲーム全体の進行状態。
  class GameState
    # 進行中の枠の進み具合（0.0〜1.0）。24時間時計の針を進めるのに使う。
    attr_accessor :slot_fraction
    attr_reader :day, :gauge, :schedule, :slot, :day_results, :days, :blink,
                :difficulty

    def initialize(difficulty = Config.default_difficulty)
      @difficulty = difficulty
      # ゲームは 00:00 から。まず30分だけ眠って、00:30 に1日がはじまる。
      @opening = true
      @gauge = SleepGauge.new
      @day   = 1
      @days  = []
      @blink = 0.0
      @blink_timer = 5.0
      @clock = 0.0
      start_day!
    end

    # --- 眠気の進む速さ ---------------------------------------------------
    # 選んだ難易度のぶんだけ、そのまま倍率がかかる。

    def difficulty_scale
      @difficulty.fetch(:scale)
    end

    def difficulty_label
      @difficulty.fetch(:label)
    end

    # 乱入してきたクイヤたち。居座られているあいだ眠気が速くなる。
    def kuiya
      @kuiya ||= Kuiya::Swarm.new
    end

    # この難易度で同時に湧く上限。0 なら出てこない。
    def kuiya_limit
      @difficulty.fetch(:kuiya, 0)
    end

    def drowsiness_rate
      Config.drowsiness_rate(@day) * difficulty_scale * kuiya.drowsiness_multiplier
    end

    def idle_rate
      Config.idle_rate(@day) * difficulty_scale * kuiya.drowsiness_multiplier
    end

    # --- 1日の進行 --------------------------------------------------------

    def start_day!
      kuiya.clear!
      @slot = 0
      @slot_fraction = 0.0
      @schedule = build_schedule
      @day_results = []
      @day_start_gauge = @gauge.value
    end

    def current_kind
      @schedule[@slot]
    end

    # ヘッドマッサージ師の乱入は断れない。
    def forced?
      current_kind == :massage
    end

    def record(result)
      @day_results << result
    end

    # 「何もしない」を選んだ枠。削減はないが、ミスもしない。
    def record_skip(kind)
      result = Result.new(kind: kind, title: Minigames.klass(kind).title,
                          score: 0.0, target: 0.0, performance: 0.0,
                          reward: 0.0, rank: "-", max_combo: 0, level: 0,
                          penalty: 0.0, skipped: true)
      @day_results << result
      result
    end

    def advance_slot!
      @slot += 1
      @slot_fraction = 0.0
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

    # --- 24時間時計 -------------------------------------------------------
    # 1日は 00:30 に始まり、4枠を消化して 00:00 に終わる。
    # 枠が進むほど時計も進むので、「やらない」を選ぶと時間だけが飛んでいく。

    # 開幕の30分睡眠がまだのあいだ。時計は 00:00 で止まっている。
    def opening? = @opening

    def finish_opening_sleep!
      @opening = false
    end

    def clock_minutes
      return 0.0 if @opening

      progress = @slot + (@slot_fraction || 0.0)
      progress = Config::GAMES_PER_DAY if progress > Config::GAMES_PER_DAY
      Config.clock_minutes(progress)
    end

    def clock_text
      Config.format_clock(clock_minutes)
    end

    # 就寝中だけは 00:00 から 00:30 へ、別枠で進める。
    def sleep_clock_text(progress)
      Config.format_clock(Config.clock_minutes(Config::GAMES_PER_DAY) +
                          Config::SLEEP_RECOVERY * progress)
    end

    # --- 集計 -------------------------------------------------------------

    def all_results
      @days.flat_map(&:results) + @day_results
    end

    def played_results
      all_results.select(&:played?)
    end

    def skipped_count
      all_results.count(&:skipped)
    end

    def average_performance
      list = played_results
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

    # 1日は4枠。うち1枠はヘッドマッサージ師の乱入で、位置はその日ごとに変わる。
    # 残りの枠は :choice ＝ その場で3つの選択肢から自分で種目を選ぶ枠。
    def build_schedule
      slots = Array.new(Config::GAMES_PER_DAY, :choice)

      # 初手からの乱入は避ける。2枠目以降に不意に割り込んでくる。
      (1...Config::GAMES_PER_DAY).to_a.sample(Config::MASSAGE_PER_DAY)
                                 .each { |i| slots[i] = :massage }
      slots
    end
  end
end
