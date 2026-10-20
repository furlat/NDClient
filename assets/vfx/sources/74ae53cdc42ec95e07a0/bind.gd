extends RefCounted
## Pure elemental candidates, separate from ordinary enhanced steel finishes.
## Configuration is explicit; frame/normal/alpha still belong to actual renderer.
const STRENGTHS := {"lesser": .50, "medium": .74, "greater": .95}
const VARIANTS := {
	"ice.pure_crystal": {"kind": 1, "variant": 0},
	"ice.pure_rime": {"kind": 1, "variant": 1},
	"electric.pure_conduit": {"kind": 2, "variant": 0},
	"electric.pure_storm": {"kind": 2, "variant": 1},
}
const SOURCES := {
	"weapon_pure_cells": "res://assets/vfx/sources/126e19553516547aa864/cell_manhattan_01.tres",
	"weapon_pure_arc_sheet": "res://assets/vfx/sources/7eddd0f4a71d6ddc658c/texture.res",
}
const PRESET_UNIFORMS := ["weapon_pure_kind", "weapon_pure_variant", "weapon_pure_strength",
	"weapon_pure_dark", "weapon_pure_body", "weapon_pure_core", "weapon_pure_accent",
	"weapon_pure_cells", "weapon_pure_arc_sheet"]

static func configure_variant(material: ShaderMaterial, variant_id: String, strength: String) -> void:
	assert(VARIANTS.has(variant_id), "Explicit pure mechanism required")
	assert(STRENGTHS.has(strength), "Explicit artistic strength required")
	var variant: Dictionary = VARIANTS[variant_id]
	material.set_shader_parameter("weapon_pure_kind", variant.kind)
	material.set_shader_parameter("weapon_pure_variant", variant.variant)
	material.set_shader_parameter("weapon_pure_strength", STRENGTHS[strength])
	var colours: Array[Vector3] = [Vector3(.025, .13, .24), Vector3(.16, .51, .72), Vector3(.58, .88, .94), Vector3(.32, .68, .83)]
	if variant_id == "ice.pure_rime":
		colours = [Vector3(.055, .18, .24), Vector3(.40, .69, .73), Vector3(.76, .89, .87), Vector3(.25, .52, .60)]
	elif variant_id == "electric.pure_storm":
		colours = [Vector3(.018, .035, .20), Vector3(.065, .16, .60), Vector3(.16, .66, .96), Vector3(.98, .63, .075)]
	elif variant.kind == 2:
		colours = [Vector3(.015, .07, .28), Vector3(.025, .32, .93), Vector3(.21, .76, .98), Vector3(.98, .61, .065)]
	for index in 4:
		material.set_shader_parameter(["weapon_pure_dark", "weapon_pure_body", "weapon_pure_core", "weapon_pure_accent"][index], colours[index])
	for name in SOURCES:
		material.set_shader_parameter(name, VfxPackageIO_74ae53cdc4.resource(SOURCES[name]))
	clear(material)

static func configure_preset(material: ShaderMaterial, preset: ShaderMaterial) -> void:
	var explicit: Dictionary = preset.get_meta("factory_weapon_pure_uniforms", {})
	for name in PRESET_UNIFORMS:
		var value: Variant = preset.get_shader_parameter(name)
		if value == null:
			value = explicit.get(name)
		assert(value != null, "Missing explicit pure material preset operand: " + name)
		material.set_shader_parameter(name, value)
	clear(material)

static func sample(material: ShaderMaterial, seconds: float, pose: Dictionary) -> bool:
	var valid: bool = is_finite(seconds) and pose.get("axis_authored", false) \
		and pose.get("visible_frame", false) and pose.get("hilt_uv") is Vector2 \
		and pose.get("tip_uv") is Vector2 and float(pose.get("blade_half_width_uv", 0.0)) > 0.0
	if valid:
		valid = pose.hilt_uv.is_finite() and pose.tip_uv.is_finite() \
			and pose.hilt_uv.distance_squared_to(pose.tip_uv) > .000001
	material.set_shader_parameter("weapon_pure_enabled", valid)
	material.set_shader_parameter("weapon_pure_axis_valid", valid)
	if not valid:
		return false
	material.set_shader_parameter("weapon_pure_seconds", maxf(0., seconds))
	material.set_shader_parameter("weapon_pure_hilt_tip", Vector4(pose.hilt_uv.x, pose.hilt_uv.y, pose.tip_uv.x, pose.tip_uv.y))
	material.set_shader_parameter("weapon_pure_half_width_uv", pose.blade_half_width_uv)
	material.set_shader_parameter("weapon_pure_grip_end", float(pose.get("grip_end", .04)))
	return true

static func clear(material: ShaderMaterial) -> void:
	material.set_shader_parameter("weapon_pure_enabled", false)
	material.set_shader_parameter("weapon_pure_axis_valid", false)

const VfxPackageIO_74ae53cdc4 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
