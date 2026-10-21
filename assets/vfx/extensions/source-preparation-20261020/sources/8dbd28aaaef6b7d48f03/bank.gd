extends "res://assets/vfx/extensions/source-preparation-20261020/sources/d212884f8ef4943bb634/bank.gd"
## Exact three sensory sources; only source construction is moved offline.
const HeadAnchor = preload("res://assets/vfx/sources/352283aaacfa78292274/overhead_anchor.gd")
const UnitState = preload("res://assets/vfx/extensions/followup-20261020/sources/7a626a58244915b1d09e/native_units.gd")
@export var surface_material_sites: Array[Dictionary] = []
@export var emitter_births: Array[Dictionary] = []
@export var world_process_units: Array[Dictionary] = []
@export var sampler_clock_indices: Array[int] = []


func decode(record: Dictionary, owner: Node3D, materials: Array, resources: Array) -> Variant:
	if record.kind == "measured_head_anchor":
		var anchor := HeadAnchor.new()
		anchor.glyph = owner.get_node(record.glyph)
		anchor.clearance_cells = record.clearance_cells
		return anchor
	return super.decode(record, owner, materials, resources)


func restore(input: Dictionary) -> Node3D:
	var owner: Node3D = super.restore(input)
	var meshes := {}
	for site: Dictionary in surface_material_sites:
		var draw: MeshInstance3D = owner.get_node(site.node)
		if not meshes.has(draw.mesh):
			meshes[draw.mesh] = draw.mesh.duplicate(false)
		draw.mesh = meshes[draw.mesh]
		assert(draw.mesh is QuadMesh and int(site.surface) == 0, "Actual finite sensory glyph is one private QuadMesh")
		draw.mesh.material = owner.prepared_materials[site.index]
	for record: Dictionary in world_process_units:
		owner.unit_operators.append(UnitState.new(owner.prepared_materials[record.index], record.operator))
	return owner


func replay_births(owner: Node3D) -> void:
	# Audited native source setter history. The saved pre-tree state is restored
	# offline; no random observed constructor seed becomes an authored operand.
	for record: Dictionary in emitter_births:
		var emitter: GPUParticles3D = owner.get_node(record.node)
		assert(emitter.use_fixed_seed == record.before_fixed and emitter.emitting == record.before_emitting)
		if record.before_fixed:
			assert(emitter.seed == record.before_seed)
		emitter.use_fixed_seed = true
		emitter.seed = record.authored_seed
		if record.authored_restart:
			emitter.emitting = record.after_emitting
			emitter.restart()
