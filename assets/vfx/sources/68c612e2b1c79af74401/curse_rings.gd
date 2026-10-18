extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
## Accepted native curse geometry and lifecycle. Variant glyphs and donor choices are data.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const PaletteTexture = preload("res://assets/vfx/sources/7ffdb77f06cb06b0c42e/contract_stage.gd")


## The selected curse recorder finished its deliberately grey native shaders
## with this encoded-energy curve and exact palette. Native occurrences perform
## that operation per fragment; no atlas block filter or renderer-wide ramp.
static func finish_material(material: ShaderMaterial, specification: Dictionary) -> void:
	if not specification.get("native_curse_finish", false):
		return
	assert(specification.has("palette") and specification.palette.size() >= 2,
		"Native curse finish requires its exact selected source palette")
	var code := SourceMaterials.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir())
	var declarations := """
uniform sampler2D curse_source_palette:filter_nearest,repeat_disable;
uniform int curse_source_palette_count=6;
uniform float curse_source_energy_gain=1.0;
uniform float curse_source_energy_cap=0.823529411765;
float curse_encode(float value){
	value=max(0.0,value);
	return value<=0.0031308?12.92*value:1.055*pow(value,1.0/2.4)-0.055;
}
float curse_decode(float value){
	return value<=0.04045?value/12.92:pow((value+0.055)/1.055,2.4);
}
"""
	code = code.replace("shader_type spatial;", "shader_type spatial;" + declarations)
	code = SourceMaterials.finish_fragment(code, """
	vec3 curse_source_linear=max(ALBEDO+EMISSION,vec3(0.0));
	float curse_energy=curse_encode(max(max(curse_source_linear.r,curse_source_linear.g),curse_source_linear.b));
	curse_energy=min(curse_energy*curse_source_energy_gain,curse_source_energy_cap);
	float curse_index=clamp(floor(pow(clamp(curse_energy,0.0,1.0),1.15)*float(curse_source_palette_count-1)+0.5),0.0,float(curse_source_palette_count-1));
	vec3 curse_choice=texture(curse_source_palette,vec2((curse_index+0.5)/float(curse_source_palette_count),0.5)).rgb;
	ALBEDO=vec3(curse_decode(curse_choice.r),curse_decode(curse_choice.g),curse_decode(curse_choice.b));
	EMISSION=vec3(0.0);
	""")
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(material, shader)
	material.set_shader_parameter("curse_source_palette", PaletteTexture.palette_texture(specification.palette))
	material.set_shader_parameter("curse_source_palette_count", specification.palette.size())
	material.set_shader_parameter("curse_source_energy_gain", float(specification.get("energyGain", 1.0)))
	material.set_shader_parameter("curse_source_energy_cap", (205.0 if specification.curseMode in ["apply", "resisted"] else 210.0) / 255.0)
	material.set_meta("native_curse_source_finish", true)


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/68c612e2b1c79af74401/curse_rings.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


var folds: Array[MeshInstance3D] = []
var receiving_surface: Dictionary = {}


func set_live_endpoints(value: Array) -> void:
	receiving_surface = {}
	for endpoint in value:
		var surface: Dictionary = endpoint.get("surface", {})
		if surface.get("actor", "") == settings.get("receiving_actor", "") and not surface.get("points", []).is_empty():
			receiving_surface = surface
			return


func update_geometry() -> void:
	_place_rings(float(tick) / float(parameters.simulation_hz))


func apply_scene_edits(node: Node) -> void:
	for i in range(3):
		var fold = MeshInstance3D.new()
		fold.name = "LingeringCurseCircle" + str(i)
		var ring = TorusMesh.new()
		ring.inner_radius = .355
		ring.outer_radius = .380
		ring.rings = 64
		ring.ring_segments = 8
		fold.mesh = ring
		node.add_child(fold)
		fold.position.y = .65 + float(i) * .23
		fold.rotation = Vector3(.08 * float(i - 1), 0., .10 * float(i - 1))
		var mat = ShaderMaterial.new()
		var shader = Shader.new()
		shader.code = RING
		mat.shader = shader
		adapt_shader(mat)
		mat.set_shader_parameter("ring_phase", float(i) * TAU / 3.)
		fold.material_override = mat
		folds.append(fold)


func advance_lifecycle(_dt: float) -> void:
	tick += 1
	var age = float(tick) / float(parameters.simulation_hz)
	var release = settings.curseMode == "release"
	var envelope = 1. - smoothstep(.08, 1.15, age) if release else smoothstep(0., .16, age)
	for mat in materials:
		mat.set_shader_parameter("support_clock", age)
		mat.set_shader_parameter("support_envelope", envelope)
		mat.set_shader_parameter("releasing", release)
	_place_rings(age)


func _place_rings(age: float) -> void:
	var body_scale := 1.0
	if settings.get("native_curse_finish", false):
		if receiving_surface.is_empty():
			for fold in folds:
				fold.hide()
			return
		var top := -INF
		for point in receiving_surface.points:
			top = maxf(top, subject.to_local(point.position).y)
		body_scale = top / float(settings.headTop)
	var release: bool = settings.curseMode == "release"
	for i in range(folds.size()):
		var phase = age * TAU / 2. + float(i) * TAU / 3.
		var radius_scale = 1. + .016 * sin(phase)
		if release:
			radius_scale *= 1. - .22 * smoothstep(.08, 1., age)
		elif age < 1.:
			radius_scale *= lerpf(1.40, 1., smoothstep(.05, .75, age))
		# Preserve the original ring mesh, tilts and relative spacing, registered
		# to the actual actor's body height instead of the taller source proxy.
		folds[i].show()
		folds[i].position.y = (.65 + float(i) * .23) * body_scale
		folds[i].scale = Vector3.ONE * radius_scale * body_scale


const RING = """shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;
uniform float ring_phase=0.;uniform bool releasing=false;varying vec3 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){float angle=atan(local_position.z,local_position.x);
float travel=sin(angle*3.-TIME*3.14159265359+ring_phase);
float accent=smoothstep(.70,.99,travel);
ALBEDO=vec3(.53+.09*accent);EMISSION=vec3(.008*accent);ALPHA=.88;
if(releasing){float cut=.28+.25*sin(angle*5.+ring_phase);ALPHA*=1.-smoothstep(cut,cut+.30,TIME);}
}"""


func adapt_shader(mat: ShaderMaterial) -> void:
	var shader = Shader.new()
	var code: String = SourceMaterials.expand_shader(
		mat.shader.code, mat.shader.resource_path.get_base_dir()
	)
	# Source-relative includes must resolve from the copied shader resource.
	code = code.replace("TIME", "support_clock")
	code = (
		code
		. replace(
			"shader_type spatial;",
			"shader_type spatial;\nuniform float support_clock=0.0;\nuniform float support_envelope=1.0;"
		)
	)
	var split = "<" if side == "front" else ">="
	var prefix = (
		"\nvec3 support_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\nif(dot(support_world,vec3(0.70710678,0.0,0.70710678)) "
		+ split
		+ " 0.0) discard;\n"
	)
	var regex = RegEx.new()
	regex.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
	var match0 = regex.search(code)
	if match0:
		var pos = match0.get_end()
		code = code.insert(pos, prefix)
		var depth = 1
		var end = pos + prefix.length()
		while end < code.length() and depth > 0:
			if code[end] == "{":
				depth += 1
			elif code[end] == "}":
				depth -= 1
			end += 1
		var correction = ""
		code = code.insert(end - 1, "\n" + correction + "\nALPHA *= support_envelope;\n")
	code = code.replace("vec3(0.70710678,0.0,0.70710678)", settings.clip_vector)
	shader.code = code
	if settings.get("native_curse_finish", false):
		SourceMaterials.replace_shader(mat, shader)
		finish_material(mat, settings)
	else:
		mat.shader = shader
	materials.append(mat)
