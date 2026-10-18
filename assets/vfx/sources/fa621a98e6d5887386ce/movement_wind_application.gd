extends "res://assets/vfx/sources/2df94cf76d6f9f33bf21/movement_wind.gd"
## Longstrider's native foot wind: one receive pulse, then quiet flow. The
## purchased polar-panning geometry/noise remains the source of the motion.
const EnergyPalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
var wind_mesh: MeshInstance3D
var resting_scale := Vector3.ONE


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/fa621a98e6d5887386ce/movement_wind_application.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	wind_mesh = node.get_node("windsoil") as MeshInstance3D
	resting_scale = wind_mesh.scale
	for material in materials:
		EnergyPalette.apply(material, settings.palette, {"quantize": false, "energy_exposure": 1.1})


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	var age := float(tick) / float(parameters.simulation_hz)
	var pulse := 1.0 - smoothstep(0.28, 0.82, age)
	var formation := smoothstep(0.0, 0.14, age)
	var removal := 1.0 - smoothstep(3.0, 4.0, age)
	var expansion := lerpf(0.68, 1.14, smoothstep(0.0, 0.32, age))
	expansion = lerpf(expansion, 1.0, smoothstep(0.32, 0.82, age))
	wind_mesh.scale = resting_scale * Vector3(expansion, 1.0, expansion)
	for material in materials:
		material.set_shader_parameter("movement_fade", formation * removal * (0.42 + 0.68 * pulse))

