extends "res://assets/vfx/sources/09f455a091382a8c92c1/cone_frost.gd"
## Same source layers, geometry equations, masks and integer simulation clock.
## Native meshes and source programs are prepared offline rather than rebuilt.
const BANK := "res://assets/vfx/sources/30dcf8ca40e1512eb9c7/immutable.tres"
static var immutable_bank: Resource

static func preparation_resources(_input: Dictionary) -> Array:
	return [BANK]

static func make_component(input: Dictionary) -> Node3D:
	if immutable_bank == null:
		immutable_bank = VfxPackageIO_b996c54280.resource(BANK)
	var instance := construct("res://assets/vfx/sources/b996c54280ac8c5720c5/prepared_cone_frost.gd", input)
	instance.parameters.lifecycle_sampling = "analytical"
	return instance

func tube(index: int) -> ArrayMesh:
	return immutable_bank.tubes[index]

func mist(strength: float, streamed: bool) -> ShaderMaterial:
	var key := "%d/mist/%.4f/%s" % [int(settings.layer), strength, str(streamed)]
	assert(immutable_bank.materials.has(key), "Uncompiled source material variant: " + key)
	var result: ShaderMaterial = immutable_bank.materials[key].duplicate(false)
	mats.append(result)
	return result

func custom(code: String) -> ShaderMaterial:
	var key := "%d/custom/%s" % [int(settings.layer), code.sha256_text()]
	assert(immutable_bank.materials.has(key), "Uncompiled native custom program")
	var result: ShaderMaterial = immutable_bank.materials[key].duplicate(false)
	mats.append(result)
	return result

func raw(path: String) -> ImageTexture:
	assert(immutable_bank.textures.has(path), "Uncompiled native source texture: " + path)
	return immutable_bank.textures[path]

func source_bindings() -> Dictionary:
	return {"geometry": assembly.get_children(), "materials": Array(mats), "static_material_topology": true}

const VfxPackageIO_b996c54280 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
