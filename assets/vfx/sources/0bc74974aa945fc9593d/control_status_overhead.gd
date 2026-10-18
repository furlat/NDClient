extends "res://assets/vfx/sources/d092a75e3b0074bcf468/control_status.gd"
## Original Blinded/Deafened glyph with measured head clearance.
const OverheadAnchor = preload("res://assets/vfx/sources/352283aaacfa78292274/overhead_anchor.gd")
var overhead := OverheadAnchor.new()
var head_endpoints: Array = []


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/0bc74974aa945fc9593d/control_status_overhead.gd", input)


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
