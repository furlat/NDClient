extends "res://assets/vfx/sources/a7bb17f8a6f8b7fadf85/treatment.gd"
## Direct receiver treatment; no secondary geometry or fitted blade required.
## A sparse/occluded source frame remains sparse, with its real alpha intact.
var actor_layers: Dictionary = {}
var bound_materials: Array[ShaderMaterial] = []
var source_noise: Texture2D
var strength := 1.0
var assignments: Dictionary = {}
const ElementBindings = preload("res://assets/vfx/sources/6e2b58c2da1471a344dd/bind.gd")
const PureBindings = preload("res://assets/vfx/sources/74ae53cdc42ec95e07a0/bind.gd")
const AuxiliaryBindings = preload("res://assets/vfx/sources/530cfc1d1d453d31a8c2/bind.gd")
var element := "fire"
var artistic_strength := "medium"
var variant_id := "fire.blade_tongues"
var auxiliary_preset: ShaderMaterial
var pure_preset: ShaderMaterial
var appearance_mode := "enhanced"
# Direct procedural slots are intentionally single-owner. Do not let a second
# occurrence overwrite another clock or clear its material during retirement.
# Authored combinations can use the separate eight-field material compositor.
static var claimed_materials: Dictionary = {}
var owner_conflict := false

func _claim(material: ShaderMaterial) -> bool:
	var identity := material.get_instance_id()
	if claimed_materials.has(identity):
		var previous: Variant = claimed_materials[identity].get_ref()
		if is_instance_valid(previous) and previous != self:
			return false
	claimed_materials[identity] = weakref(self)
	return true

func _release_material(material: ShaderMaterial) -> void:
	var identity := material.get_instance_id()
	if not claimed_materials.has(identity) or claimed_materials[identity].get_ref() != self:
		return
	material.set_shader_parameter("weapon_blade_enabled", false)
	ElementBindings.clear(material)
	AuxiliaryBindings.clear(material)
	PureBindings.clear(material)
	material.set_shader_parameter("weapon_receiver_draw_enabled", false)
	material.set_shader_parameter("weapon_receiver_draw_mode", 0)
	claimed_materials.erase(identity)

static func preparation_resources(input: Dictionary) -> Array:
	var resources: Array = [str(input.noise)]
	if input.get("element", "fire") in ["ice", "electric"]:
		resources.append_array(ElementBindings.SOURCES.values())
	if input.has("auxiliary_preset"):
		resources.append(str(input.auxiliary_preset))
	if input.has("pure_preset"):
		resources.append(str(input.pure_preset))
	return resources

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_62383d0754.resource("res://assets/vfx/sources/62383d07549e9c732af2/direct_blade_material.gd").new()
	component.source_noise = VfxPackageIO_62383d0754.resource(str(input.noise))
	component.strength = float(input.get("strength", {"lesser": .5, "medium": .74, "greater": .95}[str(input.get("artistic_strength", "medium"))]))
	component.element = str(input.get("element", "fire"))
	component.artistic_strength = str(input.get("artistic_strength", "medium"))
	component.variant_id = str(input.get("variant_id", {"fire": "fire.blade_tongues", "ice": "ice.rime_facets", "electric": "electric.axial_forks"}.get(component.element, "")))
	if input.has("auxiliary_preset"):
		component.auxiliary_preset = VfxPackageIO_62383d0754.resource(str(input.auxiliary_preset))
	component.appearance_mode = str(input.get("appearance_mode", "enhanced"))
	if input.has("pure_preset"):
		component.pure_preset = VfxPackageIO_62383d0754.resource(str(input.pure_preset))
	return component

func _ready() -> void:
	pass

func set_actor_layers(value: Dictionary) -> void:
	actor_layers = value

func _hide(reason: String) -> void:
	rejection = reason
	for material in bound_materials:
		_release_material(material)
	bound_materials.clear()
	assignments.clear()

func sample(seconds: float) -> void:
	if not _binding_valid() or actor_layers.get("actor_uuid") != binding.get("holder_uuid"):
		_hide("actual_item_not_admitted")
		return
	var selected: Array[ShaderMaterial] = []
	owner_conflict = false
	for layer in actor_layers.get("layers", []):
		if layer.get("item_uuid") != binding.item_uuid or layer.get("slot") != "weapon":
			continue
		var material: ShaderMaterial = layer.material
		if material.shader.get_meta("factory_actor_material", "") != "weapon_layers":
			continue
		if not _claim(material):
			owner_conflict = true
			continue
		var identity := material.get_instance_id()
		var axis: Dictionary = layer.get("blade_axis", {})
		var hilt_tip: Vector4 = axis.get("hilt_tip", Vector4.ZERO)
		var axis_valid: bool = axis.get("axis_valid", false)
		var normal: Texture2D = layer.get("normal")
		var normal_valid: Texture2D = layer.get("normal_valid")
		var mask_only: bool = layer.get("source_mask_only", false)
		var parameters: Array = [layer.source, layer.frame, source_noise, strength, element, artistic_strength, variant_id, hilt_tip, axis_valid, normal, auxiliary_preset, pure_preset, appearance_mode, normal_valid, mask_only]
		if assignments.get(identity) != parameters:
			material.set_shader_parameter("weapon_blade_source", layer.source)
			material.set_shader_parameter("weapon_blade_frame", layer.frame)
			material.set_shader_parameter("weapon_blade_noise", source_noise)
			material.set_shader_parameter("weapon_blade_strength", strength)
			material.set_shader_parameter("weapon_blade_hilt_tip", hilt_tip)
			material.set_shader_parameter("weapon_blade_axis_valid", axis_valid)
			material.set_shader_parameter("weapon_blade_normals", normal)
			material.set_shader_parameter("weapon_blade_has_normals", normal != null)
			material.set_shader_parameter("weapon_blade_normal_valid", normal_valid)
			material.set_shader_parameter("weapon_blade_has_normal_valid", normal_valid != null)
			material.set_shader_parameter("weapon_blade_enabled", element == "fire" and appearance_mode == "enhanced")
			material.set_shader_parameter("weapon_blade_variant", 1 if variant_id == "fire.ember_sheath" else 0)
			if element in ["ice", "electric"] and appearance_mode == "enhanced":
				ElementBindings.configure_variant(material, variant_id, artistic_strength)
				material.set_shader_parameter("weapon_element_hilt_tip", hilt_tip)
				material.set_shader_parameter("weapon_element_half_width_uv", .025)
				material.set_shader_parameter("weapon_element_grip_end", .04)
				material.set_shader_parameter("weapon_element_axis_valid", axis_valid)
				material.set_shader_parameter("weapon_element_enabled", axis_valid)
			else:
				ElementBindings.clear(material)
			if auxiliary_preset != null:
				AuxiliaryBindings.configure(material, auxiliary_preset)
				material.set_shader_parameter("weapon_auxiliary_hilt_tip", hilt_tip)
				material.set_shader_parameter("weapon_auxiliary_half_width_uv", .025)
				material.set_shader_parameter("weapon_auxiliary_grip_end", .04)
				material.set_shader_parameter("weapon_auxiliary_axis_valid", axis_valid)
				material.set_shader_parameter("weapon_auxiliary_enabled", axis_valid or mask_only)
				material.set_shader_parameter("weapon_auxiliary_source_mask_only", mask_only)
			else:
				AuxiliaryBindings.clear(material)
			if pure_preset != null and appearance_mode == "pure":
				PureBindings.configure_preset(material, pure_preset)
				material.set_shader_parameter("weapon_pure_hilt_tip", hilt_tip)
				material.set_shader_parameter("weapon_pure_half_width_uv", .025)
				material.set_shader_parameter("weapon_pure_grip_end", .04)
				material.set_shader_parameter("weapon_pure_axis_valid", axis_valid)
				material.set_shader_parameter("weapon_pure_enabled", axis_valid)
			else:
				PureBindings.clear(material)
			material.set_shader_parameter("weapon_receiver_draw_mode", 2 if appearance_mode == "effect_only" else 1 if appearance_mode == "pure" else 0)
			material.set_shader_parameter("weapon_receiver_draw_enabled", axis_valid)
			assignments[identity] = parameters
		material.set_shader_parameter("weapon_blade_seconds", seconds)
		if pure_preset != null:
			material.set_shader_parameter("weapon_pure_seconds", seconds)
		if element in ["ice", "electric"]:
			material.set_shader_parameter("weapon_element_seconds", seconds)
		if auxiliary_preset != null:
			material.set_shader_parameter("weapon_auxiliary_seconds", seconds)
		selected.append(material)
	for previous in bound_materials:
		if previous not in selected:
			_release_material(previous)
			assignments.erase(previous.get_instance_id())
	bound_materials = selected
	rejection = "" if not selected.is_empty() else "concurrent_direct_material_requires_authored_composition" if owner_conflict else "actual_item_material_missing"

func clear() -> void:
	_hide("retired")
	retired = true
	actor_layers = {}

func capture_observation() -> Dictionary:
	return {"item_uuid": binding.get("item_uuid", ""), "admitted": not bound_materials.is_empty(), "element": element, "variant_id": variant_id, "appearance_mode": appearance_mode,
		"material_count": bound_materials.size(), "optical_points": surface.get("points", []).size(),
		"rejection": rejection, "replaces_weapon": false, "fills_missing_source_pixels": false,
		"extra_meshes": 0, "lights": 0, "particles": 0}

func _exit_tree() -> void:
	_hide("detached")

const VfxPackageIO_62383d0754 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
