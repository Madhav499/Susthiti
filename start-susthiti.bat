@echo off
rem Starts the model service, backend and (by default) the app in Chrome. Options: -App none, -Lan, -SeedDemo
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-susthiti.ps1" %*
pause
