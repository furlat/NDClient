@echo off
wsl.exe -d Ubuntu-24.04 --cd "%~dp0." -- env PYTHONPATH=/home/tommaso/.cache/ndclient/dnd_engine-1f044792b1:/home/tommaso/.cache/ndclient/dnd_engine-1f044792b1/sdk/python/src /home/tommaso/.cache/dnd-engine/venv/bin/python tools/play.py %*
if errorlevel 1 pause
