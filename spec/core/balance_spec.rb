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

  it "日が進むほど1枠あたりの削減上限も増える" do
    rewards = DAYS.map { |d| Config.max_reward(d) }
    _(rewards).must_equal rewards.sort
  end

  it "ミニゲームの合間の眠気は本編より緩やか" do
    DAYS.each do |d|
      _(Config.idle_rate(d)).must_be :<, Config.drowsiness_rate(d)
    end
  end

  # 1日 = 6枠 + 朝夕の演出。説明を最後まで読んでおよそ3分に収まってほしい。
  it "1日はおよそ3分で終わる" do
    minigames = Config::GAMES_PER_DAY * Config::MINIGAME_SECONDS
    between   = Config::GAMES_PER_DAY *
                (Scenes::MinigameIntro::READ_TIME + Scenes::MinigameResult::AUTO_NEXT)
    ceremony  = Scenes::DayIntro::AUTO_START + Scenes::DayResult::MIN_SHOW +
                Scenes::Sleep::TOTAL
    total = minigames + between + ceremony

    _(total).must_be :>, 2.6 * 60
    _(total).must_be :<, 3.4 * 60
  end

  # 説明を飛ばすか読むかで所要時間は変わる。その幅ごと 20 分前後に収める。
  it "7日クリアは、飛ばしても読んでも20分前後になる" do
    minigames = Config::GAMES_PER_DAY * Config::MINIGAME_SECONDS
    skimming  = Config::GAMES_PER_DAY *
                (Scenes::MinigameIntro::MIN_READ + Scenes::MinigameResult::MIN_SHOW)
    reading   = Config::GAMES_PER_DAY *
                (Scenes::MinigameIntro::READ_TIME + Scenes::MinigameResult::AUTO_NEXT)

    fastest = (minigames + skimming + 12.0) * Config::TOTAL_DAYS / 60.0
    slowest = (minigames + reading + 12.0) * Config::TOTAL_DAYS / 60.0

    _(fastest).must_be :>, 15.0
    _(slowest).must_be :<, 25.0
  end

  it "説明画面は6秒ある" do
    _(Scenes::MinigameIntro::READ_TIME).must_equal 6.0
  end

  # 1日ぶんに自然に溜まる眠気（ミニゲーム中＋その合間）。
  def passive_gain(day)
    Config.drowsiness_rate(day) * Config::GAMES_PER_DAY * Config::MINIGAME_SECONDS +
      Config.idle_rate(day) * 42.0
  end

  # ミスの量ごとに、収支が釣り合う達成率。
  def break_even(day, penalty)
    (passive_gain(day) + penalty - Config::SLEEP_RECOVERY) /
      (Config.max_reward(day) * Config::GAMES_PER_DAY)
  end

  # 設計の要。眠気の進みを3倍にしたぶん、要求される達成率も高い。
  it "ミスさえなければ達成率75%前後で踏みとどまれる" do
    DAYS.each do |day|
      _(break_even(day, 0.0)).must_be_close_to 0.75, 0.10,
                                              "DAY#{day} の損益分岐が想定とずれている"
    end
  end

  it "1日に200ぶんのミスを出すと達成率はほぼ満点が要る" do
    DAYS.each do |day|
      _(break_even(day, 200.0)).must_be :>, 0.80,
                                        "DAY#{day} でミスが軽すぎる"
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
      reduced = Config.max_reward(day) * Config::MAX_PERFORMANCE * Config::GAMES_PER_DAY
      _(reduced).must_be :>, passive_gain(day)
    end
  end

  it "1日放置しただけでは、かろうじて気絶しない" do
    _(passive_gain(1)).must_be :<, Config::MAX_GAUGE
    _(passive_gain(1)).must_be :>, Config::MAX_GAUGE * 0.5
  end

  it "何もしないまま2日はもたない" do
    total = (1..2).sum { |d| passive_gain(d) - Config::SLEEP_RECOVERY }
    _(total).must_be :>, Config::MAX_GAUGE
  end

  describe "ミニゲーム" do
    it "4種類あり、うち3種類は自分で選べる" do
      _(Minigames::ALL_KINDS.sort).must_equal %i[bath massage muscle supplement]
      _(Minigames::BASE_KINDS.sort).must_equal %i[bath muscle supplement]
      _(Minigames::ALL_KINDS - Minigames::BASE_KINDS).must_equal [:massage]
    end

    it "それぞれ目標スコアと説明を持つ" do
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

  describe "サプリメントの色分け" do
    it "寒色は飲むもの、暖色は見送るもの" do
      good = Minigames::Supplement::GOOD.map { |t| t[:name] }
      bad  = Minigames::Supplement::BAD.map { |t| t[:name] }
      _(good).must_include "カフェイン"
      _(good).must_include "ミント"
      _(bad).must_include "ホットミルク"
      _(bad).must_include "甘酒"
    end

    # 寒色＝青みが強い、暖色＝赤みが強い、で機械的に確かめる。
    it "良いサプリは青が赤より強く、悪いサプリはその逆" do
      Minigames::Supplement::GOOD.each do |type|
        _(type[:a].blue).must_be :>, type[:a].red, "#{type[:name]} が寒色になっていない"
      end
      Minigames::Supplement::BAD.each do |type|
        _(type[:a].red).must_be :>, type[:a].blue, "#{type[:name]} が暖色になっていない"
      end
    end
  end
end
