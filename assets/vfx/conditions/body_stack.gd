extends RefCounted
## Change-time bindings only. A material retains its identity so the renderer
## continues updating its exact current pose/frame. All owner clocks are GPU.
const Program = preload("res://assets/vfx/conditions/body_program.gd")
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
static var entries: Dictionary = {}
static var textures: Dictionary = {}


static func bind(material: ShaderMaterial, owner: int, actor: String, operation: Dictionary) -> void:
	var identity := material.get_instance_id()
	if not entries.has(identity):
		entries[identity] = {"reference": weakref(material), "original": material.shader, "actor": actor, "owners": {}}
		Sources.replace_shader(material, Program.prepare(material.shader))
	assert(entries[identity].actor == actor, "Mutable actor materials cannot be shared between recipients")
	entries[identity].owners[owner] = operation
	refresh(material, entries[identity])


static func unbind(material: ShaderMaterial, owner: int) -> void:
	var identity := material.get_instance_id()
	if not entries.has(identity):
		return
	entries[identity].owners.erase(owner)
	if entries[identity].owners.is_empty():
		Sources.replace_shader(material, entries[identity].original)
		entries.erase(identity)
	else:
		refresh(material, entries[identity])


static func texture(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = VfxPackageIO_11a040843c.resource(path)
	return textures[path]


static func colours(values: Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for value in values:
		var colour := int(value)
		result.append(Vector3((colour >> 16) & 255, (colour >> 8) & 255, colour & 255) / 255.)
	return result


static func refresh(material: ShaderMaterial, entry: Dictionary) -> void:
	assert(entry.owners.size() <= 16, "Explicit actor treatment capacity exceeded")
	var slots := PackedInt32Array()
	var kinds := PackedInt32Array()
	var strengths := PackedFloat32Array()
	var periods := PackedFloat32Array()
	for operation in entry.owners.values():
		slots.append(operation.slot)
		kinds.append(operation.kind)
		strengths.append(operation.strength)
		periods.append(operation.period)
		var data: Dictionary = operation.data
		match int(operation.kind):
			1:
				material.set_shader_parameter("factory_body_bark", texture(data.texture))
			2:
				material.set_shader_parameter("factory_body_stone", texture(data.texture))
				material.set_shader_parameter("factory_body_stone_palette", colours(data.colours))
				material.set_shader_parameter("factory_body_stone_gain", float(data.gain))
				material.set_shader_parameter("factory_body_stone_repeats", float(data.texture_repeats))
				material.set_shader_parameter("factory_body_stone_weight", float(data.texture_weight))
				material.set_shader_parameter("factory_body_stone_flow", Vector2(data.flow_uv_per_second[0], data.flow_uv_per_second[1]))
			3:
				material.set_shader_parameter("factory_body_petrified", texture(data.texture))
				material.set_shader_parameter("factory_body_petrified_palette", colours(data.colours))
				material.set_shader_parameter("factory_body_petrified_repeats", float(data.texture_repeats))
				material.set_shader_parameter("factory_body_petrified_weight", float(data.texture_weight))
			4:
				material.set_shader_parameter("factory_body_metal", texture(data.texture))
	slots.resize(16)
	kinds.resize(16)
	strengths.resize(16)
	periods.resize(16)
	material.set_shader_parameter("factory_body_count", entry.owners.size())
	material.set_shader_parameter("factory_body_slots", slots)
	material.set_shader_parameter("factory_body_kinds", kinds)
	material.set_shader_parameter("factory_body_strengths", strengths)
	material.set_shader_parameter("factory_body_periods", periods)

const VfxPackageIO_11a040843c = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
