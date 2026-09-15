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

  describe "1日のメニュー" do
    it "3種目を2回ずつ、計6本になる" do
      _(@state.schedule.size).must_equal Config::GAMES_PER_DAY
      Minigames::ALL_KINDS.each do |kind|
        _(@state.schedule.count(kind)).must_equal 2
      end
    end

    it "同じ種目が連続しない" do
      20.times do
        schedule = GameState.new.schedule
        _(schedule.each_cons(2).any? { |a, b| a == b }).must_equal false
      end
    end

    it "1日の締めは必ず夜のお風呂になる" do
      20.times { _(GameState.new.schedule.last).must_equal :bath }
    end
  end

  describe "1日の進行" do
    it "6本こなすと1日が終わる" do
      5.times do
        @state.advance_slot!
        _(@state.day_finished?).must_equal false
      end
      @state.advance_slot!
      _(@state.day_finished?).must_equal true
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

    it "翌日になるとメニューが組み直される" do
      @state.advance_slot!
      @state.next_day!
      _(@state.day).must_equal 2
      _(@state.slot).must_equal 0
      _(@state.day_results).must_be_empty
    end

    it "7日目が最終日" do
      6.times { @state.next_day! }
      _(@state.day).must_equal Config::TOTAL_DAYS
      _(@state.last_day?).must_equal true
    end
  end

  describe "成績の集計" do
    it "その日の成績と通算の成績を分けて持つ" do
      result = Result.new(kind: :muscle, title: "筋トレ", score: 90.0, target: 100.0,
                          performance: 0.9, reward: 90.0, rank: "A",
                          max_combo: 5, level: 3, penalty: 12.0)
      @state.record(result)
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
end
