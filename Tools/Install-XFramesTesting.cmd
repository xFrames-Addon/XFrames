@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0Install-XFramesTesting.ps1" %*
endlocal
