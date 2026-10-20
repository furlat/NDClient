extends RefCounted
## Runtime creation from explicitly compiled immutable source assets. This never
## retains encounter facts, a prototype actor, a sampled pose or an owner clock.
static var immutable_programs: Dictionary = {}
const Paths = preload("res://assets/vfx/sources/a14e24228442da522a55/support_paths.gd")

static func resources(input: Dictionary) -> Array:
	return [str(input.prepared_receiving)] if input.has("prepared_receiving") else []

static func make(path: String, input: Dictionary, family: int) -> Node3D:
	var resource_path: String = input.prepared_receiving
	if not immutable_programs.has(resource_path):
		immutable_programs[resource_path] = VfxPackageIO_024e3436e1.resource(resource_path)
	var prepared: Resource = immutable_programs[resource_path]
	assert(prepared != null and prepared.family == family and prepared.source_constructor == path,
		"Prepared receiving program must match the selected exact constructor")
	var component: Node3D = VfxPackageIO_024e3436e1.resource(path).new()
	component.settings = input.duplicate(true)
	component.material = prepared.material.duplicate(false)
	component._prepare_pieces(prepared.meshes.size())
	component.gpu_paths = Paths.new(component, family, prepared)
	component.set_lease_input(input.get("lease", {}))
	component.set_event_input(input.get("event", {}))
	return component

const VfxPackageIO_024e3436e1 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
