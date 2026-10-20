extends "res://assets/vfx/extensions/continuation42-20261020/sources/ca544a90d8fc6e83965f/flaming_sphere_volume.gd"
## Original complete sampler; only immutable native construction is prepared.
const Readiness = preload("res://assets/vfx/extensions/followup-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
var bank: Resource
var prepared_geometry: Array[GeometryInstance3D] = []
var prepared_materials: Array[Material] = []


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.flaming_sphere_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var path := str(input.flaming_sphere_bank)
	assert(Readiness.resources.has(path),"Prepare exact Flaming Sphere native Resources before publication")
	var prepared: Resource = Readiness.resources[path]
	assert(prepared.interface_ready and prepared.scene != null)
	assert(not str(input.get("entity_uuid","")).is_empty() and not str(input.get("existence_condition_uuid","")).is_empty())
	var effect: Node3D = VfxPackageIO_55cbb7e32d.resource("res://assets/vfx/extensions/continuation42-20261020/sources/55cbb7e32d051a501164/field.gd").new()
	effect.bank = prepared
	effect.specification = input.duplicate(true)
	effect.set_body_state(input.get("state",{}))
	Profile.begin("flaming_sphere_native_scene")
	var container: Node3D = prepared.scene.instantiate()
	Profile.end("flaming_sphere_native_scene")
	Profile.begin("flaming_sphere_private_materials")
	for index in prepared.material_paths.size():
		var draw: GeometryInstance3D = container.get_node(prepared.material_paths[index])
		var material: ShaderMaterial = prepared.private_material(index)
		draw.material_override = material
		effect.prepared_geometry.append(draw)
		effect.prepared_materials.append(material)
	for index in prepared.particle_paths.size():
		var emitter: GPUParticles3D = container.get_node(prepared.particle_paths[index])
		assert(emitter.local_coords,"Only this original local native process avoids world-unit copying")
		emitter.process_material = prepared.native_processes[index].make_material()
		effect.prepared_materials.append(emitter.process_material)
		effect.emitters.append(emitter)
	Profile.end("flaming_sphere_private_materials")
	Profile.begin("flaming_sphere_source_handles")
	for path_entry: NodePath in prepared.head_paths:
		var head: MeshInstance3D = container.get_node(path_entry)
		effect.heads.append(head)
		effect.materials.append(head.material_override)
	effect.fire_material = effect.materials[0]
	effect.core = container.get_node(prepared.core_path)
	effect.core_material = effect.core.material_override
	effect.flame_root = container.get_node(prepared.flame_root_path)
	for emitter: GPUParticles3D in effect.emitters:
		effect.flame_materials.append(emitter.material_override)
	# Restore the exact original hierarchy, rather than an extra donor transform.
	# All mutable source handles are assigned before the actual first tree entry.
	for node: Node in container.find_children("*","",true,false):
		node.owner = null
	for child: Node in container.get_children():
		container.remove_child(child)
		effect.add_child(child)
	container.free()
	Profile.end("flaming_sphere_source_handles")
	return effect


func prepare() -> void:
	assert(core != null and heads.size() == 8 and emitters.size() == 2,
		"No source reconstruction fallback: immutable readiness must be complete")


func source_bindings() -> Dictionary:
	return {"geometry":prepared_geometry,"materials":prepared_materials,"players":[],"lights":[],
		"static_material_topology":true,"static_geometry_layers":true}


func has_verified_stable_paths() -> bool:
	return prepared_geometry.size() == 11 and bank.verified_stable_paths


func prepare_source_layer_mask(mask: int) -> void:
	assert(not is_inside_tree() and mask > 0)
	for draw: GeometryInstance3D in prepared_geometry:
		if draw.layers != 0 and draw.layers != mask:
			draw.layers = mask


func refresh_live_inputs(seconds: float) -> void:
	# The original callback updates placement/admission and source uniforms only.
	# No restart/process-time write is made; pending native GPU delta is untouched.
	sample(seconds)

const VfxPackageIO_55cbb7e32d = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
