extends Node3D
## Actual surviving sections; immediate disclosed apertures, no review shatter.
const WallInput = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/04632730a28d130e2df3/input.gd")
const Readiness = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
var bank: Resource
var construction := {}
var current := {}
var state := {}
var input_error := ""
var placement_valid := false
var module_roots: Array[Node3D] = []
var module_materials: Array[Array] = []
var materials: Array[ShaderMaterial] = []
var geometry: Array[GeometryInstance3D] = []
var joins: Array[Dictionary] = []
var mask: ImageTexture

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.get("solid_owner_bank", ""))]

static func make_component(input: Dictionary) -> Node3D:
	var prepared: Resource = Readiness.resources.get(str(input.get("solid_owner_bank", "")))
	if prepared == null or not prepared.interface_ready:
		return null
	var actual := WallInput.construction(input, prepared.kind)
	if not actual.error.is_empty() or actual.modules.is_empty() or bool(actual.modules[0].dome) != prepared.dome:
		return null
	var node: Node3D = VfxPackageIO_44a07f767e.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/44a07f767e19f1faf49c/wall.gd").new()
	node.bank = prepared
	node.construction = actual
	node.mask = ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_R8))
	for index in actual.modules.size():
		var module: Dictionary = actual.modules[index]
		if module.dome:
			module.absolute_center = module.center + actual.anchor
		var holder := Node3D.new()
		holder.name = "ActualSectionModule%02d" % index
		node.add_child(holder)
		node.module_roots.append(holder)
		var template: Array = prepared.templates[index % prepared.templates.size()]
		var aliases := {}
		var private_materials: Array[ShaderMaterial] = []
		for item: Dictionary in template:
			var material_index := int(item.material)
			if not aliases.has(material_index):
				var material: ShaderMaterial = prepared.materials[material_index].duplicate(false)
				material.set_shader_parameter("solid_cells", node.mask)
				if module.dome:
					material.set_shader_parameter("solid_dome_projection", Vector4(module.center.x * WallInput.CELL, module.center.y * WallInput.CELL,
						float(module.radius_feet) * WallInput.CELL / 5.0, 1.0))
				aliases[material_index] = material
				private_materials.append(material)
				node.materials.append(material)
			var draw := MeshInstance3D.new()
			draw.name = str(item.name)
			draw.mesh = item.mesh
			draw.transform = item.transform
			draw.custom_aabb = item.custom_aabb
			draw.cast_shadow = item.cast_shadow
			draw.material_override = aliases[material_index]
			holder.add_child(draw)
			node.geometry.append(draw)
		node.module_materials.append(private_materials)
		holder.position = Vector3(module.center.x * WallInput.CELL, 0.0, module.center.y * WallInput.CELL)
		if module.dome:
			holder.scale = Vector3.ONE * (float(module.radius_feet) / 10.0)
		else:
			holder.rotation.y = module.heading
			holder.scale.y = float(actual.area.height_feet) / 10.0
		holder.hide()
	if not prepared.join_template.is_empty() and actual.area.path.form == "polyline":
		for corner in range(1, actual.area.path.points.size() - 1):
			var point: Array = actual.area.path.points[corner]
			var absolute := Vector2(point[0], point[1])
			var left := -1
			var right := -1
			for index in actual.modules.size():
				if actual.modules[index].last == absolute:
					left = index
				if actual.modules[index].first == absolute:
					right = index
			if left < 0 or right < 0:
				continue
			var holder := Node3D.new()
			holder.name = "ActualCornerPort%02d" % corner
			node.add_child(holder)
			var relative: Vector2 = absolute - actual.anchor
			holder.position = Vector3(relative.x * WallInput.CELL, 0.0, relative.y * WallInput.CELL)
			holder.rotation.y = actual.modules[left].heading
			var private_materials: Array[ShaderMaterial] = []
			for item: Dictionary in prepared.join_template:
				var material: ShaderMaterial = prepared.materials[int(item.material)].duplicate(false)
				material.set_shader_parameter("solid_cells", node.mask)
				node.materials.append(material)
				private_materials.append(material)
				var draw := MeshInstance3D.new()
				draw.mesh = item.mesh
				draw.transform = item.transform
				draw.custom_aabb = item.custom_aabb
				draw.cast_shadow = item.cast_shadow
				draw.material_override = material
				holder.add_child(draw)
				node.geometry.append(draw)
			node.joins.append({"root":holder, "left":left, "right":right})
			holder.hide()
	node.hide()
	return node

func prepare_source_layer_mask(value: int) -> void:
	for draw: GeometryInstance3D in geometry:
		draw.layers = value

func source_bindings() -> Dictionary:
	return {"geometry":geometry, "materials":materials, "players":[], "lights":[],
		"static_material_topology":true, "static_geometry_layers":true}

func set_zone_geometry(value: Dictionary) -> bool:
	var observed := WallInput.observation(value, construction.owner, bank.kind, construction.area, construction.anchor)
	input_error = observed.error
	if not input_error.is_empty():
		current = {}
		hide()
		return false
	current = observed
	var image := Image.create_empty(current.size.x, current.size.y, false, Image.FORMAT_R8)
	for cell: Vector2i in current.cells:
		var pixel: Vector2i = cell - current.minimum
		image.set_pixel(pixel.x, pixel.y, Color.WHITE)
	mask.set_image(image)
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("solid_mask_origin", Vector2(current.minimum))
		material.set_shader_parameter("solid_mask_size", Vector2(current.size))
	for index in module_roots.size():
		var section := WallInput.section_for(construction.modules[index], current.sections)
		module_roots[index].visible = not section.is_empty()
		var cuts := PackedVector4Array()
		if not section.is_empty():
			for cut: Dictionary in section.get("removed_sections", []):
				cuts.append(Vector4((float(cut.minimum_position[0]) - construction.anchor.x - 0.5) * WallInput.CELL,
					(float(cut.base_height_steps) - float(construction.area.base_height_steps)) * WallInput.CELL,
					(float(cut.minimum_position[1]) - construction.anchor.y - 0.5) * WallInput.CELL, 0.0))
		var count := cuts.size()
		cuts.resize(WallInput.MAX_CUTS)
		for material: ShaderMaterial in module_materials[index]:
			material.set_shader_parameter("solid_cut_count", count)
			material.set_shader_parameter("solid_cuts", cuts)
	for join: Dictionary in joins:
		var first := WallInput.section_for(construction.modules[join.left], current.sections)
		var second := WallInput.section_for(construction.modules[join.right], current.sections)
		# A decorative port cannot refill an actual aperture or absent section.
		join.root.visible = not first.is_empty() and not second.is_empty() and first.get("removed_sections", []).is_empty() and second.get("removed_sections", []).is_empty()
	return true

func set_owner_state(value: Dictionary) -> bool:
	input_error = WallInput.owner_state(value, construction.owner)
	if not input_error.is_empty():
		state = {}
		hide()
		return false
	state = value.duplicate(true)
	if not state.present or not state.observed or state.suppressed:
		hide()
	return true

func set_targets(value: Array) -> void:
	if value.is_empty() or not value[0] is Dictionary or not value[0].get("point") is Vector3 or not value[0].point.is_finite():
		placement_valid = false
		hide()
		return
	global_position = value[0].point
	placement_valid = true

func set_live_endpoints(value: Array) -> void:
	set_targets(value)

func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)

func sample(seconds: float) -> void:
	visible = is_finite(seconds) and seconds >= 0.0 and placement_valid and not state.is_empty() and not current.is_empty() \
		and not current.cells.is_empty() and state.present and state.observed and not state.suppressed
	if not visible:
		return
	var age: float = roundf(float(state.owner_age_seconds) * 144.0) / 144.0
	if not bank.dome:
		var height: float = float(construction.area.height_feet) * WallInput.CELL / 5.0
		for index in module_roots.size():
			# Original solid_wall.advance_lifecycle formation, evaluated only
			# from the real owner age. Review break/submersion is not replayed.
			var grow := smoothstep(float(index) * 0.10, 0.95 + float(index) * 0.10, age)
			module_roots[index].position.y = -height * (1.0 - grow)
		if bank.kind == "stone":
			for join: Dictionary in joins:
				join.root.position.y = minf(module_roots[join.left].position.y, module_roots[join.right].position.y)
	var inverse := Projection(global_transform.affine_inverse())
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("solid_world_to_local", inverse)
		if material.get_meta("factory_world_space_uniform", false):
			material.set_shader_parameter("factory_world_to_source", inverse)
		if bank.dome:
			material.set_shader_parameter("age", age)
		else:
			material.set_shader_parameter("wall_clock", age)
		material.set_shader_parameter("opacity", 1.0)

func capture_observation() -> Dictionary:
	return {"owner_uuid":construction.get("owner", ""), "active":visible, "placement_valid":placement_valid,
		"owner_age_seconds":state.get("owner_age_seconds"), "visible_modules":module_roots.filter(func(value: Node3D) -> bool: return value.visible).size(),
		"native_draws":geometry.size(), "disclosed_cells":current.get("cells", []).size(), "error":input_error,
		"automatic_break":false, "automatic_retirement":false, "physics_bodies":0}

const VfxPackageIO_44a07f767e = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
