# frozen_string_literal: true

# テストは画面を開かずに走らせたいので、Gosu をスタブに差し替えてから読み込む。
$LOAD_PATH.unshift(File.expand_path("../tools/stub", __dir__))

require "minitest/autorun"
require_relative "../lib/suiminkaizen"

include Suiminkaizen # rubocop:disable Style/MixinUsage
