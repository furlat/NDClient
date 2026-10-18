extends Node3D
## Original approved holy-contact shader and six rising plumes, now registered
## on the current recipient's measured outfit surfaces instead of a fixed quad.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const ShaderSource := "res://assets/vfx/sources/388327134640b78113bd/7fbb09109872ebd1046994ac5eac8a2775bbeafbabff54c98041d8b9bcbf9ed7.gdshader"
var settings: Dictionary = {}
var surface: Dictionary = {}
var plumes: Array[MeshInstance3D] = []

static func make_component(input: Dictionary) -> Node3D:
	var instance := VfxPackageIO_41a3bc76d9.resource("res://assets/vfx/sources/41a3bc76d9238c352dd3/holy_contact.gd").new() as Node3D
	instance.settings=input.duplicate(true)
	var noise := NoiseTexture2D.new()
	noise.width=128;noise.height=128;noise.seamless=true;noise.normalize=true
	var generator := FastNoiseLite.new()
	generator.seed=916;generator.frequency=.045;generator.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.noise=generator
	var shader := Shader.new()
	shader.code=VfxPackageIO_41a3bc76d9.text(ShaderSource)
	for index in 6:
		var draw := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size=Vector2(.62+(index%3)*.065,.95+(index%2)*.3)
		draw.mesh=mesh
		draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader=shader
		material.set_shader_parameter("noise_tex",noise)
		var necrotic: bool=input.get("kind","radiant")=="necrotic"
		material.set_shader_parameter("core_color",Color(.84,1.,.9) if necrotic else Color(1.,.94,.73))
		material.set_shader_parameter("edge_color",Color(.06,.7,.55) if necrotic else Color(.93,.57,.15))
		material.set_shader_parameter("intensity",1.1)
		material.set_shader_parameter("top_fade",.98)
		draw.material_override=material
		instance.add_child(draw)
		instance.plumes.append(draw)
	return instance

func set_entity_geometry(value: Dictionary) -> void:
	surface=value

func capture_observation() -> Dictionary:
	return {"geometry_fit":{"points":surface.get("points",[]).size(),"mode":"holy_contact",
		"visible":plumes.any(func(draw: MeshInstance3D) -> bool: return draw.visible),"plumes":plumes.size()}}

func sample(seconds: float) -> void:
	var points: Array=surface.get("points",[])
	if points.is_empty():
		for draw in plumes:draw.hide()
		return
	var origin: Vector3=surface.origin
	var height := .1
	for point in points:height=maxf(height,point.position.y-origin.y)
	var inverse := global_transform.affine_inverse()
	for index in plumes.size():
		var age := seconds-float(index%3)*.065
		var envelope := smoothstep(0.,.12,age)*(1.-smoothstep(.46,1.2,age))
		var wanted: Vector3=origin+Vector3(cos(index*2.4)*.24,height*(.32+.065*float(index)),sin(index*2.4)*.24)
		var nearest: Dictionary=points[0]
		for point in points:
			if point.position.distance_squared_to(wanted)<nearest.position.distance_squared_to(wanted):nearest=point
		var draw: MeshInstance3D=plumes[index]
		draw.visible=envelope>.001
		draw.position=inverse*(nearest.position+nearest.normal*.08+Vector3.UP*maxf(0.,age)*.23)
		draw.scale=Vector3.ONE*clampf(height/1.2,.65,1.8)
		draw.material_override.set_shader_parameter("alpha_mult",envelope*.8)
		draw.material_override.set_shader_parameter("spell_clock",seconds*2.+index*.51)

const VfxPackageIO_41a3bc76d9 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
