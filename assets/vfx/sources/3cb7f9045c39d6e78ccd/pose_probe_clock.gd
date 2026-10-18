extends Node3D
## Bounded engineering inspection window only. No artwork or game lifetime.
var seconds := 0.0
static func make_component(_input: Dictionary) -> Node3D:
	return VfxPackageIO_3cb7f9045c.resource("res://assets/vfx/sources/3cb7f9045c39d6e78ccd/pose_probe_clock.gd").new()
func sample(value: float) -> void:
	seconds = value
func capture_observation() -> Dictionary:
	return {"engineering_observation_window_only": true, "seconds": seconds, "geometry": 0, "optical_lights": 0, "game_lifetime_solver": false}

const VfxPackageIO_3cb7f9045c = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
