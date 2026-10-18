extends "res://assets/vfx/sources/873e6e47725bc92490a6/sensory.gd"
## Original eye source/material/clock with a measured, view-facing head anchor.
const OverheadAnchor = preload("res://assets/vfx/sources/352283aaacfa78292274/overhead_anchor.gd")
var overhead := OverheadAnchor.new()
var head_endpoints: Array = []


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/40d1901e1f9156491a72/sensory_overhead.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	overhead.configure(node, parameters.get("overhead", {}))


func set_live_endpoints(value: Array) -> void:
	head_endpoints = value


func update_geometry() -> void:
	overhead.follow(head_endpoints)


func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result.overhead_anchor = overhead.observation
	return result
