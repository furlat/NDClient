extends Node3D
## Authored native marker with three real phases and no internal hold expiry.
## Attachment and size are explicit input; no rules, actor lookup or AABB guess.
const MaterialPlane = preload("res://assets/vfx/sources/53a08b13a376af2ecd8a/material_plane.gd")
const Program = preload("res://assets/vfx/sources/2aa74876db6a11f64ab1/condition_program.gd")
const Clock = preload("res://assets/vfx/sources/605e963db6160617a696/condition_clock.gd")
var specification: Dictionary = {}
var lifecycle_context: Dictionary = {}
var glyph: MeshInstance3D
var endpoints: Array = []
var state: Dictionary = {}


static func prepared_state_capability() -> Dictionary:
	return {"schema": "vfxfactory.prepared_state.v1", "mode": "packed_scene_with_adapter_state",
		"capture_method": "capture_prepared_state", "restore_method": "restore_prepared_state",
		"direct_time_sampling": true, "requires_warmup": false,
		"mutable_materials": ["Glyph:material_override"], "immutable_resources": ["mesh", "shader", "source_textures"]}


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = VfxPackageIO_ed7fc22f64.resource("res://assets/vfx/sources/ed7fc22f644ee87c9dd5/steady_marker.gd").new()
	instance.specification = input.duplicate(true)
	instance.glyph = MaterialPlane.make_component({"size": input.size_cells, "material": input.material})
	assert(instance.glyph != null)
	instance.glyph.name = "Glyph"
	Program.prepare(instance.glyph.material_override, str(input.material.shader), true)
	instance.add_child(instance.glyph)
	instance.glyph.owner = instance
	instance.glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func capture_prepared_state() -> Dictionary:
	return {"specification": specification.duplicate(true), "glyph": NodePath("Glyph")}


func restore_prepared_state(prepared: Dictionary) -> void:
	specification = prepared.specification.duplicate(true)
	glyph = get_node(prepared.glyph)
	# Shader/mesh/source textures are shared. No material clock can leak owners.
	glyph.material_override = glyph.material_override.duplicate(false)
	lifecycle_context = {}
	endpoints = []
	state = {}


func set_lifecycle_context(value: Dictionary) -> void:
	lifecycle_context = value.duplicate(true)


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func sample(seconds: float) -> void:
	var phase: String = lifecycle_context.get("phase", specification.phase)
	var phase_age: float = lifecycle_context.get("phase_age_seconds", seconds)
	var clock_spec := specification.duplicate()
	clock_spec.phase_seconds = specification.get("durations", {}).get(phase, specification.phase_seconds)
	state = Clock.evaluate(phase, phase_age, clock_spec, lifecycle_context)
	var material: ShaderMaterial = glyph.material_override
	material.set_shader_parameter("condition_opacity", state.opacity)
	material.set_shader_parameter(specification.clock_parameter, float(specification.get("steady_source_clock", 0.0)))
	var clearance: float = float(specification.get("clearance_cells", .16))
	var endpoint_index := int(specification.get("endpoint_index", 0))
	if endpoints.size() > endpoint_index:
		glyph.global_position = endpoints[endpoint_index].point + Vector3.UP * clearance
	else:
		glyph.position = Vector3.UP * float(specification.get("height_cells", 0.0))
	# The original XY glyph faces the current camera in its vertex program.
	# Owner attachment and opacity remain explicit inputs; no camera script.


func capture_observation() -> Dictionary:
	return {"lifecycle": state.duplicate(true), "prepared_capability": prepared_state_capability(),
		"draw_calls": 1, "particles": 0, "lights": 0, "body_surface_slots": 0,
		"source_clock_is_steady": true, "owner_controls_expiry": true}

const VfxPackageIO_ed7fc22f64 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
