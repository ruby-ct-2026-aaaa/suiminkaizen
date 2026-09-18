# frozen_string_literal: true

# 開発用：Gosuの実際の描画からスクリーンショットを作る。
# ruby tools/capture.rb [出力フォルダ]
# Linuxの画面なし環境：SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy ruby tools/capture.rb
require 'fileutils'
require_relative '../lib/stream_window'

output = File.expand_path(ARGV[0] || '../captures', __dir__)
FileUtils.mkdir_p(output)
window = Kosuke::StreamWindow.new
draw_scene = window.method(:draw)

capture = lambda do |name|
  # Gosu 1.4.6のrenderターゲットは入れ子にしない。
  # 部屋を先に描画し、通常のdrawにその同じ描画結果を渡す。
  original = window.world.method(:render)
  scene = original.call
  window.world.define_singleton_method(:render) { scene }
  begin
    image = Gosu.render(Kosuke::GameWindow::WIDTH, Kosuke::GameWindow::HEIGHT) { draw_scene.call }
    image.save(File.join(output, "#{name}.png"))
  ensure
    window.world.define_singleton_method(:render, original)
  end
  puts "Captured #{name}"
end

script = Fiber.new do
capture.call('title')
window.button_down(Gosu::KB_RETURN)
window.advance_game(18)
window.advance_game(2)
capture.call('room')
window.dispatch(:toggle_view)
capture.call('player-view')
window.dispatch(:toggle_view)
window.open_activity(:training)
capture.call('difficulty')
window.start_minigame(:normal)
window.advance_game(0.8)
capture.call('training')
window.state.finish_minigame(0.9)
capture.call('result')
window.dispatch(:continue)
window.open_activity(:bath)
window.start_minigame(:hard)
window.advance_game(1.3)
capture.call('bath')
window.state.finish_minigame(0.9)
window.dispatch(:continue)
window.open_activity(:supplement)
window.start_minigame(:normal)
window.advance_game(0.65)
capture.call('memory')
window.dispatch(:pause)
capture.call('pause')
window.dispatch(:resume)
window.state.finish_minigame(1)
window.dispatch(:continue)
window.open_activity(:massage)
window.start_minigame(:normal)
window.advance_game(0.65)
capture.call('massage')
window.state.finish_minigame(0.9)
window.dispatch(:continue)
window.open_activity(:camera)
window.start_minigame(:normal)
window.advance_game(0.65)
capture.call('camera')
window.state.finish_minigame(0.9)
window.dispatch(:continue)
window.state.advance(window.state.remaining)
capture.call('day-clear')
window.dispatch(:nap)
window.advance_game([(800 - window.state.gauge) / window.state.rate, 0].max)
window.advance_game(0)
capture.call('kuiya-room')
window.open_activity(:camera)
window.start_minigame(:normal)
window.advance_game(1)
capture.call('kuiya-camera')
window.state.finish_minigame(0)
window.dispatch(:continue)
window.advance_game(90)
capture.call('game-over')

# 勝利画面は正規の進行APIで7日間プレイして作る。
window.reset
window.dispatch(:start)
7.times do
  7.times do |i|
    window.state.advance(3.5)
    window.open_activity(Kosuke::Balance::ACTIVITIES.keys[i % 5])
    window.start_minigame(:normal)
    window.state.advance(8)
    window.state.finish_minigame(1)
    window.dispatch(:continue)
  end
  window.state.advance(window.state.remaining)
  window.dispatch(:nap)
end
raise 'Week did not complete' unless window.state.phase == :victory
capture.call('victory')
end

# キャプチャも実ウィンドウの描画フレーム内で行う。
window.define_singleton_method(:update) { }
window.define_singleton_method(:draw) do
  script.resume if script.alive?
  close! unless script.alive?
end
window.show
