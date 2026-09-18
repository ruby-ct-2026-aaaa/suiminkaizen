# frozen_string_literal: true

# 実Gosuで入力→移動→各ミニゲーム→結果画面まで確認する。
# ruby test/smoke_gosu.rb
# 画面なしLinux: SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy ruby test/smoke_gosu.rb
require_relative '../lib/stream_window'

class SmokeWindow < Kosuke::StreamWindow
  attr_accessor :simulated_keys

  def held?(*ids)
    ids.any? { |id| (@simulated_keys || []).include?(id) }
  end
end

checks = 0
check = lambda do |condition, message|
  raise message unless condition
  checks += 1
end

window = SmokeWindow.new
window.button_down(Gosu::KB_RETURN)
check.call(window.state.phase == :room, 'ENTER did not start')

reach = lambda do |key, expected|
  window.button_down(key)
  1200.times do
    window.advance_game(1.0 / 120)
    break if window.state.phase == :choose
  end
  check.call(window.state.phase == :choose && window.state.activity == expected,
             "Could not reach #{expected}")
end

reach.call(Gosu::KB_1, :training)
window.button_down(Gosu::KB_2)
window.lose_focus
gauge, time = window.state.gauge, window.mini.time
feed_time, ghost_time = window.feed.clock, window.hallucinations.time
window.advance_game(20)
window.gain_focus
check.call(window.state.phase == :paused && window.state.gauge == gauge && window.mini.time == time,
           'Focus pause did not freeze the game')
check.call(window.feed.clock == feed_time && window.hallucinations.time == ghost_time,
           'Pause did not freeze comments and hallucinations')
window.button_down(Gosu::KB_ESCAPE)
2400.times do
  break unless window.state.phase == :mini
  window.button_down(Gosu::KB_SPACE) if (window.mini.marker - 0.5).abs < 0.01
  window.advance_game(1.0 / 240)
end
check.call(window.state.phase == :result && window.state.last_result[:reward].positive?,
           'Training input did not clear')
window.button_down(Gosu::KB_RETURN)

reach.call(Gosu::KB_2, :bath)
window.button_down(Gosu::KB_2)
1200.times do
  break unless window.state.phase == :mini
  window.simulated_keys = if window.mini.position > window.mini.target + 0.012
                            [Gosu::KB_LEFT]
                          elsif window.mini.position < window.mini.target - 0.012
                            [Gosu::KB_RIGHT]
                          else []
                          end
  window.advance_game(1.0 / 120)
end
window.simulated_keys = []
check.call(window.state.phase == :result && window.state.last_result[:reward].positive?,
           'Bath controls did not clear')
window.button_down(Gosu::KB_RETURN)

reach.call(Gosu::KB_3, :supplement)
window.button_down(Gosu::KB_3)
window.button_down(Gosu::KB_1)
check.call(window.mini.answers.empty?, 'Reveal phase accepted input')
window.advance_game(window.mini.reveal_end + 0.01)
window.mini.sequence.each do |index|
  window.button_down([Gosu::KB_1, Gosu::KB_2, Gosu::KB_3, Gosu::KB_4][index])
end
check.call(window.state.phase == :result && window.state.last_result[:reward] == 300,
           'Memory controls did not clear')
window.button_down(Gosu::KB_RETURN)
reach.call(Gosu::KB_4, :massage)
window.button_down(Gosu::KB_2)
1200.times do
  break unless window.state.phase == :mini
  window.advance_game(1.0 / 120)
  next unless window.state.phase == :mini
  target = window.mini.active_target
  if target && window.mini.time >= window.mini.starts_at + 0.12
    window.button_down(target.zero? ? Gosu::KB_LEFT : Gosu::KB_RIGHT)
  end
end
check.call(window.state.phase == :result && window.state.last_result[:reward].positive?,
           'Massage arrow controls did not clear')
check.call(window.feed.history.any? { |entry| entry[:event] == :massage_ok }, 'Massage did not emit comments')
window.button_down(Gosu::KB_RETURN)
reach.call(Gosu::KB_5, :camera)
window.button_down(Gosu::KB_3)
# 5・6キーも必ず通す。
window.mini.instance_variable_set(:@targets, [4, 5, 0, 1, 2, 3])
1200.times do
  break unless window.state.phase == :mini
  window.advance_game(1.0 / 120)
  next unless window.state.phase == :mini
  target = window.mini.active_target
  if target && window.mini.time >= window.mini.starts_at + 0.12
    window.button_down([Gosu::KB_1, Gosu::KB_2, Gosu::KB_3, Gosu::KB_4, Gosu::KB_5, Gosu::KB_6][target])
  end
end
check.call(window.state.phase == :result && window.state.last_result[:reward].positive?,
           'Camera 1-6 controls did not clear')
check.call(window.feed.history.any? { |entry| entry[:event] == :camera_ok }, 'Camera did not emit comments')
window.button_down(Gosu::KB_RETURN)
window.button_down(Gosu::KB_C)
check.call(!window.comments_enabled, 'C did not hide scrolling comments')
window.button_down(Gosu::KB_C)
window.button_down(Gosu::KB_V)
check.call(!window.viewer_mode, 'V did not switch to player view')
window.button_down(Gosu::KB_V)
window.button_down(Gosu::KB_H)
check.call(window.gentle, 'H did not reduce hallucination intensity')
window.button_down(Gosu::KB_H)
window.state.advance(window.state.remaining)
window.button_down(Gosu::KB_RETURN)
check.call(window.state.day == 2 && window.state.phase == :room, 'Daily nap did not advance the day')
window.state.instance_variable_set(:@gauge, 800.0)
window.advance_game(0)
check.call(window.hallucinations.visible?, 'High gauge did not summon Kuiya')
window.button_down(Gosu::KB_9)
check.call(window.hallucinations.flee.positive? && window.state.gauge >= 800,
           'Number 9 failed to repel or incorrectly healed gauge')

# 通常のGosuメインループと描画を30フレーム実行。
window.define_singleton_method(:update) do
  @smoke_frames = (@smoke_frames || 0) + 1
  @smoke_frames >= 30 ? close! : super()
end
window.show
puts "#{checks} Gosu integration checks passed; 30 main-loop frames rendered."
