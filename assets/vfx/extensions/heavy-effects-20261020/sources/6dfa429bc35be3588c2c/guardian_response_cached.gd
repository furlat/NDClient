extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/8c0f7de15cd6d11e943d/guardian_blade_arc_trail.gd"
## Private bounded memoization of pure solutions for actual observed links.
## Source history, live fade/UV/colour/camera and node conversion stay inherited.
const ResponseArrays = preload("res://assets/vfx/extensions/heavy-effects-20261020/sources/0399d82fceb8d3cab78c/guardian_response_buffer_data.gd")
var response_arrays := ResponseArrays.new()
var private_response_mesh: ArrayMesh
var interval_solutions: Dictionary = {}
var interval_controls: Array = []
var interval_hits := 0
var interval_misses := 0
var response_camera_basis := Basis.IDENTITY


func build_intermediate_response_surface() -> bool:
	return false


func _observe_requested_age(seconds: float) -> void:
	var epoch_before := history_epoch
	super._observe_requested_age(seconds)
	if history_epoch != epoch_before:
		interval_solutions.clear()
		interval_controls.clear()


func _refresh_response() -> void:
	if live_endpoints.size() < 2 or visor_opacity <= 0.0:
		interval_solutions.clear()
		interval_controls.clear()
	super._refresh_response()
	if not arc_observation.get("visible", false):
		interval_solutions.clear()
		interval_controls.clear()


func response_interval(first: Dictionary, last: Dictionary, old_tick: int, new_tick: int) -> Dictionary:
	var controls: Array = [history_epoch, float(arc_profile.max_segment_degrees)]
	if controls != interval_controls:
		interval_solutions.clear()
		interval_controls = controls
	var key: Array = [old_tick, new_tick, first.grip, first.tip, last.grip, last.tip]
	if interval_solutions.has(key):
		interval_hits += 1
		return interval_solutions[key]
	var solution: Dictionary = super.response_interval(first, last, old_tick, new_tick)
	interval_solutions[key] = solution
	interval_misses += 1
	var capacity := maxi(2, int(history_observation.get("window_ticks", 0)) + 2)
	while interval_solutions.size() > capacity:
		interval_solutions.erase(interval_solutions.keys().front())
	return solution


func begin_response_surface() -> SurfaceTool:
	response_arrays.begin(global_transform.affine_inverse())
	response_camera_basis = get_viewport().get_camera_3d().global_basis
	return null


func emit_quad(_surface: SurfaceTool, points: Array, colour: Color, first_age: float, last_age: float) -> void:
	response_arrays.emit_quad(points, colour, first_age, last_age)


func emit_line(surface: SurfaceTool, first: Vector3, last: Vector3, width: float, colour: Color, _camera: Camera3D, first_age: float, last_age: float) -> void:
	var direction: Vector3 = last - first
	if direction.length_squared() < 0.0000000001:
		return
	var across: Vector3 = direction.cross(response_camera_basis.z).normalized()
	if across.is_zero_approx():
		across = response_camera_basis.x
	across *= width * 0.5
	emit_quad(surface, [first - across, first + across, last + across, last - across], colour, first_age, last_age)


func commit_response_surface(surface: SurfaceTool) -> ArrayMesh:
	assert(surface == null)
	if private_response_mesh == null:
		private_response_mesh = ArrayMesh.new()
	else:
		private_response_mesh.clear_surfaces()
	private_response_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, response_arrays.source_arrays())
	return private_response_mesh
