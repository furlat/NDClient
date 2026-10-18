extends "res://assets/vfx/sources/9e01bea27ad66740b60c/blast.gd"
## Actual LeLu flame, pressure flash, debris, trails and cooling smoke.
## The base owns exact committed-event admission; this node never resolves damage.
const DonorScene = preload("res://assets/vfx/sources/7fb2e55699a318c2dafb/donor_scene.gd")
const EXPLOSION_SCENE = "res://assets/vfx/sources/56f917740581a192e0eb/VFX_FirExplosion.tscn"
const CANONICAL_SCENE = "res://assets/vfx/sources/ab72dd57ae0aecf3c0a5/fire_explosion_native.tscn"
var explosion: Node3D
var explosion_materials: Array[ShaderMaterial] = []


static func make_component(input: Dictionary) -> Node3D:
	assert(input.kind == "delayed_fire")
	assert(not str(input.get("source_owner_uuid", "")).is_empty())
	assert(not str(input.get("original_caster_uuid", "")).is_empty())
	var node: Node3D = VfxPackageIO_138cd535f8.resource("res://assets/vfx/sources/138cd535f8be5f7a7ac8/fire_explosion.gd").new()
	node.specification = input.duplicate(true)
	node.set_blast_event(input.get("event", {}))
	node.prepare()
	return node


func set_blast_event(value: Dictionary) -> bool:
	var admitted: bool = super.set_blast_event(value)
	if explosion == null:
		return admitted
	explosion.hide()
	if not admitted or event.is_empty():
		return admitted
	for adapted in explosion_materials:
		Footprint.set_cells(adapted, event.admitted_cells)
	for emitter in explosion.find_children("*", "GPUParticles3D", true, false):
		emitter.emitting = false
		emitter.restart()
	var player: AnimationPlayer = explosion.get_node("AnimationPlayer")
	player.stop()
	player.play("Init")
	player.advance(0.0)
	return admitted


func prepare() -> void:
	if explosion != null:
		return
	explosion = DonorScene.instantiate(VfxPackageIO_138cd535f8.resource(CANONICAL_SCENE), [])
	Native.Graph.native_sampler_scopes += 1
	Native.Graph.isolate_node(explosion, {})
	Native.Graph.native_sampler_scopes -= 1
	add_child(explosion)
	explosion.top_level = true
	# Exclude the source demo's persistent decal and optical light, explicitly.
	# The copied animations must not retain tracks pointing at removed nodes.
	var player: AnimationPlayer = explosion.get_node("AnimationPlayer")
	for animation_name in player.get_animation_list():
		var animation: Animation = player.get_animation(animation_name)
		for track_index in range(animation.get_track_count() - 1, -1, -1):
			var path: String = str(animation.track_get_path(track_index))
			if path.begins_with("Decal:") or path.begins_with("OmniLight3D34:"):
				animation.remove_track(track_index)
	for excluded_name in ["Decal", "OmniLight3D34"]:
		var excluded: Node = explosion.get_node(excluded_name)
		explosion.remove_child(excluded)
		excluded.free()
	var cells: Array = event.get("admitted_cells", specification.get("admitted_cells", []))
	for index in explosion.get_child_count():
		var emitter: Node = explosion.get_child(index)
		if not emitter is GPUParticles3D:
			continue
		emitter.use_fixed_seed = true
		emitter.seed = 17381 + index
		emitter.fixed_fps = 144
		emitter.local_coords = true
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var adapted: ShaderMaterial
		if emitter.material_override is StandardMaterial3D:
			adapted = debris_material(emitter.material_override)
		else:
			adapted = Native.finite(emitter.material_override, .45)
			var code: String = Native.Source.scaled_billboard(adapted.shader.code).replace("depth_draw_opaque", "depth_draw_never")
			code = code.replace("ALPHA_SCISSOR_THRESHOLD = n_out33p4;", "ALPHA*=smoothstep(n_out33p4,n_out33p4+.07,ALPHA);")
			if emitter.name == "smokeball":
				# Same fire family as the retained bead: source Fireball temperature
				# ramps on this donor's actual puff geometry and native noise/age.
				code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform sampler2D fireball_dark:source_color;\nuniform sampler2D fireball_hot:source_color;\n")
				code = Native.Source.finish_fragment(code, "\nfloat heat=clamp(COLOR.r*0.9+n_out9p1*0.28,0.0,1.0);ALBEDO=texture(fireball_dark,vec2(heat)).rgb*0.4;EMISSION=texture(fireball_hot,vec2(heat)).rgb*0.12;\n")
				var fireball_source: ShaderMaterial = VfxPackageIO_138cd535f8.resource(Native.FIRE).material
				adapted.set_shader_parameter("fireball_dark", fireball_source.get_shader_parameter("Dark_Color_Gradient_1D"))
				adapted.set_shader_parameter("fireball_hot", fireball_source.get_shader_parameter("Emission_Gradient_1D"))
			if emitter.name == "VFX_StylizedSmoke_ring4":
				# The demo's custom light ignores ALBEDO and attenuation. Under
				# the character stage that becomes an unshaded orange plate.
				code = code.replace("DIFFUSE_LIGHT = clamp(LIGHT_COLOR * vec3(color_1D_gradient.xyz), vec3(0), vec3(1));", "DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * color_1D_gradient.rgb * ATTENUATION * 0.35;")
				code = Native.Source.finish_fragment(code, "\nALBEDO*=0.18;\n")
			if emitter.name == "muzzle":
				code = Native.Source.finish_fragment(code, "\nALPHA*=0.18;\n")
			var shader := Shader.new()
			shader.code = code
			Native.Source.replace_shader(adapted, shader)
		Footprint.bind(adapted, cells)
		var clipped_shader := Shader.new()
		clipped_shader.code = adapted.shader.code.replace("MODEL_MATRIX*vec4(VERTEX,1.0)", "(INV_VIEW_MATRIX*MODELVIEW_MATRIX)*vec4(VERTEX,1.0)")
		Native.Source.replace_shader(adapted, clipped_shader)
		emitter.material_override = adapted
		explosion_materials.append(adapted)
	player.play("Init")
	player.advance(0.0)
	explosion.hide()


func debris_material(source: StandardMaterial3D) -> ShaderMaterial:
	var shader := Shader.new()
	var trail_mode: String = ",particle_trails" if source.use_particle_trails else ""
	shader.code = """shader_type spatial;
render_mode blend_mix,unshaded,cull_disabled,depth_draw_never%s;
uniform sampler2D native_texture:source_color;
uniform bool has_texture=false;
uniform vec4 native_tint:source_color=vec4(1.0);
uniform float payload_seconds=0.0;
uniform float payload_alpha=0.0;
void fragment(){
 vec4 source=COLOR*native_tint;
 if(has_texture){source*=texture(native_texture,UV);}
 ALBEDO=source.rgb;
 ALPHA=source.a*payload_alpha;
}
""" % trail_mode
	var result := ShaderMaterial.new()
	result.shader = shader
	result.set_shader_parameter("has_texture", source.albedo_texture != null)
	result.set_shader_parameter("native_texture", source.albedo_texture)
	result.set_shader_parameter("native_tint", source.albedo_color)
	return result


func sample(seconds: float) -> void:
	explosion.hide()
	if event.is_empty() or endpoints.is_empty():
		return
	last_origin = endpoints[0].point
	explosion.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * .8), last_origin)
	var alpha: float = smoothstep(0.0, .015, seconds) * (1.0 - smoothstep(1.15, 1.8, seconds))
	for adapted in explosion_materials:
		Native.clock(adapted, seconds, alpha)
		Footprint.move(adapted, last_origin)
	explosion.visible = alpha > .001


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result["source_scene"] = EXPLOSION_SCENE
	result["native_emitter_layers"] = 5
	result["excluded_demo_layers"] = ["Decal", "OmniLight3D"]
	result["seek_qualified"] = false
	return result

const VfxPackageIO_138cd535f8 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
