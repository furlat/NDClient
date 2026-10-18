extends "res://assets/vfx/sources/02e8eda447821da38634/necrotic.gd"
const SpatialEnergyPalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
## Preserved V4 coating, fractured emissive seal, hit donor and ballistic flakes.
var coating: MeshInstance3D
var flakes: Array[MeshInstance3D] = []
var sigil: MeshInstance3D


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/2db9d8f5be6686ffedf1/blight.gd", input)


func apply_scene_edits(node: Node) -> void:
	tick = 0
	subject = (
		VfxPackageIO_2db9d8f5be.resource(
			"res://assets/vfx/sources/5991cf7e3e0a286577ae/VFX_Hit_dark.tscn"
		)
		. instantiate()
	)
	ResourceGraph.isolate_node(subject, {})
	subject.name = "NecroticContact"
	node.add_child(subject)
	subject.scale = Vector3.ONE * .40
	subject.position.y = 1.30
	subject.get_node("torus").visible = false
	subject.get_node("OmniLight3D").visible = false
	subject.get_node("stars").amount = 6
	for c in [subject] + subject.find_children("*", "", true, false):
		if c is GPUParticles3D:
			c.fixed_fps = 144
			c.use_fixed_seed = true
			c.seed = 52917
			c.process_material = c.process_material.duplicate(true)
			c.process_material.hue_variation_min = 0.0
			c.process_material.hue_variation_max = 0.0
			c.restart()
		for p in c.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_STORAGE and c.get(p.name) is Resource:
				recolor(c.get(p.name))
		if c is AnimationPlayer and c.has_animation("Init"):
			c.play("Init")
	# Connected curved coating, authored in native world space. The native donor's
	# dissolve/noise textures cut irregular transparent openings into this surface.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx = 64
	var ny = 24
	for j in range(ny):
		for i in range(nx):
			for c in [
				Vector2i(i, j),
				Vector2i(i + 1, j),
				Vector2i(i + 1, j + 1),
				Vector2i(i, j),
				Vector2i(i + 1, j + 1),
				Vector2i(i, j + 1)
			]:
				var u = float(c.x) / nx
				var v = float(c.y) / ny
				var a = u * TAU
				var r = (
					sin(v * PI) * (.70 + .07 * sin(a * 3. + v * 4.) + .035 * sin(a * 7. - v * 6.))
				)
				st.set_uv(Vector2(u, v))
				st.add_vertex(Vector3(cos(a) * r, (v - .5) * 2.35, sin(a) * r * .78))
	st.generate_normals()
	coating = MeshInstance3D.new()
	coating.name = "WitheringCoating"
	coating.mesh = st.commit()
	coating.position.y = 1.12
	coating.material_override = make_material(0)
	node.add_child(coating)
	# Transient necrotic seal: emissive fractured rune, native torso plane.
	sigil = MeshInstance3D.new()
	sigil.name = "BlightSeal"
	var seal = QuadMesh.new()
	seal.size = Vector2(1.55, 1.55)
	sigil.mesh = seal
	sigil.position = Vector3(.05, 1.47, .05)
	sigil.rotation.y = PI / 4.
	sigil.material_override = make_material(2)
	node.add_child(sigil)
	# Sparse rigid flakes, finite ballistic settling rather than an orbiting swarm.
	for i in range(22):
		var mesh = ArrayMesh.new()
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(
			[Vector3(-.035, 0, 0), Vector3(.018, .095, 0), Vector3(.046, .019, .018)]
		)
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(
			[Vector2(0, 0), Vector2(.5, 1), Vector2(1, 0)]
		)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var f = MeshInstance3D.new()
		f.mesh = mesh
		f.material_override = make_material(1)
		node.add_child(f)
		flakes.append(f)
	# Explicit component isolation is used by private diagnostic fixtures only.
	var visible_layers: Array = parameters.get("diagnostic_visible_layers", [])
	if not visible_layers.is_empty():
		subject.visible = visible_layers.has("donor")
		coating.visible = visible_layers.has("coating")
		sigil.visible = visible_layers.has("seal")
		for flake in flakes:
			flake.visible = visible_layers.has("flakes")


func capture_observation() -> Dictionary:
	var masks := {}
	for path in ["stars", "Pruple Expansion"]:
		var material: ShaderMaterial = subject.get_node(path).material_override
		var texture: Texture2D = material.get_shader_parameter("Mask_Texture")
		masks[path] = {
			"mask_path": "" if texture == null else texture.resource_path,
			"mask_class": "null" if texture == null else texture.get_class(),
			"opacity": material.get_shader_parameter("support_envelope"),
			"mask_floor_enabled": material.shader.code.contains("smoothstep(0.08, 0.32"),
			"palette_count": material.get_shader_parameter("native_palette_count"),
		}
		if parameters.get("diagnostic_dump_shaders", false):
			FileAccess.open("res://reviews/blight-"+path.replace(" ","_")+"-diagnostic.gdshader.txt",FileAccess.WRITE).store_string(material.shader.code)
	return {
		"component": "blight",
		"coating_style": coating.material_override.get_shader_parameter("style"),
		"seal_style": sigil.material_override.get_shader_parameter("style"),
		"coating_visible": coating.visible,
		"seal_visible": sigil.visible,
		"donor_visible": subject.visible,
		"donor_masks": masks,
	}


func make_material(style: int) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = VfxPackageIO_2db9d8f5be.text("res://assets/vfx/sources/0951ad8377f03843b870/blight_coating_v4.gdshader")
	mat.shader = sh
	(
		mat
		. set_shader_parameter(
			"source_noise",
			VfxPackageIO_2db9d8f5be.resource(
				"res://assets/vfx/sources/6961d971113968c3631f/texture.res"
			)
		)
	)
	mat.set_shader_parameter(
		"source_wave",
		VfxPackageIO_2db9d8f5be.resource("res://assets/vfx/sources/2459ed37cb0fa31767ac/texture.res")
	)
	mat.set_shader_parameter("style", style)
	adapt_shader(mat)
	return mat


func adapt_shader(material: ShaderMaterial) -> void:
	# The JPEG impact mask has a nonzero black/noise floor. HDR radiance in those
	# low-coverage texels makes the rectangular particle card visible in the live
	# transparent pass. Retain its native flare shape and soft edge above that floor.
	var code: String = NativeShaderBindings.stable_proximity(material.shader.code)
	if code.contains("n_out3p0 = texture(Mask_Texture, UV);"):
		var derivative := Shader.new()
		derivative.code = code.replace(
			"n_out3p0 = texture(Mask_Texture, UV);",
			"n_out3p0 = texture(Mask_Texture, UV); n_out3p0.r = smoothstep(0.08, 0.32, n_out3p0.r); if (n_out3p0.r <= 0.0) discard;"
		)
		NativeShaderBindings.replace_shader(material, derivative)
	super.adapt_shader(material)
	SpatialEnergyPalette.apply(material, settings.redPalette)
	var diagnostic: String = parameters.get("diagnostic_donor_output", "")
	if not diagnostic.is_empty() and material.shader.code.contains("uniform sampler2D Mask_Texture"):
		var original: String = material.shader.code
		var fragment: int = original.find("void fragment()")
		var statement: String = "ALBEDO=vec3(1.0); ALPHA=0.0;"
		if diagnostic == "mask":
			statement = "ALBEDO=vec3(texture(Mask_Texture,UV).r); ALPHA=1.0;"
		elif diagnostic == "radial":
			statement = "ALBEDO=vec3(1.0,0.0,0.0); ALPHA=1.0-smoothstep(0.25,0.45,length(UV-vec2(0.5)));"
		elif diagnostic == "coverage":
			statement = "ALBEDO=vec3(1.0); ALPHA=texture(Mask_Texture,UV).r*clamp(COLOR.a,0.0,1.0);"
		var diagnostic_shader := Shader.new()
		diagnostic_shader.code = original.substr(0,fragment)+"void fragment(){"+statement+"}"
		NativeShaderBindings.replace_shader(material,diagnostic_shader)


func advance_lifecycle(_delta: float) -> void:
	if subject == null:
		return
	tick += 1
	var age = float(tick) / 144.
	var env = smoothstep(0., .055, age) * (1. - smoothstep(1.10, 1.55, age))
	for m in materials:
		m.set_shader_parameter("support_clock", age)
		m.set_shader_parameter("support_envelope", env)
	var squeeze = smoothstep(.16, .90, age)
	coating.scale = Vector3(1. - .32 * squeeze, 1. - .14 * squeeze, 1. - .32 * squeeze)
	coating.position.y = 1.12 - .10 * squeeze
	for i in range(flakes.size()):
		var f = flakes[i]
		var a = float(i) * 2.399963
		var delay = .28 + float(i % 5) * .035
		var age2 = max(0., age - delay)
		var height = .35 + float(i % 7) * .21
		f.position = Vector3(
			sin(a) * (.57 + .20 * age2),
			max(.02, height - .28 * age2 - 2.1 * age2 * age2),
			cos(a) * (.44 + .11 * age2)
		)
		f.rotation = Vector3(a * .2 + age2 * .8, a, a * .6 + age2 * .45)
		f.scale = (
			Vector3.ONE
			* (.65 + float(i % 4) * .15)
			* smoothstep(delay, delay + .10, age)
			* (1. - smoothstep(.88, 1.30, age))
		)

const VfxPackageIO_2db9d8f5be = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
