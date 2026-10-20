extends "res://assets/vfx/extensions/late-20261020/sources/9e01bea27ad66740b60c/blast.gd"
## The complete inspected LeLu AcidExplosion source replaces the twelve cups.
## Inherited admission still owns committed-event identity, suppression and cells.
const DonorScene = preload("res://assets/vfx/sources/7fb2e55699a318c2dafb/donor_scene.gd")
const ACID_SCENE = "res://assets/vfx/extensions/late-20261020/sources/5801308b5f88d6edd316/VFX_AcidExplosion_Big.tscn"
var splash: Node3D
var splash_materials: Array[ShaderMaterial] = []


static func make_component(input: Dictionary) -> Node3D:
	assert(input.kind == "acid")
	assert(not str(input.get("source_owner_uuid", "")).is_empty())
	assert(not str(input.get("original_caster_uuid", "")).is_empty())
	var node: Node3D = VfxPackageIO_2dae5063c4.resource("res://assets/vfx/extensions/late-20261020/sources/2dae5063c4170b477276/acid_explosion.gd").new()
	node.specification = input.duplicate(true)
	node.set_blast_event(input.get("event", {}))
	node.prepare()
	return node


func set_blast_event(value: Dictionary) -> bool:
	var admitted: bool = super.set_blast_event(value)
	if splash == null:
		return admitted
	splash.hide()
	if not admitted or event.is_empty():
		return admitted
	apply_footprint_cells(splash_materials, event.admitted_cells)
	for emitter in splash.find_children("*", "GPUParticles3D", true, false):
		emitter.emitting = false
		emitter.restart()
	var player: AnimationPlayer = splash.get_node("AnimationPlayer")
	player.stop()
	player.play("Init")
	player.advance(0.0)
	return admitted


func prepare() -> void:
	if splash != null:
		return
	splash = DonorScene.instantiate(VfxPackageIO_2dae5063c4.resource(ACID_SCENE), [])
	Native.Graph.native_sampler_scopes += 1
	Native.Graph.isolate_node(splash, {})
	Native.Graph.native_sampler_scopes -= 1
	add_child(splash)
	splash.top_level = true
	var cells: Array = event.get("admitted_cells", specification.get("admitted_cells", []))
	for index in splash.get_child_count():
		var emitter: Node = splash.get_child(index)
		if not emitter is GPUParticles3D:
			continue
		emitter.use_fixed_seed = true
		emitter.seed = 8273 + index
		emitter.fixed_fps = 144
		emitter.local_coords = true
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if emitter.name == "spheres":
			# The donor's 2–4x growing spheres become a tall opaque globe at
			# character scale. Keep these as actual ballistic liquid globules;
			# the native crown, mist, bubbles and splatter carry the main blast.
			var process: ParticleProcessMaterial = emitter.process_material
			process.scale_min *= .26
			process.scale_max *= .26
			process.directional_velocity_min = 0.0
			process.directional_velocity_max = 0.0
			process.initial_velocity_min = 2.5
			process.initial_velocity_max = 4.0
			process.spread = 65.0
			process.gravity = Vector3(0, -6, 0)
		var adapted: ShaderMaterial
		if emitter.material_override is StandardMaterial3D:
			adapted = smoke_material(emitter.material_override)
		else:
			adapted = Native.finite(emitter.material_override, .7)
		Footprint.bind(adapted, cells)
		# Particle billboards change MODELVIEW_MATRIX. Measure that rendered
		# geometry for footprint clipping rather than the pre-billboard quad.
		var shader := Shader.new()
		shader.code = adapted.shader.code.replace("MODEL_MATRIX*vec4(VERTEX,1.0)", "(INV_VIEW_MATRIX*MODELVIEW_MATRIX)*vec4(VERTEX,1.0)")
		shader.code = shader.code.replace("depth_draw_opaque", "depth_draw_never")
		# Retain the source particle-age dissolve threshold, with a finite
		# coverage band rather than unstable binary holes across the liquid.
		shader.code = shader.code.replace("ALPHA_SCISSOR_THRESHOLD = n_out4p4;", "ALPHA*=smoothstep(n_out4p4,n_out4p4+.09,n_out10p1);")
		shader.code = Native.Source.finish_fragment(shader.code, "\nEMISSION+=ALBEDO*.24;\n")
		if emitter.name in ["mist", "VFX_Smoke_B_green"]:
			shader.code = Native.Source.finish_fragment(shader.code, "\nALPHA*=.25;\n")
		Native.Source.replace_shader(adapted, shader)
		emitter.material_override = adapted
		splash_materials.append(adapted)
	var player: AnimationPlayer = splash.get_node("AnimationPlayer")
	player.play("Init")
	player.advance(0.0)
	splash.hide()


func smoke_material(source: StandardMaterial3D) -> ShaderMaterial:
	# Preserve this source's actual 8x8 atlas and per-particle rotation. The
	# older four-frame helper would address the wrong smoke frames here.
	assert(source.particles_anim_h_frames == 8 and source.particles_anim_v_frames == 8)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D source_tex:source_color;
uniform vec4 source_tint:source_color=vec4(1.0);
uniform float payload_seconds=0.0;
uniform float payload_alpha=0.0;
varying float smoke_frame;
void vertex(){
 float angle=INSTANCE_CUSTOM.x;
 vec3 right=INV_VIEW_MATRIX[0].xyz*cos(angle)+INV_VIEW_MATRIX[1].xyz*sin(angle);
 vec3 up=-INV_VIEW_MATRIX[0].xyz*sin(angle)+INV_VIEW_MATRIX[1].xyz*cos(angle);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(right*length(MODEL_MATRIX[0].xyz),0.0),vec4(up*length(MODEL_MATRIX[1].xyz),0.0),vec4(INV_VIEW_MATRIX[2].xyz*length(MODEL_MATRIX[2].xyz),0.0),MODEL_MATRIX[3]);
 smoke_frame=clamp(floor(INSTANCE_CUSTOM.z*64.0),0.0,63.0);
}
void fragment(){
 vec2 atlas_uv=(UV+vec2(mod(smoke_frame,8.0),floor(smoke_frame/8.0)))/8.0;
 vec4 colour=texture(source_tex,atlas_uv)*source_tint*COLOR;
 ALBEDO=colour.rgb*.7;
 ALPHA=colour.a*payload_alpha;
}
"""
	var result := ShaderMaterial.new()
	result.shader = shader
	result.set_shader_parameter("source_tex", source.albedo_texture)
	result.set_shader_parameter("source_tint", source.albedo_color)
	return result


func sample(seconds: float) -> void:
	splash.hide()
	if event.is_empty() or endpoints.is_empty():
		return
	last_origin = endpoints[0].point
	splash.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * .65), last_origin)
	var alpha: float = smoothstep(0.0, .025, seconds) * (1.0 - smoothstep(.7, 1.5, seconds))
	for adapted in splash_materials:
		Native.clock(adapted, seconds, alpha)
		Footprint.move(adapted, last_origin)
	splash.visible = alpha > .001


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result["source_scene"] = ACID_SCENE
	result["native_emitter_layers"] = 6
	result["persistent_acid_pool"] = false
	result["seek_qualified"] = false
	return result

const VfxPackageIO_2dae5063c4 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
