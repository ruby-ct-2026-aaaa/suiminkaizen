# frozen_string_literal: true

# Windows 向けの「Ruby 同梱」配布パッケージを組み立てる。
#
#   ruby tools/build_windows_package.rb [出力先ディレクトリ]
#
# 遊ぶ側に何もインストールさせないための形。いま動いている Ruby 本体と gosu を
# まるごと同梱し、解凍して start_game.bat を押すだけで遊べるようにする。
# ビルド用の MSYS2（約900MB）やドキュメント（約214MB）は入れない。
#
# 組み上がったら、MSYS2 が見えない状態で gosu を読み込めるかまで確認する。
# ここを確かめないと「自分のPCでだけ動く」パッケージが出来上がる。

require "rbconfig"
require "fileutils"

SOURCE   = RbConfig::TOPDIR                  # いま動いている Ruby の場所
RUBY_API = RbConfig::CONFIG["ruby_version"]  # 例: "4.0.0"
PROJECT  = File.expand_path("..", __dir__)
DEST     = File.expand_path(ARGV[0] || File.join(PROJECT, "tmp", "dist"))
PKG      = File.join(DEST, "suiminkaizen")

# 実行に要らないもの。ここを削らないと 1GB を超える。
SKIP_DIRS = [
  "msys64",        # ビルド用ツールチェーン（約900MB）
  "share",         # ドキュメント・ロケール（約214MB）
  "include",       # C ヘッダ
  "lib/pkgconfig"  # ビルド設定
].freeze

SKIP_GEM_SUBDIRS  = %w[cache doc plugins build_info].freeze
# gosu はソースからビルドする gem なので、ビルド材料が丸ごと残っている。
# 実行に要るのは lib（gosu.so を含む）と lib64（SDL2.dll）だけ。
SKIP_GOSU_SUBDIRS = %w[dependencies src ext include rdoc].freeze

# このマシンの Ruby は utf_16be.so を読み込むとクラッシュする。
# ゲームは UTF-16 を使わないので、壊れたものを配るより外しておく。
SKIP_FILES = ["enc/utf_16be.so"].freeze

# gosu.so が要求する MSYS2 製の DLL。MSYS2 を同梱しない以上、
# これだけは個別に持っていく必要がある（合計 200KB 程度）。
RUNTIME_DLLS = %w[libgcc_s_seh-1.dll libwinpthread-1.dll].freeze

def skip?(relative)
  return true if SKIP_DIRS.any? { |d| relative == d || relative.start_with?("#{d}/") }
  return true if SKIP_FILES.any? { |f| relative.end_with?(f) }

  gems_root = "lib/ruby/gems/#{RUBY_API}/"
  return false unless relative.start_with?(gems_root)

  rest = relative.delete_prefix(gems_root)
  return true if SKIP_GEM_SUBDIRS.any? { |d| rest == d || rest.start_with?("#{d}/") }

  if (match = rest.match(%r{\Agems/gosu-[^/]+/(.+)\z}))
    inner = match[1]
    return true if SKIP_GOSU_SUBDIRS.any? { |d| inner == d || inner.start_with?("#{d}/") }
  end
  false
end

# from 以下を、prefix からの相対パスを保ったまま to_root へ複写する。
def copy_tree(from, to_root, prefix, filter: true)
  copied = 0
  bytes  = 0
  Dir.glob("#{from}/**/*").each do |path|
    relative = path.delete_prefix("#{prefix}/")
    next if filter && skip?(relative)

    target = File.join(to_root, relative)
    if File.directory?(path)
      FileUtils.mkdir_p(target)
    else
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(path, target)
      copied += 1
      bytes  += File.size(path)
    end
  end
  [copied, bytes]
end

def mb(bytes) = format("%.1f MB", bytes / 1024.0 / 1024.0)

# cmd.exe とメモ帳がそのまま読めるよう CP932 + CRLF で書き出す。
# 波ダッシュ(U+301C)は CP932 に無いので、全角チルダ(U+FF5E)へ寄せる。
def write_cp932(path, text)
  text = text.tr("〜−―", "～－—")
  unless (bad = text.each_char.reject { |c| c.encode("Windows-31J") rescue nil }).empty?
    abort "CP932 に変換できない文字があります (#{path}): #{bad.uniq.inspect}"
  end

  File.binwrite(path, text.encode("Windows-31J").gsub(/\r?\n/, "\r\n"))
end

# --- 組み立て ---------------------------------------------------------------

puts "同梱元の Ruby : #{SOURCE} (#{RUBY_VERSION})"
puts "出力先        : #{PKG}"
puts

FileUtils.rm_rf(PKG)
FileUtils.mkdir_p(PKG)

total = 0
%w[bin lib].each do |dir|
  count, bytes = copy_tree(File.join(SOURCE, dir), File.join(PKG, "ruby"), SOURCE)
  total += bytes
  puts format("  ruby/%-4s  %5d ファイル  %s", dir, count, mb(bytes))
end

game = File.join(PKG, "game")
FileUtils.mkdir_p(game)
FileUtils.cp(File.join(PROJECT, "main.rb"), game)
count, bytes = copy_tree(File.join(PROJECT, "lib"), game, PROJECT, filter: false)

# 峰小輔の立ち絵。変換済みの PNG だけを持っていく（元の JPG は不要）。
portraits = Dir.glob(File.join(PROJECT, "assets", "kosuke", "*.png"))
abort "立ち絵が見つからない。先に tools/prepare_sprites.rb を実行すること" if portraits.empty?

FileUtils.mkdir_p(File.join(game, "assets", "kosuke"))
portraits.each do |path|
  FileUtils.cp(path, File.join(game, "assets", "kosuke"))
  bytes += File.size(path)
  count += 1
end

total += bytes
puts format("  game/      %5d ファイル  %s", count + 1, mb(bytes))

# gosu の隣と ruby/bin の両方へ置いておく（どちらから探されても拾えるように）
gosu_lib64 = Dir.glob(File.join(PKG, "ruby/lib/ruby/gems/*/gems/gosu-*/lib64")).first
abort "gosu の lib64 が見つからない" unless gosu_lib64

RUNTIME_DLLS.each do |dll|
  source = File.join(SOURCE, "msys64", "ucrt64", "bin", dll)
  abort "同梱すべき DLL が見つからない: #{source}" unless File.exist?(source)

  [File.join(PKG, "ruby", "bin"), gosu_lib64].each { |dir| FileUtils.cp(source, dir) }
  total += File.size(source) * 2
  puts format("  DLL        %s (%s)", dll, mb(File.size(source)))
end

# --- 同梱物を置く -----------------------------------------------------------

write_cp932(File.join(PKG, "start_game.bat"), <<~BAT)
  @echo off
  rem Keep every command and comment in this file ASCII-only.
  rem cmd.exe parses .bat with the console code page, so non-ASCII syntax
  rem breaks parsing. Japanese appears only in echo output, and this file
  rem is saved as CP932 (Shift_JIS) for that reason.
  cd /d "%~dp0"
  setlocal

  rem Ignore whatever Ruby settings the machine may already have.
  set "RUBYOPT="
  set "RUBYLIB="
  set "GEM_HOME="
  set "GEM_PATH="
  set "PATH=%~dp0ruby\\bin;%PATH%"

  echo ==========================================================
  echo  睡眠改善プロジェクト
  echo  ショートスリーパー峰小輔の一週間
  echo ==========================================================
  echo.
  echo 起動します。この黒いウィンドウは閉じずにそのままにしてください。
  echo.

  "%~dp0ruby\\bin\\ruby.exe" "%~dp0game\\main.rb"

  if errorlevel 1 (
    echo.
    echo [エラー] ゲームが異常終了しました。
    echo          上のメッセージを控えて、配布元にお知らせください。
    echo.
    pause
  )

  endlocal
BAT

write_cp932(File.join(PKG, "README.txt"), <<~TXT)
  睡眠改善プロジェクト 〜ショートスリーパー峰小輔の一週間〜

  ■ 遊びかた

    start_game.bat をダブルクリックするだけです。
    Ruby のインストールは要りません（このフォルダに同梱しています）。

    黒いウィンドウが一緒に開きますが、閉じないでください。
    閉じるとゲームも終了します。

  ■ 操作

    SPACE / Enter  決定、筋トレのバーベル、サプリを飲む、ウトウトからの復帰
    左右キー       サプリメントのコップを動かす
    上下キー       お風呂の湯温を上げ下げ（押しっぱなし）
    ESC            ポーズ（ポーズ中に T でタイトル、Q で終了）
    R              ゲームオーバー／クリア画面からやり直し

  ■ ゲームの目的

    睡眠ゲージは 0 が健康、1000 に達すると気絶＝ゲームオーバーです。
    1日6本のミニゲーム（筋トレ・お風呂・サプリメント）でゲージを削り、
    1日を乗り切ると夜に30分だけ眠れてゲージが30だけ減ります。
    これを7日間くり返し、一度も気絶させなければ勝ちです。

    1日およそ5分、7日クリアでおよそ35分を見込んでいます。

  ■ うまく動かないとき

    ・フォルダごと解凍できているか確認してください。
      ZIP の中身を直接ダブルクリックしても動きません。
    ・ウイルス対策ソフトに止められることがあります。
      その場合はこのフォルダを除外設定に入れてください。

  ■ 同梱しているもの

    ruby/   Ruby 本体（BSDライセンス / Rubyライセンス）
            gosu（MITライセンス）
            SDL2（zlibライセンス）
            libgcc / libwinpthread（GCC Runtime Library Exception 付き GPL,
            mingw-w64）
    game/   ゲーム本体のソースコード

    それぞれのライセンス全文は ruby/ 以下および
    ruby/lib/ruby/gems/*/gems/gosu-*/COPYING を参照してください。
TXT

puts "  同梱物     start_game.bat, README.txt"

# --- 自分のPC以外でも動くかの確認 -------------------------------------------

puts
puts "MSYS2 が見えない状態で gosu を読み込めるか確認..."

bundled = File.join(PKG, "ruby", "bin", "ruby.exe")
abort "ruby.exe が同梱できていない" unless File.exist?(bundled)

clean_env = {
  "RUBYOPT" => nil, "RUBYLIB" => nil, "GEM_HOME" => nil, "GEM_PATH" => nil,
  "PATH" => "#{ENV.fetch('SystemRoot', 'C:\\Windows')}\\system32;#{ENV.fetch('SystemRoot', 'C:\\Windows')}"
}
ok = system(clean_env, bundled, "-e", <<~CHECK)
  require "gosu"
  puts "  gosu #{'#{Gosu::VERSION}'} を読み込めました"
CHECK
abort "同梱した Ruby から gosu を読み込めなかった" unless ok

# 立ち絵が欠けていると、ゲームは動くが峰小輔だけ消える。ここで検算しておく。
missing = %w[normal success fail sleep].reject do |name|
  File.exist?(File.join(game, "assets", "kosuke", "#{name}.png"))
end
abort "立ち絵が足りない: #{missing.join(', ')}" unless missing.empty?
puts "  立ち絵 4 種をすべて同梱しました"

puts
puts "完成: #{PKG}"
puts "合計 #{mb(total)}"
puts
puts "ZIP にするには:"
puts %(  powershell Compress-Archive -Path "#{PKG}" -DestinationPath "#{PKG}.zip" -Force)
