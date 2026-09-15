# frozen_string_literal: true

# 本物のミニゲーム（筋トレ／お風呂／サプリメント）の仕様が企画側から届くまでの仮実装。
# CLAUDE.mdで定めたミニゲーム共通インターフェースだけを満たす最小のダミーで、
# 骨組み（DayCycle・7日間サイクル）の疎通確認に使う。
class DummyMinigame
  # succeeds:        このミニゲームが成功する扱いかどうか
  # gauge_reduction: 成功したときに睡眠ゲージから減らす量
  def initialize(succeeds:, gauge_reduction:)
    @succeeds = succeeds
    @gauge_reduction = gauge_reduction
  end

  # フレームごとの更新。ダミーなので受け取るだけで何もしない。
  def update(dt); end

  # 描画。lib/core同様Gosuに依存させないため、仮実装では空にしておく。
  def draw; end

  # 1回の呼び出しで即座に結果が出る仮実装なので常にtrue。
  def finished?
    true
  end

  def succeeded?
    @succeeds
  end

  # 成功時のみコンストラクタで渡された減少量を返す。失敗時は0。
  def gauge_reduction
    succeeded? ? @gauge_reduction : 0
  end
end
