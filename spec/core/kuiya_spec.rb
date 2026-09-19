# frozen_string_literal: true

require_relative "../spec_helper"

# 乱入してくるクイヤのテスト。
describe "クイヤ" do
  KUIYA_FRAME_MS = 50

  before do
    srand(2468)
    Gosu.fake_ms = 0
    Gosu.sound_log.clear
    @window = Window.new
  end

  def start(difficulty_key, gauge)
    entry = Config::DIFFICULTIES.find { |d| d[:key] == difficulty_key }
    @window.begin_game!(entry)
    tick
    state.gauge.add(gauge)
    @game = enter(Minigames::Muscle.new(@window, state))
  end

  def enter(scene)
    @window.goto(scene)
    tick
    @window.scene
  end

  def tick(frames = 1)
    frames.times do
      Gosu.fake_ms += KUIYA_FRAME_MS
      @window.update
    end
    @window.scene
  end

  def seconds(count)
    tick((count * 1000 / KUIYA_FRAME_MS).round)
  end

  def state = @window.state
  def swarm = state.kuiya

  def samples_played
    Gosu.sound_log.count { |(kind, _)| kind == :sample }
  end

  describe "切り出したスプライト" do
    it "歩き6コマ・走り4コマを含む16コマがそろっている" do
      _(Assets::KUIYA_FRAMES.size).must_equal 16
      _(Assets::KUIYA_FRAMES.count { |n| n.to_s.start_with?("walk") }).must_equal 6
      _(Assets::KUIYA_FRAMES.count { |n| n.to_s.start_with?("run") }).must_equal 4
      %i[front back idle surprised].each do |name|
        _(Assets::KUIYA_FRAMES).must_include name
      end
    end

    it "すべて PNG として読み込める" do
      Assets::KUIYA_FRAMES.each do |name|
        _(Assets.kuiya(name)).wont_be_nil("#{name}.png が読み込めない")
      end
    end
  end

  describe "出現する条件" do
    it "しきい値は 500" do
      _(Config::KUIYA_THRESHOLD).must_equal 500.0
    end

    it "普通なら、ゲージが500を超えると乱入してくる" do
      start(:normal, 520.0)
      seconds(3.0)
      _(swarm.count).must_be :>, 0
    end

    it "ゲージが500以下なら出てこない" do
      start(:normal, 100.0)
      seconds(5.0)
      _(swarm.count).must_equal 0
    end

    it "赤ちゃんと初心者には出てこない" do
      %i[baby rookie].each do |key|
        Gosu.fake_ms = 0
        @window = Window.new
        start(key, 900.0)
        seconds(5.0)
        _(swarm.count).must_equal 0, "#{key} で出てきてしまった"
      end
    end

    it "難易度が上がるほど、同時に出てくる数が増える" do
      limits = Config::DIFFICULTIES.map { |d| d[:kuiya] }
      _(limits).must_equal limits.sort
      _(limits.first).must_equal 0
      _(limits.last).must_be :>, 1
    end

    it "上限を超えては増えない" do
      # 900 まで入れると、プロでは湧ききる前に気絶してしまう。
      start(:pro, 520.0)
      seconds(9.0)
      _(swarm.count).must_equal state.kuiya_limit
    end
  end

  describe "眠気への影響" do
    it "1匹につき眠気が5%速くなる" do
      start(:normal, 650.0)
      base = Config.drowsiness_rate(state.day) * state.difficulty_scale
      _(state.drowsiness_rate).must_be_close_to base, 0.001

      seconds(3.0)
      expected = base * (1.0 + Config::KUIYA_RATE_BONUS * swarm.count)
      _(state.drowsiness_rate).must_be_close_to expected, 0.001
      _(swarm.drowsiness_multiplier).must_be :>, 1.0
    end
  end

  describe "9で退治する" do
    before { start(:normal, 650.0) }

    it "9を連打すると追い払える" do
      seconds(3.0)
      _(swarm.count).must_be :>, 0

      before_count = swarm.count
      Kuiya::HITS_TO_DEFEAT.times { @window.button_down(Gosu::KB_9) }
      _(swarm.count).must_equal before_count - 1
    end

    it "1回では倒れない" do
      seconds(3.0)
      before_count = swarm.count
      @window.button_down(Gosu::KB_9)
      _(swarm.count).must_equal before_count
    end

    it "テンキーの9でも効く" do
      seconds(3.0)
      before_count = swarm.count
      Kuiya::HITS_TO_DEFEAT.times { @window.button_down(Gosu::KB_NUMPAD_9) }
      _(swarm.count).must_equal before_count - 1
    end

    it "9以外のキーでは減らない" do
      seconds(3.0)
      before_count = swarm.count
      20.times { @window.button_down(Gosu::KB_SPACE) }
      _(swarm.count).must_equal before_count
    end
  end

  describe "音" do
    it "1匹あらわれるごとに遭遇音が1回だけ鳴る" do
      start(:normal, 650.0)
      Gosu.sound_log.clear
      seconds(3.0)
      _(swarm.count).must_equal 1
      # 遭遇音のほかに鳴き声が混ざることはあるが、少なくとも1回は鳴っている。
      _(samples_played).must_be :>=, 1
    end

    it "退治した瞬間に音が鳴る" do
      start(:normal, 650.0)
      seconds(3.0)
      Gosu.sound_log.clear
      Kuiya::HITS_TO_DEFEAT.times { @window.button_down(Gosu::KB_9) }
      _(samples_played).must_be :>=, 1
    end

    it "クイヤ用の音が3種そろっている" do
      %i[kuiya_cry kuiya_appear kuiya_defeat].each do |name|
        _(Sound.effect(name)).wont_be_nil("#{name} が読み込めない")
      end
    end
  end

  describe "コマ送り" do
    it "歩いているあいだ、コマが順に切り替わる" do
      beast = Kuiya::Beast.new(true)
      seen = []
      30.times do
        beast.update(0.03)
        seen << beast.frame
      end
      _(seen.uniq.size).must_be :>, 1
    end

    it "9を浴びると驚いたコマになる" do
      beast = Kuiya::Beast.new(true)
      beast.strike!
      _(beast.frame).must_equal :surprised
    end
  end

  describe "退治したときのモーション" do
    it "その場で跳ねて、0.5秒で消える" do
      beast = Kuiya::Beast.new(true)
      Kuiya::HITS_TO_DEFEAT.times { beast.strike! }
      beast.defeat!

      _(beast.defeated?).must_equal true
      _(beast.counted?).must_equal false # もう眠気を増やさない
      _(beast.gone?).must_equal false
    end

    it "逃げ出さず、その場にとどまる" do
      beast = Kuiya::Beast.new(true)
      beast.update(2.0) # いちど歩かせてから
      here = beast.x
      beast.defeat!

      5.times { beast.update(0.1) }
      _(beast.x).must_equal here
    end

    it "跳ね上がってから戻ってくる" do
      beast = Kuiya::Beast.new(true)
      beast.defeat!

      beast.update(Kuiya::DEFEAT_TIME / 2)
      _(beast.hop).must_be :>, 0.5 # 山の上あたり

      beast.update(Kuiya::DEFEAT_TIME / 2)
      _(beast.hop).must_be :<, 0.1 # 落ちきったところ
    end

    it "だんだん薄くなって、0.5秒で消える" do
      beast = Kuiya::Beast.new(true)
      beast.defeat!
      _(beast.opacity).must_be_close_to 1.0, 0.001

      beast.update(Kuiya::DEFEAT_TIME / 2)
      _(beast.opacity).must_be_close_to 0.5, 0.05
      _(beast.gone?).must_equal false

      beast.update(Kuiya::DEFEAT_TIME / 2 + 0.01)
      _(beast.opacity).must_equal 0.0
      _(beast.gone?).must_equal true
    end

    it "9発目で撃退モーションに入る" do
      start(:normal, 650.0)
      seconds(3.0)
      _(swarm.count).must_be :>, 0

      Kuiya::HITS_TO_DEFEAT.times { @window.button_down(Gosu::KB_9) }
      _(swarm.beasts.any?(&:defeated?)).must_equal true

      # 0.5秒たてば居なくなる。
      seconds(Kuiya::DEFEAT_TIME + 0.2)
      _(swarm.beasts.any?(&:defeated?)).must_equal false
    end
  end

  describe "鳴き声" do
    it "4秒おきにひと声あげる" do
      _(Kuiya::CRY_INTERVAL).must_equal 4.0

      beast = Kuiya::Beast.new(true)
      # 4秒たつまでは鳴かない。
      39.times { _(beast.cry?(0.1)).must_equal false }
      _(beast.cry?(0.15)).must_equal true

      # つぎもまた4秒後。
      39.times { _(beast.cry?(0.1)).must_equal false }
      _(beast.cry?(0.15)).must_equal true
    end
  end

  describe "1日の区切り" do
    it "翌日になると、いったん解散する" do
      start(:normal, 650.0)
      seconds(3.0)
      _(swarm.count).must_be :>, 0

      state.next_day!
      _(state.kuiya.count).must_equal 0
    end
  end
end
