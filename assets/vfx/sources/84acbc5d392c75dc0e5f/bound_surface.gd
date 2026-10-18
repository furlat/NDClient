extends Node3D
## Small common ownership/geometry adapter. Visible compositions live in the
## two concrete components; no stage, camera, game action or rule solver here.
const Ownership = preload("res://assets/vfx/sources/6ee57b6fb1e6037a0826/ownership.gd")
const MeasuredSurface = preload("res://assets/vfx/sources/2e511bee2be14a679d5d/measured_surface.gd")
const NativeMaterial = preload("res://assets/vfx/sources/642a744813f07bd93ffe/native_material.gd")
const PathRibbon = preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")

var settings: Dictionary = {}
var ownership := Ownership.new()
var surface: Dictionary = {}
var endpoints: Array = []
var imprint: MeshInstance3D
var imprint_material: ShaderMaterial
var measurement: Dictionary = {}
var local_clock := 0.0
var envelope := 0.0

func configure(input: Dictionary, motif: String, finish: String) -> void:
	settings = input.duplicate(true)
	ownership.configure(input.ownership)
	imprint_material = NativeMaterial.make(input.material, motif, finish)
	imprint = make_mesh("ActualEquippedItemSurface", imprint_material)

func make_mesh(label: String, material: ShaderMaterial) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.top_level = true
	node.mesh = ArrayMesh.new()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.hide()
	add_child(node)
	return node

func set_weapon_binding(value: Dictionary) -> bool:
	var accepted := ownership.bind(value)
	# Ownership changes clear every old surface before accepting a new packet.
	surface.clear()
	measurement.clear()
	_hide_all()
	return accepted

func set_entity_geometry(value: Dictionary) -> void:
	surface = value
	if not ownership.matches_surface(surface):
		measurement.clear()
		_hide_all()
		return
	_rebuild()

func set_live_endpoints(value: Array) -> void:
	endpoints = value

func _hand() -> Vector3:
	return endpoints[0].point if not endpoints.is_empty() else surface.get("origin", Vector3.ZERO)

func _rebuild() -> void:
	if surface.is_empty() or not ownership.matches_surface(surface):
		_hide_all()
		return
	measurement = MeasuredSurface.build(surface, str(ownership.state.render_slot), _hand(), .006)
	imprint.global_transform = Transform3D(Basis.IDENTITY, surface.origin)
	imprint.mesh = measurement.mesh
	imprint.visible = envelope > .0001 and measurement.cells > 0

func _hide_all() -> void:
	for child in get_children():
		if child is GeometryInstance3D:
			child.hide()

func phase_envelope(seconds: float) -> float:
	var lifetime := float(settings.seconds)
	# A retained production condition does not expire with a preview interval.
	# Only the disclosed binding can suppress/remove this held state. Bounded
	# authoring examples opt in explicitly to a staged retirement schedule.
	if str(settings.phase) == "sustain" and str(settings.get("lifecycle_mode", "owned_state")) == "owned_state":
		return smoothstep(0.0, .15, seconds)
	if seconds < 0.0 or seconds >= lifetime:
		return 0.0
	match str(settings.phase):
		"windup":
			return smoothstep(0.0, .12, seconds) * (1.0 - smoothstep(lifetime - .12, lifetime, seconds))
		"application":
			return smoothstep(0.0, .08, seconds) * (1.0 - smoothstep(lifetime - .15, lifetime, seconds))
		"sustain":
			return smoothstep(0.0, .15, seconds) * (1.0 - smoothstep(lifetime - .15, lifetime, seconds))
		"retire":
			return 1.0 - smoothstep(0.0, lifetime, seconds)
		"hit":
			return smoothstep(0.0, .035, seconds) * (1.0 - smoothstep(.09, lifetime, seconds))
	return 0.0

func capture_observation() -> Dictionary:
	return {"weapon_binding":{"owner_kind":ownership.owner_kind, "owner_uuid":ownership.owner_uuid,
		"effect_uuid":ownership.effect_uuid, "state":ownership.state.duplicate(true),
		"rejection":ownership.rejection, "surface_actor":surface.get("actor"),
		"fixture_uuid_gap":not surface.has("item_uuid"), "phase":settings.get("phase"),
		"clock":local_clock, "envelope":envelope, "visible":imprint.visible,
		"cells":measurement.get("cells",0), "triangles":measurement.get("triangles",0),
		"normal_clearance_cells":.006, "lights":0, "physical_item_replaced":false}}
