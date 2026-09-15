@echo off
rem ---------------------------------------------------------------
rem  Launcher for Windows. Double-click this file to play.
rem  NOTE: keep every command and comment in this file ASCII-only.
rem  cmd.exe parses .bat with the console code page, so non-ASCII
rem  syntax breaks parsing. Japanese appears only in echo output,
rem  and this file is saved as CP932 (Shift_JIS) for that reason.
rem ---------------------------------------------------------------
cd /d "%~dp0"
setlocal

echo ==========================================================
echo  睡眠改善プロジェクト
echo  ショートスリーパー峰小輔の一週間
echo ==========================================================
echo.

rem --- locate ruby.exe -------------------------------------------
set "RUBY="

rem 1. on PATH
where ruby.exe >nul 2>&1 && set "RUBY=ruby.exe"

rem 2. RubyInstaller default locations
if not defined RUBY (
  for /d %%D in ("C:\Ruby*") do (
    if exist "%%~D\bin\ruby.exe" set "RUBY=%%~D\bin\ruby.exe"
  )
)
if not defined RUBY (
  for /d %%D in ("%LOCALAPPDATA%\Programs\Ruby*") do (
    if exist "%%~D\bin\ruby.exe" set "RUBY=%%~D\bin\ruby.exe"
  )
)

if not defined RUBY (
  echo [エラー] Ruby が見つかりませんでした。
  echo          https://rubyinstaller.org/ からインストールしてください。
  echo.
  pause
  exit /b 1
)

echo 使用する Ruby : %RUBY%

rem --- make sure gosu is available --------------------------------
"%RUBY%" -e "require 'gosu'" >nul 2>&1
if errorlevel 1 (
  echo gosu が見つからないのでインストールします...
  "%RUBY%" -S gem install gosu --no-document
  "%RUBY%" -e "require 'gosu'" >nul 2>&1
  if errorlevel 1 (
    echo.
    echo [エラー] gosu を用意できませんでした。
    echo          コマンドプロンプトで gem install gosu を試してください。
    echo.
    pause
    exit /b 1
  )
)

rem --- run --------------------------------------------------------
echo 起動します。この黒いウィンドウは閉じずにそのままにしてください。
echo.
"%RUBY%" main.rb
if errorlevel 1 (
  echo.
  echo [エラー] ゲームが異常終了しました。上のメッセージを確認してください。
  echo.
  pause
)

endlocal
