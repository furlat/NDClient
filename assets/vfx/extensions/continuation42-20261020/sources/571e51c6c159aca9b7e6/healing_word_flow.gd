extends "res://assets/vfx/sources/529d93ad9ac310bf78c5/healing_word_flow.gd"
## Both original curved W1 source emitters remain native and owner-private.
const Restore = preload("res://assets/vfx/sources/ca69e9e47c9d66bb69fd/restore.gd")


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = Restore.make("res://assets/vfx/extensions/continuation42-20261020/sources/571e51c6c159aca9b7e6/healing_word_flow.gd", input)
	if input.get("restore_native_seed_birth", false):
		var bank: Resource = VfxPackageIO_571e51c6c1.resource(input.prepared_recipient_bank)
		var commands: Array = bank.provenance.get("constructor_native_seed_births", [])
		assert(commands.size() == 2, "Exact prepared original Word seed commands required")
		node.set_meta("prepared_word_seed_births", commands)
	return node


func source_bindings() -> Dictionary:
	return Restore.declared_bindings(self, true)


func sample(seconds: float) -> void:
	if not initialized and parameters.get("restore_native_seed_birth", false):
		assert(seconds == 0.0, "Original native seed commands precede exactly the first sample0")
		var commands: Array = get_meta("prepared_word_seed_births")
		assert(commands.size() == seeds.size(), "Exact original seed-record cardinality")
		for index in commands.size():
			var binding: Dictionary = commands[index]
			var emitter: GPUParticles3D = subject.get_node(binding.node)
			assert(emitter.is_inside_tree() and not emitter.emitting and
				emitter.use_fixed_seed == binding.before_fixed and
				binding.before_seed_policy == "native_unfixed_constructor_default",
				"The actual original pre-tree seed baseline must survive until first sample0")
			assert(str(get_path_to(emitter)) == seeds[index].path and int(seeds[index].seed) == int(binding.seed),
				"Only the original ordered seed setter commands may be replayed")
			emitter.use_fixed_seed = binding.fixed
			emitter.seed = int(binding.seed)
		set_meta("prepared_word_seed_births_applied", 1)
	super.sample(seconds)

const VfxPackageIO_571e51c6c1 = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
