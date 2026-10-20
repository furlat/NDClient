extends Resource
## OFFLINE post-native-duplicate state, not a guess at native setter behavior.
## The original unit source fields and every stored native property are proved
## after the runtime restoration order; immutable descendants have no writers.
@export var properties: Array[Dictionary] = []
@export var source_fields: Dictionary = {}
@export var proof: Dictionary = {}

func make_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	for property: Dictionary in properties:
		material.set(property.name,property.value)
	return material
