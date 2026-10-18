extends RefCounted
## Omni lights ignore inherited scale. Keep authored lengths apart from the
## per-instance world lengths, just as the native particle-unit adapter does.

static func prepare(light: OmniLight3D) -> Dictionary:
    return {"node":light, "range":light.omni_range, "size":light.light_size,"energy":light.light_energy}

static func restore(bindings: Dictionary) -> void:
    for binding in bindings.values():
        if not is_instance_valid(binding.node): continue
        binding.node.omni_range = binding.range
        binding.node.light_size = binding.size
        binding.node.light_energy = binding.energy

static func apply(bindings: Dictionary, scale: float) -> void:
    for binding in bindings.values():
        if not is_instance_valid(binding.node): continue
        binding.range = binding.node.omni_range
        binding.size = binding.node.light_size
        binding.energy = binding.node.light_energy
    rescale(bindings, scale)

static func rescale(bindings: Dictionary, scale: float) -> void:
    var units := absf(scale)
    for binding in bindings.values():
        if not is_instance_valid(binding.node): continue
        binding.node.omni_range = binding.range * units
        binding.node.light_size = binding.size * units
