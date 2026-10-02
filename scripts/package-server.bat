@echo off
rem Packs what the internet server needs into release\susthiti-server.tar.gz.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0package-server.ps1"
