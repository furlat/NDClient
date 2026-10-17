@echo off
rem Records every native spell clip into .derived/baked_effects (local generated data).
rem Run after importing changed Factory sources; stale recordings fall back to the native source.
rem Arguments pass through, e.g. --spells=fireball or --clips=<id> or --variants=3 (default --all).
set ARGS=%*
if "%ARGS%"=="" set ARGS=--all --variants=3
"%~dp0..\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0." --rendering-method forward_plus --rendering-driver vulkan --fixed-fps 60 --script res://tools/bake_native_effects.gd -- %ARGS%
exit /b %errorlevel%
