# frozen_string_literal: true

# 実ゲームの描画を連番PNGへ。プレビュー用に各場面の開始ゲージのみ設定する。
# ruby tools/capture_animation.rb [出力フォルダ]
require 'fileutils'
require_relative '../lib/stream_window'

class PreviewWindow < Kosuke::StreamWindow
  attr_accessor :simulated_keys

  def held?(*ids)
    ids.any? { |id| (@simulated_keys || []).include?(id) }
  end
end

output = File.expand_path(ARGV[0] || '../animation_frames', __dir__)
FileUtils.mkdir_p(output)
window = PreviewWindow.new
draw_scene = window.method(:draw)
frame_index = 0

capture = lambda do
  original = window.world.method(:render)
  scene = original.call
  window.world.define_singleton_method(:render) { scene }
  begin
    image = Gosu.render(1120, 780) { draw_scene.call }
    image.save(File.join(output, format('frame-%04d.png', frame_index)))
    frame_index += 1
  ensure
    window.world.define_singleton_method(:render, original)
  end
end

script = Fiber.new do
  [:room, :training, :bath, :supplement, :massage, :camera].each do |kind|
    window.reset
    window.dispatch(:start)
    window.state.instance_variable_set(:@gauge, kind == :room ? 810.0 : 590.0)
    window.advance_game(0)
    unless kind == :room
      window.open_activity(kind)
      window.start_minigame(:normal)
    end
    frames = kind == :room ? 40 : 44
    frames.times do |index|
      window.dispatch(:repel) if kind == :room && index == 28
      12.times do
        if window.state.phase == :mini
          game = window.mini
          case game
          when Kosuke::Minigames::Bath
            window.simulated_keys = game.position > game.target + 0.01 ? [Gosu::KB_LEFT] :
              (game.position < game.target - 0.01 ? [Gosu::KB_RIGHT] : [])
          when Kosuke::Minigames::Training
            window.dispatch(:action) if (game.marker - 0.5).abs < 0.014
          when Kosuke::Minigames::Supplement
            if !game.revealing? && game.answers.size < 4 && game.time >= game.reveal_end + game.answers.size * 0.25
              window.dispatch(%i[one two three four][game.sequence[game.answers.size]])
            end
          when Kosuke::Minigames::Reaction
            if game.active_target && game.time >= game.starts_at + 0.24
              # カメラの2回目のみ、外した時の待機画面も見せる。
              choice = kind == :camera && game.scores.size == 1 ? (game.active_target + 1) % 6 : game.active_target
              window.dispatch(game.actions[choice])
            end
          end
        end
        window.advance_game(1.0 / 120)
      end
      capture.call
      Fiber.yield
    end
    window.simulated_keys = []
  end
end

window.define_singleton_method(:update) { }
window.define_singleton_method(:draw) do
  script.resume if script.alive?
  close! unless script.alive?
end
window.show
puts "Captured #{frame_index} frames at 10 fps."
