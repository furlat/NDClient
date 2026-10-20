extends "res://assets/vfx/extensions/followup-20261020/sources/8289e804134694b54536/dancing_lights.gd"
## Original four-wisp movement/owner sampler; donor extraction occurs offline.
const Readiness = preload("res://assets/vfx/extensions/followup-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
var bank: Resource
var geometry: Array[MeshInstance3D] = []


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.dancing_lights_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var path := str(input.dancing_lights_bank)
	assert(Readiness.resources.has(path), "Prepare immutable Dancing Lights operands before construction")
	var prepared: Resource = Readiness.resources[path]
	var source := input.duplicate(true)
	source.erase("dancing_lights_bank")
	assert({"palette":source.palette,"palette_options":source.palette_options} == prepared.material_parameters,
		"Changed native material choices need explicit preparation")
	var effect: Node3D = VfxPackageIO_b886461c95.resource("res://assets/vfx/extensions/followup-20261020/sources/b886461c95443c086930/field.gd").new()
	effect.bank = prepared
	effect.specification = source
	effect.prepare()
	return effect


func prepare() -> void:
	if not wisps.is_empty():
		return
	Profile.begin("dancing_lights_private_materials_and_draws")
	for index in 4:
		var wisp := MeshInstance3D.new()
		wisp.name = "Wisp" + str(index)
		wisp.mesh = bank.sphere
		var material: ShaderMaterial = bank.materials[index * 2].duplicate(false)
		wisp.material_override = material
		wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wisp)
		wisps.append(wisp)
		materials.append(material)
		geometry.append(wisp)
		var corona := MeshInstance3D.new()
		corona.name = "PolarCorona"
		corona.mesh = bank.corona
		var corona_material: ShaderMaterial = bank.materials[index * 2 + 1].duplicate(false)
		corona.material_override = corona_material
		corona.scale = Vector3.ONE * 3.0
		corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wisp.add_child(corona)
		corona_materials.append(corona_material)
		geometry.append(corona)
	Profile.end("dancing_lights_private_materials_and_draws")
	Profile.begin("dancing_lights_optical_owner")
	light = OmniLight3D.new()
	light.name = "OneOpticalOwner"
	light.position.y = 0.95
	light.omni_range = 6.0
	light.light_energy = 0.8
	light.light_color = Color("afd4e2")
	light.set_meta("factory_light_role", "optical")
	add_child(light)
	Profile.end("dancing_lights_optical_owner")


func refresh_live_inputs(seconds: float) -> void:
	# Owner observations and occurrence movement remain meaningful at held age.
	sample(seconds)


func source_bindings() -> Dictionary:
	var mutable_materials: Array = []
	mutable_materials.append_array(materials)
	mutable_materials.append_array(corona_materials)
	return {"geometry":geometry,"materials":mutable_materials,"lights":[light],"players":[],
		"static_material_topology":true,"static_geometry_layers":true}

const VfxPackageIO_b886461c95 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
