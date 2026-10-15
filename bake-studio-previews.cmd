@echo off
"%~dp0..\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0." --rendering-method forward_plus --rendering-driver vulkan --script res://tools/bake_studio_spell_previews.gd -- %*
exit /b %errorlevel%
