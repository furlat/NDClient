extends Node3D
## Actual native VFX geometry fitted to measured actor surfaces / weapon layers.
## The host supplies geometry data; this component never loads actors or cameras.
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const Values = preload("res://assets/vfx/sources/601eb8db9c55b6ad084e/shader_material.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")

var settings: Dictionary = {}
var surface: Dictionary = {}
var effect: MeshInstance3D
var material: ShaderMaterial
var local_clock: float = 0.0
var last_pose: Array = []
var donor_bounds: AABB
var blade_orbit: GPUParticles3D
var fitted_key: Array=[]
var fitted_origin:=Vector3.ZERO
var fitted_root:=Vector3.ZERO
var cached_orbit_position:=Vector3.ZERO
var geometry_builds:=0

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_8c70ca642f.resource("res://assets/vfx/sources/8c70ca642faba181b8dd/fitted_native_field.gd").new()
	component.settings = input.duplicate(true)
	var source: Node3D
	var selected: MeshInstance3D
	var original: Material
	if input.has("material_resource"):
		original = VfxPackageIO_8c70ca642f.resource(input.material_resource)
	else:
		var scene: PackedScene = VfxPackageIO_8c70ca642f.resource(input.material_scene)
		source = scene.instantiate()
		ResourceGraph.isolate_node(source, {})
		selected = source.get_node(input.material_node)
		original = selected.get(input.get("material_property", "material_override"))
	if not original is ShaderMaterial:
		push_error("Fitted native field requires its selected donor ShaderMaterial.")
		if source != null:
			source.free()
		component.free()
		return null
	component.material = original.duplicate(true)
	var shader := Shader.new()
	shader.code = original.shader.code.replace("TIME", "entity_clock").replace("shader_type spatial;",
		"shader_type spatial;\nuniform float entity_clock=0.0;\nuniform float entity_envelope=1.0;")
	shader.code = shader.code.insert(shader.code.rfind("}"), "\nALPHA*=entity_envelope*"+str(float(input.get("alpha_factor",1.0)))+";\n")
	# Preserve source default samplers when replacing a VisualShader with code.
	for uniform in original.shader.get_shader_uniform_list():
		if int(uniform.type) == TYPE_OBJECT and original.get_shader_parameter(uniform.name) == null:
			var texture: Texture2D = original.shader.get_default_texture_parameter(uniform.name)
			if texture != null:
				component.material.set_shader_parameter(uniform.name, texture)
	SourceMaterials.replace_shader(component.material,shader)
	var known_uniforms: Dictionary = {}
	var declarations := RegEx.new()
	declarations.compile("uniform\\s+(?:(?:lowp|mediump|highp)\\s+)?\\w+\\s+(\\w+)")
	for uniform in declarations.search_all(shader.code):
		known_uniforms[uniform.get_string(1)] = true
	for uniform in input.get("uniforms", {}):
		if not known_uniforms.has(uniform):
			push_error("Fitted native field selected an absent donor uniform: " + uniform)
			if source != null:
				source.free()
			component.free()
			return null
	for uniform in input.get("gradient_palettes", {}):
		var original_gradient: GradientTexture1D = component.material.get_shader_parameter(uniform)
		if original_gradient == null:
			push_error("Selected gradient palette requires its donor GradientTexture1D: " + uniform)
			component.free()
			return null
		var recoloured: GradientTexture1D = original_gradient.duplicate(true)
		var palette := Gradient.new()
		var colours := PackedColorArray()
		for html in input.gradient_palettes[uniform]:
			colours.append(Color.html(html))
		palette.colors = colours
		var offsets := PackedFloat32Array()
		for index in colours.size():
			offsets.append(float(index) / maxf(1.0, colours.size() - 1))
		palette.offsets = offsets
		for index in recoloured.gradient.get_point_count():
			var original_colour: Color = recoloured.gradient.get_color(index)
			var replacement: Color = palette.sample(float(index) / maxf(1.0, recoloured.gradient.get_point_count() - 1))
			replacement.a = original_colour.a
			recoloured.gradient.set_color(index, replacement)
		component.material.set_shader_parameter(uniform, recoloured)
	for uniform in input.get("uniforms", {}):
		component.material.set_shader_parameter(uniform, Values.uniform_value(input.uniforms[uniform]))
	component.effect = MeshInstance3D.new()
	if input.get("shape", "orbits") == "donor_shell":
		component.effect.mesh = selected.mesh.duplicate(true)
		component.donor_bounds = selected.mesh.get_aabb()
	else:
		component.effect.mesh = ArrayMesh.new()
	component.effect.material_override = component.material
	component.effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	component.add_child(component.effect)
	if input.has("weapon_orbit_scene"):
		var orbit_scene: PackedScene = VfxPackageIO_8c70ca642f.resource(input.weapon_orbit_scene)
		component.blade_orbit = orbit_scene.instantiate()
		ResourceGraph.isolate_node(component.blade_orbit, {})
		component.blade_orbit.use_fixed_seed = true
		component.blade_orbit.seed = 47291
		var orbit_material: StandardMaterial3D = component.blade_orbit.material_override
		var image: Image = orbit_material.albedo_texture.get_image()
		# Reuse this donor as an alpha-bearing energy ribbon, with a deliberately
		# separate astral colour. Preserve its original trail/UV/particle behaviour.
		for y in image.get_height():
			for x in image.get_width():
				var pixel: Color = image.get_pixel(x, y)
				image.set_pixel(x, y, Color(1, 1, 1, pixel.a * maxf(pixel.r, maxf(pixel.g, pixel.b))))
		orbit_material.albedo_texture = ImageTexture.create_from_image(image)
		orbit_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		component.blade_orbit.process_material.color = Color(.10, .34, .75, .6)
		component.add_child(component.blade_orbit)
	if source != null:
		source.free()
	return component

func set_entity_geometry(value: Dictionary) -> void:
	surface = value

func capture_observation() -> Dictionary:
	return {"geometry_fit":{"points":surface.get("points",[]).size(),"visible":effect.visible,
		"layers":effect.layers,"mode":settings.get("shape"),"mesh_surfaces":effect.mesh.get_surface_count(),
		"fitted_length_cells":get_meta("measured_blade_length_cells",0.0)}}

func sample(seconds: float) -> void:
	local_clock = seconds
	material.set_shader_parameter("entity_clock", seconds)
	var lifetime: float = float(settings.get("seconds", 4.8))
	var envelope: float = smoothstep(0.0, .3, seconds) * (1.0 - smoothstep(lifetime - .5, lifetime, seconds))
	material.set_shader_parameter("entity_envelope", envelope)
	for uniform in settings.get("uniform_oscillations", {}):
		var wave: Dictionary = settings.uniform_oscillations[uniform]
		material.set_shader_parameter(uniform, float(wave.centre) + float(wave.amplitude) * sin(seconds * TAU * float(wave.hz)))
	if blade_orbit != null:
		blade_orbit.emitting = envelope > .05
	if surface.get("points", []).is_empty():
		effect.hide()
		return
	effect.show()
	if settings.get("shape", "orbits") == "weapon_surface":
		_weapon_mesh()
	elif settings.get("shape", "orbits") == "donor_shell":
		_donor_shell()
	else:
		_orbits()

func _donor_shell() -> void:
	var centre: Vector3 = surface.origin
	var height: float = 0.0
	var radius: float = .22
	for point in surface.points:
		height = maxf(height, point.position.y - centre.y)
		if point.position.y - centre.y > .2:
			radius = maxf(radius, Vector2(point.position.x - centre.x, point.position.z - centre.z).length())
	radius = minf(radius, .45) + float(settings.get("clearance_cells", .06))
	var dimensions := Vector3(radius * 2.0, height * float(settings.get("height_fraction", 1.0)), radius * 2.0)
	var scale_values := dimensions / donor_bounds.size
	var rotation := Basis(Vector3.UP, local_clock * float(settings.get("rotation_radians_per_second", 0.0)))
	effect.basis = rotation.scaled(scale_values)
	effect.position = global_transform.affine_inverse() * (centre + Vector3.UP * height * .5)
	effect.position -= effect.basis * donor_bounds.get_center()
	set_meta("fit_points", surface.points.size())

func _weapon_mesh() -> void:
	var pose: Array=preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(surface)
	var key: Array=[pose,global_basis]
	if not pose.is_empty() and key==fitted_key:
		var delta: Vector3=global_basis.inverse()*(surface.origin-fitted_origin-(global_position-fitted_root))
		effect.position=delta
		if blade_orbit!=null:blade_orbit.position=cached_orbit_position+delta
		return
	fitted_key=key
	fitted_origin=surface.origin
	fitted_root=global_position
	effect.position=Vector3.ZERO
	geometry_builds+=1
	# Fit a continuous closed blade shell, not disconnected pixel-sized facets.
	# The displayed weapon packet owns axis/length; the donor owns its material.
	var centre := Vector3.ZERO
	for point in surface.points:
		centre += point.position
	centre /= float(surface.points.size())
	var axis := Vector3.UP
	for iteration in 12:
		var next := Vector3.ZERO
		for point in surface.points:
			var offset: Vector3 = point.position - centre
			next += offset * offset.dot(axis)
		if next.length_squared() > .000001:
			axis = next.normalized()
	var low: float = INF
	var high: float = -INF
	for point in surface.points:
		var projection: float = (point.position - centre).dot(axis)
		low = minf(low, projection)
		high = maxf(high, projection)
	var first: Vector3 = centre + axis * low
	var last: Vector3 = centre + axis * high
	var side: Vector3 = axis.cross(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = axis.cross(Vector3.RIGHT).normalized()
	var across: Vector3 = axis.cross(side).normalized()
	if blade_orbit != null:
		blade_orbit.position = global_transform.affine_inverse() * first
		cached_orbit_position=blade_orbit.position
		blade_orbit.basis = global_basis.inverse() * Basis(side, axis, side.cross(axis))
		blade_orbit.scale = Vector3.ONE * clampf(first.distance_to(last) / .5, .5, 1.5)
	var inverse := global_transform.affine_inverse()
	var radius: float = float(settings.get("clearance_cells", .018)) + .012
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for length_step in 12:
		for around in 8:
			var vertices: Array = []
			for corner in [[length_step, around], [length_step + 1, around], [length_step, around + 1], [length_step + 1, around + 1]]:
				var progress: float = float(corner[0]) / 12.0
				var angle: float = TAU * float(corner[1]) / 8.0
				var normal: Vector3 = side * cos(angle) + across * sin(angle)
				var taper: float = .35 + .65 * sin(PI * progress)
				vertices.append({"position": first.lerp(last, progress) + normal * radius * taper,
					"normal": normal, "uv": Vector2(float(corner[1]) / 8.0, progress)})
			for corner in [0, 1, 2, 2, 1, 3]:
				var point: Dictionary = vertices[corner]
				builder.set_normal((global_basis.inverse() * point.normal).normalized())
				builder.set_uv(point.uv)
				builder.add_vertex(inverse * point.position)
	effect.mesh = builder.commit()
	set_meta("fit_points", surface.points.size())
	set_meta("measured_blade_length_cells", first.distance_to(last))

func _orbits() -> void:
	var centre: Vector3 = surface.origin
	var height: float = 0.0
	for point in surface.points:
		height = maxf(height, point.position.y - centre.y)
	var inverse := global_transform.affine_inverse()
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = int(settings.get("arcs", 4))
	var extent: float = deg_to_rad(float(settings.get("arc_degrees", 110.0)))
	var width: float = float(settings.get("width_cells", .055))
	for arc in count:
		var level: float = height * (.24 + float(arc % 3) * .24)
		var radius: float = .16
		# Fit this orbit to the current outfit at its own height. The hidden half
		# is an explicit radial envelope, not invented anatomical/back geometry.
		for point in surface.points:
			if absf(point.position.y - centre.y - level) < height * .12:
				radius = maxf(radius, Vector2(point.position.x - centre.x, point.position.z - centre.z).length())
		radius = minf(radius, .48) + float(settings.get("clearance_cells", .05))
		for step in 40:
			var vertices: Array = []
			for corner in [[step, -1], [step + 1, -1], [step, 1], [step + 1, 1]]:
				var fraction: float = float(corner[0]) / 40.0
				var angle: float = local_clock * float(settings.get("orbit_radians_per_second", 1.5)) + float(arc) * TAU / count + fraction * extent
				var normal := Vector3(cos(angle), 0, sin(angle))
				var y: float = level + sin(angle * 1.6 + float(arc)) * height * .055 + float(corner[1]) * width
				vertices.append({"point": centre + normal * radius + Vector3.UP * y,
					"normal": normal, "uv": Vector2(fraction, 0.0 if corner[1] < 0 else 1.0)})
			for corner in [0, 1, 2, 2, 1, 3]:
				var vertex: Dictionary = vertices[corner]
				builder.set_normal((global_basis.inverse() * vertex.normal).normalized())
				builder.set_uv(vertex.uv)
				builder.add_vertex(inverse * vertex.point)
	effect.mesh = builder.commit()
	set_meta("fit_points", surface.points.size())

const VfxPackageIO_8c70ca642f = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
