extends "res://assets/vfx/sources/3388e7d838f178594366/glyph_payload.gd"
## The original one-event admission, live origin/radius and clock are inherited.
## Programs and fixed geometry are prepared before publication, not specialized
## in the first triggered occurrence. No event facts are stored in the bank.
var bank: Resource

static func preparation_resources(input: Dictionary) -> Array:
	return [input.immutable_payload_bank]

static func make_component(input: Dictionary) -> Node3D:
	assert(not str(input.get("spatial_owner_uuid", "")).is_empty())
	var node: Node3D = VfxPackageIO_4251bf816e.resource("res://assets/vfx/sources/4251bf816ed8ac6ca5cb/prepared_glyph_payload.gd").new()
	node.bank = VfxPackageIO_4251bf816e.resource(input.immutable_payload_bank)
	node.specification = input.duplicate(true)
	node.set_trigger_event(input.get("event", {}))
	return node

func set_trigger_event(value: Dictionary) -> bool:
	if bank == null or str(value.get("payload", "")) != str(bank.constants.payload):
		return false
	return super.set_trigger_event(value)

func prepare() -> void:
	rune_material = bank.materials[0].duplicate(false)
	rune = Native.draw(self, "NativeWardTriggerDissolve", bank.meshes[0], rune_material)
	rune.top_level = true
	if bank.materials.size() > 1:
		element_material = bank.materials[1].duplicate(false)
		wave = Native.draw(self, "BriefNativeElementalGroundResponse", bank.meshes[1], element_material)
		wave.top_level = true

const VfxPackageIO_4251bf816e = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
