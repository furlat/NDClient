extends "res://assets/vfx/extensions/source-preparation-20261020/sources/a7cd7e8bec03d73e1fe0/composition.gd"
## Original native controllers, measured head placement and144Hz source sample.
var unit_operators: Array = []
var previous_unit_scale := 1.0


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_native_composition_bank]


static func make_component(input: Dictionary) -> Node3D:
	var bank: Resource = VfxPackageIO_0bfa45a045.resource(input.get("prepared_native_composition_bank", ""))
	if bank == null or not bank.interface_ready:
		return null
	return bank.restore(input)


func _ready() -> void:
	prepared_bank.replay_births(self)
	# The original sensory apply_scene_edits stops donor autoplay after its
	# tree entry. A packed inactive player still re-enters its authored
	# autoplay before root _ready; replay the same explicit stop at this edge.
	for record: Dictionary in prepared_bank.player_records:
		var player: AnimationPlayer = get_node(record.node)
		assert(record.animation.is_empty() and not player.active, "Only the audited stopped sensory donor player is admitted")
		player.stop()
		player.active = false
	prepared_bank.apply_consumer_callback_policy(self)


func sample(seconds: float) -> void:
	var scale_value := global_basis.get_scale().x
	if scale_value != previous_unit_scale:
		for operator: RefCounted in unit_operators:
			operator.advance(scale_value)
		previous_unit_scale = scale_value
	super.sample(seconds)
	# Captured from the real sampler's handle.clocks, not inferred from a
	# uniform name. These stopped donor players have no later clock writers.
	for index: int in prepared_bank.sampler_clock_indices:
		prepared_materials[index].set_shader_parameter("sandbox_source_seconds", seconds)


func refresh_live_inputs(seconds: float) -> void:
	# Match the original held-age path: placement updates without a second
	# native process-unit setter history or native simulation advance.
	super.sample(seconds)

const VfxPackageIO_0bfa45a045 = preload("res://assets/vfx/extensions/source-preparation-20261020/scoped_resource_io.gd")
