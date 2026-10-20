extends "res://assets/vfx/sources/ce3fb52e9d3edba4bb39/cold_breath_particles.gd"
## Original source admission, face origin, live heading, 144Hz clocks and both
## native particle layers. No current actor, endpoint or event lives in the bank.
var bank: Resource

static func preparation_resources(input: Dictionary) -> Array:
	return [input.immutable_plume_bank]

static func make_component(input: Dictionary) -> Node3D:
	assert(input.element == "cold" and input.phase == "exhale")
	assert(not str(input.get("grant_uuid", "")).is_empty())
	assert(not str(input.get("recipient_uuid", "")).is_empty())
	var node: Node3D = VfxPackageIO_69332c8476.resource("res://assets/vfx/sources/69332c8476b08e07ee05/prepared_cold_breath.gd").new()
	node.bank = VfxPackageIO_69332c8476.resource(input.immutable_plume_bank)
	node.specification = input.duplicate(true)
	node.set_grant_state(input.get("state", {}))
	node.prepare_plume()
	return node

func prepare_plume() -> void:
	plume = bank.scene.instantiate()
	add_child(plume)
	plume.top_level = true
	for path in bank.paths:
		var emitter: GPUParticles3D = plume.get_node(path)
		plume_emitters.append(emitter)
		plume_materials.append(emitter.material_override)
	plume.hide()

func source_bindings() -> Dictionary:
	return {"geometry": plume_emitters, "materials": plume_materials, "static_material_topology": true}

const VfxPackageIO_69332c8476 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
