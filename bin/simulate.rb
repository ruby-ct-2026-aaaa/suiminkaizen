#!/usr/bin/env ruby
# frozen_string_literal: true

# 7日間ぶんのゲームループを標準出力だけで確認する簡易シミュレーター。
# 本物のミニゲームが届くまで、DummyMinigameで骨組みの疎通を確認するためのもの。
#
#   ruby bin/simulate.rb

require_relative "../lib/core/sleep_gauge"
require_relative "../lib/core/day_cycle"
require_relative "../lib/minigames/dummy_minigame"

# 睡眠ゲージの初期値。ゲージの自然増加ロジックが未実装（企画側の仕様待ち）で
# 現状はゲージが減る一方のため、動きが見えるように持たせている暫定値。
INITIAL_GAUGE = 500

# ダミーのミニゲームの成功時ゲージ減少量の範囲。これも本物が届くまでの暫定値。
DUMMY_REDUCTION_RANGE = (10..80).freeze

def random_minigame
  DummyMinigame.new(succeeds: [true, false].sample, gauge_reduction: rand(DUMMY_REDUCTION_RANGE))
end

def describe(minigame)
  return "失敗" unless minigame.succeeded?

  "成功(-#{minigame.gauge_reduction})"
end

gauge = SleepGauge.new(initial_value: INITIAL_GAUGE)
day_cycle = DayCycle.new(gauge)

puts "睡眠ゲージ初期値: #{gauge.value}"

SleepGauge::TOTAL_DAYS.times do
  day = gauge.current_day
  actions = Array.new(DayCycle::ACTIONS_PER_DAY) { random_minigame }

  # その日に組んだ行動リスト（＝処理される前の「予定」）を1行で表示する。
  puts "Day #{day} の行動: #{actions.map { |minigame| describe(minigame) }.join(' / ')}"

  unless day_cycle.play_day(actions)
    puts "Day #{day}で強制気絶... GAME OVER"
    break
  end

  puts "Day #{day}終了: ゲージ=#{gauge.value}"
end

puts "#{SleepGauge::TOTAL_DAYS}日間生存！WIN" if gauge.cleared?
