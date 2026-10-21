extends Node3D
## One bounded draw for one real surface UUID. Full neighbors/plane bounds are
## supplied once per footprint change; no area solver, registry or new clock.
const Readiness = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
var bank: Resource
var owner_uuid := ""
var material: ShaderMaterial
var plane: MeshInstance3D
var packet: Dictionary = {}
var owner_state: Dictionary = {}
var anchor_valid := false
var state_error := ""

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.get("surface_bank", ""))]

static func make_component(input: Dictionary) -> Node3D:
	var prepared: Resource = Readiness.resources.get(str(input.get("surface_bank", "")))
	if prepared == null or not prepared.interface_ready or str(input.get("surface_uuid", "")).is_empty():
		return null
	var node: Node3D = VfxPackageIO_e337e0c543.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/e337e0c543aa9b9a17b2/field.gd").new()
	node.bank = prepared
	node.owner_uuid = input.surface_uuid
	node.material = prepared.partition_material.duplicate(false)
	node.plane = MeshInstance3D.new()
	node.plane.name = "ObservedPartition"
	node.plane.material_override = node.material
	node.plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.plane.top_level = true
	node.add_child(node.plane)
	node.plane.hide()
	return node

func source_bindings() -> Dictionary:
	return {"geometry": [plane], "materials": [material], "players": [], "lights": [],
		"static_material_topology": true, "static_geometry_layers": true}

func prepare_source_layer_mask(value: int) -> void:
	plane.layers = value

func set_surface_partition(value: Dictionary) -> bool:
	plane.hide()
	packet.clear()
	state_error = "Partition must be produced from the actual full admitted owner topology"
	if not value.get("error", "Missing topology").is_empty() or str(value.get("owner_uuid", "")) != owner_uuid:
		return false
	if value.get("capacity") != bank.capacity or not value.get("points") is PackedVector2Array or not value.get("edges") is PackedVector4Array or not value.get("draw_flags") is PackedFloat32Array:
		return false
	if value.points.size() != bank.capacity or value.edges.size() != bank.capacity or value.draw_flags.size() != bank.capacity:
		return false
	if not value.get("minimum") is Vector2 or not value.get("maximum") is Vector2 or not value.minimum.is_finite() or not value.maximum.is_finite():
		return false
	var count: int = value.get("count", -1)
	var draw_count: int = value.get("draw_count", -1)
	if count < 0 or count > bank.capacity or draw_count < 0 or draw_count > count:
		return false
	var seen := {}
	var actual_draw_count := 0
	for index in count:
		var point: Vector2 = value.points[index]
		var edge: Vector4 = value.edges[index]
		if not point.is_finite() or point != point.floor() or seen.has(point) or value.draw_flags[index] not in [0.0, 1.0]:
			return false
		for axis in 4:
			if edge[axis] not in [0.0, 1.0]:
				return false
		seen[point] = true
		actual_draw_count += int(value.draw_flags[index])
	if actual_draw_count != draw_count:
		return false
	packet = value.duplicate(true)
	state_error = ""
	if draw_count == 0:
		plane.mesh = null
		return true
	var extent: Vector2 = packet.maximum - packet.minimum
	if extent.x <= 0.0 or extent.y <= 0.0:
		packet.clear()
		state_error = "Positive full-owner plane bounds required"
		return false
	# Keep the ORIGINAL full-owner geometry/UV on every disjoint draw. A local
	# chunk mesh would change native texture coordinates/vertex displacement.
	var mesh := PlaneMesh.new()
	mesh.size = extent
	mesh.center_offset = Vector3((packet.minimum.x + packet.maximum.x) * 0.5,
		0.02 if bank.style == "ice" else 0.018, (packet.minimum.y + packet.maximum.y) * 0.5)
	mesh.subdivide_width = 32 if bank.style == "ice" else 24
	mesh.subdivide_depth = mesh.subdivide_width
	plane.mesh = mesh
	var prefix := "payload_" if bank.style == "ice" else "observed_"
	material.set_shader_parameter(prefix + "cells", packet.points)
	material.set_shader_parameter(prefix + "open_edges", packet.edges)
	material.set_shader_parameter(prefix + "draw_flags", packet.draw_flags)
	material.set_shader_parameter(prefix + "cell_count", packet.count)
	return true

func set_owner_state(value: Dictionary) -> bool:
	plane.hide()
	owner_state.clear()
	if str(value.get("owner_uuid", "")) != owner_uuid:
		return false
	for field in ["present", "observed", "suppressed"]:
		if typeof(value.get(field)) != TYPE_BOOL:
			return false
	var age: Variant = value.get("owner_age_seconds")
	if typeof(age) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(age)) or float(age) < 0.0:
		return false
	owner_state = value.duplicate(true)
	return true

func set_live_endpoints(value: Array) -> void:
	anchor_valid = not value.is_empty() and value[0] is Dictionary and value[0].get("point") is Vector3 and value[0].point.is_finite()
	if not anchor_valid:
		plane.hide()
		return
	plane.global_transform = Transform3D(Basis.IDENTITY, value[0].point)
	if bank.style == "ice":
		material.set_shader_parameter("payload_footprint_origin", value[0].point)

func sample(_seconds: float) -> void:
	plane.hide()
	var alpha := 0.0
	var age := float(owner_state.get("owner_age_seconds", 0.0))
	if anchor_valid and not packet.is_empty() and packet.draw_count > 0 and not owner_state.is_empty() and owner_state.present and owner_state.observed and not owner_state.suppressed:
		alpha = smoothstep(0.0, 0.2 if bank.style == "ice" else float(bank.source_input.get("birth_seconds", 0.22)), age)
		alpha *= 0.36 if bank.style == "ice" else float(bank.source_input.get("opacity", 0.65))
	if bank.style == "ice":
		material.set_shader_parameter("payload_alpha", alpha)
	else:
		material.set_shader_parameter("orb_burst_seconds", age)
		material.set_shader_parameter("orb_burst_envelope", alpha)
	plane.visible = alpha > 0.001

func refresh_live_inputs(seconds: float) -> void:
	# Actual Occurrence refreshes same-age changed inputs through this hook.
	# This source is analytic: no emitter restart or history is advanced.
	sample(seconds)

const VfxPackageIO_e337e0c543 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
