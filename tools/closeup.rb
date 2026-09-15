# frozen_string_literal: true

# 一部を拡大して切り出す確認用スクリプト。
#   ruby tools/closeup.rb

$LOAD_PATH.unshift(File.expand_path("stub", __dir__))
require_relative "canvas"
require_relative "../lib/suiminkaizen"
require "fileutils"

include Suiminkaizen # rubocop:disable Style/MixinUsage

OUT = File.expand_path("../tmp/shots", __dir__)
FileUtils.mkdir_p(OUT)

srand(20_260_915)
Gosu.fake_ms = 0
window = Window.new
window.state.gauge.add(420)
window.goto(Minigames::Bath.new(window, window.state))
180.times { Gosu.fake_ms += 50; window.update }

canvas = Canvas.new(window.width, window.height)
Gosu.canvas = canvas
window.draw
Gosu.canvas = nil
canvas.save_crop(File.join(OUT, "closeup_bath_head.png"), 390, 300, 180, 130, 4)
puts "ok"
