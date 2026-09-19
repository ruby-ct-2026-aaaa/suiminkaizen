# frozen_string_literal: true

require_relative "../spec_helper"

# 音まわりのテスト。
# スタブの Gosu は実際には鳴らさず、鳴らされた回数だけ数えている。
describe "音" do
  SOUND_FRAME_MS = 50

  before do
    srand(777)
    Gosu.fake_ms = 0
    Gosu.sound_log.clear
    @window = Window.new
  end

  def enter(scene)
    @window.goto(scene)
    tick
    @window.scene
  end

  def tick(frames = 1)
    frames.times do
      Gosu.fake_ms += SOUND_FRAME_MS
      @window.update
    end
    @window.scene
  end

  def seconds(count)
    tick((count * 1000 / SOUND_FRAME_MS).round)
  end

  def state = @window.state

  def samples_played
    Gosu.sound_log.count { |(kind, _)| kind == :sample }
  end

  # 鳴らされた音のファイル名（鳴った順）。
  def played
    Gosu.sound_log.select { |(kind, _)| kind == :sample }.map(&:last)
  end

  describe "用意されているファイル" do
    it "メインBGMと5つの効果音がそろっている" do
      _(File.exist?(File.join(Sound::ROOT, Sound::BGM))).must_equal true
      Sound::EFFECTS.each_value do |file|
        _(File.exist?(File.join(Sound::ROOT, file)))
          .must_equal true, "#{file} が見つからない"
      end
    end

    it "すべて読み込める" do
      _(Sound.bgm).wont_be_nil
      Sound::EFFECTS.each_key { |name| _(Sound.effect(name)).wont_be_nil }
    end
  end

  describe "メインBGM" do
    it "ウィンドウを開いた時点でループ再生されている" do
      # すでに鳴っていれば重ねて鳴らさないので、いったん止めてから確かめる。
      Sound.stop_bgm
      Gosu.sound_log.clear
      Window.new

      _(Sound.bgm.playing?).must_equal true
      _(Gosu.sound_log).must_include [:song, true]
    end

    it "すでに鳴っているときは重ねて鳴らさない" do
      Sound.play_bgm
      Gosu.sound_log.clear
      Sound.play_bgm
      _(Gosu.sound_log).must_be_empty
    end
  end

  describe "台詞の音量" do
    it "台詞は重ねて鳴らし、効果音は1回だけ鳴らす" do
      _(Sound::VOICE_LAYERS).must_be :>, 1
      _(Sound::VOICES.sort).must_equal %i[faint good_morning good_night]

      before = samples_played
      Sound.play(:decide)
      _(samples_played).must_equal before + 1

      before = samples_played
      Sound.play(:good_morning)
      _(samples_played).must_equal before + Sound::VOICE_LAYERS
    end

    it "引っこめる音量は、ふだんの BGM よりはっきり小さい" do
      _(Sound::BGM_DUCK_VOLUME).must_be :<, Sound::BGM_VOLUME / 4.0
    end
  end

  describe "小さすぎた音の持ち上げ" do
    # クイヤの撃退音は録音が小さく、BGM に埋もれて聞こえなかった。
    it "クイヤの撃退音は重ねて鳴らす" do
      layers = Sound::LOUD_EFFECTS[:kuiya_defeat]
      _(layers).must_be :>, 1

      before = samples_played
      Sound.play(:kuiya_defeat)
      _(samples_played).must_equal before + layers
    end

    it "持ち上げるのは撃退音だけで、ほかの効果音は1回のまま" do
      %i[select decide supplement flick kuiya_appear kuiya_cry].each do |name|
        before = samples_played
        Sound.play(name)
        _(samples_played).must_equal before + 1, "#{name} が重なっている"
      end
    end

    it "持ち上げても BGM は引っこめない" do
      Sound.update
      before = Sound.ducking?
      Sound.play(:kuiya_defeat)
      _(Sound.ducking?).must_equal before
    end
  end

  describe "気絶したとき" do
    it "堀大輔の声が重ねて鳴る" do
      before = samples_played
      enter(Scenes::GameOver.new(@window, state))
      _(samples_played).must_equal before + Sound::VOICE_LAYERS
    end

    it "そのあいだ BGM は引っこむ" do
      enter(Scenes::GameOver.new(@window, state))
      _(Sound.ducking?).must_equal true
      _(Sound.bgm.volume).must_equal Sound::BGM_DUCK_VOLUME
    end

    it "声のファイルが用意されている" do
      _(Sound::EFFECTS[:faint]).must_equal "堀大輔ブちぎれ.ogg"
      _(Sound.effect(:faint)).wont_be_nil
    end
  end

  describe "筋トレの判定音" do
    # 中央の黄色 = PERFECT、緑 = GOOD、外せばミス。
    # それぞれ別の音が、ひとつだけ鳴る。
    def muscle_game
      game = enter(Minigames::Muscle.new(@window, state))
      game.instance_variable_set(:@balance, 0.0) # 軸のブレは判定から外しておく
      game
    end

    def stop_at(game, offset)
      center = game.instance_variable_get(:@zone_center)
      game.instance_variable_set(:@cursor, center + offset)
      Gosu.sound_log.clear
      @window.button_down(Gosu::KB_SPACE)
    end

    it "PERFECT では perfect音 だけが鳴る" do
      game = muscle_game
      stop_at(game, 0.0)

      _(game.instance_variable_get(:@reps)).must_equal 1
      _(played).must_equal ["perfect音.mp3"]
    end

    it "GOOD では good音 だけが鳴る" do
      game = muscle_game
      # 黄色の外、緑の内側で止める。
      perfect = game.instance_variable_get(:@perfect_half)
      half    = game.instance_variable_get(:@zone_half)
      stop_at(game, (perfect + half) / 2.0)

      _(game.instance_variable_get(:@reps)).must_equal 1
      _(played).must_equal ["good音.mp3"]
    end

    it "外すとミス音が鳴る" do
      game = muscle_game
      stop_at(game, game.instance_variable_get(:@zone_half) * 3.0)

      _(game.instance_variable_get(:@reps)).must_equal 0
      _(played).must_equal ["新miss音.mp3"]
    end

    it "3つとも別々のファイルが用意されている" do
      files = %i[perfect good miss].map { |name| Sound::EFFECTS[name] }
      _(files).must_equal ["perfect音.mp3", "good音.mp3", "新miss音.mp3"]
      _(files.uniq.size).must_equal 3
      files.each_index { |i| _(Sound.effect(%i[perfect good miss][i])).wont_be_nil }
    end
  end

  describe "ミスの音" do
    # ミスは4種目に共通の blunder から鳴らしているので、どの種目でも鳴る。
    it "お風呂でも、サプリでも、マッサージでも鳴る" do
      [Minigames::Bath, Minigames::Supplement, Minigames::HeadMassage].each do |klass|
        game = enter(klass.new(@window, state))
        Gosu.sound_log.clear
        game.blunder(5.0, "テスト")
        _(played).must_equal ["新miss音.mp3"], "#{klass} でミス音が鳴らない"
      end
    end

    it "じわじわ増える眠気（drip）では鳴らさない" do
      game = enter(Minigames::Bath.new(@window, state))
      Gosu.sound_log.clear
      game.drip(5.0)
      _(played).must_be_empty
    end
  end

  describe "ヘッドマッサージの乱入" do
    it "始まった瞬間に警報が鳴る" do
      before = samples_played
      enter(Minigames::HeadMassage.new(@window, state))
      _(samples_played).must_equal before + 1
    end

    it "警報のファイルが用意されている" do
      _(Sound::EFFECTS[:alarm]).must_equal "警報が鳴る.mp3"
      _(Sound.effect(:alarm)).wont_be_nil
    end
  end

  describe "選択と決定" do
    it "難易度を選び直すと選択音が鳴る" do
      enter(Scenes::DifficultySelect.new(@window, state))
      before = samples_played
      @window.button_down(Gosu::KB_DOWN)
      _(samples_played).must_equal before + 1
    end

    it "難易度を決めると決定音が鳴る" do
      enter(Scenes::DifficultySelect.new(@window, state))
      before = samples_played
      @window.button_down(Gosu::KB_SPACE)
      _(samples_played).must_equal before + 1
    end

    it "種目を選び直すと選択音、はじめると決定音が鳴る" do
      enter(Scenes::MinigameIntro.new(@window, state, :choice))
      before = samples_played
      @window.button_down(Gosu::KB_RIGHT)
      _(samples_played).must_equal before + 1

      @window.button_down(Gosu::KB_SPACE)
      _(samples_played).must_equal before + 2
    end
  end

  describe "就寝と起床" do
    before { Config::GAMES_PER_DAY.times { state.advance_slot! } }

    # 台詞は小さすぎて聞こえなかったので、重ねて鳴らして振幅を稼いでいる。
    it "眠りはじめに「おやすみなさいませ」が重ねて鳴る" do
      before = samples_played
      enter(Scenes::Sleep.new(@window, state))
      _(samples_played).must_equal before + Sound::VOICE_LAYERS
    end

    it "目覚ましの瞬間に「おはようございます」が鳴り、二度は鳴らない" do
      enter(Scenes::Sleep.new(@window, state))
      before = samples_played

      seconds(Scenes::Sleep::FALL + Scenes::Sleep::DOZE + 0.2)
      _(samples_played).must_equal before + Sound::VOICE_LAYERS

      # 残りを再生し切っても、もう一度は鳴らない。
      seconds(Scenes::Sleep::WAKE)
      _(samples_played).must_equal before + Sound::VOICE_LAYERS
    end

    it "眠りはじめた瞬間から BGM が引っこむ" do
      enter(Scenes::Sleep.new(@window, state))
      _(Sound.ducking?).must_equal true
      _(Sound.bgm.volume).must_equal Sound::BGM_DUCK_VOLUME
    end

    # 就寝画面は途中で起床の台詞も鳴らすので、戻るところは単独で確かめる。
    it "台詞が鳴り終わると BGM の音量が戻る" do
      Sound.update
      Sound.play(:good_night)
      _(Sound.ducking?).must_equal true
      _(Sound.bgm.volume).must_equal Sound::BGM_DUCK_VOLUME

      seconds(Sound::VOICE_SECONDS[:good_night] + Sound::DUCK_TAIL + 0.2)
      _(Sound.ducking?).must_equal false
      _(Sound.bgm.volume).must_equal Sound::BGM_VOLUME
    end

    it "効果音では BGM を引っこめない" do
      Sound.update
      before = Sound.ducking?
      Sound.play(:select)
      _(Sound.ducking?).must_equal before
    end
  end

  describe "サプリ獲得" do
    it "寒色のサプリを飲めた瞬間に鳴る" do
      game = enter(Minigames::Supplement.new(@window, state))
      pills = game.instance_variable_get(:@pills)
      pills.clear
      pills << { type: Minigames::Supplement::GOOD.first, lane: 1,
                 z: Minigames::Supplement::CATCH_BEST, spin: 0.0, done: false }

      Gosu.sound_log.clear
      @window.button_down(Gosu::KB_SPACE)
      _(played).must_equal ["サプリゲット.mp3"]
    end

    it "暖色を飲んでしまったときは、獲得音ではなくミス音になる" do
      game = enter(Minigames::Supplement.new(@window, state))
      pills = game.instance_variable_get(:@pills)
      pills.clear
      pills << { type: Minigames::Supplement::BAD.first, lane: 1,
                 z: Minigames::Supplement::CATCH_BEST, spin: 0.0, done: false }

      Gosu.sound_log.clear
      @window.button_down(Gosu::KB_SPACE)
      _(played).must_equal ["新miss音.mp3"]
    end
  end
end
