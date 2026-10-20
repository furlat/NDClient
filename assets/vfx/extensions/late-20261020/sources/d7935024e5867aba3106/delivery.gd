extends "res://assets/vfx/extensions/late-20261020/sources/09f066b260c75308b10a/acid_bow_delivery.gd"
## Exact existing adaptive bow/arrow sampler with offline native operands.
## The three mutable station textures remain private and follow actual input.
const Readiness = preload("res://assets/vfx/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
var bank: Resource
var materials: Array[ShaderMaterial] = []
var geometry: Array[MeshInstance3D] = []

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.acid_arrow_bank)]

static func make_component(input: Dictionary) -> Node3D:
	var path := str(input.acid_arrow_bank)
	assert(Readiness.resources.has(path), "Prepare immutable Acid Arrow operands before construction")
	var prepared: Resource = Readiness.resources[path]
	var source := input.duplicate(true)
	source.erase("acid_arrow_bank")
	assert(source == prepared.source_parameters, "Changed donor/material choices require explicit preparation")
	var effect: Node3D = VfxPackageIO_d7935024e5.resource("res://assets/vfx/extensions/late-20261020/sources/d7935024e5867aba3106/delivery.gd").new()
	effect.bank = prepared
	effect.specification = source
	effect.launch_seconds = float(source.launch_seconds)
	effect.travel_seconds = float(source.travel_seconds)
	effect.prepare()
	return effect

func prepare() -> void:
	if missile != null:
		return
	Profile.begin("acid_arrow_private_materials")
	for prototype in bank.materials:
		materials.append(prototype.duplicate(false))
	Profile.end("acid_arrow_private_materials")
	Profile.begin("acid_arrow_private_atlases")
	for definition in bank.atlas_definitions:
		var image: Image = definition.image.duplicate()
		var texture := ImageTexture.create_from_image(image)
		var atlas := {"image":image,"texture":texture,"rows":int(definition.rows)}
		var material := materials[int(definition.material)]
		material.set_meta(str(definition.metadata),atlas)
		material.set_shader_parameter(str(definition.uniform),texture)
	Profile.end("acid_arrow_private_atlases")
	Profile.begin("acid_arrow_native_draws")
	missile = Node3D.new()
	missile.name = "LayeredAcidArrow"
	add_child(missile)
	bow = Node3D.new()
	bow.name = "HandBoundAcidBow"
	add_child(bow)
	for record in bank.draws:
		var parent: Node3D = missile if record.parent == "missile" else bow if record.parent == "bow" else self
		var draw := Materials.draw(parent,str(record.name),record.mesh,materials[int(record.material)])
		draw.transform = record.transform
		draw.sorting_offset = float(record.sorting_offset)
		draw.custom_aabb = record.custom_aabb
		for key in record.metadata:
			draw.set_meta(key,record.metadata[key])
		for key in record.instance_uniforms:
			draw.set_instance_shader_parameter(key,record.instance_uniforms[key])
		geometry.append(draw)
	Profile.end("acid_arrow_native_draws")
	for index in bank.groups.native:
		native_draws.append(geometry[int(index)])
	for index in bank.groups.wakes:
		wakes.append(geometry[int(index)])
	for index in bank.groups.drops:
		drops.append(geometry[int(index)])
	for index in bank.groups.native_materials:
		native_materials.append(materials[int(index)])
	bow_limbs = geometry[int(bank.groups.bow_limbs)]
	bow_limb_core = geometry[int(bank.groups.bow_limb_core)]
	bow_string = geometry[int(bank.groups.bow_string)]
	bow_material = materials[int(bank.material_roles.bow_material)]
	string_material = materials[int(bank.material_roles.string_material)]
	head_material = materials[int(bank.material_roles.head_material)]
	head_core_material = materials[int(bank.material_roles.head_core_material)]
	wake_material = materials[int(bank.material_roles.wake_material)]
	drop_material = materials[int(bank.material_roles.drop_material)]

func refresh_live_inputs(seconds: float) -> void:
	# Held-age context changes update the original sampler, without advancing
	# external animation players or inventing target motion/impact ownership.
	sample(seconds)

func source_bindings() -> Dictionary:
	return {"geometry":geometry,"materials":materials,"lights":[],
		"static_material_topology":true,"static_geometry_layers":true}

const VfxPackageIO_d7935024e5 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
