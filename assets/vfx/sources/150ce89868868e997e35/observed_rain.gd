extends Node3D
## Rain and water-bearing surface after-values supplied by the caller.
## The deposit, wet lease and surface removal have independent owners.
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Graph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
var specification: Dictionary = {}
var records: Array = []
var groups: Array = []
var prepared := false
var last_seconds := 0.0

static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_150ce89868.resource("res://assets/vfx/sources/150ce89868868e997e35/observed_rain.gd").new()
	effect.specification = input.duplicate(true)
	effect.records = input.get("surface_groups", []).duplicate(true)
	return effect

func set_surface_records(value: Array) -> void:
	assert(not prepared, "Replace surface records before construction; occurrences own their immutable coverage")
	records = value.duplicate(true)

func prepare() -> void:
	assert(specification.form in ["create", "destroy"], "An observed water form is required")
	assert(not records.is_empty(), "Observed surface groups are required")
	var source: Node3D = VfxPackageIO_150ce89868.resource(specification.drop_scene).instantiate()
	var original: GPUParticles3D = source.get_node("Particles")
	for record in records:
		assert(record.cells.size() > 0 and record.cells.size() <= 32, "Partition supplied cells explicitly, at most 32 per group")
		assert(record.points.size() == 160, "Retain explicit 160-point native density coverage")
		var data := PackedVector4Array()
		for point in record.points:
			data.append(Vector4(point[0], 2.0, point[1], 1.0))
		var shader := Shader.new()
		var code := VfxPackageIO_150ce89868.text(specification.surface_shader)
		code = code.replace("void fragment(){", "uniform vec2 coverage_origin; uniform vec2 coverage_size; uniform float coverage_opacity=1.0;\nvoid fragment(){")
		code = code.replace("vec2 world=UV*4.0-.5;", "vec2 world=coverage_origin+UV*coverage_size+vec2(1.5);")
		code = code.replace("ALPHA=coverage_alpha*end*min(1.0,body_alpha+glint*.48);", "ALPHA=coverage_alpha*end*min(1.0,body_alpha+glint*.48)*coverage_opacity;")
		shader.code = code
		var surface := ShaderMaterial.new()
		surface.shader = shader
		surface.set_shader_parameter("marble", Materials.raw_texture(specification.marble))
		for i in 3:
			surface.set_shader_parameter(["dark", "mid", "light"][i], Color(specification.colours[i]))
		surface.set_shader_parameter("body_alpha", .64)
		surface.set_shader_parameter("material_kind", 0)
		var origin := Vector2(record.bounds[0],record.bounds[1])
		var size := Vector2(record.bounds[2],record.bounds[3])
		surface.set_shader_parameter("coverage_origin",origin)
		surface.set_shader_parameter("coverage_size",size)
		var plane := MeshInstance3D.new()
		plane.name = "ObservedWaterSurface"+str(groups.size())
		var mesh := PlaneMesh.new()
		mesh.size = size
		plane.mesh = mesh
		plane.position = Vector3(origin.x+size.x*.5, .014, origin.y+size.y*.5)
		plane.material_override = surface
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(plane)
		var drops := MultiMeshInstance3D.new()
		drops.name = "NativeWaterDrops"+str(groups.size())
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		var bead := SphereMesh.new()
		bead.radius = .018
		bead.height = .13
		bead.radial_segments = 8
		bead.rings = 4
		var drop_material: ShaderMaterial = Graph.clone_value(original.material_override,{})
		var drop_code := Materials.expand_shader(drop_material.shader.code,drop_material.shader.resource_path.get_base_dir())
		drop_code = drop_code.replace("blend_add","blend_mix")
		drop_code = drop_code.replace("shader_type spatial;","shader_type spatial; uniform float rain_opacity=1.0;")
		drop_code = Materials.finish_fragment(drop_code,"\nALBEDO*=0.65; ALPHA*=rain_opacity;\n")
		var drop_shader := Shader.new()
		drop_shader.code = drop_code
		Materials.replace_shader(drop_material,drop_shader)
		for parameter in ["primary_color","secondary_color","tertiary_color"]:
			drop_material.set_shader_parameter(parameter,Color(specification.colours[1]))
		bead.material = drop_material
		multimesh.mesh = bead
		multimesh.instance_count = 160
		var instance_buffer:=PackedFloat32Array()
		instance_buffer.resize(160*16)
		var delays: Array[float]=[]
		for index in 160:
			instance_buffer[index*16+12]=.5
			instance_buffer[index*16+13]=.5
			instance_buffer[index*16+14]=.5
			instance_buffer[index*16+15]=1.
			delays.append(fposmod(sin(float(index)*12.9898+71.3)*43758.5453,1.0)*.55)
		drops.multimesh = multimesh
		drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(drops)
		groups.append({"record":record,"fluid":data,"surface":surface,"plane":plane,"drops":drops,"drop_material":drop_material,"instance_buffer":instance_buffer,"delays":delays,"initialized":false,"was_dynamic":false})
	source.free()
	prepared = true

func sample(seconds: float) -> void:
	if not prepared: prepare()
	last_seconds = seconds
	var destroying: bool = specification.form == "destroy"
	var clear_age: float = seconds-float(specification.get("clear_at_seconds", 0.0))
	for group in groups:
		var fluid: PackedVector4Array = group.fluid
		var opacity: float = 1.0-smoothstep(.18,.9,clear_age) if destroying else 1.0
		var dynamic: bool=(not destroying and seconds<1.3) or (destroying and clear_age>.18 and clear_age<1.3)
		if dynamic or bool(group.was_dynamic) or not bool(group.initialized):
			var buffer: PackedFloat32Array=group.instance_buffer
			for index in 160:
				var point: Array = group.record.points[index]
				var delay: float = group.delays[index]
				var age: float = seconds-delay
				var fall: float = clampf(age/.68,0.0,1.0)
				var height: float = 1.8*(1.0-fall*fall)
				var on_surface: bool = destroying or age>=.68
				fluid[index] = Vector4(point[0],0.0 if on_surface else 1.0,point[1],1.0)
				var visible_drop: bool = age>=0.0 and age<.68 and not destroying
				if destroying:
					visible_drop = clear_age>.18 and clear_age<.9 and index%4==0
					height = .05+(clear_age-.18)*.38
				var base: int=index*16
				var size:=1. if visible_drop else 0.
				buffer[base]=size
				buffer[base+5]=size
				buffer[base+10]=size
				buffer[base+3]=point[0]
				buffer[base+7]=height
				buffer[base+11]=point[1]
			group.fluid=fluid
			group.surface.set_shader_parameter("fluid",fluid)
			group.drops.multimesh.buffer=buffer
			group.instance_buffer=buffer
			group.initialized=true
		group.was_dynamic=dynamic
		group.surface.set_shader_parameter("clock",seconds)
		group.surface.set_shader_parameter("coverage_opacity",opacity)
		group.drop_material.set_shader_parameter("rain_opacity",opacity*.8)
		group.plane.visible = opacity>.001
		group.drops.visible = clear_age<1.3 if destroying else seconds<1.3

func capture_observation() -> Dictionary:
	return {"form":specification.form,"observed_groups":records.size(),"points_per_group":160,
		"density_shader":specification.surface_shader,"seconds":last_seconds,"optical_lights":0,
		"wet_lease_owned_here":false,"surface_expiry_owned_here":false,
		"water_persists_after_rain":specification.form=="create","backend_radius_inferred":false}

const VfxPackageIO_150ce89868 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
