@echo off
wsl.exe -d Ubuntu-24.04 --cd "%~dp0." -- env PYTHONPATH=../dnd_engine:../dnd_engine/sdk/python/src /home/tommaso/.cache/dnd-engine/venv/bin/python tools/play.py %*
if errorlevel 1 pause
