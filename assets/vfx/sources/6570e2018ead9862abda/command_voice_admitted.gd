extends "res://assets/vfx/sources/048e2881b9068776f055/clocked_source.gd"
## Original LeLu anticipation-wave scene, aimed between current supplied face
## sockets. Native particle velocity determines travel, not a second projectile.
const Palette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
const ClipBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var endpoints: Array = []
var voice_materials: Array[ShaderMaterial] = []
var transport_ready: bool = false
var transport_restarts: int = 0


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/6570e2018ead9862abda/command_voice_admitted.gd", input)


func set_live_endpoints(value: Array) -> void:
	endpoints = value
	if prepared:
		_configure_transport()


func apply_scene_edits(node: Node) -> void:
	# Wave33's authored local half-turn points its velocity along source +Z.
	# Remove only the recorder's positional offset so it begins at the face.
	node.get_node("Wave33").position = Vector3.ZERO
	var wave: GPUParticles3D = node.get_node("Wave33")
	var process: ParticleProcessMaterial = wave.process_material.duplicate(true)
	wave.process_material = process
	_configure_transport()
	for light in node.find_children("*", "Light3D", true, false):
		light.visible = false
	for player in node.find_children("*", "AnimationPlayer", true, false):
		for name in player.get_animation_list():
			var animation: Animation = player.get_animation(name)
			for track in animation.get_track_count():
				if str(animation.track_get_path(track)).begins_with("OmniLight3D:"):
					animation.track_set_enabled(track, false)


func _configure_transport() -> void:
	if transport_ready or tick <= 0 or endpoints.size() < 2 or not is_instance_valid(subject):
		return
	var wave: GPUParticles3D = subject.get_node("Wave33")
	var process: ParticleProcessMaterial = wave.process_material
	var distance: float = endpoints[0].point.distance_to(endpoints[1].point)
	if distance <= .0001:
		return
	var velocity: float = distance/(float(settings.native_travel_seconds)*float(settings.radius_cells))
	process.initial_velocity_min = velocity
	process.initial_velocity_max = velocity
	var source_range: float = velocity*float(settings.native_travel_seconds)
	wave.visibility_aabb = AABB(Vector3(-4,-4,-source_range-4),Vector3(8,8,source_range+8))
	# Factory source construction samples zero before live face context exists.
	# Admit and seed the actual transport once the first valid endpoints arrive,
	# at its first advancing source tick, rather than binding an idle/windup pose.
	wave.restart()
	wave.emitting = true
	transport_restarts += 1
	transport_ready = true


func prepare_materials(node: Node) -> void:
	super.prepare_materials(node)
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		if child.material_override is ShaderMaterial:
			Palette.apply(child.material_override,settings.voice_palette,{"quantize":false,"energy_exposure":.65})
			var material: ShaderMaterial = child.material_override
			var shader := Shader.new()
			shader.code = material.shader.code.replace("shader_type spatial;", "shader_type spatial;\nuniform vec3 voice_start=vec3(0.0);\nuniform vec3 voice_finish=vec3(0.0,0.0,1.0);\n")
			shader.code = ClipBindings.finish_fragment(shader.code,"""
vec3 voice_world=INV_VIEW_MATRIX[3].xyz+mat3(INV_VIEW_MATRIX)*VERTEX;
vec3 voice_axis=voice_finish-voice_start;
float voice_length=length(voice_axis);
float voice_along=dot(voice_world-voice_start,voice_axis/max(.0001,voice_length));
ALPHA*=smoothstep(-.025,.025,voice_along)*(1.-smoothstep(voice_length-.06,voice_length+.015,voice_along));
""")
			ClipBindings.replace_shader(material,shader)
			voice_materials.append(material)


func update_geometry() -> void:
	_configure_transport()
	if endpoints.size() < 2 or not subject.is_inside_tree():
		return
	var start: Vector3 = endpoints[0].point
	var direction: Vector3 = endpoints[1].point-start
	if direction.length_squared() < .000001:
		subject.visible = false
		return
	subject.visible = true
	var up := Vector3.UP if absf(direction.normalized().y) < .99 else Vector3.RIGHT
	var radius: float = settings.radius_cells
	var basis := Basis.looking_at(-direction.normalized(),up)*Basis.from_scale(Vector3.ONE*radius)
	subject.global_transform = Transform3D(basis,start)
	for material in voice_materials:
		material.set_shader_parameter("voice_start",start)
		material.set_shader_parameter("voice_finish",endpoints[1].point)


func capture_observation() -> Dictionary:
	return {"transport_ready":transport_ready,"transport_restarts":transport_restarts,
		"native_velocity":subject.get_node("Wave33").process_material.initial_velocity_min if prepared else null,
		"face_endpoints":endpoints,"native_travel_seconds":settings.native_travel_seconds,
		"source_layers_removed":false,"nonuniform_scene_scale":false}
