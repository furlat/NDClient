extends "res://assets/vfx/extensions/late-20261020/sources/161f0610c6995cab5fde/liquid.gd"
## Only originally adaptive sources expose committed events and live particles.
static func preparation_resources(input: Dictionary) -> Array:
	# Script.has_method() does not publish inherited static entry points. The
	# public adaptive leaf must expose its actual bank before any occurrence.
	return [String(input.liquid_bank)]

static func make_component(input: Dictionary) -> Node3D:
	return build(input, VfxPackageIO_c952b48391.resource("res://assets/vfx/extensions/late-20261020/sources/c952b48391f8cc44666f/live.gd"))

func set_live_particles(value: PackedVector4Array) -> void:
	_replace_live_particles(value)

func set_transition_events(value: Array) -> void:
	_replace_transition_events(value)

const VfxPackageIO_c952b48391 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
