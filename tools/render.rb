# frozen_string_literal: true

# ゲーム画面を PNG に書き出して見た目を確認するツール。
#
#   ruby tools/render.rb [出力ディレクトリ]
#
# tools/canvas.rb のソフトウェアラスタライザに描画を流すので、
# 実機を起動しなくても疑似3Dの部屋やドット絵の組み上がりを目で確かめられる。
# （文字は本物のフォントを持てないため、位置と幅を示す帯で描かれる）

$LOAD_PATH.unshift(File.expand_path("stub", __dir__))
require_relative "canvas"
require_relative "../lib/suiminkaizen"

include Suiminkaizen # rubocop:disable Style/MixinUsage

OUT = ARGV[0] || File.expand_path("../tmp/shots", __dir__)
require "fileutils"
FileUtils.mkdir_p(OUT)

def shot(name, seconds: 1.0, gauge: nil, frames: nil)
  srand(20_260_915)
  Gosu.fake_ms = 0
  Gosu.canvas = nil
  window = Window.new
  window.state.gauge.add(gauge) if gauge

  yield(window) if block_given?

  # 見栄えのする瞬間まで進める
  steps = frames || (seconds / 0.05).round
  steps.times do
    Gosu.fake_ms += 50
    window.update
  end

  canvas = Canvas.new(Config::SCREEN_W, Config::SCREEN_H)
  Gosu.canvas = canvas
  window.draw
  Gosu.canvas = nil

  path = File.join(OUT, "#{name}.png")
  canvas.save(path)
  puts "  #{path}  (#{window.scene.class.name.split('::').last})"
end

puts "PNG を書き出します -> #{OUT}"

shot("01_title", seconds: 1.0)

shot("02_day_intro", seconds: 1.0) do |w|
  w.goto(Scenes::DayIntro.new(w, w.state))
end

shot("03_muscle", seconds: 6.0, gauge: 180) do |w|
  w.goto(Minigames::Muscle.new(w, w.state))
end

shot("04_bath", seconds: 9.0, gauge: 420) do |w|
  w.goto(Minigames::Bath.new(w, w.state))
end

shot("05_supplement", seconds: 7.0, gauge: 300) do |w|
  w.goto(Minigames::Supplement.new(w, w.state))
end

shot("06_sleep", seconds: 3.0, gauge: 500) do |w|
  w.goto(Scenes::Sleep.new(w, w.state))
end

shot("07_game_over", seconds: 1.5, gauge: 999) do |w|
  w.goto(Scenes::GameOver.new(w, w.state))
end

shot("08_drowsy", seconds: 6.0, gauge: 880) do |w|
  w.goto(Minigames::Muscle.new(w, w.state))
end

puts "完了"
