extends Node3D
## Finite holy descent and local burning tongues. LeLu's native torch graph
## supplies actual evolving flame, rather than stretching laser noise into it.
## Meshes rebuild on measured pose changes; native motion stays on the GPU.
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Fire = preload("res://assets/vfx/sources/cb6c8716b8516ba846d5/native_fire.gd")
const Ribbon = preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")
const Frame = preload("res://assets/vfx/sources/02d90ce9caaa3a5e1100/receiving_frame.gd")
const GeometryKey = preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd")
const Palette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
var settings: Dictionary = {}
var receiving: Dictionary = {}
var fitted_key: Array = []
var fitted_frame: Dictionary = {}
var anchor: Node3D
var beams: Array[MeshInstance3D] = []
var tongues: Array[MeshInstance3D] = []
var beam_material: ShaderMaterial
var flame_material: ShaderMaterial
var seconds := -1.0
var geometry_builds := 0

static func make_component(input: Dictionary) -> Node3D:
	var result: Node3D = VfxPackageIO_1e4fc79417.resource("res://assets/vfx/sources/1e4fc794172dba0795de/sacred_contact.gd").new()
	result.settings = input.duplicate(true)
	result.beam_material = _material(false)
	result.flame_material = _material(true)
	result.anchor = Node3D.new()
	result.anchor.name = "MeasuredSacredContact"
	result.anchor.top_level = true
	result.add_child(result.anchor)
	for index in 1:
		var draw := MeshInstance3D.new()
		draw.name = "DescendingFlame"+str(index)
		draw.material_override = result.beam_material
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.hide()
		result.anchor.add_child(draw)
		result.beams.append(draw)
	for index in 3:
		var draw := MeshInstance3D.new()
		draw.name = "ReceivingTongue"+str(index)
		draw.material_override = result.flame_material
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.hide()
		result.anchor.add_child(draw)
		result.tongues.append(draw)
		draw.set_instance_shader_parameter("sacred_phase",float(index)*.173)
	return result

static func _material(contact: bool) -> ShaderMaterial:
	var result: ShaderMaterial = Fire.flame(.50 if contact else .85, false, true)
	var code := result.shader.code
	if contact:
		# At recipient scale the source's low-density threshold fills almost
		# every carrier fragment. Retain its evolving fire field, but expose
		# real gaps and graded coverage instead of a pale opaque leaf.
		code = code.replace("smoothstep(0.04,0.28,n_out57p0)", "smoothstep(0.30,0.62,n_out57p0)")
	# An open path has a linear base-to-tip UV, unlike the donor cone's bulb.
	# Flame tongues reverse that axis; the descending stroke uses the source's
	# active middle so an empty cone tip cannot leave a gap above the victim.
	var native_uv := "vec2(UV.x,1.0-UV.y)" if contact else "vec2(UV.x,mix(.22,.78,UV.y))"
	code = code.replace("void fragment() {","void fragment() {\nvec2 sacred_fire_uv="+native_uv+";\n")
	code = code.replace("UV * Scale_XY2","sacred_fire_uv * Scale_XY2").replace("texture(Texture_add, UV)","texture(Texture_add, sacred_fire_uv)").replace("texture(Texture_substract, UV +", "texture(Texture_substract, sacred_fire_uv +").replace("texture(tex_frg_58, UV)","texture(tex_frg_58, sacred_fire_uv)")
	code = code.replace("uniform float fire_owner_seconds=0.0;", "uniform float fire_owner_seconds=0.0;\ninstance uniform float sacred_phase=0.0;")
	code = code.replace("vec2(fire_owner_seconds)","vec2(fire_owner_seconds+sacred_phase)")
	code = code.replace("fire_owner_seconds * speed","(fire_owner_seconds+sacred_phase) * speed")
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float sacred_seconds=0.0;\nuniform float sacred_envelope=0.0;\nuniform bool sacred_contact=false;\n")
	code = Materials.finish_fragment(code, """
	float front = mix(1.06,-0.12,smoothstep(0.0,0.24,sacred_seconds));
	float descent = sacred_contact ? 1.0 : smoothstep(front,front+0.10,UV.y);
	float receiving_coverage = sacred_contact ? 0.55*smoothstep(0.0,0.16,UV.y) : 1.0;
	ALPHA *= descent*sacred_envelope*receiving_coverage;
	""")
	var shader := Shader.new()
	shader.code = code
	Materials.replace_shader(result, shader)
	# Keep native fire mask/noise/subtraction/scroll/gradient station positions.
	# Its original rose ramp becomes a private sacred gold/ivory ramp.
	var source_ramp: GradientTexture1D = result.get_shader_parameter("Gradient_Color_1D2")
	var ramp: GradientTexture1D = source_ramp.duplicate(true)
	ramp.gradient.colors = PackedColorArray([Color(0,0,0,0),Color(0,0,0,1),Color(.13,.045,.003,1),Color(.48,.24,.025,1),Color(.94,.66,.15,1),Color(1,.94,.66,1)])
	result.set_shader_parameter("Gradient_Color_1D2",ramp)
	result.set_shader_parameter("wobble_strength",.20)
	if contact:
		result.set_shader_parameter("enable_vertex_movement",false)
	result.set_shader_parameter("sacred_contact",contact)
	Palette.apply(result,["#503006","#a8650b","#e2ab30","#f3d577","#fff0bc"],{"quantize":false,"energy_exposure":1.3})
	return result

func set_entity_geometry(value: Dictionary) -> void:
	receiving = value
	if value.get("points",[]).is_empty():
		fitted_frame.clear()
		anchor.hide()
		return
	var key: Array = GeometryKey.from_surface(value)
	if fitted_frame.is_empty() or key.is_empty() or key != fitted_key:
		fitted_frame = Frame.measure(value)
		if fitted_frame.is_empty():
			anchor.hide()
			return
		fitted_key = key
		_fit_meshes()
	# Geometry is measured in world space. Do not translate/scale it twice
	# when the attached occurrence receives its own placement transform.
	anchor.global_transform = Transform3D(Basis.IDENTITY,value.origin)
	anchor.visible = seconds >= 0.0 and seconds < 1.3

func _fit_meshes() -> void:
	geometry_builds += 1
	var height: float = fitted_frame.height
	var centre: Vector3 = fitted_frame.centre-receiving.origin
	var width: float = minf(fitted_frame.half_width,height*.30)
	for index in beams.size():
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		for station in 33:
			var u := float(station)/32.
			points.append(centre+Vector3.UP*height*(-.18+u*2.7))
			widths.append(height*(.055+.065*sin(PI*u)))
		beams[index].mesh = Ribbon.build(points,widths)
	for index in tongues.size():
		var across := (float(index)-1.)*width*.65
		var support: Dictionary = Frame.support(fitted_frame,across,fitted_frame.bottom+height*(.25+.08*float(index%3)))
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		for station in 25:
			var u := float(station)/24.
			var offset: Vector3 = fitted_frame.side*height*.08*sin(u*PI+float(index))*u
			points.append(support.position-receiving.origin+support.normal*.04+Vector3.UP*height*(.60+.09*float(index%2))*u+offset)
			widths.append(height*.16*smoothstep(0.,.12,u)*pow(1.-u,1.4))
		tongues[index].mesh = _receiving_flame_mesh(points,widths,fitted_frame.normal)

func _receiving_flame_mesh(points: Array[Vector3],widths: Array[float],outward: Vector3) -> ArrayMesh:
	# Crossed three-fin transport ribbons are useful for the falling stroke.
	# On an already fitted body they triple the same fire coverage, turning a
	# translucent field into opaque folded foil. Use one gently bowed surface
	# per receiving flame with its actual receiving normal instead.
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coordinates := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in points.size():
		var tangent: Vector3 = (points[mini(index+1,points.size()-1)]-points[maxi(index-1,0)]).normalized()
		var side: Vector3 = tangent.cross(outward).normalized()
		var normal: Vector3 = side.cross(tangent).normalized()
		for edge in [-1.0,0.0,1.0]:
			vertices.append(points[index]+side*widths[index]*edge+normal*widths[index]*.20*(1.0-edge*edge))
			normals.append(normal)
			coordinates.append(Vector2((edge+1.0)*.5,float(index)/float(points.size()-1)))
		if index > 0:
			for column in 2:
				var first: int = (index-1)*3+column
				indices.append_array(PackedInt32Array([first,first+1,first+3,first+1,first+4,first+3]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = coordinates
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func sample(age: float) -> void:
	seconds = age
	var beam_alpha := smoothstep(0.0,.055,age)*(1.0-smoothstep(.25,.48,age))
	var flame_alpha := smoothstep(.22,.32,age)*(1.0-smoothstep(.65,1.25,age))
	beam_material.set_shader_parameter("sacred_seconds",maxf(age,0.0))
	beam_material.set_shader_parameter("sacred_envelope",beam_alpha)
	flame_material.set_shader_parameter("sacred_seconds",maxf(age,0.0))
	flame_material.set_shader_parameter("sacred_envelope",flame_alpha)
	Fire.clock(beam_material,age,beam_alpha)
	Fire.clock(flame_material,age,flame_alpha)
	for beam in beams: beam.visible = beam_alpha > .0001
	for tongue in tongues: tongue.visible = flame_alpha > .0001
	anchor.visible = not fitted_frame.is_empty() and age >= 0.0 and age < 1.3

func capture_observation() -> Dictionary:
	return {"sacred_contact":{"actor":receiving.get("actor",""),"source_clock":seconds,"receiving_height":fitted_frame.get("height",0.0),"geometry_builds":geometry_builds,"open_meshes":beams.size()+tongues.size(),"capped_cylinders":0,"optical_lights":0}}

const VfxPackageIO_1e4fc79417 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
