#!/usr/bin/env ruby
# frozen_string_literal: true

# 睡眠改善プロジェクト 〜ショートスリーパー峰小輔の一週間〜
#
#   ruby main.rb
#
# で起動する。必要なのは gosu だけ（gem install gosu）。

require_relative "lib/suiminkaizen"

Suiminkaizen::Window.new.show
