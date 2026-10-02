@echo off
rem Builds the Android APKs and the web app for your internet server.
rem Usage: scripts\build-release.bat https://your-domain
if "%~1"=="" (
  echo Usage: scripts\build-release.bat https://your-domain
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-release.ps1" -Server "%~1"
