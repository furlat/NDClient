extends Node3D
## Actual LeLu skeletal strand cage. Demo bodies are not part of this selection.
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")

var settings: Dictionary = {}
var trap: Node3D
var meshes: Array = []
var players: Array = []
var started: bool = false
var receiving_surface: Dictionary = {}
var source_bounds: AABB
var upper_webs: Array[MeshInstance3D] = []
var fitted_points: Array[Vector3] = []
var fitted_key: Array=[]
var fitted_origin:=Vector3.ZERO
var fitted_root:=Vector3.ZERO
var fitted_trap_position:=Vector3.ZERO

func set_entity_geometry(value: Dictionary) -> void:
	receiving_surface = value

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_d276426f4f.resource("res://assets/vfx/sources/d276426f4ff400d7c7ac/bound_web.gd").new()
	component.settings = input.duplicate(true)
	var scene: PackedScene = VfxPackageIO_d276426f4f.resource(input.scene)
	component.trap = scene.instantiate()
	ResourceGraph.isolate_node(component.trap, {})
	component.add_child(component.trap)
	var selected: StandardMaterial3D = VfxPackageIO_d276426f4f.resource(input.material).duplicate(true)
	selected.albedo_color = Color(.74, .83, .79, 1.0)
	selected.emission_energy_multiplier = .08
	for mesh in component.trap.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = selected.duplicate(true)
		component.meshes.append(mesh)
		var transform: Transform3D = mesh.transform
		var parent: Node3D = mesh.get_parent()
		while parent != component.trap:
			transform = parent.transform * transform
			parent = parent.get_parent()
		var bounds: AABB = transform * mesh.mesh.get_aabb()
		component.source_bounds = bounds if component.meshes.size() == 1 else component.source_bounds.merge(bounds)
	for player in component.trap.find_children("*", "AnimationPlayer", true, false):
		component.players.append(player)
	if input.has("upper_web_texture"):
		var shader := Shader.new()
		shader.code = "shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;uniform sampler2D source_web_mask:source_color,filter_linear_mipmap;uniform float silk_envelope=0.;void fragment(){vec4 silk=texture(source_web_mask,UV);float shade=.6+.3*abs(dot(normalize(NORMAL),normalize(vec3(-.4,.8,.6))));ALBEDO=vec3(.65,.74,.70)*shade;ALPHA=silk.a*silk_envelope*.8;}"
		for index in 4:
			var web := MeshInstance3D.new()
			web.name = "UpperBodySilkPatch" + str(index)
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("source_web_mask", VfxPackageIO_d276426f4f.resource(input.upper_web_texture))
			web.material_override = material
			web.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			component.add_child(web)
			component.upper_webs.append(web)
	return component

func sample(seconds: float) -> void:
	if not started:
		started = true
		for player in players:
			if player.has_animation("Init_loop"):
				player.play("Init_loop")
	var lifetime: float = float(settings.get("seconds", 4.6))
	var envelope: float = smoothstep(0.0, .45, seconds) * (1.0 - smoothstep(lifetime - .5, lifetime, seconds))
	for mesh in meshes:
		mesh.material_override.albedo_color.a = envelope
	for web in upper_webs:
		web.material_override.set_shader_parameter("silk_envelope", envelope)
	_fit_recipient()

func _fit_recipient() -> void:
	var points: Array = receiving_surface.get("points", [])
	if points.is_empty():
		return
	var pose: Array=preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(receiving_surface)
	var key: Array=[pose,global_basis]
	if not pose.is_empty() and key==fitted_key:
		var delta: Vector3=global_basis.inverse()*(receiving_surface.origin-fitted_origin-(global_position-fitted_root))
		trap.position=fitted_trap_position+delta
		for web in upper_webs:web.position=delta
		return
	fitted_key=key
	fitted_origin=receiving_surface.origin
	fitted_root=global_position
	for web in upper_webs:web.position=Vector3.ZERO
	var inverse := global_transform.affine_inverse()
	var ground: Vector3 = inverse * receiving_surface.origin
	var height := 0.0
	var radius := 0.0
	var local_points: Array[Vector3] = []
	for point in points:
		var local: Vector3 = inverse * point.position
		local_points.append(local)
		height = maxf(height, local.y - ground.y)
		radius = maxf(radius, Vector2(local.x - ground.x, local.z - ground.z).length())
	if local_points == fitted_points:
		return
	fitted_points = local_points
	var clearance: float = float(settings.get("clearance_cells", 0.04)) / absf(global_basis.get_scale().x)
	radius = maxf(radius, 0.15 / absf(global_basis.get_scale().x)) + clearance
	# The original trap is a ground-anchored lower-body mesh. Stretching its
	# radial skirt to head height made a curtain; upper silk is fitted separately.
	var dimensions := Vector3(radius * 1.45, height * 0.52 + clearance, radius * 1.45)
	trap.scale = dimensions / source_bounds.size
	trap.position = ground - Vector3(source_bounds.get_center().x, source_bounds.position.y, source_bounds.get_center().z) * trap.scale
	fitted_trap_position=trap.position
	# Measure principal horizontal axes, then each height's actual outline.
	# A circular radius around a flat reconstructed actor created detached wings.
	var average := Vector3.ZERO
	for point in local_points:
		average += point
	average /= float(local_points.size())
	var covariance_xx := 0.0
	var covariance_xz := 0.0
	var covariance_zz := 0.0
	for point in local_points:
		var relative: Vector3 = point - average
		covariance_xx += relative.x * relative.x
		covariance_xz += relative.x * relative.z
		covariance_zz += relative.z * relative.z
	var principal_angle: float = 0.5 * atan2(2.0 * covariance_xz, covariance_xx - covariance_zz)
	var major := Vector3(cos(principal_angle), 0.0, sin(principal_angle))
	var minor := Vector3(-major.z, 0.0, major.x)
	var rows: Array[Dictionary] = []
	for row in 9:
		var elevation: float = height * lerpf(0.15, 0.86, float(row) / 8.0)
		var minimum := Vector2(INF, INF)
		var maximum := Vector2(-INF, -INF)
		var nearest_height := INF
		for point in local_points:
			nearest_height = minf(nearest_height, absf(point.y - ground.y - elevation))
		var slice_band: float = maxf(height * 0.075, nearest_height + 0.0001)
		for point in local_points:
			if absf(point.y - ground.y - elevation) <= slice_band:
				var coordinate := Vector2(point.dot(major), point.dot(minor))
				minimum = minimum.min(coordinate)
				maximum = maximum.max(coordinate)
		assert(minimum.is_finite(), "Web recipient has an empty fitted height slice")
		var centre: Vector2 = (minimum + maximum) * 0.5
		var extents: Vector2 = (maximum - minimum) * 0.5 + Vector2.ONE * clearance
		rows.append({"centre": major * centre.x + minor * centre.y,
			"extents": extents.max(Vector2.ONE * clearance), "elevation": ground.y + elevation})
	for patch in upper_webs.size():
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for section in 16:
			for row in 8:
				for corner in [Vector2i(section, row), Vector2i(section + 1, row), Vector2i(section, row + 1), Vector2i(section + 1, row), Vector2i(section + 1, row + 1), Vector2i(section, row + 1)]:
					var uv := Vector2(float(corner.x) / 16.0, float(corner.y) / 8.0)
					var angle: float = (float(patch) + uv.x) * PI * 0.5
					var outline: Dictionary = rows[corner.y]
					var normal: Vector3 = major * cos(angle) + minor * sin(angle)
					builder.set_normal(normal)
					# One continuous interior source net wraps the whole silhouette;
					# four repeated full circular masks were visible as paired ovals.
					builder.set_uv(Vector2(0.2 + 0.6 * (float(patch) + uv.x) / 4.0, 0.2 + uv.y * 0.6))
					builder.add_vertex(outline.centre + major * cos(angle) * outline.extents.x
						+ minor * sin(angle) * outline.extents.y + Vector3.UP * outline.elevation)
		upper_webs[patch].mesh = builder.commit()

func capture_observation() -> Dictionary:
	return {"recipient_points": receiving_surface.get("points", []).size(),
		"upper_body_patches": upper_webs.size(),
		"source_bounds": [source_bounds.size.x, source_bounds.size.y, source_bounds.size.z],
		"fitted_scale": [trap.scale.x, trap.scale.y, trap.scale.z]}

const VfxPackageIO_d276426f4f = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
