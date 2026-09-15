# frozen_string_literal: true

require_relative "sleep_gauge"

# 1日ぶんの行動ループを進めるクラス。
#
# ゲージの上限到達判定（＝強制気絶）と下限クランプ、日末の固定処理はすべて
# SleepGauge側に一元化されているため、ここでは「1日に何回行動できるか」と
# 「どの時点で1日を中断するか」というループの制御だけを扱う。
#
# 行動として渡すミニゲームは、描画・入力を伴う実際のループ（lib/states）が
# update/drawを回してfinished?になった後のもの、つまり結果が確定済みのものを
# 想定している。DayCycleはsucceeded?とgauge_reductionしか参照しない。
class DayCycle
  # 1日あたりの行動回数。
  # 企画側で1日の行動回数の仕様が決まったら差し替える前提の暫定値。
  ACTIONS_PER_DAY = 3

  # 「何もしない」行動。ミニゲームへの挑戦は任意なので、この選択が常に成立する。
  WAIT = :wait

  def initialize(gauge)
    @gauge = gauge
  end

  # その日の行動リストを順に処理して1日を進める。
  #
  # actions: :wait またはミニゲームのインスタンス（succeeded? / gauge_reduction を持つ
  #          オブジェクト）の配列。
  #          ACTIONS_PER_DAYより少ない場合、足りないぶんは:waitとして扱う。
  #          多い場合はACTIONS_PER_DAY回ぶんだけ処理し、残りは無視する。
  #
  # 戻り値: 1日を最後まで消化してend_of_day!に到達したらtrue、
  #         途中でゲームオーバーになって中断したらfalse。
  def play_day(actions = [])
    ACTIONS_PER_DAY.times do |index|
      perform(actions[index] || WAIT)
      # 行動1つごとに強制気絶を確認し、その時点で残りの行動を捨てて中断する。
      return false if @gauge.game_over?
    end

    @gauge.end_of_day!
    true
  end

  private

  # ミニゲームに成功していれば、その減少量ぶんをマイナスにしてゲージに渡す。
  # 失敗した場合と:waitの場合はゲージを一切動かさない
  # （ゲージの自然増加ロジックは企画側の仕様待ちのため未実装）。
  def perform(action)
    return if action == WAIT
    return unless action.succeeded?

    @gauge.apply(-action.gauge_reduction)
  end
end
