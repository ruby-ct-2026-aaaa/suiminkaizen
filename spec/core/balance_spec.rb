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

  # ミニゲームそのものの時間は固定。ここだけは動かさない。
  it "1日のミニゲームは4本 x 15秒 ＝ 1分ちょうど" do
    _(Config::MINIGAME_SECONDS).must_equal 15.0
    _(Config::GAMES_PER_DAY * Config::MINIGAME_SECONDS).must_equal 60.0
  end

  # 選択とリザルトはどちらも「最大10秒」で、押せばすぐ進む。
  # そのぶん1日の長さは、プレイヤーの決断の早さで変わる。
  it "1日は、即決なら約70秒・迷いきると150秒" do
    minigames = Config::GAMES_PER_DAY * Config::MINIGAME_SECONDS
    dithering = Config::GAMES_PER_DAY *
                (Scenes::MinigameIntro::READ_TIME + Scenes::MinigameResult::AUTO_NEXT)
    ceremony  = Scenes::DayIntro::AUTO_START + Scenes::DayResult::AUTO_NEXT +
                Scenes::Sleep::TOTAL

    quickest = minigames + ceremony
    slowest  = minigames + dithering + ceremony

    _(quickest).must_be_close_to 70.0, 2.0
    _(slowest).must_be_close_to 150.0, 2.0
  end

  it "7日クリアは、即決で約8分・迷いきって約17分半" do
    minigames = Config::GAMES_PER_DAY * Config::MINIGAME_SECONDS
    dithering = Config::GAMES_PER_DAY *
                (Scenes::MinigameIntro::READ_TIME + Scenes::MinigameResult::AUTO_NEXT)
    ceremony  = Scenes::DayIntro::AUTO_START + Scenes::DayResult::AUTO_NEXT +
                Scenes::Sleep::TOTAL

    quickest = (minigames + ceremony) * Config::TOTAL_DAYS / 60.0
    slowest  = (minigames + dithering + ceremony) * Config::TOTAL_DAYS / 60.0

    _(quickest).must_be_close_to 8.2, 0.4
    _(slowest).must_be_close_to 17.5, 0.5
  end

  it "選択画面は10秒あり、3つの選択肢が出る" do
    _(Scenes::MinigameIntro::READ_TIME).must_equal 10.0
    _(Minigames::BASE_KINDS.size).must_equal 3
  end

  # 画面が切り替わった瞬間の SPACE も拾えるよう、待ち時間はゼロにしてある。
  it "選択画面もリザルト画面も、最初のフレームから入力を受け付ける" do
    _(Scenes::MinigameIntro::MIN_READ).must_equal 0.0
    _(Scenes::MinigameResult::MIN_SHOW).must_equal 0.0
  end

  it "リザルト画面は最大10秒で、放っておけば次へ進む" do
    _(Scenes::MinigameResult::AUTO_NEXT).must_equal 10.0
  end

  it "1日目の眠気はちょうど 10/秒" do
    _(Config.drowsiness_rate(1)).must_equal 10.0
  end

  # 眠気が進む画面の秒数。
  # 種目の選択画面もリザルト画面も時計ごと止まっているので、数に入らない。
  # 残るのは朝の導入4秒と夜の集計3秒だけ。
  IDLE_QUICK = Scenes::DayIntro::AUTO_START + Scenes::DayResult::AUTO_NEXT

  # 1日ぶんに自然に溜まる眠気（ミニゲーム中＋その合間）。
  def passive_gain(day, idle = IDLE_QUICK)
    Config.drowsiness_rate(day) * Config::GAMES_PER_DAY * Config::MINIGAME_SECONDS +
      Config.idle_rate(day) * idle
  end

  # ミスの量ごとに、収支が釣り合う達成率。
  def break_even(day, penalty, idle = IDLE_QUICK)
    (passive_gain(day, idle) + penalty - Config::SLEEP_RECOVERY) /
      (Config.max_reward(day) * Config::GAMES_PER_DAY)
  end

  # 設計の要。1枠の削減上限（max_reward）を動かすと、ここが真っ先に動く。
  it "等倍（難易度の基準）ではミスなしの達成率50%前後で踏みとどまれる" do
    DAYS.each do |day|
      _(break_even(day, 0.0)).must_be_close_to 0.51, 0.06,
                                              "DAY#{day} の損益分岐が想定とずれている"
    end
  end

  # 選択画面は時計ごと止まるので、迷っても眠気は増えない。
  it "選択画面で迷っても、要求される達成率は変わらない" do
    dithering = IDLE_QUICK + Config::GAMES_PER_DAY * Scenes::MinigameIntro::READ_TIME
    DAYS.each do |day|
      _(break_even(day, 0.0, IDLE_QUICK))
        .must_be_close_to break_even(day, 0.0, IDLE_QUICK), 0.0001
      _(dithering).must_be :>, IDLE_QUICK # 実時間は延びるが、眠気は進まない
    end
  end

  it "1日に200ぶんのミスを出すと要求される達成率がはっきり上がる" do
    DAYS.each do |day|
      _(break_even(day, 200.0)).must_be :>, break_even(day, 0.0) + 0.06,
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

  describe "難易度" do
    it "赤ちゃんからプロまで5段階ある" do
      _(Config::DIFFICULTIES.map { |d| d[:label] })
        .must_equal %w[赤ちゃん 初心者 普通 上級者 プロ]
    end

    it "下から順に眠気が速くなる" do
      scales = Config::DIFFICULTIES.map { |d| d[:scale] }
      _(scales).must_equal scales.sort
      _(scales.uniq.size).must_equal scales.size
    end

    it "既定は普通" do
      _(Config.default_difficulty[:key]).must_equal :normal
    end

    # これまで遊んでいた等倍（10/秒）は「初心者と普通のあいだ」だった、
    # という手応えをそのまま刻みにしてある。
    it "等倍は初心者と普通のちょうどあいだにある" do
      rookie = Config::DIFFICULTIES[1][:scale]
      normal = Config::DIFFICULTIES[2][:scale]
      _(rookie).must_be :<, 1.0
      _(normal).must_be :>, 1.0
      _((rookie + normal) / 2.0).must_be_close_to 1.0, 0.05
    end

    it "選んだ難易度のぶんだけ、眠気の進みが変わる" do
      Config::DIFFICULTIES.each do |entry|
        state = GameState.new(entry)
        _(state.drowsiness_rate)
          .must_be_close_to Config.drowsiness_rate(1) * entry[:scale], 0.001
        _(state.idle_rate).must_be :<, state.drowsiness_rate
      end
    end

    it "難易度を指定しなければ普通ではじまる" do
      _(GameState.new.difficulty_label).must_equal "普通"
    end
  end

  describe "ミニゲーム" do
    it "4種類あり、うち3種類は選択肢として毎回出てくる" do
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
