@echo off
"%~dp0..\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." --rendering-method forward_plus --rendering-driver vulkan --resolution 1440x900 res://spell-sandbox.tscn -- %*
