extends Node3D
## One small optional source-mask edge per actual item draw. No CPU image work,
## inferred blade or per-frame mesh creation. Source node keeps the weapon draw.
const Binding = preload("res://assets/vfx/sources/6e2b58c2da1471a344dd/bind.gd")
var variant_id := "electric.axial_forks"
var artistic_strength := "medium"
var binding: Dictionary = {}
var actor_layers: Dictionary = {}
var entries: Dictionary = {}
var retired := false
var prepared_draw: MeshInstance3D
var prepared_material: ShaderMaterial
var material_preset: ShaderMaterial

func _ready() -> void:
	# Stable topology before source registration. The empty carrier never draws
	# a replacement weapon; binding assigns the actual source quad by reference.
	prepared_material = material_preset.duplicate(false) if material_preset != null else ShaderMaterial.new()
	var electrical := variant_id.begins_with("electric.")
	if material_preset == null:
		prepared_material.shader = VfxPackageIO_d2dce11aa9.resource("factory-path:factory/components/weapon_appearance/element_studies/" + ("electric_corona.gdshader" if electrical else "frost_rim.gdshader"))
		if electrical:
			Binding.configure_corona_variant(prepared_material, variant_id, artistic_strength)
		else:
			Binding.configure_frost_rim_variant(prepared_material, variant_id, artistic_strength)
	prepared_material.set_shader_parameter("weapon_element_half_width_uv", .025)
	prepared_material.set_shader_parameter("weapon_element_grip_end", .04)
	prepared_draw = MeshInstance3D.new()
	prepared_draw.material_override = prepared_material
	prepared_draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	prepared_draw.layers = 1 << 19
	prepared_draw.name = "ActualWeaponMaskEdge"
	prepared_draw.hide()
	add_child(prepared_draw)

func set_weapon_binding(value: Dictionary) -> void:
	binding = value

func set_actor_layers(value: Dictionary) -> void:
	actor_layers = value

func _entry(source: MeshInstance3D) -> Dictionary:
	var identity := source.get_instance_id()
	if not entries.has(identity):
		entries.clear()
		prepared_draw.mesh = source.mesh
		entries[identity] = {"draw": prepared_draw, "material": prepared_material, "key": []}
	return entries[identity]

func sample(seconds: float) -> void:
	for value in entries.values():
		value.draw.hide()
	if retired or binding.get("suppressed", true) or not binding.get("equipped", false) \
		or not binding.get("present", false) or not binding.get("observed", false) \
		or actor_layers.get("actor_uuid") != binding.get("holder_uuid"):
		return
	var seen := {}
	for layer in actor_layers.get("layers", []):
		if layer.get("item_uuid") != binding.get("item_uuid") or layer.get("slot") != "weapon" \
			or not is_instance_valid(layer.get("node")):
			continue
		var source: MeshInstance3D = layer.node
		if seen.has(source.get_instance_id()):
			continue # Source + received pass represent the SAME physical draw.
		seen[source.get_instance_id()] = true
		var axis: Dictionary = layer.get("blade_axis", {})
		if not axis.get("axis_valid", false):
			continue
		var value := _entry(source)
		var material: ShaderMaterial = value.material
		var parameters: Array = [layer.source, layer.frame, axis.hilt_tip]
		if value.key != parameters:
			var prefix := "weapon_corona_" if variant_id.begins_with("electric.") else "weapon_frost_"
			material.set_shader_parameter(prefix + "source", layer.source)
			material.set_shader_parameter(prefix + "frame", layer.frame)
			material.set_shader_parameter("weapon_element_hilt_tip", axis.hilt_tip)
			material.set_shader_parameter("weapon_element_axis_valid", true)
			material.set_shader_parameter("weapon_element_enabled", true)
			value.key = parameters
		material.set_shader_parameter("weapon_element_seconds", seconds)
		value.draw.global_transform = source.global_transform
		value.draw.visible = source.visible

func clear() -> void:
	retired = true
	binding = {}
	actor_layers = {}
	for value in entries.values():
		value.draw.hide()
		Binding.clear(value.material)

func capture_observation() -> Dictionary:
	return {"variant_id": variant_id, "private_edge_draws": entries.size(),
		"visible": entries.values().filter(func(value: Dictionary) -> bool: return value.draw.visible).size(),
		"reconstructs_hidden_blade": false, "geometry": "original source quad; bounded source-alpha neighbours",
		"depth_qualification": "source-plane edge only; optical edge reconstruction remains separate"}

const VfxPackageIO_d2dce11aa9 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
