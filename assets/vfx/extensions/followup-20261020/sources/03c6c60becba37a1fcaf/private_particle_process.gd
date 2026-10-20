extends RefCounted
## Explicit ownership proof for an already-private native process material.
## Resource banks and unprepared donors never acquire this occurrence claim.
const OWNER_META := "factory_private_process_owner"
const EMITTER_META := "factory_private_process_emitter"
const MATERIAL_META := "factory_private_process_identity"
const FROZEN_META := "factory_private_process_frozen_descendants"
const UNIT_READY_META := "factory_private_process_unit_source"


static func claim(emitter: GPUParticles3D, owner: Node3D, frozen_descendants: bool = false) -> bool:
	if not frozen_descendants or owner == null or emitter == null or not owner.is_ancestor_of(emitter):
		return false
	var material: ParticleProcessMaterial = emitter.process_material as ParticleProcessMaterial
	if material == null:
		return false
	if material.has_meta(OWNER_META) or material.has_meta(EMITTER_META) or material.has_meta(MATERIAL_META):
		return owned_by(emitter, owner)
	material.set_meta(OWNER_META, weakref(owner))
	material.set_meta(EMITTER_META, weakref(emitter))
	material.set_meta(MATERIAL_META, weakref(material))
	material.set_meta(FROZEN_META, true)
	return true


static func owned_by(emitter: GPUParticles3D, owner: Node3D = null) -> bool:
	if emitter == null or not emitter.process_material is ParticleProcessMaterial:
		return false
	var material: ParticleProcessMaterial = emitter.process_material
	if not material.has_meta(OWNER_META) or not material.has_meta(EMITTER_META) or not material.has_meta(MATERIAL_META) \
		or not bool(material.get_meta(FROZEN_META, false)):
		return false
	var claimed_owner: Variant = material.get_meta(OWNER_META)
	var claimed_emitter: Variant = material.get_meta(EMITTER_META)
	var claimed_material: Variant = material.get_meta(MATERIAL_META)
	if not claimed_owner is WeakRef or not claimed_emitter is WeakRef or not claimed_material is WeakRef:
		return false
	var actual_owner: Node3D = claimed_owner.get_ref() as Node3D
	return actual_owner != null and (owner == null or actual_owner == owner) \
		and claimed_emitter.get_ref() == emitter and claimed_material.get_ref() == material \
		and actual_owner.is_ancestor_of(emitter)


static func binding(emitter: GPUParticles3D, length_fields: Array) -> Dictionary:
	if emitter.local_coords or not owned_by(emitter):
		return {}
	var prior: ParticleProcessMaterial = emitter.process_material
	if prior.has_meta(UNIT_READY_META):
		var operand: Variant = prior.get_meta(UNIT_READY_META)
		if not operand is Dictionary:
			return {}
		var prepared_source: Dictionary = operand
		if _source(prior, length_fields) != prepared_source:
			return {}
		return {"emitter": emitter, "source": prepared_source.duplicate()}
	return {}


static func claim_unit_ready(emitter: GPUParticles3D, owner: Node3D, source_fields: Dictionary) -> bool:
	if emitter == null or not emitter.process_material is ParticleProcessMaterial:
		return false
	var material: ParticleProcessMaterial = emitter.process_material
	var unit_fields: Array = preload("res://assets/vfx/sources/07cc721710dacce01ef6/native_particle_units.gd").LENGTH_FIELDS
	if _source(material, unit_fields) != source_fields:
		return false
	if not claim(emitter, owner, true):
		return false
	material.set_meta(UNIT_READY_META, source_fields.duplicate())
	return true


static func _source(material: ParticleProcessMaterial, length_fields: Array) -> Dictionary:
	var fields: Array = length_fields.duplicate()
	if not material.particle_flag_inherit_emitter_scale:
		fields.append_array(["scale_3d_min", "scale_3d_max"] if material.use_scale_3d else ["scale_min", "scale_max"])
	if not material.particle_flag_damping_as_friction:
		fields.append_array(["damping_min", "damping_max"])
	fields.append_array(["directional_velocity_min", "directional_velocity_max"])
	var source := {}
	for field: String in fields:
		source[field] = material.get(field)
	return source
