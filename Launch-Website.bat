@echo off
title St. Thomas Church Website
echo Starting St. Thomas Malankara Catholic Church Web Portal...
start "" "http://localhost:8080/index.html"
powershell -ExecutionPolicy Bypass -File "%~dp0server.ps1"
pause
