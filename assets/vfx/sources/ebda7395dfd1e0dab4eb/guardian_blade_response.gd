extends "res://assets/vfx/sources/0ec5574c2ad8d38dec6c/guardian_source_colour.gd"
## Finite source-family blade trail and magical recipient continuation.
## Original source mesh/rig/shaders/pose sampling remain inherited unchanged.
var response_data: Dictionary
var response_mesh: MeshInstance3D
var response_material: StandardMaterial3D
var blade_bone: int = -1
var response_age: float = 0.0
var history: Dictionary = {}
var response_observation: Dictionary = {"visible": false}


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = construct("res://assets/vfx/sources/ebda7395dfd1e0dab4eb/guardian_blade_response.gd", input)
	instance.name = "effect"
	return instance


func build() -> void:
	super.build()
	assert(settings.has("blade_response") and settings.blade_response is Dictionary)
	response_data = settings.blade_response.duplicate(true)
	assert(response_data.palette.size() == 3 and response_data.native_blend == "add")
	assert(int(response_data.contact_source_tick) == 348)
	var attachment := sword.get_parent() as BoneAttachment3D
	assert(attachment != null and attachment.get_parent() == skeleton and sword.skin == null)
	blade_bone = skeleton.find_bone(attachment.bone_name)
	assert(blade_bone >= 0)
	response_material = StandardMaterial3D.new()
	response_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	response_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	response_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	response_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	response_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	response_material.vertex_color_use_as_albedo = true
	response_material.vertex_color_is_srgb = true
	response_material.render_priority = 1
	response_mesh = MeshInstance3D.new()
	response_mesh.name = "OriginalBladeResponse"
	response_mesh.material_override = response_material
	response_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	response_mesh.visible = false
	add_child(response_mesh)


func sample(seconds: float) -> void:
	super.sample(seconds)
	response_age = seconds
	# NativeSource advances its collected player after this sample. Read the final
	# bone state in the deferred phase, without advancing or modifying that pose.
	_refresh_response.call_deferred()


func actual_blade() -> Dictionary:
	# BoneAttachment synchronization is deferred. Compose its actual current bone
	# transform directly; this observes the rig without changing any source node.
	var transform: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(blade_bone) * sword.transform
	var box: AABB = sword.get_aabb()
	return {"grip": transform * Vector3.ZERO,
		"tip": transform * Vector3(box.position.x + box.size.x * 0.5, box.end.y, box.position.z + box.size.z * 0.5)}


func add_triangle(surface: SurfaceTool, first: Vector3, second: Vector3, third: Vector3, colour: Color) -> void:
	for point in [first, second, third]:
		surface.set_color(colour)
		surface.add_vertex(to_local(point))


func add_quad(surface: SurfaceTool, points: Array, colour: Color) -> void:
	add_triangle(surface, points[0], points[1], points[2], colour)
	add_triangle(surface, points[0], points[2], points[3], colour)


func add_line(surface: SurfaceTool, first: Vector3, second: Vector3, width: float, colour: Color, camera: Camera3D) -> void:
	var direction: Vector3 = second - first
	if direction.length_squared() < 0.0000000001:
		return
	var across: Vector3 = direction.cross(camera.global_basis.z).normalized()
	if across.is_zero_approx():
		across = camera.global_basis.x
	across *= width * 0.5
	add_quad(surface, [first - across, first + across, second + across, second - across], colour)


func source_colour(index: int, alpha: float) -> Color:
	var colour := Color(str(response_data.palette[index]))
	colour.a = clampf(alpha * visor_opacity, 0.0, 1.0)
	return colour


func _refresh_response() -> void:
	if not is_instance_valid(response_mesh) or live_endpoints.size() < 2:
		return
	var source_frame: int = maxi(0, floori(float(tick - 1) * 32.0 / float(parameters.simulation_hz)))
	var strike_frame: int = source_frame - 64
	var blade: Dictionary = actual_blade()
	if strike_frame >= 0 and strike_frame < 32:
		history[strike_frame] = blade
	var first: int = int(response_data.first_trail_frame)
	var last: int = int(response_data.last_trail_frame)
	response_mesh.visible = false
	response_observation = {"visible": false, "strike_frame": strike_frame, "native_tick": tick,
		"actual_tip": [blade.tip.x, blade.tip.y, blade.tip.z], "actual_grip": [blade.grip.x, blade.grip.y, blade.grip.z],
		"historical_blend": "screen", "native_blend": "add", "physical_collision_claimed": false}
	if strike_frame < first or strike_frame > last or visor_opacity <= 0.0:
		return
	var camera := get_viewport().get_camera_3d()
	assert(camera != null, "Blade response requires the existing host camera for ribbon width")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var taper: float = 1.0 - smoothstep(float(response_data.taper_begin_frame), float(response_data.taper_end_frame), float(strike_frame))
	var trail_quads: int = 0
	for back in range(3, -1, -1):
		var index: int = maxi(0, strike_frame - back)
		if not history.has(index) or not history.has(maxi(0, index - 1)):
			continue
		var current: Dictionary = history[index]
		var previous: Dictionary = history[maxi(0, index - 1)]
		var inner: Vector3 = current.grip.lerp(current.tip, 0.8)
		var old_inner: Vector3 = previous.grip.lerp(previous.tip, 0.8)
		var strength: float = 1.0 - float(back) / 4.0
		add_quad(surface, [inner, current.tip, previous.tip, old_inner], source_colour(0, strength * 0.16 * taper))
		add_line(surface, previous.tip, current.tip, float(response_data.stroke_width_cells), source_colour(1, strength * 0.6 * taper), camera)
		trail_quads += 1
	var contact_age: float = response_age - float(response_data.contact_source_tick) / float(parameters.simulation_hz)
	var continuation_alpha: float = smoothstep(-0.07, 0.0, contact_age) * (1.0 - smoothstep(0.04, 0.20, contact_age))
	var segments: int = 0
	var target: Vector3 = live_endpoints[1].point
	if continuation_alpha > 0.0:
		# The native continuation attaches to the current measured blade tip and
		# actual recipient body endpoint; it is explicitly magical, never a hit test.
		var control: Vector3 = blade.tip.lerp(target, 0.5) + Vector3.UP * float(response_data.continuation_bend_cells)
		var previous: Vector3 = blade.tip
		for index in range(1, 17):
			var progress: float = float(index) / 16.0
			var point: Vector3 = blade.tip.lerp(control, progress).lerp(control.lerp(target, progress), progress)
			add_line(surface, previous, point, float(response_data.continuation_width_cells), source_colour(2, continuation_alpha * 0.85), camera)
			previous = point
			segments += 1
	if trail_quads == 0 and segments == 0:
		return
	response_mesh.mesh = surface.commit()
	response_mesh.visible = trail_quads > 0 or segments > 0
	response_observation.merge({"visible": response_mesh.visible, "trail_quads": trail_quads,
		"continuation_segments": segments, "continuation_alpha": continuation_alpha * visor_opacity,
		"target_endpoint": [target.x, target.y, target.z], "contact_source_tick": int(response_data.contact_source_tick),
		"actual_tip_to_endpoint_distance_cells": blade.tip.distance_to(target), "source_occurrence_alpha": visor_opacity}, true)


func capture_observation() -> Dictionary:
	var observation: Dictionary = super.capture_observation()
	observation["blade_response"] = response_observation.duplicate(true)
	return observation
