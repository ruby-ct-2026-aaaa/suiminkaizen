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
  echo [1/2] Ruby が見つかりませんでした。
  echo.
  echo   このゲームを動かすには Ruby が必要です。
  echo.
  echo   1. https://rubyinstaller.org/downloads/ を開く
  echo   2. "Ruby+Devkit" と書かれた x64 版をダウンロードする
  echo      ^(Devkit なしの版だと次の手順で必ず失敗します^)
  echo   3. インストール中の "Add Ruby to PATH" にチェックを入れる
  echo   4. 最後に出る黒い画面で Enter を押し、MSYS2 の導入まで終わらせる
  echo   5. パソコンを再起動してから、もう一度このファイルを押す
  echo.
  pause
  exit /b 1
)

echo 使用する Ruby : %RUBY%

rem --- make sure gosu is available --------------------------------
"%RUBY%" -e "require 'gosu'" >nul 2>&1
if errorlevel 1 (
  echo.
  echo [2/2] 描画ライブラリ gosu が入っていないので、これから導入します。
  echo       初回だけビルドが走るため 3～10 分ほどかかります。
  echo       このウィンドウを閉じずに、そのままお待ちください。
  echo.
  "%RUBY%" -S gem install gosu --no-document
  "%RUBY%" -e "require 'gosu'" >nul 2>&1
  if errorlevel 1 (
    echo.
    echo [エラー] gosu を用意できませんでした。
    echo.
    echo   gosu は Windows 用のビルド済みパッケージが配布されておらず、
    echo   コンパイル環境 ^(MSYS2 Devkit^) がないと導入できません。
    echo.
    echo   対処: コマンドプロンプトを開いて次を実行してください。
    echo.
    echo       ridk install
    echo.
    echo   選択肢が出たら 3 を入力して Enter。終わったらこのファイルを
    echo   もう一度押してください。
    echo.
    echo   ridk が見つからない場合は、Devkit なしの Ruby が入っています。
    echo   https://rubyinstaller.org/downloads/ から "Ruby+Devkit" を
    echo   入れ直してください。
    echo.
    pause
    exit /b 1
  )
  echo.
  echo gosu の導入が完了しました。
)

rem --- run --------------------------------------------------------
echo.
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
