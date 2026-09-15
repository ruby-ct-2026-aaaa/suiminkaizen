# frozen_string_literal: true

# 本物の Gosu でウィンドウを開き、数秒ぶん自動で操作してから閉じる起動確認。
#   ruby tools/gosu_check.rb

require_relative "../lib/suiminkaizen"

module Suiminkaizen
  class Window
    alias_method :__check_update, :update

    def update
      @frames = (@frames || 0) + 1
      __check_update
      button_down(Gosu::KB_SPACE) if (@frames % 30).zero?
      close if @frames > 360
    end
  end
end

font = Suiminkaizen::Assets.normal
puts "font candidates : #{Suiminkaizen::Assets.available.inspect}"
puts "font in use     : #{font.name.inspect} (height #{font.height})"
puts "width of 睡眠   : #{font.text_width('睡眠ゲージ')}"
puts "width of ABC    : #{font.text_width('ABC')}"

Suiminkaizen::Window.new.show
puts "ウィンドウは正常に開閉しました"
