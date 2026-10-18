extends Node3D
## Native port of the accepted class-action geometry/material family. No capture
## code, camera-half assets, actor film or per-spell stage is loaded here.
const Shaders := {
	"flow":"res://assets/vfx/sources/04422ebafdeb369c5c7a/d32a1a7e0472cd39ad89b97b5a801945add16bb64e5ac5f0b64503969d689806.gdshader",
	"arc":"res://assets/vfx/sources/649785ebb3c1bc498ccf/a8cf5127a0ae9a1dc84b4e34e0d7c8e94a41210e854f3102b4c78cb8500c3f17.gdshader",
	"roar":"res://assets/vfx/sources/3174c3adf04efba0fdb5/38e00da788125cd1ce193ef50a2ab4d5edebfede1330bda222535674e51d28c3.gdshader",
	"presence":"res://assets/vfx/sources/0a2aa8c42dce4063b3b2/c130ea5e24c38baf614eef5159cacbea1e85ebd34998b650f8c69d3c52d3913d.gdshader"}
const NativePalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
var settings: Dictionary
var kind: String
var pieces: Array[MeshInstance3D] = []
var geometry: Dictionary = {}
var endpoints: Array = []
var fit: Node3D
var flow_noise: NoiseTexture2D
var cores: Array[MeshInstance3D] = []
var motes: Array[MeshInstance3D] = []

static func make_component(input: Dictionary) -> Node3D:
	var node := VfxPackageIO_5944248dd6.resource("res://assets/vfx/sources/5944248dd6bb52ef8394/class_action.gd").new() as Node3D
	node.settings=input.duplicate(true)
	node.kind=input.kind
	node._build()
	return node

static func source_noise() -> NoiseTexture2D:
	# Exact numeric settings from the preserved flow_noise.tres.
	var texture := NoiseTexture2D.new()
	texture.width=256;texture.height=256;texture.seamless=true;texture.seamless_blend_skirt=.2;texture.generate_mipmaps=true
	var noise := FastNoiseLite.new()
	noise.noise_type=3;noise.frequency=.018
	noise.fractal_type=2;noise.fractal_octaves=4;noise.fractal_gain=.55
	texture.noise=noise
	return texture

func _piece(family: String, index: int) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code=VfxPackageIO_5944248dd6.text(Shaders[family])
	material.shader=shader
	material.set_shader_parameter("source_noise" if family!="flow" else "flow_tex",flow_noise)
	material.set_shader_parameter("seed",float(index)*.173)
	material.set_shader_parameter("side",0.)
	NativePalette.apply(material, settings.get("native_palette", []))
	piece.material_override=material
	piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.custom_aabb=AABB(Vector3(-4,-2,-4),Vector3(8,8,8))
	fit.add_child(piece)
	pieces.append(piece)
	return piece

func _build() -> void:
	flow_noise=source_noise()
	fit=Node3D.new()
	fit.scale.y=.816496580927726
	add_child(fit)
	if kind=="roar":
		for shell in 3:
			for wake in [false,true]:
				var piece := _piece("roar",shell)
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				for x in 96:
					for y in 6:
						for ij in [Vector2i(x,y),Vector2i(x+1,y),Vector2i(x,y+1),Vector2i(x+1,y),Vector2i(x+1,y+1),Vector2i(x,y+1)]:
							surface.set_uv(Vector2(ij.x/96.,ij.y/6.));surface.add_vertex(Vector3.ZERO)
				piece.mesh=surface.commit()
				piece.material_override.set_shader_parameter("shell",float(shell))
				piece.material_override.set_shader_parameter("wake",wake)
	elif kind=="presence":
		for layer in 3:
			var piece := _piece("presence",layer)
			var plane := PlaneMesh.new()
			plane.size=Vector2(2.6,2.6);plane.subdivide_width=16;plane.subdivide_depth=16
			piece.mesh=plane;piece.position.y=.08+layer*.09
	else:
		var family := "arc" if kind in ["quickened","twinned","distant","affinity"] else "flow"
		var count: int={"mantle":5,"affinity":5,"twinned":4,"distant":4,"quickened":3,"ground":7,"heal":6,"burst":6}.get(kind,6)
		for index in count:_piece(family,index)
		if family=="arc" and kind!="affinity":
			var glow_shader := Shader.new()
			var code := VfxPackageIO_5944248dd6.text("res://assets/vfx/sources/3cf525dfd27524c63fa6/dcd7c27efcd84ec38e226e5180e753edb56d4c28a8364bf3053a30322f6d8774.gdshader")
			code=code.replace("void fragment(){","void vertex(){ MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]); }\nvoid fragment(){")
			glow_shader.code=code
			var image := Image.new()
			image.load_png_from_buffer(VfxPackageIO_5944248dd6.bytes("res://assets/vfx/sources/0153d00f65f7d8626351/texture.res"))
			var texture := ImageTexture.create_from_image(image)
			for index in (2 if kind=="twinned" else 1):
				var core := MeshInstance3D.new()
				var quad := QuadMesh.new();quad.size=Vector2(.38,.38)
				core.mesh=quad
				core.position.x=(-.2 if index==0 else .2) if kind=="twinned" else 0.
				var material := ShaderMaterial.new();material.shader=glow_shader
				material.set_shader_parameter("glow_tex",texture)
				NativePalette.apply(material, settings.get("native_palette", []))
				core.material_override=material
				core.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				fit.add_child(core);cores.append(core)
		# These are the original orbiting native motes, not a noise film painted
		# onto the body. Preserve them with the source arc/flow layers.
		for index in (14 if family=="arc" else 12):
			var mote := MeshInstance3D.new()
			var ball := SphereMesh.new();ball.radius=.013 if family=="arc" else .018;ball.height=ball.radius*2.;ball.radial_segments=4;ball.rings=2
			mote.mesh=ball
			var material := StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			mote.material_override=material;mote.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fit.add_child(mote);motes.append(mote)
		sample(0.)

func set_entity_geometry(value: Dictionary) -> void:
	geometry=value

func set_live_endpoints(value: Array) -> void:
	endpoints=value

func _point(index: int, u: float, seconds: float) -> Vector3:
	var phase := TAU*seconds/2.
	if kind=="mantle":
		var angle := u*TAU*.67+index*1.26+phase
		var radius := .29+.09*sin(u*PI+index)
		return Vector3(cos(angle)*radius,.16+u*(.85+.16*sin(index))+.035*sin(phase+index),sin(angle)*radius)
	if kind=="ground":
		var angle := index*.9+u*1.6+.12*sin(phase+index)
		var radius := .25+u*.60
		return Vector3(cos(angle)*radius,.025+.02*sin(u*PI),sin(angle)*radius)
	if kind=="heal":
		var angle := index*1.047+.25*sin(phase+u*2.)
		var radius := .22+.07*sin(u*PI)
		return Vector3(cos(angle)*radius,u*1.32,sin(angle)*radius)
	if kind=="burst":
		var angle := index*TAU/6.
		var reach := .05+clampf(seconds/.45,0.,1.)*.65
		return Vector3(cos(angle)*reach*u,.40+.18*sin(u*PI)+seconds*.18,sin(angle)*reach*u)
	var angle := u*TAU*.86+seconds*TAU*(2. if kind=="quickened" else .65)+index*1.57
	if kind=="quickened":
		var radius := .21+.12*u
		return Vector3(cos(angle)*radius,sin(angle)*radius,0).rotated(Vector3.UP,index*TAU/3.)
	if kind=="twinned":
		return Vector3(cos(angle)*.20,sin(angle)*.20,0).rotated(Vector3.UP,.75 if index%2==0 else -.75)+Vector3(-.20 if index<2 else .20,0,0)
	if kind=="distant":
		var radius := .14+index*.095+smoothstep(0.,.8,seconds)*.10
		return Vector3(cos(angle)*radius,0,sin(angle)*radius).rotated(Vector3.RIGHT,.5+index*.30)
	angle=u*TAU*.80+index*1.256+seconds*TAU*.25
	var radius := .36+.035*sin(u*PI)
	return Vector3(cos(angle)*radius,.10+u*1.12,sin(angle)*radius)

func _strip(index: int, seconds: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := .045 if kind=="affinity" else .026 if kind in ["quickened","twinned","distant"] else .05 if kind=="mantle" else .065
	for step in 48:
		for ij in [Vector2i(step,0),Vector2i(step,1),Vector2i(step+1,1),Vector2i(step,0),Vector2i(step+1,1),Vector2i(step+1,0)]:
			var u: float = ij.x/48.
			var point := _point(index,u,seconds)
			var tangent := (_point(index,minf(u+.005,1.),seconds)-_point(index,maxf(u-.005,0.),seconds)).normalized()
			var across := tangent.cross(Vector3(.5,.7,.5)).normalized()
			if across.length()<.1:across=Vector3.RIGHT
			surface.set_uv(Vector2(u,ij.y));surface.add_vertex(point+across*width*(1. if ij.y else -1.))
	return surface.commit()

func sample(seconds: float) -> void:
	if not endpoints.is_empty() and kind in ["roar","quickened","twinned","distant"]:
		fit.position=global_transform.affine_inverse()*endpoints[0].point
		if kind=="roar" and endpoints.size()>1:
			var target: Vector3=global_transform.affine_inverse()*endpoints[1].point
			var direction := target-fit.position
			fit.rotation.y=atan2(direction.x,direction.z)
	elif not geometry.get("points",[]).is_empty():
		var inverse := global_transform.affine_inverse()
		var low := INF
		var high := -INF
		var radius := 0.
		for sample_point in geometry.points:
			var point: Vector3=inverse*sample_point.position
			low=minf(low,point.y);high=maxf(high,point.y)
			radius=maxf(radius,Vector2(point.x,point.z).length())
		fit.scale=Vector3(clampf(radius/.38,.65,2.5),clampf(high-low,.65,3.)*.81649658,clampf(radius/.38,.65,2.5))
		fit.position.y=low
	var duration := float(settings.get("seconds",2.))
	var envelope := smoothstep(0.,.14,seconds)*(1.-smoothstep(duration-.35,duration,seconds))
	envelope *= float(settings.get("strength_multiplier", 1.0))
	if kind in ["quickened","twinned","distant","affinity"]:envelope=smoothstep(0.,.14,seconds)*(1.-smoothstep(.80,1.25,seconds))
	elif kind=="heal":envelope=smoothstep(0.,.16,seconds)*(1.-smoothstep(1.,1.5,seconds))
	elif kind=="burst":envelope=sin(clampf(seconds/.85,0.,1.)*PI)
	for index in pieces.size():
		var material: ShaderMaterial=pieces[index].material_override
		material.set_shader_parameter("clock",seconds)
		if kind in ["roar","presence"]:continue
		pieces[index].mesh=_strip(index,seconds)
		material.set_shader_parameter("strength",envelope)
	for core in cores:core.material_override.set_shader_parameter("strength",envelope*.52)
	for index in motes.size():
		var point: Vector3
		var alpha := envelope*.65
		if kind in ["quickened","twinned","distant","affinity"]:
			point=_point(index%pieces.size(),fposmod(index*.137+seconds*.43,1.),seconds)
		else:
			var phase := fposmod(seconds/2.+index/12.,1.)
			var angle := index*2.399963+.14*sin(seconds*PI)
			var radius := .32 if kind in ["mantle","heal"] else .65
			point=Vector3(cos(angle)*radius,.06+phase*1.14,sin(angle)*radius)
			if kind=="ground":point.y=.02+.03*sin(phase*PI)
			elif kind=="burst":
				radius=.05+seconds*.7
				point=Vector3(cos(angle)*radius,.38+seconds*.3-seconds*seconds*.4,sin(angle)*radius)
			alpha=.8*sin(phase*PI)*envelope
		motes[index].position=point
		var brightness := .92 if kind in ["quickened","twinned","distant","affinity"] else .88
		var colour := Color(brightness,brightness,brightness,alpha)
		if settings.has("native_palette"):
			colour = Color(settings.native_palette[mini(3, settings.native_palette.size()-1)])
			colour.a = alpha
		motes[index].material_override.albedo_color = colour

func capture_observation() -> Dictionary:
	return {"kind":kind,"native_meshes":pieces.size(),"measured_points":geometry.get("points",[]).size(),"live_endpoints":endpoints.size()}

const VfxPackageIO_5944248dd6 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
