@echo off
setlocal
set "AHK=%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe"
if not exist "%AHK%" (
  echo AutoHotkey v2 not found at %AHK%
  echo Install with: winget install -e --id AutoHotkey.AutoHotkey
  exit /b 1
)
start "" "%AHK%" "%~dp0scripts\voice-to-claude.ahk"
