# frozen_string_literal: true

require "gosu"

# 睡眠改善プロジェクト 〜ショートスリーパー峰小輔の一週間〜
#
# ドット絵 + 疑似3D（1点透視）のミニゲーム集。
# 読み込み順は依存関係の順そのまま。
module Suiminkaizen
end

require_relative "suiminkaizen/config"
require_relative "suiminkaizen/palette"
require_relative "suiminkaizen/px"
require_relative "suiminkaizen/assets"
require_relative "suiminkaizen/pixel_sprite"
require_relative "suiminkaizen/sprites"
require_relative "suiminkaizen/camera"
require_relative "suiminkaizen/stage"
require_relative "suiminkaizen/sleep_gauge"
require_relative "suiminkaizen/hud"
require_relative "suiminkaizen/scene"
require_relative "suiminkaizen/minigames/base"
require_relative "suiminkaizen/minigames/muscle"
require_relative "suiminkaizen/minigames/bath"
require_relative "suiminkaizen/minigames/supplement"
require_relative "suiminkaizen/game_state"
require_relative "suiminkaizen/scenes/title"
require_relative "suiminkaizen/scenes/day_intro"
require_relative "suiminkaizen/scenes/minigame_intro"
require_relative "suiminkaizen/scenes/minigame_result"
require_relative "suiminkaizen/scenes/day_result"
require_relative "suiminkaizen/scenes/sleep"
require_relative "suiminkaizen/scenes/game_over"
require_relative "suiminkaizen/scenes/ending"
require_relative "suiminkaizen/window"
