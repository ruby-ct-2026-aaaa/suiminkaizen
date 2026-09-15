# frozen_string_literal: true

require_relative "../spec_helper"

# ゲームバランスの前提が崩れていないかを見張るテスト。
# 数字そのものではなく「どういう関係になっているべきか」を書いている。
describe "ゲームバランス" do
  DAYS = (1..Config::TOTAL_DAYS)

  it "日が進むほど眠気は速く溜まる" do
    rates = DAYS.map { |d| Config.drowsiness_rate(d) }
    _(rates).must_equal rates.sort
    _(rates.uniq.size).must_equal rates.size
  end

  it "日が進むほど1本あたりの削減上限も増える" do
    rewards = DAYS.map { |d| Config.max_reward(d) }
    _(rewards).must_equal rewards.sort
    _(rewards.first).must_equal 100.0
  end

  it "ミニゲームの合間の眠気は本編より緩やか" do
    DAYS.each do |d|
      _(Config.idle_rate(d)).must_be :<, Config.drowsiness_rate(d)
    end
  end

  # 1日 = ミニゲーム6本 + その合間。だいたい 5 分に収まってほしい。
  it "1日はおよそ5分で終わる" do
    minigames = Config::GAMES_PER_DAY * Config::MINIGAME_SECONDS
    # 説明とリザルトの最短表示時間 + 朝夕の演出
    between = Config::GAMES_PER_DAY *
              (Scenes::MinigameIntro::MIN_READ + Scenes::MinigameResult::MIN_SHOW)
    ceremony = Scenes::DayIntro::MIN_SHOW + 1.4 + Scenes::Sleep::TOTAL
    total = minigames + between + ceremony

    _(total).must_be :>, 4.5 * 60
    _(total).must_be :<, 5.5 * 60
  end

  it "7日クリアはおよそ35分になる" do
    per_day = Config::GAMES_PER_DAY * (Config::MINIGAME_SECONDS + 4.0) + 12.0
    week = per_day * Config::TOTAL_DAYS
    _(week / 60.0).must_be_close_to 35.0, 4.0
  end

  # 1日ぶんに自然に溜まる眠気（ミニゲーム中＋その合間）。
  def passive_gain(day)
    Config.drowsiness_rate(day) * Config::GAMES_PER_DAY * Config::MINIGAME_SECONDS +
      Config.idle_rate(day) * 32.0
  end

  # ミスをまったくしなかった場合に、収支が釣り合う達成率。
  def break_even(day, penalty)
    (passive_gain(day) + penalty - Config::SLEEP_RECOVERY) /
      (Config.max_reward(day) * Config::GAMES_PER_DAY)
  end

  # 設計の要。ミスを出さずに丁寧にこなせば達成率6割でも粘れるが、
  # ミスを重ねると9割近い達成率を求められるようになる、という傾斜。
  it "ミスさえなければ達成率6割前後で踏みとどまれる" do
    DAYS.each do |day|
      _(break_even(day, 0.0)).must_be_close_to 0.58, 0.08,
                                              "DAY#{day} の損益分岐が想定とずれている"
    end
  end

  it "1日に200ぶんのミスを出すと9割近い達成率が必要になる" do
    DAYS.each do |day|
      _(break_even(day, 200.0)).must_be_close_to 0.86, 0.10,
                                                "DAY#{day} でミスの重みが想定とずれている"
    end
  end

  it "後半の日ほど要求される達成率がじりじり上がる" do
    curve = DAYS.map { |d| break_even(d, 0.0) }
    _(curve).must_equal curve.sort
    _(curve.last).must_be :>, curve.first
  end

  # 削減量の上限は日ごとに増えるので、数字の上での要求はゆるやかにしか上がらない。
  # 終盤のきつさは、ミニゲームそのものが速く・シビアになることで出している。
  it "後半の日ほどミニゲーム自体が難しくなる" do
    levels = DAYS.map { |d| Config.difficulty(d) }
    _(levels).must_equal levels.sort
    _(levels.first).must_equal 1.0
    _(levels.last).must_be :>, 1.5
  end

  it "完璧にこなせば1日でゲージは確実に減る" do
    DAYS.each do |day|
      gained = Config.drowsiness_rate(day) * Config::GAMES_PER_DAY * Config::MINIGAME_SECONDS
      reduced = Config.max_reward(day) * Config::MAX_PERFORMANCE * Config::GAMES_PER_DAY
      _(reduced).must_be :>, gained
    end
  end

  it "1日放置したくらいでは気絶しない" do
    _(passive_gain(1)).must_be :<, Config::MAX_GAUGE
  end

  it "何もしないまま3日は絶対にもたない" do
    total = (1..3).sum { |d| passive_gain(d) - Config::SLEEP_RECOVERY }
    _(total).must_be :>, Config::MAX_GAUGE
  end

  describe "ミニゲーム" do
    it "3種目そろっていて、それぞれ目標スコアを持つ" do
      _(Minigames::ALL_KINDS.sort).must_equal %i[bath muscle supplement]
      Minigames::ALL_KINDS.each do |kind|
        klass = Minigames.klass(kind)
        _(klass.target_score).must_be :>, 0
        _(klass.title).wont_be_empty
        _(klass.rules).wont_be_empty
        _(klass.controls).wont_be_empty
        _(Stage::THEMES).must_include klass.theme
      end
    end

    it "達成率からランクが決まる" do
      base = Minigames::Muscle.allocate
      _(base.rank_for(1.20)).must_equal "S"
      _(base.rank_for(1.00)).must_equal "A"
      _(base.rank_for(0.80)).must_equal "B"
      _(base.rank_for(0.60)).must_equal "C"
      _(base.rank_for(0.10)).must_equal "D"
    end
  end
end
