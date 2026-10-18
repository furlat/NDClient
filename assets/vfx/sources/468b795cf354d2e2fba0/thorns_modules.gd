extends Node3D
const CELL = 2.121320344
var circular = false
var module_count = 1
var heading = 0.0
var camera_ground = Vector2(1, 1).normalized()
var split_layers = false
var foreground = false
var retiring = 0.0
var lifecycle_age = 0.0
const SPEC = {
	"spell": "wall_of_thorns",
	"palette": ["22271c", "473823", "716044", "a18b61", "44502b", "69713d", "9b995c", "d0c096"],
	"scale": 0.38
}
var subject: Node3D
var players: Array[AnimationPlayer] = []
var mats: Array[ShaderMaterial] = []
var strike_root: Node3D
var strike_pieces: Array[MeshInstance3D] = []
var strike_material: ShaderMaterial
var contact_flakes: Array[MeshInstance3D] = []
var tick = 0
var occupants: Array[Vector4] = []
var occupant_state_known := false
var visual_settings: Array = []
var last_retirement := -1.0


func set_visual_occupants(values: Array[Vector4]) -> void:
	var current: Array[Vector4] = values.slice(0, 16)
	if occupant_state_known and occupants == current:
		return
	occupant_state_known = true
	occupants = current
	var packed := PackedVector4Array(occupants)
	for m in mats:
		m.set_shader_parameter("occupant_count", mini(values.size(), 16))
		if values.size() > 0:
			m.set_shader_parameter("occupants", packed)


func build(node: Node3D) -> void:
	subject = node
	var roots = [node]
	for j in range(module_count - 1):
		var copy = node.duplicate() as Node3D
		node.get_parent().add_child(copy)
		roots.append(copy)
	var scale3 = Vector3(.3539, .4362, 1.004)
	var lift = .7538
	if SPEC.spell == "wall_of_ice":
		scale3 = Vector3(1.3137, 2.2704, .6547)
		lift = .1059
	elif SPEC.spell == "wall_of_stone":
		scale3 = Vector3(1.976, 1.391, .215)
		lift = 1.163
	var items = []
	for index in range(module_count):
		var root = roots[index] as Node3D
		root.scale = scale3
		root.position = Vector3(
			(float(index) + 0.5 - (0.0 if circular else float(module_count) * .5)) * CELL, lift, 0
		)
		vary_interior(root, index)
		items.append_array(root.find_children("*", "", true, false))
	for item in items:
		if item is Light3D:
			item.visible = false
		if item is Decal:
			item.visible = false
		if item is GeometryInstance3D and "distortion" in str(item.name).to_lower():
			item.layers = 0
		if item is GPUParticles3D:
			item.layers = 0
			item.emitting = false
		if item is AnimationPlayer:
			players.append(item)
		if item is MeshInstance3D:
			item.custom_aabb = (
				item.global_transform.affine_inverse()
				* AABB(Vector3(-40, -.5, -40), Vector3(80, 6, 80))
			)
		if item is GeometryInstance3D:
			if item.material_override is ShaderMaterial:
				item.material_override = adapt(item.material_override)
			elif item is MeshInstance3D and item.mesh:
				for i in item.mesh.get_surface_count():
					var m = item.mesh.surface_get_material(i)
					if m is ShaderMaterial:
						item.set_surface_override_material(i, adapt(m))


func adapt(original: ShaderMaterial) -> ShaderMaterial:
	var m = original.duplicate(true) as ShaderMaterial
	var sh = Shader.new()
	var s = m.shader.code
	var re = RegEx.new()
	re.compile("\\bTIME\\b")
	s = re.sub(s, "wall_clock", true)
	s = (
		s
		. replace(
			"shader_type spatial;",
			"shader_type spatial;uniform float wall_clock=0.0;uniform float wall_fade=1.0;uniform int occupant_count=0;uniform vec4 occupants[16];uniform float contact_pulse=0.0;uniform vec2 actor_ground=vec2(0.0);uniform vec2 camera_ground=vec2(.70710678);uniform bool split_layers=false;uniform bool foreground=false;uniform float retirement=0.0;uniform float wall_heading=0.0;uniform bool circular=false;"
		)
	)
	var fr = RegEx.new()
	fr.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
	var found = fr.search(s)
	if found:
		var end = found.get_end()
		var depth = 1
		while depth > 0 and end < s.length():
			if s[end] == "{":
				depth += 1
			elif s[end] == "}":
				depth -= 1
			end += 1
		s = s.insert(end - 1, "ALPHA*=wall_fade;")
		s = (
			s
			. insert(
				end - 1,
				"vec3 contact_surface=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;if(split_layers && ((dot(contact_surface.xz-actor_ground,camera_ground)>0.0)!=foreground))discard;"
			)
		)
	if original.shader.code.contains("VinesTexture"):
		var vertex_re = RegEx.new()
		vertex_re.compile("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{")
		var hit = vertex_re.search(s)
		if hit:
			var begin = hit.get_end()
			var end = begin
			var depth = 1
			while depth > 0:
				if s[end] == "{":
					depth += 1
				elif s[end] == "}":
					depth -= 1
				end += 1
			var living = "vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;float anchor=pow(clamp(wp.y/4.242640688,0.0,1.0),1.45);float phase=wall_clock*3.14159265359;float broad=sin(wp.x/33.941125504*6.28318530718*3.0+wp.z*1.1-phase);float tips=sin(wp.x/33.941125504*6.28318530718*7.0+wp.y*1.6+phase*2.0);wp.z+=anchor*(0.23*broad+0.075*tips);wp.x+=anchor*0.08*sin(wp.x/33.941125504*6.28318530718*4.0+wp.y*0.7+phase);wp.y-=anchor*0.065*(0.5+0.5*sin(wp.x/33.941125504*6.28318530718*5.0-phase*2.0));wp.z=1.060660172*tanh(wp.z/1.060660172);if(circular){float theta=wp.x/33.941125504*6.28318530718;float radius=4.242640688+wp.z;wp=vec3(sin(theta)*radius,wp.y,cos(theta)*radius);vec3 wn=MODEL_NORMAL_MATRIX*NORMAL;vec3 curved_n=vec3(cos(theta)*wn.x+sin(theta)*wn.z,wn.y,-sin(theta)*wn.x+cos(theta)*wn.z);NORMAL=normalize(inverse(MODEL_NORMAL_MATRIX)*curved_n);}float ch=cos(wall_heading);float sh=sin(wall_heading);wp.xz=mat2(vec2(ch,-sh),vec2(sh,ch))*wp.xz;wp.y*=1.0-retirement;for(int i=0;i<16;i++){if(i>=occupant_count)break;vec2 offset=wp.xz-occupants[i].xy;float distance=length(offset);float influence=(1.0-smoothstep(0.25,1.45,distance))*occupants[i].z;float body=(1.0-smoothstep(2.0,2.9,wp.y))*smoothstep(0.0,0.45,wp.y);vec2 away=offset/max(distance,0.12);wp.xz+=away*influence*body*(0.32-occupants[i].w*0.58);wp.y-=influence*body*(0.05+0.035*sin(phase*2.0+wp.x));}VERTEX=(inverse(MODEL_MATRIX)*vec4(wp,1.0)).xyz;"
			s = s.substr(0, begin) + living + s.substr(end - 1)
	s = s.replace("NoiseSpeed * wall_clock", "NoiseSpeed * 0.0").replace(
		"dissolve_step_high * DisolverColorEnergy", "dissolve_step_high * 0.0"
	)
	s = s.replace("cull_back", "cull_disabled")
	sh.code = s
	m.shader = sh
	mats.append(m)
	if SPEC.spell == "wall_of_thorns":
		m.set_shader_parameter("Intensity", 2.2)
		m.set_shader_parameter("DisolverColorEnergy", 2.0)
		m.set_shader_parameter("SwayAmplitude", 0.0)
		m.set_shader_parameter("VertexIntensity", 0.0)
	return m


func start() -> void:
	for ap in players:
		ap.clear_caches()
		ap.play("Start")


func set_visual_state(age: float, values: Array[Vector4], removal: float = 0.0) -> void:
	lifecycle_age = age
	retiring = clampf(removal, 0.0, 1.0)
	set_visual_occupants(values)
	var current_settings: Array = [heading, circular, split_layers, foreground, camera_ground]
	var settings_changed: bool = visual_settings != current_settings
	var retirement_changed: bool = last_retirement != retiring
	for material in mats:
		material.set_shader_parameter("wall_clock", fmod(age, 2.0))
		if retirement_changed:
			material.set_shader_parameter("wall_fade", 1.0 - smoothstep(.65, 1.0, retiring))
			material.set_shader_parameter("retirement", retiring)
		if settings_changed:
			material.set_shader_parameter("wall_heading", heading)
			material.set_shader_parameter("circular", circular)
			material.set_shader_parameter("split_layers", split_layers)
			material.set_shader_parameter("foreground", foreground)
			material.set_shader_parameter("camera_ground", camera_ground)
			material.set_shader_parameter("actor_ground", Vector2.ZERO)
	last_retirement = retiring
	visual_settings = current_settings


func vary_interior(root: Node3D, variant: int) -> void:
	for item in root.find_children("*", "MeshInstance3D", true, false):
		if str(item.name) != "SmVinePlants11" or not item.mesh:
			continue
		var source = item.mesh
		var box = source.get_aabb()
		var replacement = ArrayMesh.new()
		for surface in range(source.get_surface_count()):
			var arrays = source.surface_get_arrays(surface)
			var verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for k in range(verts.size()):
				var vertex = verts[k]
				var u = clamp((vertex.x - box.position.x) / box.size.x, 0.0, 1.0)
				var interior = pow(sin(PI * u), 2.0)
				vertex.y += sin(u * 8.0 + float(variant) * 1.9) * interior * .65
				vertex.z += cos(u * 6.0 + float(variant) * 2.1) * interior * .11
				verts[k] = vertex
			arrays[Mesh.ARRAY_VERTEX] = verts
			replacement.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
			replacement.surface_set_material(surface, source.surface_get_material(surface))
		item.mesh = replacement

# Native nearest visible surface coordinates, retaining the original alpha mask.
# RG stores a 16-bit unsigned axis value; alpha identifies valid samples.
