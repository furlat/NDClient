extends RefCounted
## Native immutable templates with occurrence-private uniforms and nodes.
static var banks := {}

static func obtain(path: String) -> Resource:
	if not banks.has(path):
		banks[path] = VfxPackageIO_1ce921e2e0.resource(path)
	return banks[path]

static func material_copies(bank: Resource) -> Array[ShaderMaterial]:
	var copies: Array[ShaderMaterial] = []
	for material: ShaderMaterial in bank.materials:
		copies.append(material.duplicate(false))
	return copies

static func group(bank: Resource, name: String, parent: Node3D, materials: Array[ShaderMaterial]) -> Array[MeshInstance3D]:
	var draws: Array[MeshInstance3D] = []
	for index: int in bank.groups[name]:
		var draw := MeshInstance3D.new()
		draw.name = name + str(index)
		draw.mesh = bank.meshes[index]
		draw.transform = bank.transforms[index]
		draw.sorting_offset = bank.sorting_offsets[index]
		draw.material_override = materials[bank.material_indices[index]]
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.hide()
		parent.add_child(draw)
		draws.append(draw)
	return draws

const VfxPackageIO_1ce921e2e0 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
