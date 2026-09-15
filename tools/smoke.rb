# frozen_string_literal: true

# 画面を開かずにゲームを丸ごと走らせる動作確認。
#
#   ruby tools/smoke.rb
#
# tools/stub/gosu.rb が Gosu を肩代わりするので、実際のウィンドウは開かない。
# 腕前の違う4人で通しプレイして、
#   - 例外が出ないこと（描画の座標や色が壊れていればスタブが落ちる）
#   - 7日間クリアと気絶の両方に到達できること
#   - 1日あたりの所要時間がおよそ5分に収まること
# を確かめる。バランス調整の数字もここで眺められる。

$LOAD_PATH.unshift(File.expand_path("stub", __dir__))
require_relative "../lib/suiminkaizen"

include Suiminkaizen # rubocop:disable Style/MixinUsage

MS_PER_FRAME = 50 # Window::MAX_DT と同じ 0.05 秒きざみ
DRAW_EVERY   = 7
MAX_FRAMES   = 60_000

# 腕前を accuracy(0..1) で表すプレイヤー。
# 各ミニゲームの内部状態を覗いて「正解の操作」を確率的に行う。
class Player
  def initialize(accuracy)
    @accuracy = accuracy
  end

  # 押しっぱなしのキー（お風呂の温度調整）
  def held(scene)
    return [] unless scene.is_a?(Minigames::Bath)
    # 下手な人ほど反応が鈍く、修正が後手に回る。
    return [] if rand > @accuracy * 0.85 + 0.15

    diff = scene.instance_variable_get(:@target) - scene.instance_variable_get(:@temp)
    return [] if diff.abs < scene.band_half * 0.3

    [diff.positive? ? Gosu::KB_UP : Gosu::KB_DOWN]
  end

  def presses(scene)
    case scene
    when Minigames::Muscle      then muscle(scene)
    when Minigames::Bath        then bath(scene)
    when Minigames::Supplement  then supplement(scene)
    when Minigames::HeadMassage then massage(scene)
    when Minigames::Base        then []
    when Scene                  then [Gosu::KB_SPACE] # メニューはとにかく進める
    else []
    end
  end

  private

  def muscle(scene)
    cursor  = scene.instance_variable_get(:@cursor)
    center  = scene.instance_variable_get(:@zone_center)
    half    = scene.instance_variable_get(:@zone_half)
    perfect = scene.instance_variable_get(:@perfect_half)
    distance = (cursor - center).abs

    return rand < @accuracy ? [Gosu::KB_SPACE] : [] if distance <= perfect * 0.75

    # 下手な人ほど、見当違いのところでボタンを押してしまう。
    return [Gosu::KB_SPACE] if distance <= half * 2.2 && rand < (1.0 - @accuracy) * 0.02

    []
  end

  def bath(scene)
    return [] unless scene.instance_variable_get(:@doze_active)

    rand < @accuracy * 0.06 ? [Gosu::KB_SPACE] : []
  end

  # ヘッドマッサージは反応勝負。腕前が低いほど反応が遅れ、押し間違える。
  def massage(scene)
    prompt = scene.instance_variable_get(:@prompt)
    return [] unless prompt
    return [] if rand > @accuracy

    correct = rand < @accuracy
    [correct ? prompt[:key] : Minigames::HeadMassage::KEYS.keys.sample]
  end

  def supplement(scene)
    pills = scene.instance_variable_get(:@pills)
    lane  = scene.instance_variable_get(:@lane)

    candidates = pills.select { |p| p[:z] > 1.0 && p[:z] < 6.5 }
    # 見分けがつくかどうかも腕前しだい。
    candidates = candidates.select { |p| p[:type][:good] } if rand < @accuracy
    target = candidates.min_by { |p| p[:z] }
    return [] unless target

    return [target[:lane] > lane ? Gosu::KB_RIGHT : Gosu::KB_LEFT] if target[:lane] != lane

    window = 0.12 + (1.0 - @accuracy) * 1.6
    (target[:z] - Minigames::Supplement::CATCH_BEST).abs <= window ? [Gosu::KB_SPACE] : []
  end
end

# メニューだけ進めて、ミニゲームでは何もしない人。
class IdlePlayer < Player
  def initialize = super(0.0)
  def held(_scene) = []
  def presses(scene) = scene.is_a?(Minigames::Base) ? [] : [Gosu::KB_SPACE]
end

def terminal?(scene)
  scene.is_a?(Scenes::GameOver) || scene.is_a?(Scenes::Ending)
end

def play(label, player, seed)
  srand(seed)
  Gosu.fake_ms = 0
  Gosu.draw_calls = 0

  window = Window.new
  transitions = []
  last_class = nil
  frames = 0

  while frames < MAX_FRAMES
    Gosu.held = player.held(window.scene)
    Gosu.fake_ms += MS_PER_FRAME
    window.update

    scene = window.scene
    if scene.class != last_class
      last_class = scene.class
      transitions << [Gosu.fake_ms / 1000.0, scene.class.name.split("::").last,
                      window.state.day, window.state.gauge.to_i]
    end
    break if terminal?(scene)

    player.presses(scene).each { |key| window.button_down(key) }
    window.draw if (frames % DRAW_EVERY).zero?
    frames += 1
  end

  window.draw
  seconds = Gosu.fake_ms / 1000.0
  puts format("%-14s %-9s day=%d gauge=%4d  %5.1f分  (%d frames, %s draws)",
              label, window.scene.class.name.split("::").last, window.state.day,
              window.state.gauge.to_i, seconds / 60.0, frames,
              Gosu.draw_calls.to_s.reverse.scan(/\d{1,3}/).join(",").reverse)
  { window: window, transitions: transitions, seconds: seconds,
    outcome: window.scene.class.name.split("::").last }
end

def report_by_kind(window)
  window.state.all_results.group_by(&:kind).each do |kind, results|
    avg = results.sum(&:performance) / results.size
    raw = results.sum(&:raw_performance) / results.size
    score = results.sum(&:score) / results.size
    ranks = results.group_by(&:rank).transform_values(&:size).sort.map { |r, c| "#{r}:#{c}" }
    puts format("    %-11s 素点 %6.1f / 目標 %5.1f  素の達成率 %5.1f%%  採用 %5.1f%%  %s",
                kind, score, results.first.target, raw * 100, avg * 100, ranks.join(" "))
  end
end

puts "=== 通しプレイ ==="
runs = {
  "達人 (0.95)"  => play("達人 (0.95)", Player.new(0.95), 1),
  "中級 (0.72)"  => play("中級 (0.72)", Player.new(0.72), 2),
  "初心者 (0.45)" => play("初心者 (0.45)", Player.new(0.45), 3),
  "無操作"        => play("無操作", IdlePlayer.new, 4)
}

runs.each do |label, run|
  puts
  puts "=== #{label} ==="
  report_by_kind(run[:window])
  run[:window].state.days.each do |d|
    puts format("    DAY %d: %4d -> %4d  (削減 %3d / ミス +%3d)  %s",
                d.day, d.start_gauge.round, d.end_gauge.round,
                d.results.sum(&:reward).round, d.results.sum(&:penalty).round,
                d.results.map(&:rank).join)
  end
end

puts
puts "=== 各日の開始時刻（達人） ==="
runs["達人 (0.95)"][:transitions]
  .select { |(_, name, _, _)| name == "DayIntro" }
  .each { |(t, _, day, gauge)| puts format("    DAY%d  %6.1fs (%4.2f分)  gauge=%d", day, t, t / 60.0, gauge) }

outcomes = runs.values.map { |r| r[:outcome] }
puts
puts "クリア到達: #{outcomes.include?('Ending') ? 'OK' : 'NG'}" \
     " / 気絶到達: #{outcomes.include?('GameOver') ? 'OK' : 'NG'}"
