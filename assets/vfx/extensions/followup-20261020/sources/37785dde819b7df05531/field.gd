extends "res://assets/vfx/extensions/followup-20261020/sources/cfd9b5e2882e480dfcd1/acid_arrow.gd"
## Original residual/impact/cell samplers, with offline native materials/meshes.
const Readiness = preload("res://assets/vfx/extensions/followup-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
const Bank = preload("res://assets/vfx/extensions/followup-20261020/sources/bf40f205bcb4f72d44db/bank.gd")
var bank: Resource
var geometry: Array[MeshInstance3D] = []


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.acid_residual_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var path := str(input.acid_residual_bank)
	assert(Readiness.resources.has(path),"Prepare native Acid residual operands before construction")
	var prepared: Resource = Readiness.resources[path]
	var source := input.duplicate(true)
	source.erase("acid_residual_bank")
	assert(source.phase in ["impact","residue","tick","patch"],"Existing residual phases only; delivery remains independent")
	assert(Bank.material_signature(source) == prepared.material_parameters and (source.phase == "patch") == prepared.includes_patch,
		"Changed material choices require explicit preparation")
	var effect: Node3D = VfxPackageIO_37785dde81.resource("res://assets/vfx/extensions/followup-20261020/sources/37785dde819b7df05531/field.gd").new()
	effect.bank = prepared
	effect.specification = source
	effect.launch_seconds = float(source.get("launch_seconds",0.3))
	effect.travel_seconds = float(source.get("travel_seconds",0.5))
	if source.phase == "patch":
		effect.set_admitted_cells(source.get("admitted_cells",[]))
	if source.phase in ["residue","tick"]:
		effect.condition_allowed = source.get("attack_outcome","") == "hit" and bool(source.get("condition_admitted",false))
		if source.phase == "tick":
			effect.condition_allowed = effect.condition_allowed and bool(source.get("factual_delayed_tick",false))
	effect.prepare()
	return effect


func prepare() -> void:
	if pivot != null:
		return
	Profile.begin("acid_residual_private_materials")
	for prototype in bank.materials:
		materials.append(prototype.duplicate(false))
	Profile.end("acid_residual_private_materials")
	Profile.begin("acid_residual_native_draws")
	pivot = Node3D.new()
	pivot.name = "LiquidArrow"
	add_child(pivot)
	arrow_parts.append(Materials.draw(pivot,"PointedArrowHead",bank.head,materials[0]))
	arrow_parts.append(Materials.draw(pivot,"LiquidShaft",bank.shaft,materials[1]))
	arrow_parts[1].position.y = -0.29
	trail = Materials.draw(self,"DropletWake",null,materials[2])
	for index in 12:
		droplets.append(Materials.draw(self,"AcidDrop" + str(index),bank.bead,materials[3]))
	geometry.append_array(arrow_parts)
	geometry.append(trail)
	geometry.append_array(droplets)
	Profile.end("acid_residual_native_draws")
	if bank.includes_patch:
		Profile.begin("acid_residual_current_cell_topology")
		patch = Materials.draw(self,"AdmittedAcidSurface",null,materials[4])
		patch.top_level = true
		geometry.append(patch)
		_update_patch_topology()
		Profile.end("acid_residual_current_cell_topology")


func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)


func source_bindings() -> Dictionary:
	return {"geometry":geometry,"materials":materials,"lights":[],"players":[],
		"static_material_topology":true,"static_geometry_layers":true}

const VfxPackageIO_37785dde81 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
