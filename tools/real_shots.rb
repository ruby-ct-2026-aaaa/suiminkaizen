# frozen_string_literal: true

# 本物の Gosu でオフスクリーン描画し、実際のフォントを含む画面を PNG に保存する。
#   ruby tools/real_shots.rb
#
# 一瞬ウィンドウが開くが、撮り終わると自動的に閉じる。

require_relative "../lib/suiminkaizen"
require "fileutils"

OUT = File.expand_path("../tmp/real", __dir__)
FileUtils.mkdir_p(OUT)

module Suiminkaizen
  # 決められた場面まで進めては1枚撮る、撮影専用のウィンドウ。
  class ShotWindow < Window
    PLAN = [
      ["01_title",       20, 0,   ->(_w) {}],
      ["02_day_intro",   20, 0,   ->(w) { w.goto(Scenes::DayIntro.new(w, w.state)) }],
      ["03_intro",       40, 120, lambda { |w|
        w.goto(Scenes::MinigameIntro.new(w, w.state, :supplement))
      }],
      ["04_muscle",     120, 180, ->(w) { w.goto(Minigames::Muscle.new(w, w.state)) }],
      ["05_bath",       180, 420, ->(w) { w.goto(Minigames::Bath.new(w, w.state)) }],
      ["06_supplement", 140, 300, ->(w) { w.goto(Minigames::Supplement.new(w, w.state)) }],
      ["07_massage",    200, 260, ->(w) { w.goto(Minigames::HeadMassage.new(w, w.state)) }],
      ["08_sleep",       40, 500, ->(w) { w.goto(Scenes::Sleep.new(w, w.state)) }],
      ["09_game_over",   30, 999, ->(w) { w.goto(Scenes::GameOver.new(w, w.state)) }],
      ["10_ending",      40, 120, ->(w) { w.goto(Scenes::Ending.new(w, w.state)) }]
    ].freeze

    def initialize
      super
      @index = -1
      @wait = 0
      next_shot!
    end

    def update
      super
      @wait -= 1
      return if @wait.positive?

      @capture = true
    end

    def draw
      unless @capture
        super
        return
      end

      @capture = false
      name = PLAN[@index][0]
      image = Gosu.render(width, height) do
        scene.draw
      end
      path = File.join(OUT, "#{name}.png")
      image.save(path)
      puts "  #{path}"
      image.draw(0, 0, 0)
      next_shot!
    end

    private

    def next_shot!
      @index += 1
      if @index >= PLAN.size
        close
        return
      end

      _, frames, gauge, setup = PLAN[@index]
      reset!
      state.gauge.add(gauge) if gauge.positive?
      setup.call(self)
      @wait = frames
    end
  end
end

srand(20_260_915)
puts "実機描画の PNG を書き出します -> #{OUT}"
Suiminkaizen::ShotWindow.new.show
puts "完了"
