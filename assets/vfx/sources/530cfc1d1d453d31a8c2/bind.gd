extends RefCounted
## Explicit prepared-uniform binding. Configure once on a private receiver;
## sampling changes only the current pose and owner-controlled source clock.
const PARAMETERS := [
	"weapon_auxiliary_family", "weapon_auxiliary_variant", "weapon_auxiliary_strength",
	"weapon_auxiliary_texture_a", "weapon_auxiliary_texture_b",
	"weapon_auxiliary_dark", "weapon_auxiliary_body", "weapon_auxiliary_edge",
]

static func configure(material: ShaderMaterial, preset: ShaderMaterial) -> void:
	assert(material != null and preset != null, "Explicit private receiver and prepared preset required")
	for parameter in PARAMETERS:
		material.set_shader_parameter(parameter, preset.get_shader_parameter(parameter))
	material.set_shader_parameter("weapon_auxiliary_enabled", false)
	material.set_shader_parameter("weapon_auxiliary_source_mask_only", false)
	material.set_shader_parameter("weapon_auxiliary_axis_valid", false)

static func sample(material: ShaderMaterial, seconds: float, pose: Dictionary) -> bool:
	var valid: bool = pose.get("axis_authored", false) \
		and pose.get("visible_frame", false) \
		and pose.get("hilt_uv") is Vector2 and pose.get("tip_uv") is Vector2 \
		and float(pose.get("blade_half_width_uv", 0.0)) > 0.0
	if valid:
		valid = pose.hilt_uv.distance_squared_to(pose.tip_uv) > 0.000001
	material.set_shader_parameter("weapon_auxiliary_enabled", valid)
	material.set_shader_parameter("weapon_auxiliary_axis_valid", valid)
	if not valid:
		return false
	material.set_shader_parameter("weapon_auxiliary_seconds", maxf(seconds, 0.0))
	material.set_shader_parameter("weapon_auxiliary_hilt_tip", Vector4(
		pose.hilt_uv.x, pose.hilt_uv.y, pose.tip_uv.x, pose.tip_uv.y))
	material.set_shader_parameter("weapon_auxiliary_half_width_uv", pose.blade_half_width_uv)
	material.set_shader_parameter("weapon_auxiliary_grip_end", float(pose.get("grip_end", 0.20)))
	return true

static func clear(material: ShaderMaterial) -> void:
	material.set_shader_parameter("weapon_auxiliary_enabled", false)
	material.set_shader_parameter("weapon_auxiliary_source_mask_only", false)
	material.set_shader_parameter("weapon_auxiliary_axis_valid", false)
