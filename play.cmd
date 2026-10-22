@echo off
wsl.exe -d Ubuntu-24.04 --cd "%~dp0." -- env PYTHONPATH=/home/tommaso/.cache/ndclient/dnd_engine-bedc3d92dc:/home/tommaso/.cache/ndclient/dnd_engine-bedc3d92dc/sdk/python/src /home/tommaso/.cache/dnd-engine/venv/bin/python tools/play.py %*
if errorlevel 1 pause
