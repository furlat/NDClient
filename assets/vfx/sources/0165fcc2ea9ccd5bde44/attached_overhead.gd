extends Node3D
## A steady source glyph at a supplied current head socket. The condition owner
## owns admission/removal; this component does not infer duration or gameplay.
const Marker = preload("res://assets/vfx/sources/956b2fde8af4cd11d880/overhead_marker.gd")
const Opacity = preload("res://assets/vfx/sources/39f30ee3f172ac269cd6/native_opacity.gd")
var marker: Node3D
var endpoints: Array = []
var clearance: float = .16


static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_0165fcc2ea.resource("res://assets/vfx/sources/0165fcc2ea9ccd5bde44/attached_overhead.gd").new()
	var visual: Dictionary = input.marker.duplicate(true)
	visual.height_cells = 0.0
	# No auto expiry or looping opacity trough in a persistent condition glyph.
	visual.duration_seconds = 1e12
	component.marker = Marker.make_component(visual)
	if component.marker == null:
		component.free()
		return null
	component.clearance = float(input.clearance_cells)
	component.add_child(component.marker)
	Opacity.apply(component.marker)
	return component


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func sample(seconds: float) -> void:
	if not endpoints.is_empty():
		marker.global_position = endpoints[0].point + Vector3.UP*clearance
	marker.sample(seconds)

const VfxPackageIO_0165fcc2ea = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
