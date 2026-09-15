# frozen_string_literal: true

# すべてのテストをまとめて走らせる。
#   ruby spec/all.rb

Dir[File.expand_path("core/*_spec.rb", __dir__)].sort.each { |f| require f }
