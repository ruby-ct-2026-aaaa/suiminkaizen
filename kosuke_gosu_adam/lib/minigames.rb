# frozen_string_literal: true

require_relative 'minigames/training'
require_relative 'minigames/bath'
require_relative 'minigames/supplement'
require_relative 'minigames/massage'
require_relative 'minigames/camera'

module Kosuke
  module Minigames
    # 新しいミニゲームは共通クラスを継承して、この対応表に登録する。
    REGISTRY = {
      training: Training,
      bath: Bath,
      supplement: Supplement,
      massage: Massage,
      camera: Camera
    }.freeze
  end
end
