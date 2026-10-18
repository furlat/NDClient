extends Node3D
## Original ContinuousWeb texture, geometry deployment and strand coverage.
## Local ignition chars/disappears the same strands; it does not replace a mask.
const ImportedImages = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Events = preload("res://assets/vfx/sources/fb7d771675b2f9a86e34/committed_surface_events.gd")
const Emitters = preload("res://assets/vfx/sources/640361420840ef7d5319/source_emitters.gd")
const SourceShader := "res://assets/vfx/sources/3a1ad1b2f07adba54c86/ContinuousWeb.gdshader"
const SourceTexture := "res://assets/vfx/sources/0b13f8c9f190dd46fcfa/texture.res"
const Cell := 2.121320344
var settings: Dictionary
var transition_state := Events.new()
var material: ShaderMaterial
var flames: Array[GPUParticles3D] = []
var support_points: Array[Vector3] = []

static func make_component(input: Dictionary) -> Node3D:
	var node := VfxPackageIO_4d694813ce.resource("res://assets/vfx/sources/4d694813ce66e646e55c/reactive_web.gd").new() as Node3D
	node.settings=input.duplicate(true)
	node._build()
	return node

func _build() -> void:
	var source := VfxPackageIO_4d694813ce.text(SourceShader)
	var shared := VfxPackageIO_4d694813ce.text("res://assets/vfx/sources/1429ef3d5c897b3c25a7/surface_states.gdshaderinc")
	source=source.replace("void vertex(){","varying vec2 surface_local_point;\nvoid vertex(){")
	source=source.replace("shader_type spatial;","shader_type spatial;\nuniform float owner_envelope=1.;")
	source=source.replace("void fragment(){",shared+"\nvoid fragment(){")
	var split := source.find("\nvoid fragment(){")
	var before := source.substr(0,split)
	# Last vertex brace precedes the shared uniforms/functions, so anchor the
	# assignment on the original last vertex statement rather than a generic brace.
	before=before.replace("source_clock*15.+along*2.)*.025*trailing*min(1.,-source_clock*8.):0.;", "source_clock*15.+along*2.)*.025*trailing*min(1.,-source_clock*8.):0.;\nsurface_local_point=VERTEX.xz/2.121320344;")
	source=before+source.substr(split)
	source=source.insert(source.rfind("}"),"\nvec4 state=factory_surface_states(surface_local_point,0.); ALBEDO=mix(ALBEDO,vec3(.065,.035,.02),state.z); EMISSION=vec3(.7,.12,.015)*state.z*(1.-state.z); ALPHA*= (1.-smoothstep(.5,1.,state.z))*(1.-state.w)*owner_envelope;\n")
	var shader := Shader.new()
	shader.code=source
	material=ShaderMaterial.new()
	material.shader=shader
	var image := ImportedImages.imported_image(SourceTexture)
	image.generate_mipmaps()
	material.set_shader_parameter("silk_texture",ImageTexture.create_from_image(image))
	material.set_shader_parameter("forward_axis",Vector2(1,0))
	var mesh := PlaneMesh.new()
	mesh.size=Vector2(10.6,10.6)
	mesh.subdivide_width=100
	mesh.subdivide_depth=100
	var field := MeshInstance3D.new()
	field.mesh=mesh
	field.material_override=material
	field.scale=Vector3.ONE/Cell
	field.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(field)
	# Sample supported original silk texels; apply the original settled vertex
	# mapping to their bases. Thus flames originate on strands, not empty quads.
	for z in range(3,18,2):
		for x in range(3,18,2):
			var uv := Vector2(x,z)/20.
			if image.get_pixel(int(uv.x*(image.get_width()-1)),int(uv.y*(image.get_height()-1))).a<.20:continue
			support_points.append(_source_rest_point((uv-Vector2.ONE*.5)*10.6)/Cell)
	for index in 16:flames.append(Emitters.make(self,"fire",index))
	set_transition_events(settings.get("events",[]))

static func _source_rest_point(point: Vector2) -> Vector3:
	var radius := point.length()
	var edge := maxf(absf(point.x),absf(point.y))
	var q := point*lerpf(1.,radius/maxf(edge,.0001),.82)
	var angle := atan2(q.y,q.x)
	var irregular := .065*sin(angle*3.+.7)+.04*sin(angle*2.-1.3)
	var bend := .10*sin(radius*.7+angle*2.)*minf(radius/3.,1.)
	q=q.rotated(bend)*(1.+irregular)
	q+=Vector2(sin(q.y*1.05+.7),sin(q.x*.87-1.1))*.18*minf(radius/3.,1.)
	return Vector3(q.x,.035+.016*(1.+sin(q.x*2.+q.y*1.7)),q.y)

func set_transition_events(value: Array) -> void:
	var error: String=transition_state.replace(value,["ignite","douse","clear"])
	if not error.is_empty():push_error(error);return
	transition_state.bind(material)

func sample(seconds: float) -> void:
	var retirement := 1.-smoothstep(float(settings.get("remove_at",9.)),float(settings.get("remove_at",9.))+.4,seconds)
	material.set_shader_parameter("source_clock",minf(seconds,1.5))
	material.set_shader_parameter("surface_seconds",seconds)
	material.set_shader_parameter("owner_envelope",retirement)
	visible=retirement>.001
	for index in flames.size():
		var strength := 0.
		if not support_points.is_empty():
			var point: Vector3=support_points[(index*7+3)%support_points.size()]
			flames[index].position=point
			var state: Vector4=transition_state.state_at(Vector2(point.x,point.z),seconds)
			strength=state.z*(1.-state.w)*retirement
		Emitters.sample(flames[index],seconds,strength)

func capture_observation() -> Dictionary:
	return {"source_silk_points":support_points.size(),"committed_cell_records":transition_state.contacts.size(),"flame_emitters":flames.size()}

const VfxPackageIO_4d694813ce = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
