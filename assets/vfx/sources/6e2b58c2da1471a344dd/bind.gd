extends RefCounted
## Small uniform adapter for the actual receiver or isolated-sheet material.
## An explicit current-frame hilt/tip axis is required; no pixel fitting occurs.
const ROOT := "factory-path:authoring/modular-weapons-20261020/element-studies/"
const STRENGTHS := {"lesser": 0.50, "medium": 0.74, "greater": 0.95}
const CORONA_RADII_PIXELS := {"lesser": 1.0, "medium": 2.0, "greater": 3.0}
const VARIANTS := {
	"ice.rime_facets": {"element": "ice", "index": 0},
	"ice.clear_glaze": {"element": "ice", "index": 1},
	"electric.axial_forks": {"element": "electric", "index": 0},
	"electric.cross_discharge": {"element": "electric", "index": 1},
}
const SOURCES := {
	"weapon_element_noise": "res://assets/vfx/sources/8bc8bf311494b7cec395/texture.res",
	"weapon_element_arc_sheet": "res://assets/vfx/sources/7eddd0f4a71d6ddc658c/texture.res",
	"weapon_element_ice_cells": "res://assets/vfx/sources/126e19553516547aa864/cell_manhattan_01.tres",
	"weapon_element_ice_detail": "res://assets/vfx/sources/9dcaa1fc11385c7a38ab/cell_manhattan_02.tres",
}

static func configure(material: ShaderMaterial, element: String, strength: String) -> void:
	assert(element in ["ice", "electric"], "Explicit supported element required")
	assert(STRENGTHS.has(strength), "Explicit artistic strength required")
	material.set_shader_parameter("weapon_element_kind", 1 if element == "ice" else 2)
	material.set_shader_parameter("weapon_element_variant", 0)
	material.set_shader_parameter("weapon_element_strength", STRENGTHS[strength])
	for parameter in SOURCES:
		material.set_shader_parameter(parameter, VfxPackageIO_6e2b58c2da.resource(SOURCES[parameter]))

static func configure_variant(material: ShaderMaterial, variant_id: String, strength: String) -> void:
	assert(VARIANTS.has(variant_id), "Explicit supported material mechanism required")
	var variant: Dictionary = VARIANTS[variant_id]
	configure(material, variant.element, strength)
	material.set_shader_parameter("weapon_element_variant", variant.index)

static func sample(material: ShaderMaterial, seconds: float, pose: Dictionary) -> bool:
	# Both endpoints belong to the same actual current source frame. Inferred
	# visible extents and optical-point averages are intentionally not accepted.
	var valid: bool = pose.get("axis_authored", false) \
		and pose.get("visible_frame", false) \
		and pose.get("hilt_uv") is Vector2 and pose.get("tip_uv") is Vector2 \
		and float(pose.get("blade_half_width_uv", 0.0)) > 0.0
	if valid:
		valid = pose.hilt_uv.distance_squared_to(pose.tip_uv) > 0.000001
	material.set_shader_parameter("weapon_element_axis_valid", valid)
	material.set_shader_parameter("weapon_element_enabled", valid)
	if not valid:
		return false
	material.set_shader_parameter("weapon_element_seconds", maxf(seconds, 0.0))
	material.set_shader_parameter("weapon_element_hilt_tip", Vector4(
		pose.hilt_uv.x, pose.hilt_uv.y, pose.tip_uv.x, pose.tip_uv.y))
	material.set_shader_parameter("weapon_element_half_width_uv", pose.blade_half_width_uv)
	material.set_shader_parameter("weapon_element_grip_end", float(pose.get("grip_end", 0.20)))
	return true

static func configure_corona(material: ShaderMaterial, strength: String) -> void:
	configure(material, "electric", strength)
	material.set_shader_parameter("weapon_corona_radius_pixels", CORONA_RADII_PIXELS[strength])
	material.set_shader_parameter("weapon_corona_enabled", true)

static func configure_corona_variant(material: ShaderMaterial, variant_id: String, strength: String) -> void:
	assert(variant_id.begins_with("electric."), "Electrical corona needs an electrical mechanism")
	configure_variant(material, variant_id, strength)
	material.set_shader_parameter("weapon_corona_radius_pixels", CORONA_RADII_PIXELS[strength])
	material.set_shader_parameter("weapon_corona_enabled", true)

static func configure_frost_rim_variant(material: ShaderMaterial, variant_id: String, strength: String) -> void:
	assert(variant_id.begins_with("ice."), "Stationary rime needs an ice mechanism")
	configure_variant(material, variant_id, strength)
	var radii: Dictionary = {"lesser": 0.75, "medium": 1.0, "greater": 1.5}
	material.set_shader_parameter("weapon_frost_radius_pixels", radii[strength])
	material.set_shader_parameter("weapon_frost_rim_enabled", true)

static func clear(material: ShaderMaterial) -> void:
	material.set_shader_parameter("weapon_element_enabled", false)
	material.set_shader_parameter("weapon_element_axis_valid", false)

const VfxPackageIO_6e2b58c2da = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
