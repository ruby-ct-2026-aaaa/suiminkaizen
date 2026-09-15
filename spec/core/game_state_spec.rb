# frozen_string_literal: true

require_relative "../spec_helper"

describe GameState do
  before do
    srand(1234)
    @state = GameState.new
  end

  it "DAY 1 のゲージ 0 からはじまる" do
    _(@state.day).must_equal 1
    _(@state.gauge.value).must_equal 0.0
    _(@state.slot).must_equal 0
  end

  describe "1日の予定" do
    it "6枠ある" do
      _(@state.schedule.size).must_equal Config::GAMES_PER_DAY
    end

    it "ヘッドマッサージ師がちょうど2回、2枠目以降に乱入する" do
      20.times do
        schedule = GameState.new.schedule
        _(schedule.count(:massage)).must_equal Config::MASSAGE_PER_DAY
        _(schedule.first).wont_equal :massage
      end
    end

    it "残りの枠は筋トレ・お風呂・サプリで埋まる" do
      base = @state.schedule.reject { |kind| kind == :massage }
      _(base.size).must_equal Config::GAMES_PER_DAY - Config::MASSAGE_PER_DAY
      base.each { |kind| _(Minigames::BASE_KINDS).must_include kind }
    end

    it "同じ種目が続けて並ばない" do
      20.times do
        base = GameState.new.schedule.reject { |kind| kind == :massage }
        _(base.each_cons(2).any? { |a, b| a == b }).must_equal false
      end
    end

    it "その日の最後の自前の種目は夜のお風呂になる" do
      20.times do
        base = GameState.new.schedule.reject { |kind| kind == :massage }
        _(base.last).must_equal :bath
      end
    end
  end

  describe "24時間時計" do
    it "1日は 00:30 にはじまる" do
      _(@state.clock_text).must_equal "00:30"
    end

    it "枠が進むと時計も進む" do
      @state.advance_slot!
      @state.advance_slot!
      _(@state.clock_text).must_equal "08:20"
    end

    it "枠の途中でも針が進む" do
      @state.slot_fraction = 0.5
      _(@state.clock_text).must_equal "02:28"
    end

    it "6枠すべて終えると 00:00 になる" do
      Config::GAMES_PER_DAY.times { @state.advance_slot! }
      _(@state.clock_text).must_equal "00:00"
    end

    it "就寝は 00:00 からで、30分眠ると 00:30 ＝ 翌日の始まりに戻る" do
      _(@state.sleep_clock_text(0.0)).must_equal "00:00"
      _(@state.sleep_clock_text(1.0)).must_equal "00:30"
      _(@state.sleep_clock_text(1.0)).must_equal Config.format_clock(Config::DAY_START_MINUTES)
    end
  end

  describe "1日の進行" do
    it "6枠こなすと1日が終わる" do
      (Config::GAMES_PER_DAY - 1).times do
        @state.advance_slot!
        _(@state.day_finished?).must_equal false
      end
      @state.advance_slot!
      _(@state.day_finished?).must_equal true
    end

    it "ヘッドマッサージの枠だけは断れない" do
      index = @state.schedule.index(:massage)
      index.times { @state.advance_slot! }
      _(@state.forced?).must_equal true
    end

    it "30分の睡眠でちょうど30だけ減る" do
      @state.gauge.add(500.0)
      _(@state.sleep!).must_equal Config::SLEEP_RECOVERY
      _(@state.gauge.value).must_equal 470.0
    end

    it "眠るとその日の記録が残る" do
      @state.gauge.add(200.0)
      @state.sleep!
      _(@state.days.size).must_equal 1
      _(@state.days.first.day).must_equal 1
      _(@state.days.first.end_gauge).must_equal 170.0
    end

    it "すでに眠気が浅ければ30も減らない" do
      @state.gauge.add(10.0)
      _(@state.sleep!).must_equal 10.0
      _(@state.gauge.value).must_equal 0.0
    end

    it "翌日になると予定が組み直される" do
      @state.advance_slot!
      @state.next_day!
      _(@state.day).must_equal 2
      _(@state.slot).must_equal 0
      _(@state.day_results).must_be_empty
      _(@state.clock_text).must_equal "00:30"
    end

    it "7日目が最終日" do
      6.times { @state.next_day! }
      _(@state.day).must_equal Config::TOTAL_DAYS
      _(@state.last_day?).must_equal true
    end
  end

  describe "「何もしない」を選んだ枠" do
    before { @result = @state.record_skip(:muscle) }

    it "記録として残る" do
      _(@state.day_results.size).must_equal 1
      _(@result.skipped).must_equal true
      _(@result.played?).must_equal false
    end

    it "削減もミスもゼロ" do
      _(@result.reward).must_equal 0.0
      _(@result.penalty).must_equal 0.0
    end

    it "達成率の平均には数えない" do
      @state.record(playing_result(0.8))
      _(@state.average_performance).must_be_close_to 0.8
      _(@state.skipped_count).must_equal 1
    end
  end

  describe "成績の集計" do
    it "その日の成績と通算の成績を分けて持つ" do
      @state.record(playing_result(0.9))
      _(@state.day_results.size).must_equal 1
      _(@state.all_results.size).must_equal 1
      _(@state.average_performance).must_be_close_to 0.9
      _(@state.best_rank_count("A")).must_equal 1
    end
  end

  describe "眠気の演出" do
    it "ゲージが浅いうちはまぶたが落ちてこない" do
      100.times { @state.update_effects(0.05) }
      _(@state.eyelid_closure).must_equal 0.0
    end

    it "ゲージが深いとまぶたが落ちる瞬間がある" do
      @state.gauge.add(900.0)
      closures = Array.new(600) do
        @state.update_effects(0.05)
        @state.eyelid_closure
      end
      _(closures.max).must_be :>, 0.3
    end
  end

  def playing_result(performance)
    Result.new(kind: :muscle, title: "筋トレ", score: 90.0, target: 100.0,
               performance: performance, reward: 90.0, rank: "A",
               max_combo: 5, level: 3, penalty: 12.0)
  end
end
