@echo off
setlocal
REM Kill only the AutoHotkey instance running voice-to-claude.ahk
for /f "tokens=2 delims=," %%P in ('tasklist /FI "IMAGENAME eq AutoHotkey64.exe" /FO CSV /NH 2^>nul') do (
  for /f "tokens=*" %%C in ('wmic process where "ProcessId=%%~P" get CommandLine /value 2^>nul ^| find "voice-to-claude.ahk"') do (
    taskkill /PID %%~P /F >nul 2>&1 && echo Stopped PID %%~P
  )
)
