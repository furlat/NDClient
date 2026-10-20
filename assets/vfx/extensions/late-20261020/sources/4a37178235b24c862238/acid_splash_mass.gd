extends "res://assets/vfx/extensions/late-20261020/sources/2dae5063c4170b477276/acid_explosion.gd"
## Readable native liquid sheets and ballistic teardrops lead the composition;
## the six original emitter layers remain subordinate breakup and vapour.
const CROWN_MESH = "res://assets/vfx/extensions/late-20261020/sources/d82fc55ef84819dfd01f/sm_plane_coned_spiked_waved2.res"
const DROP_MESH = "res://assets/vfx/extensions/late-20261020/sources/19a90c674ccf2c896718/sm_teardrop.res"
var liquid_draws: Array[MeshInstance3D] = []
var liquid_materials: Array[ShaderMaterial] = []


static func make_component(input: Dictionary) -> Node3D:
	assert(input.kind == "acid")
	assert(not str(input.get("source_owner_uuid", "")).is_empty())
	assert(not str(input.get("original_caster_uuid", "")).is_empty())
	var node: Node3D = VfxPackageIO_4a37178235.resource("res://assets/vfx/extensions/late-20261020/sources/4a37178235b24c862238/acid_splash_mass.gd").new()
	node.specification = input.duplicate(true)
	node.set_blast_event(input.get("event", {}))
	node.prepare()
	return node


func prepare() -> void:
	super.prepare()
	var original: Node3D = DonorScene.instantiate(VfxPackageIO_4a37178235.resource(ACID_SCENE), [])
	var cells: Array = event.get("admitted_cells", specification.get("admitted_cells", []))
	for index in 16:
		var source: ShaderMaterial = original.get_node("splatter2" if index < 2 else "spheres").material_override
		var adapted: ShaderMaterial = Native.finite(source, .85)
		adapted.set_shader_parameter("Scale", Vector2.ONE)
		var code: String = adapted.shader.code.replace("depth_draw_opaque", "depth_draw_never")
		code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float liquid_dissolve=.0;")
		code = Native.Source.finish_function(code, "vertex", "\nCOLOR=vec4(1.2,1.2,1.2,liquid_dissolve);\n")
		code = code.replace("ALPHA_SCISSOR_THRESHOLD = n_out4p4;", "ALPHA=smoothstep(n_out4p4,n_out4p4+.1,n_out10p1);")
		code = Native.Source.finish_fragment(code, "\nEMISSION+=ALBEDO*.2;\n")
		var shader := Shader.new()
		shader.code = code
		Native.Source.replace_shader(adapted, shader)
		Footprint.bind(adapted, cells)
		var draw: MeshInstance3D = Native.draw(self, "NativeLiquidCrown" + str(index) if index < 2 else "BallisticNativeTeardrop" + str(index), VfxPackageIO_4a37178235.resource(CROWN_MESH if index < 2 else DROP_MESH), adapted)
		draw.top_level = true
		liquid_materials.append(adapted)
		liquid_draws.append(draw)
	original.free()


func set_blast_event(value: Dictionary) -> bool:
	var admitted: bool = super.set_blast_event(value)
	for draw in liquid_draws:
		draw.hide()
	if admitted and not event.is_empty():
		apply_footprint_cells(liquid_materials, event.admitted_cells)
	return admitted


func sample(seconds: float) -> void:
	super.sample(seconds)
	for draw in liquid_draws:
		draw.hide()
	if event.is_empty() or endpoints.is_empty():
		return
	for index in liquid_draws.size():
		var age: float = seconds - (.065 * index if index < 2 else float(index % 4) * .025)
		var alpha: float = smoothstep(0.0, .035, age) * (1.0 - smoothstep(.45, .8, age))
		var direction_angle: float = float(index) * 2.399963
		var relative: Vector3
		var axes: Basis
		if index < 2:
			var expansion: float = 1.0 - exp(-maxf(age, 0.0) * 7.0)
			var radius: float = .12 + expansion * (2.05 if index == 0 else 1.5)
			var height: float = .18 + 1.35 * sin(clampf(age / .8, 0.0, 1.0) * PI)
			relative = Vector3(.25 * index, .02 + .32 * height, -.18 * index)
			axes = Basis.from_euler(Vector3(.07 * index, direction_angle, -.06 * index)) * Basis.from_scale(Vector3(radius, height, radius * .8))
		else:
			var speed: float = 2.5 + float(index % 4) * .6
			var lift: float = 2.1 + float(index % 3) * .35
			var velocity := Vector3(cos(direction_angle) * speed, lift, sin(direction_angle) * speed)
			relative = Vector3(0, .15, 0) + velocity * maxf(age, 0.0) + Vector3(0, -4.5 * age * age, 0)
			var tangent: Vector3 = (velocity + Vector3(0, -9.0 * age, 0)).normalized()
			axes = Basis(Quaternion(Vector3.UP, tangent)) * Basis.from_scale(Vector3(.065, .16, .065))
			alpha *= smoothstep(.015, .12, relative.y)
		liquid_draws[index].global_transform = Transform3D(axes, last_origin + relative)
		Footprint.move(liquid_materials[index], last_origin)
		liquid_materials[index].set_shader_parameter("liquid_dissolve", .12 + smoothstep(.25, .8, age) * .78)
		Native.clock(liquid_materials[index], maxf(age, 0.0), alpha * .85)
		liquid_draws[index].visible = age >= 0.0 and alpha > .001


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result["liquid_crown_mesh"] = CROWN_MESH
	result["ballistic_teardrop_mesh"] = DROP_MESH
	result["native_liquid_sheets"] = 2
	result["ballistic_teardrops"] = 14
	return result

const VfxPackageIO_4a37178235 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
