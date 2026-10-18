extends Node3D
## A source-native flowing material on the actual equipped item's measured
## surface. No substitute sword/staff, body deformation, inferred attack or light.
const MeasuredSurface = preload("res://assets/vfx/sources/2e511bee2be14a679d5d/measured_surface.gd")
const ContactMaterial = preload("res://assets/vfx/sources/77df0f04e1ac57bc4f5e/contact_material.gd")

var settings: Dictionary = {}
var surface: Dictionary = {}
var endpoints: Array = []
var enchantment: Dictionary = {}
var measurement: Dictionary = {}
var weapon_mesh: MeshInstance3D
var material: ShaderMaterial
var pose_key := ""
var local_clock := 0.0
var envelope := 0.0


static func make_component(input: Dictionary) -> Node3D:
	var result := VfxPackageIO_7ba5fd40e0.resource("res://assets/vfx/sources/7ba5fd40e010d019813f/equipped_enchantment.gd").new() as Node3D
	result.configure(input)
	return result


func configure(input: Dictionary) -> void:
	settings = input.duplicate(true)
	enchantment = input.enchantment.duplicate(true)
	# The donor's masks/flow/fresnel survive. The measured item silhouette
	# supplies coverage; a mask drawn for the donor's original blade does not.
	material = ContactMaterial.make(input.material, "\nALPHA *= owned_envelope;\n")
	weapon_mesh = MeshInstance3D.new()
	weapon_mesh.name = "ActualEquippedItemEnchantment"
	weapon_mesh.top_level = true
	weapon_mesh.mesh = ArrayMesh.new()
	weapon_mesh.material_override = material
	weapon_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weapon_mesh.visible = false
	add_child(weapon_mesh)


func set_entity_geometry(value: Dictionary) -> void:
	surface = value if str(value.get("actor", "")) == str(settings.actor) else {}
	if surface.is_empty():
		weapon_mesh.visible = false


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func set_enchantment_input(value: Dictionary) -> void:
	# Runtime supplies ownership, equipped-item and suppression facts. This
	# component does not invent condition UUIDs or decide spell eligibility.
	enchantment = value.duplicate(true)
	weapon_mesh.visible = false


func admitted() -> bool:
	return bool(enchantment.get("present", false)) \
		and bool(enchantment.get("observed", false)) \
		and bool(enchantment.get("equipped", false)) \
		and not bool(enchantment.get("suppressed", true)) \
		and str(enchantment.get("actor", "")) == str(settings.actor)


func sample(seconds: float) -> void:
	local_clock = seconds
	var duration: float = settings.duration_seconds
	envelope = smoothstep(0.0, float(settings.fade_in_seconds), seconds) \
		* (1.0 - smoothstep(duration - float(settings.fade_out_seconds), duration, seconds))
	material.set_shader_parameter("owned_clock", seconds)
	material.set_shader_parameter("owned_envelope", envelope)
	if not admitted() or surface.get("points", []).is_empty() or endpoints.is_empty():
		weapon_mesh.visible = false
		return
	var next_key: String = str(surface.get("pose_key", ""))
	if pose_key != next_key or measurement.is_empty():
		measurement = MeasuredSurface.build(surface, str(settings.slot), endpoints[0].point, float(settings.clearance_cells))
		weapon_mesh.mesh = measurement.mesh
		pose_key = next_key
	# The measured mesh is relative to the actor origin, with world-space axes.
	# Attachment scale/yaw must not transform this geometry a second time.
	weapon_mesh.global_transform = Transform3D(Basis.IDENTITY, surface.origin)
	weapon_mesh.visible = envelope > 0.0 and int(measurement.get("cells", 0)) > 1


func capture_observation() -> Dictionary:
	return {"equipped_enchantment": {"actor": settings.actor, "clock": local_clock,
		"admitted": admitted(), "envelope": envelope, "pose_key": pose_key,
		"measured_cells": measurement.get("cells", 0), "visible": weapon_mesh.visible,
		"donor_scene_attached": false, "lights": 0, "rule_solver": false}}

const VfxPackageIO_7ba5fd40e0 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
