# frozen_string_literal: true

module Suiminkaizen
  # BGM と効果音。
  #
  # 音のファイルが無い環境（テストやヘッドレスの通しプレイ）でも動かしたいので、
  # 読み込みに失敗したものは黙って nil にして、鳴らす側は何も起きないだけにする。
  # ゲームの進行が音の有無で変わることはない。
  module Sound
    ROOT = File.expand_path("../../assets/sound", __dir__)

    # 名前 => ファイル名。ここに無いものは鳴らさない。
    EFFECTS = {
      select:    "選択音.mp3",
      decide:    "決定音1.mp3",
      supplement: "サプリゲット.mp3",
      good_night: "おやすみなさいませ.mp3",
      good_morning: "おはようございます.mp3",
      flick:        "振り払い.mp3",
      kuiya_cry:    "kuiya.ogg",
      kuiya_appear: "遭遇クイヤ.mp3",
      kuiya_defeat: "器具破壊.mp3",
      faint:        "堀大輔ブちぎれ.ogg",
      alarm:        "警報が鳴る.mp3",
      perfect:      "perfect音.mp3",
      good:         "good音.mp3",
      miss:         "新miss音.mp3"
    }.freeze

    BGM = "メインBGM.ogg"

    BGM_VOLUME    = 0.45
    EFFECT_VOLUME = 0.7
    VOICE_VOLUME  = 1.0
    VOICES = %i[good_night good_morning faint].freeze

    # 効果音のうち、録音が小さくて埋もれてしまうもの。
    # 台詞と同じように重ねて鳴らし、振幅そのものを稼ぐ。
    LOUD_EFFECTS = { kuiya_defeat: 3 }.freeze

    # 台詞の2本はもともと録音が小さく、BGM に埋もれて聞こえなかった。
    # 音量は 1.0 が上限で、それ以上を渡しても頭打ちになってしまうので、
    # 同じ音を重ねて鳴らして振幅そのものを稼ぐ（3本で約 +9.5dB）。
    VOICE_LAYERS = 3

    # さらに、しゃべっているあいだだけ BGM を引っこめる。
    BGM_DUCK_VOLUME = 0.06
    # 台詞の長さ（実測）。鳴り終わったら BGM を元に戻す。
    VOICE_SECONDS = { good_night: 2.06, good_morning: 2.69, faint: 2.11 }.freeze
    DUCK_TAIL     = 0.35

    module_function

    # --- BGM ------------------------------------------------------------
    # メインBGM はタイトルからずっと流しっぱなしにして、ループさせる。

    def bgm
      return @bgm if defined?(@bgm)

      @bgm = load_song(File.join(ROOT, BGM))
    end

    def play_bgm
      song = bgm
      return unless song
      return if song.playing?

      song.volume = bgm_volume
      song.play(true) # ループ再生
    rescue StandardError
      nil
    end

    # いま BGM をどの音量で鳴らすべきか。台詞の最中だけ下がる。
    def bgm_volume
      ducking? ? BGM_DUCK_VOLUME : BGM_VOLUME
    end

    def ducking?
      !@duck_until.nil?
    end

    # 毎フレーム呼ばれる。台詞が終わっていれば BGM の音量を戻す。
    def update
      return unless @duck_until
      return if now < @duck_until

      @duck_until = nil
      apply_bgm_volume
    end

    def duck_bgm!(seconds)
      @duck_until = now + seconds
      apply_bgm_volume
    end

    def apply_bgm_volume
      song = bgm
      return unless song

      song.volume = bgm_volume
    rescue StandardError
      nil
    end

    def now
      Gosu.milliseconds / 1000.0
    rescue StandardError
      0.0
    end

    def stop_bgm
      bgm&.stop
    rescue StandardError
      nil
    end

    # --- 効果音 ----------------------------------------------------------

    def effect(name)
      @effects ||= {}
      return @effects[name] if @effects.key?(name)

      file = EFFECTS[name]
      @effects[name] = file && load_sample(File.join(ROOT, file))
    end

    def play(name)
      sample = effect(name)
      return unless sample

      unless VOICES.include?(name)
        # 小さすぎる効果音だけは、重ねて鳴らして持ち上げる。
        layers = LOUD_EFFECTS[name]
        return layers.times { sample.play(VOICE_VOLUME) } if layers

        return sample.play(EFFECT_VOLUME)
      end

      # 台詞。BGM を引っこめたうえで、重ねて鳴らして聞こえるようにする。
      duck_bgm!(VOICE_SECONDS.fetch(name, 2.5) + DUCK_TAIL)
      VOICE_LAYERS.times { sample.play(VOICE_VOLUME) }
      sample
    rescue StandardError
      nil
    end

    # 音が1つでも用意できているか（開発時の確認用）。
    def available?
      !bgm.nil? || EFFECTS.keys.any? { |name| effect(name) }
    end

    def load_song(path)
      return nil unless File.exist?(path)
      return nil unless defined?(Gosu::Song)

      Gosu::Song.new(path)
    rescue StandardError
      nil
    end

    def load_sample(path)
      return nil unless File.exist?(path)
      return nil unless defined?(Gosu::Sample)

      Gosu::Sample.new(path)
    rescue StandardError
      nil
    end
  end
end
