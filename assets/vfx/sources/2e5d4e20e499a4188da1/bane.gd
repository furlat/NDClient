extends "res://assets/vfx/sources/2f63b2ef0cb2d87dafc6/blessing.gd"
## Preserved LeLu smoke geometry/noise plus authored curse brands and ground lifecycle.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/2e5d4e20e499a4188da1/bane.gd", input)


func apply_scene_edits(node: Node) -> void:
	if settings.name == "vfx_status_void":
		node.get_node("MeshInstance3D").layers = 0
		var smoke_texture = (
			ImageTexture
			. create_from_image(
				(
					VfxPackageIO_2e5d4e20e4.image(
						"res://assets/vfx/sources/8b50d862e875547c4693/texture.res"
					)
				)
			)
		)
		var smoke_triangles = JSON.parse_string(
			VfxPackageIO_2e5d4e20e4.text(
				"res://assets/vfx/sources/25658d39d65c2810ff8e/lelu_smoke_triangles.json"
			)
		)
		var smoke_surface = SurfaceTool.new()
		smoke_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for point in smoke_triangles:
			smoke_surface.set_uv(Vector2(point[3], 1.0 - point[4]))
			smoke_surface.add_vertex(Vector3(point[0], point[1], point[2]))
		var smoke_mesh = smoke_surface.commit()
		for i in range(3):
			var glyph = MeshInstance3D.new()
			glyph.name = "OrbitBrand" + str(i)
			var plane = QuadMesh.new()
			plane.size = Vector2(0.68, 0.816)
			glyph.mesh = plane
			var material = ShaderMaterial.new()
			var shader = Shader.new()
			shader.code = "shader_type spatial;\nrender_mode unshaded,cull_disabled;\n// curse_brand_marker\nfloat stroke(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0));}\nvoid vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);}\nvoid fragment(){\n vec2 p=(UV-vec2(0.5))*vec2(1.0,-1.2);\n float d=stroke(p,vec2(0.035,-0.46),vec2(-0.025,-0.06));\n d=min(d,stroke(p,vec2(-0.025,-0.06),vec2(-0.04,0.12)));\n d=min(d,stroke(p,vec2(-0.04,0.12),vec2(-0.27,0.31)));\n d=min(d,stroke(p,vec2(-0.27,0.31),vec2(-0.22,0.48)));\n d=min(d,stroke(p,vec2(-0.04,0.12),vec2(0.28,0.43)));\n d=min(d,stroke(p,vec2(-0.27,-0.17),vec2(0.2,-0.27)));\n float core=1.0-smoothstep(0.04,0.047,d);\n float rim=1.0-smoothstep(0.062,0.072,d);\n ALBEDO=mix(vec3(0.045,0.015,0.025),vec3(1.0,0.035,0.07),core);\n ALPHA=rim;\n}"
			shader.code = shader.code.replace(
				"// curse_brand_marker", "// curse_brand_marker\nuniform sampler2D mark_noise;"
			)
			shader.code = (
				shader
				. code
				. replace(
					"ALPHA=rim;",
					"float mottling=texture(mark_noise,UV*1.5+vec2(TIME/6.0,-TIME/3.0)).r;\n ALBEDO*=mix(0.48,1.0,smoothstep(0.2,0.8,mottling));\n ALPHA=rim;"
				)
			)
			material.shader = shader
			material.set_shader_parameter("mark_noise", smoke_texture)
			glyph.material_override = material
			node.add_child(glyph)
			for puff_index in range(2):
				var aura = MeshInstance3D.new()
				aura.name = "CurseWisp" + str(i) + str(puff_index)
				aura.mesh = smoke_mesh
				var aura_mat = ShaderMaterial.new()
				var aura_shader = Shader.new()
				aura_shader.code = """shader_type spatial;
render_mode unshaded,cull_disabled;
// Authored LeLu smoke mesh and tiled dissolve texture, adapted lifecycle.
uniform sampler2D Disolver_Texture;
uniform float puff_life=0.0;
void fragment(){
	vec2 uv=UV*0.75+vec2(TIME/6.0,-TIME/3.0);
	float n=texture(Disolver_Texture,uv).r;
	float detail=texture(Disolver_Texture,UV*1.9+vec2(-TIME/3.0,TIME/6.0)).r;
	float erosion=mix(0.30,0.94,pow(puff_life,0.8));
	float body=smoothstep(erosion,erosion+0.14,n)*smoothstep(0.16,0.39,detail);
	float lit_edge=1.0-smoothstep(erosion+0.14,erosion+0.30,n);
	ALBEDO=mix(vec3(0.065,0.01,0.024),vec3(0.56,0.025,0.055),lit_edge*mix(0.35,1.0,detail));
	ALPHA=body*smoothstep(0.0,0.16,puff_life)*(1.0-smoothstep(0.66,1.0,puff_life))*0.48;
}"""
				aura_mat.shader = aura_shader
				aura_mat.set_shader_parameter("Disolver_Texture", smoke_texture)
				aura.material_override = aura_mat
				node.add_child(aura)
			for j in range(2):
				var tear = MeshInstance3D.new()
				tear.name = "BloodTear" + str(i) + str(j)
				var tear_mesh = QuadMesh.new()
				tear_mesh.size = Vector2(0.14, 0.23)
				tear.mesh = tear_mesh
				var tear_mat = ShaderMaterial.new()
				var tear_shader = Shader.new()
				tear_shader.code = """shader_type spatial;
render_mode unshaded,cull_disabled;
// curse_brand_marker
uniform float tear_alpha=1.0;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);}
void fragment(){
	vec2 p=UV-vec2(0.5);
	float width=mix(0.07,0.44,smoothstep(-0.4,0.22,p.y));
	float edge=(1.0-smoothstep(width-0.07,width,abs(p.x)))*(1.0-smoothstep(0.29,0.48,p.y))*smoothstep(-0.5,-0.3,p.y);
	ALBEDO=mix(vec3(0.23,0.012,0.025),vec3(0.72,0.025,0.04),1.0-smoothstep(0.02,0.3,abs(p.x)));
	ALPHA=edge*tear_alpha;
}"""
				tear_mat.shader = tear_shader
				tear.material_override = tear_mat
				node.add_child(tear)

	if settings.name == "vfx_status_void" and settings.get("mode", "") != "sustain":
		var ground = MeshInstance3D.new()
		ground.name = "CurseGround"
		var ground_mesh = PlaneMesh.new()
		ground_mesh.size = Vector2(3.6, 3.6)
		ground.mesh = ground_mesh
		ground.position.y = -float(settings.height) / float(settings.scale) + 0.015
		var ground_mat = ShaderMaterial.new()
		var ground_shader = Shader.new()
		ground_shader.code = """shader_type spatial;
render_mode unshaded,cull_disabled;
// curse_ground_marker
uniform sampler2D curse_noise;
uniform float curse_age=0.0;
void fragment(){
	vec2 p=(UV-vec2(0.5))*2.0;
	float age=curse_age;
	float shrink=mix(0.86,1.16,smoothstep(0.05,0.6,age));
	vec2 q=p*shrink;
	float n=texture(curse_noise,UV*1.9+vec2(age*0.12,-age*0.08)).r;
	float a=atan(q.y,q.x);
	float lobe=0.69+0.11*sin(a*3.0+0.4)+0.075*cos(a*5.0-0.8);
	float r=length(q)+(n-0.5)*0.2;
	float edge=1.0-smoothstep(0.04,0.13,abs(r-lobe));
	float body=(1.0-smoothstep(lobe-0.13,lobe+0.08,r))*smoothstep(0.05,0.36,r);
	float torn=smoothstep(0.30,0.58,n);
	float env=smoothstep(0.02,0.14,age)*(1.0-smoothstep(0.4,0.95,age));
	float pulse=1.0+0.45*exp(-pow((age-0.23)/0.1,2.0));
	ALBEDO=mix(vec3(0.09,0.008,0.022),vec3(0.72,0.025,0.04),edge*torn);
	ALPHA=(body*0.40+edge*torn*0.7)*env*pulse;
}"""
		ground_mat.shader = ground_shader
		var noise = FastNoiseLite.new()
		noise.seed = 417
		noise.noise_type = 2
		noise.frequency = 0.02
		noise.fractal_octaves = 1
		var tex = NoiseTexture2D.new()
		tex.noise = noise
		tex.seamless = true
		ground_mat.set_shader_parameter("curse_noise", tex)
		ground.material_override = ground_mat
		node.add_child(ground)
	super.apply_scene_edits(node)


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var age = float(tick) / 144.0
	if settings.name == "vfx_status_void":
		var shape = subject.get_node_or_null("MeshInstance3D")
		if shape:
			var contraction = lerpf(1.4, 0.5, smoothstep(0.12, 0.85, age))
			shape.scale = Vector3(contraction, contraction * 1.12, contraction)
			if age > 1.25:
				shape.visible = false
	var fade = float(settings.get("alphaGain", 1.0))
	fade *= smoothstep(0.0, 0.18, age)
	fade *= lerpf(1.0, 0.25, smoothstep(0.85, 1.65, age))
	if int(settings.close) > 0 and tick > int(settings.close):
		fade *= (
			1.0
			- smoothstep(float(settings.close) / 144.0, float(settings.frames - 12) / 144.0, age)
		)
	var shader_age = age
	if settings.get("mode", "") == "sustain":
		shader_age = 0.5 + 0.3 * sin(TAU * float((tick - 1) % 288) / 288.0)
		fade = float(settings.get("alphaGain", 1.0)) * 0.35
	if settings.name == "vfx_status_void":
		var elapsed = (
			float((tick - 1) % 864) / 144.0 if settings.get("mode", "") == "sustain" else age - 1.5
		)
		for i in range(3):
			var glyph = subject.get_node_or_null("OrbitBrand" + str(i))
			if glyph:
				var angle = TAU * elapsed / 6.0 + [0.2, 2.35, 4.6][i]
				var radius = (
					[1.03, 1.27, 1.12][i]
					if settings.get("mode", "") == "sustain"
					else lerpf(1.65, [1.03, 1.27, 1.12][i], smoothstep(0.12, 0.8, age))
				)
				glyph.position = Vector3(
					cos(angle) * radius,
					[-0.4, 0.08, 0.55][i] + 0.07 * sin(angle * 2.0),
					sin(angle) * radius
				)
				for puff_index in range(2):
					var puff = subject.get_node("CurseWisp" + str(i) + str(puff_index))
					var life = fposmod(elapsed + float(i) * 0.43 + float(puff_index), 2.0) / 2.0
					var birth_angle = angle - TAU * life * 0.65 / 6.0
					puff.position = Vector3(
						cos(birth_angle) * (radius + 0.23),
						[-0.4, 0.08, 0.55][i] - 0.25 + life * 0.65,
						sin(birth_angle) * (radius + 0.23)
					)
					puff.rotation = Vector3(
						float(i) * 0.7 + life * 0.45,
						float(puff_index) * 1.8 + life * 0.65,
						float(i) * 0.4
					)
					puff.scale = Vector3(
						lerpf(0.075, 0.13, life), lerpf(0.11, 0.25, life), lerpf(0.07, 0.12, life)
					)
					puff.material_override.set_shader_parameter("puff_life", life)
				for j in range(2):
					var tear = subject.get_node("BloodTear" + str(i) + str(j))
					var cycle = fposmod(elapsed + float(i) * 0.39 + float(j) * 0.75, 1.5)
					var falling = minf(cycle, 0.46)
					var birth_angle = angle - TAU * falling / 6.0
					tear.position = Vector3(
						cos(birth_angle) * radius,
						(
							[-0.4, 0.08, 0.55][i]
							+ 0.07 * sin(birth_angle * 2.0)
							- 0.34
							- (1.1 + float(i) * 0.55) * falling
							- 4.9 * falling * falling
						),
						sin(birth_angle) * radius
					)
					var spawn_height = (
						float(settings.height) / float(settings.scale)
						+ [-0.4, 0.08, 0.55][i]
						+ 0.07 * sin(birth_angle * 2.0)
						- 0.34
					)
					var initial_speed = 1.1 + float(i) * 0.55
					var ground_time = (
						(
							-initial_speed
							+ sqrt(initial_speed * initial_speed + 19.6 * maxf(spawn_height, 0.0))
						)
						/ 9.8
					)
					tear.position.y = maxf(
						tear.position.y, -float(settings.height) / float(settings.scale) + 0.015
					)
					tear.material_override.set_shader_parameter(
						"tear_alpha",
						(
							smoothstep(0.0, 0.045, cycle)
							* (1.0 - smoothstep(maxf(0.1, ground_time - 0.055), ground_time, cycle))
						)
					)
		shader_age = elapsed

	for mat in materials:
		mat.set_shader_parameter("curse_age", age)
		mat.set_shader_parameter("support_clock", shader_age)
		mat.set_shader_parameter("support_envelope", fade)
	if tick == int(settings.close):
		for particles in subject.find_children("*", "GPUParticles3D", true, false):
			particles.emitting = false
		for player in subject.find_children("*", "AnimationPlayer", true, false):
			for ending in ["close", "End"]:
				if player.has_animation(ending):
					player.play(ending)
					break

const VfxPackageIO_2e5d4e20e4 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
