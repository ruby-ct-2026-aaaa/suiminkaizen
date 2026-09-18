# frozen_string_literal: true

# 実描画で登録されたボタンの中心をクリックし、全5種の入力を確認する。
require_relative '../lib/stream_window'

class MouseSmokeWindow < Kosuke::StreamWindow
  attr_accessor :holding_mouse, :test_mouse_x, :test_mouse_y

  def mouse_x
    test_mouse_x || super
  end

  def mouse_y
    test_mouse_y || super
  end

  def held?(*ids)
    holding_mouse && ids.include?(Gosu::MS_LEFT)
  end
end

window = MouseSmokeWindow.new
activities = Kosuke::Balance::ACTIVITIES.keys.dup
checks = 0
clicks = 0
draw_scene = window.method(:draw)

window.define_singleton_method(:update) do
  unless state.phase == :mini
    if activities.empty?
      close!
      next
    end
    reset
    dispatch(:start)
    open_activity(activities.shift)
    start_minigame(:normal)
  end
  case mini
  when Kosuke::Minigames::Reaction
    advance_game([mini.starts_at + 0.08 - mini.time, 0].max)
  when Kosuke::Minigames::Supplement
    advance_game([mini.reveal_end + 0.05 - mini.time, 0].max)
  when Kosuke::Minigames::Training
    advance_game(0.4)
  end
end

window.define_singleton_method(:draw) do
  next unless state.phase == :mini
  draw_scene.call
  action = case mini
           when Kosuke::Minigames::Training then :action
           when Kosuke::Minigames::Bath then :left
           when Kosuke::Minigames::Supplement then %i[one two three four][mini.sequence[mini.answers.size]]
           when Kosuke::Minigames::Reaction then mini.actions[mini.active_target]
           end
  button = @buttons.find { |b| b[:id] == action }
  raise "Missing button #{action}" unless button
  raise 'Mini button overlaps sidebar' unless button[:x] >= 24 && button[:x] + button[:w] <= 784
  checks += 1
  self.test_mouse_x = button[:x] + button[:w] / 2
  self.test_mouse_y = button[:y] + button[:h] / 2
  @last_ms = Gosu.milliseconds
  before = mini.respond_to?(:scores) ? mini.scores.size : (mini.respond_to?(:answers) ? mini.answers.size : mini.position)
  if mini.is_a?(Kosuke::Minigames::Bath)
    self.holding_mouse = true
    advance_game(0.2)
    self.holding_mouse = false
    raise 'Bath hold did not move left' unless mini.position < before
    state.finish_minigame(0)
  else
    button_down(Gosu::MS_LEFT)
    after = mini.respond_to?(:scores) ? mini.scores.size : mini.answers.size
    raise "Click was not received: #{action}" unless after == before + 1
  end
  checks += 1
  clicks += 1
end

window.show
puts "#{checks} mouse layout checks passed; #{clicks} inputs across all 5 minigames."
