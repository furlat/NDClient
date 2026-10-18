extends Node3D
## Read-only rain-Wet lease visual; does not own its three-round expiry or reveal.
const Graph=preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const Materials=preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Ribbon=preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")
var specification:Dictionary={}
var geometry:Dictionary={}
var pieces:Array[MeshInstance3D]=[]
var material:ShaderMaterial
var wet_present:=true
var last_age:=0.0

static func make_component(input:Dictionary)->Node3D:
	var effect:Node3D=VfxPackageIO_cd12c6c1f4.resource("res://assets/vfx/sources/cd12c6c1f4bcdd41b2a7/rain_wet.gd").new()
	effect.specification=input.duplicate(true)
	return effect

func set_entity_geometry(value:Dictionary)->void:
	geometry=value

func set_wet_presence(value:bool)->void:
	wet_present=value

func prepare()->void:
	var donor:Node3D=VfxPackageIO_cd12c6c1f4.resource(specification.drop_scene).instantiate()
	material=Graph.clone_value(donor.get_node("Particles").material_override,{})
	var code:=Materials.expand_shader(material.shader.code,material.shader.resource_path.get_base_dir())
	code=code.replace("blend_add","blend_mix")
	code=code.replace("shader_type spatial;","shader_type spatial; uniform float wet_presence=1.0;")
	code=Materials.finish_fragment(code,"\nALBEDO*=0.65; ALPHA*=wet_presence;\n")
	var shader:=Shader.new();shader.code=code
	Materials.replace_shader(material,shader)
	for uniform in ["primary_color","secondary_color","tertiary_color"]:
		material.set_shader_parameter(uniform,Color("739da8"))
	for index in 5:
		var piece:=MeshInstance3D.new()
		piece.name="ReceivedWaterRunoff"+str(index)
		piece.material_override=material
		piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece);pieces.append(piece)
	donor.free()

func sample(seconds:float)->void:
	if pieces.is_empty():prepare()
	last_age=seconds
	var points:Array=geometry.get("points",[])
	var present:bool=wet_present and not points.is_empty()
	for piece in pieces:piece.visible=present
	if not present:return
	var inverse:=global_transform.affine_inverse()
	var origin:Vector3=inverse*geometry.origin
	var height:=0.0
	for point in points:height=maxf(height,(inverse*point.position).y-origin.y)
	for index in pieces.size():
		var phase:float=fposmod(seconds*.48+float(index)*.211,1.0)
		var desired:float=origin.y+height*(.88-phase*.5)
		var choice:Dictionary=points[0]
		var best:=INF
		# Stable per-strand source support choices; current geometry remains live.
		for p in range(index,points.size(),5):
			var local:Vector3=inverse*points[p].position
			var score:float=absf(local.y-desired)+absf(local.x-origin.x-float(index-2)*.045)*.4
			if score<best:best=score;choice=points[p]
		var contact:Vector3=inverse*choice.position
		var normal:Vector3=(global_basis.inverse()*choice.normal).normalized()
		var vertices:Array[Vector3]=[]
		var widths:Array[float]=[]
		for sample_index in 9:
			var u:float=float(sample_index)/8.0
			vertices.append(contact+normal*.012+Vector3.DOWN*u*.10+Vector3.RIGHT*sin(u*PI)*.006)
			widths.append(.008*pow(maxf(0.0,sin(u*PI)),.6)*(.7+.3*sin(phase*PI)))
		if specification.get("gpu_paths",false):
			preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd").assign(pieces[index],vertices,widths,Color.WHITE,Vector2(0,1),false)
		else:
			pieces[index].mesh=Ribbon.build(vertices,widths)
	material.set_shader_parameter("wet_presence",smoothstep(0.0,.25,seconds)*.65)

func capture_observation()->Dictionary:
	return {"wet_presence_supplied":wet_present,"owns_rounds":false,"owns_reveal":false,
		"body_points":geometry.get("points",[]).size(),"optical_lights":0,"seconds":last_age}

const VfxPackageIO_cd12c6c1f4 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
