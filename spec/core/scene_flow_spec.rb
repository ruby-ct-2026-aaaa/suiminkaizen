# frozen_string_literal: true

require_relative "../spec_helper"

# 画面の進行そのものを確かめるテスト。
# 「いつ入力を受け付けるか」「どの画面で時間が進むか」は数字ではなく挙動なので、
# 実際にウィンドウを1フレームずつ回して確かめる。
describe "画面の進行" do
  FRAME_MS = 50

  before do
    srand(4321)
    Gosu.fake_ms = 0
    @window = Window.new
  end

  # goto は次の update で反映されるので、1フレーム回してから触る。
  def enter(scene)
    @window.goto(scene)
    tick
    @window.scene
  end

  def tick(frames = 1)
    frames.times do
      Gosu.fake_ms += FRAME_MS
      @window.update
    end
    @window.scene
  end

  def seconds(count)
    tick((count * 1000 / FRAME_MS).round)
  end

  def state = @window.state

  describe "ゲームのはじまり" do
    it "DAY1 の導入は 00:00 を指している" do
      enter(Scenes::DayIntro.new(@window, state))
      _(state.opening?).must_equal true
      _(state.clock_text).must_equal "00:00"
    end

    it "導入のつぎは、いきなりミニゲームではなく30分の睡眠" do
      enter(Scenes::DayIntro.new(@window, state))
      @window.button_down(Gosu::KB_SPACE)
      seconds(Scenes::DayIntro::AUTO_START + 0.2)
      _(@window.scene).must_be_kind_of Scenes::Sleep
      _(@window.scene.opening?).must_equal true
    end

    it "その睡眠は日付をまたがず、1枠目の選択画面へつながる" do
      enter(Scenes::Sleep.new(@window, state, opening: true))
      _(state.days).must_be_empty

      seconds(Scenes::Sleep::TOTAL + 0.3)
      _(@window.scene).must_be_kind_of Scenes::MinigameIntro
      _(state.day).must_equal 1
      _(state.slot).must_equal 0
      _(state.opening?).must_equal false
      _(state.clock_text).must_equal "00:30"
      _(state.days).must_be_empty # 1日目の記録はまだ付かない
    end

    it "1日の終わりの睡眠は、いままでどおり翌日へ送る" do
      state.finish_opening_sleep!
      Config::GAMES_PER_DAY.times { state.advance_slot! }
      enter(Scenes::Sleep.new(@window, state))
      _(@window.scene.opening?).must_equal false

      seconds(Scenes::Sleep::TOTAL + 0.3)
      _(@window.scene).must_be_kind_of Scenes::DayIntro
      _(state.day).must_equal 2
      _(state.days.size).must_equal 1
    end
  end

  describe "起床のあと" do
    it "目覚ましから2秒見せてから次へ進む" do
      _(Scenes::Sleep::WAKE).must_equal 2.0

      state.finish_opening_sleep!
      Config::GAMES_PER_DAY.times { state.advance_slot! }
      enter(Scenes::Sleep.new(@window, state))

      # 目覚ましが鳴ってから1.5秒はまだ睡眠画面のまま。
      seconds(Scenes::Sleep::FALL + Scenes::Sleep::DOZE + 1.5)
      _(@window.scene).must_be_kind_of Scenes::Sleep

      seconds(0.8)
      _(@window.scene).wont_be_kind_of Scenes::Sleep
    end
  end

  describe "選択画面" do
    before { enter(Scenes::MinigameIntro.new(@window, state, :choice)) }

    it "切り替わった瞬間の SPACE でもミニゲームが始まる" do
      _(@window.scene).must_be_kind_of Scenes::MinigameIntro
      _(@window.scene.elapsed).must_be :<=, 0.06 # 切り替わってまだ1フレーム

      @window.button_down(Gosu::KB_SPACE)
      _(tick).must_be_kind_of Minigames::Base
    end

    it "10秒待つとランダムに選ばれて強制的に始まる" do
      _(seconds(9.0)).must_be_kind_of Scenes::MinigameIntro
      scene = seconds(1.5)
      _(scene).must_be_kind_of Minigames::Base
      _(Minigames::BASE_KINDS).must_include scene.class.kind
    end

    it "左右キーで選んでいる種目が変わる" do
      before_kind = @window.scene.kind
      @window.button_down(Gosu::KB_RIGHT)
      _(@window.scene.kind).wont_equal before_kind
      @window.button_down(Gosu::KB_LEFT)
      _(@window.scene.kind).must_equal before_kind
    end

    it "表示しているあいだ睡眠ゲージは増えない" do
      state.gauge.add(200.0)
      before_gauge = state.gauge.value
      seconds(5.0)
      _(@window.scene).must_be_kind_of Scenes::MinigameIntro
      _(state.gauge.value).must_equal before_gauge
    end

    it "表示しているあいだゲーム内の時計も止まる" do
      before_clock = state.clock_text
      seconds(5.0)
      _(state.clock_text).must_equal before_clock
    end

    it "N を押せば何もしないままリザルトへ進む" do
      @window.button_down(Gosu::KB_N)
      scene = tick
      _(scene).must_be_kind_of Scenes::MinigameResult
      _(state.day_results.last.skipped).must_equal true
    end
  end

  describe "難易度の選択画面" do
    before { enter(Scenes::DifficultySelect.new(@window, state)) }

    it "選ぶまでいつまでも表示されつづける" do
      _(seconds(30.0)).must_be_kind_of Scenes::DifficultySelect
    end

    it "待っているあいだに睡眠ゲージも増えない" do
      before_gauge = state.gauge.value
      seconds(30.0)
      _(state.gauge.value).must_equal before_gauge
    end

    it "上下キーで難易度が変わる" do
      _(@window.scene.difficulty[:key]).must_equal :normal
      @window.button_down(Gosu::KB_DOWN)
      _(@window.scene.difficulty[:key]).must_equal :hard
      @window.button_down(Gosu::KB_UP)
      @window.button_down(Gosu::KB_UP)
      _(@window.scene.difficulty[:key]).must_equal :rookie
    end

    it "端では反対側へ回り込む" do
      2.times { @window.button_down(Gosu::KB_UP) }
      _(@window.scene.difficulty[:key]).must_equal :baby
      @window.button_down(Gosu::KB_UP)
      _(@window.scene.difficulty[:key]).must_equal :pro
    end

    it "決定すると、その難易度で1日目がはじまる" do
      2.times { @window.button_down(Gosu::KB_DOWN) }
      _(@window.scene.difficulty[:key]).must_equal :pro

      @window.button_down(Gosu::KB_SPACE)
      _(tick).must_be_kind_of Scenes::DayIntro
      _(@window.state.difficulty_label).must_equal "プロ"
      _(@window.state.day).must_equal 1
    end
  end

  describe "ミニゲーム中の削減" do
    before do
      state.gauge.add(600.0)
      @game = enter(Minigames::Muscle.new(@window, state))
    end

    it "得点が入ったその瞬間にゲージが減る" do
      before_gauge = state.gauge.value
      @game.succeed(20.0)
      _(@game.paid_reward).must_be :>, 0.0
      _(state.gauge.value).must_be_close_to before_gauge - @game.paid_reward, 0.001
    end

    it "稼ぐほど、その場で減る量が積み上がる" do
      @game.succeed(10.0)
      first = @game.paid_reward
      @game.succeed(10.0)
      _(@game.paid_reward).must_be :>, first
    end

    it "終了時に同じぶんをもう一度引かれたりはしない" do
      @game.succeed(20.0)
      paid = @game.paid_reward
      before_gauge = state.gauge.value

      @game.finish!
      _(state.gauge.value).must_equal before_gauge
      _(state.day_results.last.reward).must_be_close_to paid, 0.001
    end
  end

  describe "リザルト画面" do
    before do
      state.gauge.add(200.0)
      enter(Scenes::MinigameResult.new(@window, state, state.record_skip(:muscle)))
    end

    it "表示しているあいだ睡眠ゲージは増えない" do
      before_gauge = state.gauge.value
      seconds(5.0)
      _(@window.scene).must_be_kind_of Scenes::MinigameResult
      _(state.gauge.value).must_equal before_gauge
    end

    it "表示しているあいだゲーム内の時計も止まる" do
      before_clock = state.clock_text
      seconds(5.0)
      _(state.clock_text).must_equal before_clock
    end

    it "最初のフレームの入力でもすぐ次へ進む" do
      _(@window.scene.elapsed).must_be :<=, 0.06 # 切り替わってまだ1フレーム
      @window.button_down(Gosu::KB_SPACE)
      _(tick).wont_be_kind_of Scenes::MinigameResult
    end

    it "入力がなくても10秒で次へ進む" do
      _(seconds(9.0)).must_be_kind_of Scenes::MinigameResult
      _(seconds(1.5)).must_be_kind_of Scenes::MinigameIntro
    end
  end
end
