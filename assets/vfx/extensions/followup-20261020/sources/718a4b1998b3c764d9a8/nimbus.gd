extends "res://assets/vfx/extensions/followup-20261020/sources/d94cb458d7e38082f91f/divine_effect.gd"
## Actual supplied Holy Nimbus light plus open shoulder rays. Native light is
## confined to this mechanically luminous feature, never to ordinary heal art.
var bright_light: OmniLight3D
var dim_light: OmniLight3D

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = create("res://assets/vfx/extensions/followup-20261020/sources/718a4b1998b3c764d9a8/nimbus.gd", input)
	component.bright_light = component._make_light("ActualBrightLight", float(input.light.bright_radius_cells), .28)
	component.dim_light = component._make_light("ActualDimLight", float(input.light.dim_radius_cells), .10)
	return component

func _make_light(label: String, radius: float, strength: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = label
	light.omni_range = radius
	light.light_color = Color.html(str(settings.light.colour))
	light.light_energy = strength
	light.shadow_enabled = false
	light.hide()
	add_child(light)
	return light

func sample(seconds: float) -> void:
	super.sample(seconds)
	if bright_light == null or dim_light == null:
		return
	var admitted: bool = owner_admitted() and bool(settings.light.grant_active) and envelope > .0001
	for light in [bright_light, dim_light]:
		light.visible = admitted
		if not frame.is_empty():
			light.global_position = frame.centre

func _paths() -> Array:
	var result: Array = []
	for ray in 6:
		var parity: float = -1.0 if ray % 2 == 0 else 1.0
		var tier: float = float(ray / 2)
		var points: Array[Vector3] = []
		var normals: Array[Vector3] = []
		for index in 25:
			var u: float = float(index) / 24.0
			var across: float = parity * frame.half_width * (.62 + .18 * sin(u * PI) + .12 * tier)
			var elevation: float = frame.bottom + frame.height * (.33 + .30 * u + .075 * tier)
			var support: Dictionary = Frame.support(frame, across, elevation)
			points.append(support.position + support.normal * (.045 + .07 * sin(u * PI))
				+ frame.side * parity * .065 * sin(u * PI))
			normals.append(support.normal)
		result.append(ribbon(points, normals, .085 - .012 * tier))
	return result

func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.native_light = {"mechanical_feature": "planned Holy Nimbus", "bright_radius_cells": settings.light.bright_radius_cells,
		"dim_radius_cells": settings.light.dim_radius_cells, "visible": bright_light != null and bright_light.visible,
		"falloff": "native continuous optical approximation; logical bright/dim membership stays supplied"}
	return result
