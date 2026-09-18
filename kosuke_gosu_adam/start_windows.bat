@echo off
cd /d "%~dp0"
ruby main.rb
if errorlevel 1 pause
