extends "res://assets/vfx/sources/f95a9864b1f165d83f44/timed_assembly.gd"
## Family-only whole-source admission. Geometry, source clock and real physics
## remain inherited. These three masks belonged to the old separate half exports.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const HALF_CUTS: Array[Dictionary] = [
	{"role":"exterior", "before":"if(wp.y<0.0||(wp.x+wp.z>=0.0)!=front)discard;", "after":"if(wp.y<0.0)discard;"},
	{"role":"interior", "before":"if(wp.y<0.||((wp.x+wp.z>=0.)!=front))discard;", "after":"if(wp.y<0.)discard;"},
	{"role":"powder", "before":"if((wp.x+wp.z>=0.)!=front)discard;", "after":""}
]
var material_repairs: Array = []

static func make_component(input: Dictionary) -> Node3D:
	var node := VfxPackageIO_0fbe9e56f1.resource("res://assets/vfx/sources/0fbe9e56f12742f3ca05/ice_storm_whole_composition.gd").new() as Node3D
	node.selections = input.entries.duplicate(true)
	node.opacity_control = input.get("opacity_control", false)
	return node

func _prepare() -> void:
	super._prepare()
	for entry: Dictionary in entries:
		var declared_components: Array = entry.definition.composition.components
		if declared_components.size() != 1 or declared_components[0].input.get("side", "") != "full":
			push_error("Ice whole-source admission requires the declared full source side")
			return
		var repaired_roles: Array = []
		for material: ShaderMaterial in entry.source_materials:
			var original_code := material.shader.code
			for cut: Dictionary in HALF_CUTS:
				if not original_code.contains(cut.before):
					continue
				if original_code.count(cut.before) != 1 or repaired_roles.has(cut.role):
					push_error("Ice whole-source exact legacy mask admission changed: " + str(cut.role))
					return
				var shader := Shader.new()
				shader.code = original_code.replace(cut.before, cut.after)
				SourceMaterials.replace_shader(material, shader)
				repaired_roles.append(cut.role)
				material_repairs.append({"entry":entry.definition.id, "role":cut.role,
					"before_SHA256":original_code.sha256_text(), "after_SHA256":shader.code.sha256_text()})
		if repaired_roles.size() != 3:
			push_error("Ice whole-source admission requires exactly exterior/interior/powder legacy masks")
			return

func sample(seconds: float) -> void:
	super.sample(seconds)
	# The inherited writer supplies Transform3D; mat4 expects Projection. Correct
	# only this family after sampling, including hidden entries and held samples.
	for entry: Dictionary in entries:
		var source_matrix := Projection(entry.root.global_transform.affine_inverse())
		for material: ShaderMaterial in entry.source_materials:
			material.set_shader_parameter("factory_world_to_source", source_matrix)

func capture_observation() -> Dictionary:
	var observation := _capture_source_observation()
	observation.observer_only = false
	observation.source_physics_unchanged = true
	observation.family_exact_half_cut_repair = material_repairs.duplicate(true)
	observation.family_mat4_projection = true
	var matrix_rows: Array = []
	for entry: Dictionary in entries:
		var expected := Projection(entry.root.global_transform.affine_inverse())
		var types: Array = []
		var equal_inverse: bool = true
		var remaining_half_cuts: int = 0
		for material: ShaderMaterial in entry.source_materials:
			var value: Variant = material.get_shader_parameter("factory_world_to_source")
			types.append(type_string(typeof(value)))
			equal_inverse = equal_inverse and value is Projection and value == expected
			for cut: Dictionary in HALF_CUTS:
				remaining_half_cuts += material.shader.code.count(cut.before)
		matrix_rows.append({"entry":entry.definition.id,"parameter_types":types,
			"all_equal_actual_entry_inverse":equal_inverse,"remaining_original_half_cuts":remaining_half_cuts})
	observation.actual_source_matrix_parameters = matrix_rows
	return observation

# Read-only body observation retained exactly from the frozen V206 baseline.
func _vector(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func _transform(value: Transform3D) -> Dictionary:
	return {"origin":_vector(value.origin),"basis":[_vector(value.basis.x),_vector(value.basis.y),_vector(value.basis.z)],"scale":_vector(value.basis.get_scale())}

func _capture_source_observation() -> Dictionary:
	var observations: Array = []
	for entry: Dictionary in entries:
		var component: Node = entry.composition.components.effect
		var bodies: Array = []
		for index in component.bodies.size():
			var body: RigidBody3D = component.bodies[index]
			var visual: MeshInstance3D = component.visuals[index]
			var row := {"index":index,"body_world":_vector(body.global_position),"visual_world":_vector(visual.global_position),
				"linear_velocity":_vector(body.linear_velocity),"angular_velocity":_vector(body.angular_velocity),"freeze":body.freeze,"sleeping":body.sleeping,"visual_visible":visual.is_visible_in_tree()}
			# One actual chunk's eight pieces carry full matrices every recorded frame.
			# All ten chunks still expose source ticks, travel, visibility and freeze.
			if entry.definition.id == "chunk_0":
				row.body_local = _transform(body.transform)
				row.body_global = _transform(body.global_transform)
				row.visual_local = _transform(visual.transform)
				row.visual_global = _transform(visual.global_transform)
				row.gravity_scale = body.gravity_scale
			bodies.append(row)
		observations.append({"id":entry.definition.id,"source_tick":component.tick,"source_hz":component.parameters.simulation_hz,
			"source_hit_time":component.hit_time,"entry_begin":entry.definition.begin,"entry_seconds":entry.definition.seconds,
			"shattered":component.shattered,"source_frozen":component.frozen,"entry_visible":entry.root.is_visible_in_tree(),
			"intact_visible":component.chunk.is_visible_in_tree(),"component_transform":_transform(component.global_transform),"bodies":bodies})
	return {"observer_only":true,"source_physics_unchanged":true,"engine_physics_frames":Engine.get_physics_frames(),"entries":observations}

const VfxPackageIO_0fbe9e56f1 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
