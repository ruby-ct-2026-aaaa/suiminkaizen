# frozen_string_literal: true

begin
  require_relative 'lib/stream_window'
rescue LoadError => e
  warn "起動に必要なライブラリを読み込めませんでした: #{e.message}"
  warn 'Gosuをインストールしてください: gem install gosu -v 1.4.6'
  exit 1
end

Kosuke::StreamWindow.new.show
