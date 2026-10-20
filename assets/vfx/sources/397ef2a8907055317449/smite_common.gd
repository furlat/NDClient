extends Node3D
## Explicit strike and receiving-condition packets. Gameplay eligibility, toggle
## choice, cost, saves, damage and lifetime are disclosed inputs, never inferred.
const MeasuredSurface = preload("res://assets/vfx/sources/2e511bee2be14a679d5d/measured_surface.gd")
const SmiteMaterial = preload("res://assets/vfx/sources/e0cbef75c1fd5001da18/smite_material.gd")
const PathRibbon = preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")
const GeometryKey = preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd")

var settings: Dictionary = {}
var strike: Dictionary = {}
var condition: Dictionary = {}
var tick: Dictionary = {}
var weapon: Dictionary = {}
var endpoints: Array = []
var meshes: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var measurement: Dictionary = {}
var local_clock := 0.0
var envelope := 0.0
var cached_contact_key: Array = []
var cached_contact_index := -1
var cached_patch_key: Array = []
var cached_patch_indices: Array[int] = []
var cached_patch: Dictionary = {}
var cached_patch_origin := Vector3.ZERO
var cached_torso_key: Array = []
var cached_torso_index := -1

func configure(input: Dictionary) -> void:
	settings = input.duplicate(true)
	set_strike_input(input.get("strike",{}))
	set_condition_input(input.get("condition",{}))
	set_tick_input(input.get("tick",{}))

func set_strike_input(value: Dictionary) -> void:
	strike = value.duplicate(true)
	_hide_all()

func set_condition_input(value: Dictionary) -> void:
	condition = value.duplicate(true)
	_hide_all()

func set_tick_input(value: Dictionary) -> void:
	tick = value.duplicate(true)
	_hide_all()

func set_entity_geometry(value: Dictionary) -> void:
	weapon = value
	if str(value.get("actor","")) != str(settings.source_actor_uuid):
		weapon = {}
	if value.has("item_uuid") and str(value.item_uuid) != str(settings.item_uuid):
		weapon = {}
	if weapon.is_empty():
		_hide_all()

func set_live_endpoints(value: Array) -> void:
	endpoints = value

func payload_admitted() -> bool:
	return str(strike.get("source_actor_uuid","")) == str(settings.source_actor_uuid) \
		and str(strike.get("recipient_uuid","")) == str(settings.recipient_uuid) \
		and str(strike.get("item_uuid","")) == str(settings.item_uuid) \
		and str(strike.get("attack_uuid","")) == str(settings.attack_uuid) \
		and str(strike.get("behavior_id","")) == str(settings.behavior_id) \
		and str(strike.get("equipment_slot","")) == str(settings.equipment_slot) \
		and str(strike.get("source_kind","")) == "equipped" \
		and str(strike.get("attack_kind","")) == "weapon" \
		and str(strike.get("outcome","")) in ["hit","critical"] \
		and bool(strike.get("payload_applied",false)) \
		and not str(strike.get("damage_component_uuid","")).is_empty()

func condition_admitted() -> bool:
	return not str(condition.get("condition_uuid","")).is_empty() \
		and str(condition.get("condition_uuid","")) == str(settings.get("condition_uuid","")) \
		and str(condition.get("condition_id","")) == str(settings.get("condition_id","")) \
		and str(condition.get("source_actor_uuid","")) == str(settings.source_actor_uuid) \
		and str(condition.get("recipient_uuid","")) == str(settings.recipient_uuid) \
		and bool(condition.get("present",false)) and bool(condition.get("observed",false)) \
		and bool(condition.get("contribution_active",false)) and not bool(condition.get("suppressed",true))

func tick_admitted() -> bool:
	return condition_admitted() and str(tick.get("condition_uuid","")) == str(condition.condition_uuid) \
		and str(tick.get("recipient_uuid","")) == str(settings.recipient_uuid) \
		and bool(tick.get("damage_applied",false)) and not str(tick.get("damage_fact_uuid","")).is_empty()

func make_mesh(label: String, material: ShaderMaterial) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.top_level = true
	node.mesh = ArrayMesh.new()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.hide()
	add_child(node)
	meshes.append(node)
	if not materials.has(material):
		materials.append(material)
	return node

func _hide_all() -> void:
	for mesh in meshes:
		mesh.hide()

func phase_envelope(seconds: float) -> float:
	var phase := str(settings.phase)
	if phase == "condition" and str(settings.get("lifecycle_mode","owned_state")) == "owned_state":
		return smoothstep(0.0,.16,seconds)
	var lifetime := float(settings.seconds)
	if seconds < 0.0 or seconds >= lifetime:
		return 0.0
	if phase == "retire":
		return 1.0-smoothstep(0.0,lifetime,seconds)
	return smoothstep(0.0,.045,seconds)*(1.0-smoothstep(lifetime*.50,lifetime,seconds))

func _sample_materials(seconds: float, value: float) -> void:
	local_clock = seconds
	envelope = value
	for material in materials:
		material.set_shader_parameter("smite_clock",seconds)
		material.set_shader_parameter("smite_envelope",envelope)

func measure_weapon() -> Dictionary:
	if weapon.is_empty():
		return {}
	var hand: Vector3 = endpoints[0].point if not endpoints.is_empty() else weapon.origin
	measurement = MeasuredSurface.build(weapon,str(settings.render_slot),hand,.006)
	return measurement

func recipient_surface() -> Dictionary:
	if endpoints.size() < 2:
		return {}
	var value: Dictionary = endpoints[1].get("surface",{})
	return value if str(value.get("actor","")) == str(settings.recipient_uuid) else {}

func contact() -> Dictionary:
	var surface := recipient_surface()
	if surface.get("points",[]).is_empty() or endpoints.size() < 2:
		return {}
	var point: Vector3 = endpoints[1].point
	var pose := GeometryKey.from_surface(surface)
	var query: Array = [pose, point - surface.get("origin", Vector3.ZERO), surface.points.size()]
	var prepared: bool = settings.get("prepared_geometry_queries", false) and not pose.is_empty()
	if prepared and query == cached_contact_key and cached_contact_index >= 0:
		var selected: Dictionary = surface.points[cached_contact_index]
		return {"position": selected.position + selected.normal * .012, "normal": selected.normal.normalized()}
	var best: Dictionary = surface.points[0]
	var best_index := 0
	for index in surface.points.size():
		var candidate: Dictionary = surface.points[index]
		if candidate.position.distance_squared_to(point) < best.position.distance_squared_to(point):
			best = candidate
			best_index = index
	if prepared:
		cached_contact_key = query.duplicate(true)
		cached_contact_index = best_index
	return {"position":best.position+best.normal*.012,"normal":best.normal.normalized()}

func recipient_patch() -> Dictionary:
	var surface := recipient_surface()
	var result := {"actor":settings.recipient_uuid,"origin":surface.get("origin",Vector3.ZERO),"points":[],"gpu_geometry_key":surface.get("gpu_geometry_key",surface.get("pose_key",[]))}
	if surface.get("points",[]).is_empty():
		return result
	var pose := GeometryKey.from_surface(surface)
	var prepared: bool = settings.get("prepared_geometry_queries", false) and not pose.is_empty()
	var key: Array = [pose, surface.points.size()]
	if prepared and key == cached_patch_key:
		if cached_patch_origin != result.origin:
			# Read the actual current source samples by original ordinal. Do not
			# reconstruct translated positions or average a replacement surface.
			for index in cached_patch_indices.size():
				var current: Dictionary = surface.points[cached_patch_indices[index]]
				cached_patch.points[index].position = current.position
				cached_patch.points[index].normal = current.normal
			cached_patch.origin = result.origin
			cached_patch_origin = result.origin
		return cached_patch
	var ordinals: Array[int] = []
	var height := .0
	for point in surface.points:
		height = maxf(height,point.position.y-result.origin.y)
	for index in surface.points.size():
		var point: Dictionary = surface.points[index]
		var relative: float = (point.position.y-result.origin.y)/maxf(.01,height)
		if not str(point.slot) in ["body","chest","cloak"] or relative < .43 or relative > .80:
			continue
		var copy: Dictionary = point.duplicate()
		copy.slot = "recipient_patch"
		result.points.append(copy)
		ordinals.append(index)
	if prepared:
		cached_patch_key = key.duplicate(true)
		cached_patch_indices = ordinals
		cached_patch = result
		cached_patch_origin = result.origin
	return result

func recipient_torso_contact(patch: Dictionary) -> Dictionary:
	if patch.points.is_empty():
		return {}
	var pose := GeometryKey.from_surface(patch)
	var key: Array = [pose, patch.origin, patch.points.size()]
	var prepared: bool = settings.get("prepared_geometry_queries", false) and not pose.is_empty()
	if not prepared or key != cached_torso_key or cached_torso_index < 0:
		# Preserve the original source's exact centre accumulation and nearest
		# sample tie order. Only unchanged declared poses/origins reuse the pick.
		var centre := Vector3.ZERO
		for point in patch.points:
			centre += point.position
		centre /= float(patch.points.size())
		var nearest: Dictionary = patch.points[0]
		var selected := 0
		for index in patch.points.size():
			var point: Dictionary = patch.points[index]
			if point.position.distance_squared_to(centre) < nearest.position.distance_squared_to(centre):
				nearest = point
				selected = index
		if prepared:
			cached_torso_key = key.duplicate(true)
			cached_torso_index = selected
		return {"position": nearest.position + nearest.normal * .018, "normal": nearest.normal.normalized()}
	var nearest: Dictionary = patch.points[cached_torso_index]
	return {"position": nearest.position + nearest.normal * .018, "normal": nearest.normal.normalized()}

func plane_axes(normal: Vector3) -> Array[Vector3]:
	var side := normal.cross(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = Vector3.RIGHT
	return [side,side.cross(normal).normalized()]

func capture_observation() -> Dictionary:
	return {"smite":{"phase":settings.get("phase"),"clock":local_clock,"envelope":envelope,
		"source_actor_uuid":settings.get("source_actor_uuid"),"recipient_uuid":settings.get("recipient_uuid"),
		"item_uuid":settings.get("item_uuid"),"attack_uuid":settings.get("attack_uuid"),
		"payload_admitted":payload_admitted(),"condition_admitted":condition_admitted(),"tick_admitted":tick_admitted(),
		"condition_uuid":condition.get("condition_uuid"),"weapon_cells":measurement.get("cells",0),
		"visible_meshes":meshes.filter(func(mesh:MeshInstance3D)->bool:return mesh.is_visible_in_tree()).size(),
		"lights":0,"extra_attacks":0,"rule_solver":false}}
