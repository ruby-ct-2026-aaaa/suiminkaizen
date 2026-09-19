# frozen_string_literal: true

module Suiminkaizen
  module Scenes
    # 難易度を選ぶ画面。
    #
    # ここだけは時間で勝手に進まない。選ぶまでいつまでも待つ。
    # 変えているのは「眠気の進む速さ」ひとつだけなので、
    # その日1日目に何秒で気絶するかを添えて、重さが伝わるようにしている。
    class DifficultySelect < Scene
      UP_KEYS   = [Gosu::KB_UP,   Gosu::KB_W].freeze
      DOWN_KEYS = [Gosu::KB_DOWN, Gosu::KB_S].freeze

      ROW_H  = 24
      ROW_Y  = 56
      ROW_X  = 20
      ROW_W  = Config::W - 40

      TONES = [Palette::AQUA, Palette::GREEN, Palette::YELLOW,
               Palette::ORANGE, Palette::RED].freeze

      def initialize(window, state, index = Config::DEFAULT_DIFFICULTY)
        super(window, state)
        @index  = index
        @camera = Camera.new
      end

      def difficulty = Config.difficulty_at(@index)

      def update(dt)
        super
        @camera.update(dt)
        # 眠気も時間も進めない。ここは決めるまで止まったまま。
      end

      def button_down(id)
        return move(-1) if UP_KEYS.include?(id)
        return move(1)  if DOWN_KEYS.include?(id)

        start! if confirm?(id)
      end

      def draw
        Stage.draw(@camera, :bedroom, elapsed)
        Px.rect(0, 0, Config::W, Config::H, Palette.alpha(Palette::INK, 210), 100)

        Px.text_shadow(Assets.large, "難易度をえらぶ", Config::W / 2, 24,
                       Palette::WHITE, 101, align: :center)
        Px.text_shadow(Assets.tiny, "↑ ↓ で選んで SPACE で決定", Config::W / 2, 44,
                       Palette::SLATE, 101, align: :center)

        Config::DIFFICULTIES.each_with_index { |entry, i| draw_row(entry, i) }
        draw_detail
      end

      private

      def move(step)
        size = Config::DIFFICULTIES.size
        @index = (@index + step) % size
        Sound.play(:select)
      end

      def start!
        return if @moved

        @moved = true
        Sound.play(:decide)
        window.begin_game!(difficulty)
      end

      def draw_row(entry, i)
        selected = i == @index
        y = ROW_Y + i * ROW_H
        tone = TONES[i]

        body = selected ? Palette.alpha(Palette::DUSK, 250) : Palette.alpha(Palette::INK, 215)
        Px.rect(ROW_X, y, ROW_W, ROW_H - 4, body, 101)
        Px.rect(ROW_X, y, 4, ROW_H - 4, tone, 102)

        if selected
          Px.frame(ROW_X - 2, y - 2, ROW_W + 4, ROW_H,
                   Palette.alpha(Palette::YELLOW, blinking_alpha(6.0)), 103, 2)
          Px.text_shadow(Assets.small, "▶", ROW_X - 14, y + 3, Palette::YELLOW, 103)
        end

        Px.text_shadow(Assets.small, entry.fetch(:label), ROW_X + 12, y + 3,
                       selected ? Palette::WHITE : Palette::GRAY, 103)

        # 眠気の重さを、目盛りの本数でも見せる。
        5.times do |n|
          filled = n < i + 1
          Px.rect(ROW_X + 96 + n * 9, y + 7, 7, 8,
                  filled ? tone : Palette.alpha(Palette::SLATE, 90), 103)
        end

        Px.text_shadow(Assets.tiny, format("眠気 %.1f / 秒", day1_rate(entry)),
                       ROW_X + ROW_W - 8, y + 7,
                       selected ? Palette::BONE : Palette::SLATE, 103, align: :right)
      end

      def draw_detail
        entry = difficulty
        y = ROW_Y + Config::DIFFICULTIES.size * ROW_H + 4

        Px.rect(ROW_X, y, ROW_W, 32, Palette.alpha(Palette::INK, 225), 101)
        Px.frame(ROW_X, y, ROW_W, 32, Palette::VIOLET, 102)
        Px.text_shadow(Assets.tiny, entry.fetch(:note), Config::W / 2, y + 6,
                       Palette::BONE, 103, align: :center)
        Px.text_shadow(Assets.tiny, limit_text(entry), Config::W / 2, y + 19,
                       Palette::CYAN, 103, align: :center)

        Px.text_shadow(Assets.small, "SPACE ではじめる", Config::W / 2, Config::H - 20,
                       Palette.alpha(Palette::YELLOW, blinking_alpha), 103,
                       align: :center)
      end

      def day1_rate(entry)
        Config.drowsiness_rate(1) * entry.fetch(:scale)
      end

      # 何もしなければ1日目に何秒でゲージが満タンになるか。
      def limit_text(entry)
        seconds = Config::MAX_GAUGE / day1_rate(entry)
        format("何もしなければ DAY1 は約 %d 秒で気絶", seconds.round)
      end
    end
  end
end
