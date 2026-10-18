extends Node3D
## Finite initial-area reveal accent. Cells are supplied preview results, not a
## persistent damaging floor or an entry trigger. No optical source is invented.
const Ribbon = preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")
var specification: Dictionary = {}
var draws: Array[MeshInstance3D] = []
var material: ShaderMaterial

static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_2124c27274.resource("res://assets/vfx/sources/2124c27274ad67bd1b12/faerie_seeds.gd").new()
	effect.specification = input.duplicate(true)
	effect.prepare()
	return effect

func prepare() -> void:
	material = ShaderMaterial.new()
	material.shader = VfxPackageIO_2124c27274.resource("res://assets/vfx/sources/8c3a2317a76384635dbc/faerie_flow.gdshader")
	material.set_shader_parameter("native_wind_mask", VfxPackageIO_2124c27274.resource(specification.wind_mask))
	material.set_shader_parameter("native_flow_mask", VfxPackageIO_2124c27274.resource(specification.flow_mask))
	material.set_shader_parameter("deep_colour", Color(specification.colours[0]))
	material.set_shader_parameter("flow_colour", Color(specification.colours[1]))
	material.set_shader_parameter("crest_colour", Color(specification.colours[2]))
	for index in specification.cells.size():
		var draw := MeshInstance3D.new()
		draw.name = "InitialFeyGleam" + str(index)
		draw.material_override = material.duplicate()
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(draw)
		draws.append(draw)

func sample(seconds: float) -> void:
	if material == null:
		prepare()
	for index in draws.size():
		var cell: Array = specification.cells[index]
		var seed := float(index) * 2.39996
		var age := seconds - fposmod(sin(seed * 7.15) * 351.37, 1.0) * .20
		var envelope := smoothstep(0.0, .16, age) * (1.0 - smoothstep(.42, .78, age))
		var point := Vector3(cell[0] + cos(seed) * .27, .08 + maxf(0.0, age) * .35, cell[1] + sin(seed) * .27)
		var path: Array[Vector3] = []
		var widths: Array[float] = []
		for station in 9:
			var u := float(station) / 8.0
			path.append(point + Vector3(cos(seed) * sin(u * PI) * .035, u * .13, sin(seed) * sin(u * PI) * .035))
			widths.append(.014 * pow(maxf(0.0, sin(u * PI)), .7))
		draws[index].mesh = Ribbon.build(path, widths)
		draws[index].visible = envelope > .001
		draws[index].material_override.set_shader_parameter("presence_alpha", envelope)
		draws[index].material_override.set_shader_parameter("local_clock_seconds", seconds + seed)

func capture_observation() -> Dictionary:
	return {"supplied_area_cells": specification.cells.size(), "persistent_area": false,
		"entry_trigger": false, "optical_lights": 0}

const VfxPackageIO_2124c27274 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
