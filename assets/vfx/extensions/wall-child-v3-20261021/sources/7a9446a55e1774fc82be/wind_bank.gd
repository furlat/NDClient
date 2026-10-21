extends "res://assets/vfx/extensions/production-review-20261020/sources/b761a45e7828c15c978f/wind_bank.gd"
## Resource-only admission of the original live Wind bank. No path/owner cache.
const Methods = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const Interfaces = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
@export var adapter_script: Script
@export var pool_required := false
@export var provenance: Dictionary = {}


func prepare_immutable_interface() -> void:
	if interface_ready: return
	if pool_required: Clock.ensure_pool()
	# Parent resolves exactly the original donor references and shader lists.
	super.prepare_immutable_interface()
	Methods.methods(adapter_script)
	for material: ShaderMaterial in flow_materials+hit_materials:
		material.get_rid()
		Interfaces.declared_uniforms(material.shader)
	# The original live bank omits its native debris material interface/RID.
	# This is immutable preparation, never a hidden first draw/occurrence.
	feed_material.get_property_list()
	feed_material.get_rid()
