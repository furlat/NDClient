extends Node3D
## Current production weapon_binding/entity_geometry contract. Source owns no
## replacement weapon, item creation, attack, condition identity or gameplay timer.
const Measured = preload("res://assets/vfx/sources/a4f6231f0bb4547489bc/condition_measured.gd")
var style: Resource
var receiving := Measured.new()
var binding: Dictionary = {}
var surface: Dictionary = {}
var owner_state: Dictionary = {}
var materials: Array[ShaderMaterial] = []
var draws: Array[MeshInstance3D] = []
var rejection := "weapon_not_bound"
var clock := 0.0
var retired := false

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.style)]

static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_a7bb17f8a6.resource("res://assets/vfx/sources/a7bb17f8a6f8b7fadf85/treatment.gd").new()
	node.style = VfxPackageIO_a7bb17f8a6.resource(str(input.style))
	return node

func _ready() -> void:
	var geometry := []
	for index in style.materials.size():
		var material: ShaderMaterial = style.materials[index].duplicate(false)
		materials.append(material)
		var draw := MeshInstance3D.new()
		draw.name = "MeasuredWeaponShell"+str(index)
		draw.mesh = style.mesh
		draw.material_override = material
		draw.layers = 1<<19
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.custom_aabb = AABB(Vector3(-4,-2,-4),Vector3(8,6,8))
		draw.set_meta("condition_measured_template",true)
		draw.hide()
		add_child(draw)
		draws.append(draw)
		geometry.append({"node":draw})
	receiving.configure(self,{"settings":{"slot":"weapon","requires_equipped_item":true,"capacity":style.capacity,"clearance_cells":.003}},geometry)

func _hide(reason: String) -> void:
	rejection = reason
	receiving.admitted_geometry = false
	receiving.last_key = []
	for draw in draws:
		draw.hide()

func set_weapon_binding(value: Dictionary) -> bool:
	binding = value
	if not _binding_valid():
		_hide("actual_weapon_membership_missing")
		return false
	return true

func _binding_valid() -> bool:
	if retired:
		return false
	for name in ["item_uuid","holder_uuid","owner_uuid","item_id"]:
		if str(binding.get(name,"")).is_empty():
			return false
	if binding.get("owner_kind") not in ["item","caster"]:
		return false
	if binding.owner_kind == "item" and str(binding.owner_uuid)!=str(binding.item_uuid):
		return false
	if binding.owner_kind == "caster" and str(binding.owner_uuid)!=str(binding.holder_uuid):
		return false
	if binding.get("binding_origin") == "intrinsic_authored_item":
		if binding.owner_kind != "item" or str(binding.get("authored_effect_source","")).is_empty():
			return false
	elif str(binding.get("effect_uuid","")).is_empty():
		return false
	for name in ["present","observed","equipped","suppressed"]:
		if not binding.get(name) is bool:
			return false
	return binding.present and binding.observed and binding.equipped and not binding.suppressed \
		and binding.get("render_slot")=="weapon" and binding.get("equipment_slot") in ["MELEE_MAIN","RANGED_MAIN"]

func set_entity_geometry(value: Dictionary) -> void:
	surface = value
	if str(value.get("item_uuid","")) != str(binding.get("item_uuid","")) or str(value.get("actor","")) != str(binding.get("holder_uuid","")):
		_hide("exact_item_surface_missing")

func set_owner_state(value: Dictionary) -> void:
	owner_state = value

func set_root_path(value: Transform3D) -> void:
	global_transform = value

func sample(seconds: float) -> void:
	if not _binding_valid():
		_hide("actual_weapon_not_admitted")
		return
	# Commit current binding and pose together; do not rebuild the old pose with
	# a new hand before the caller supplies its matching optical packet.
	receiving.weapon_binding = binding
	receiving.update(surface)
	if not receiving.admitted_geometry:
		rejection = "actual_weapon_geometry_unavailable"
		return
	rejection = ""
	clock = float(owner_state.get("source_age_seconds",owner_state.get("owner_age_seconds",seconds)))
	for material in materials:
		material.set_shader_parameter("weapon_clock",clock)
		material.set_shader_parameter("weapon_opacity",1.)

func clear() -> void:
	retired = true
	binding = {}
	surface = {}
	receiving.current_surface = {}
	_hide("retired")
	for material in materials:
		material.set_shader_parameter("weapon_opacity",0.)
		material.set_shader_parameter("vfx_measured_points",null)

func source_bindings() -> Dictionary:
	return {"geometries":draws,"materials":materials,"lights":[]}

func capture_observation() -> Dictionary:
	return {"element":style.element,"strength":style.strength,"rejection":rejection,"item_uuid":binding.get("item_uuid",""),
		"holder_uuid":binding.get("holder_uuid",""),"source_seconds":clock,"measured_uploads":receiving.uploads,
		"table_builds":receiving.table_builds,"shared_table_hits":receiving.cache_hits,"admitted":receiving.admitted_geometry,
		"uses_fake_condition":false,"replaces_weapon":false,"owns_hit_or_lamp":false}

const VfxPackageIO_a7bb17f8a6 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
