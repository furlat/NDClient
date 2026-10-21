extends "res://assets/vfx/extensions/source-preparation-20261020/sources/6bdce07d3db39a20bcff/counterspell_contact.gd"
## Retains the original arbitrary incoming presentation and contact contract.
const PreparedFragments = preload("res://assets/vfx/extensions/source-preparation-20261020/sources/e08482398af856bc5bab/counter_fragments.gd")


static func preparation_resources(input: Dictionary) -> Array:
	return [input.fragments.prepared_visual_bank]


static func make_component(input: Dictionary) -> Node3D:
	var style: Dictionary = input.get("fragments", {})
	if not style.has("material") or not style.has("palette") or not style.has("scale_cells_per_source_unit"):
		return null
	var result: Node3D = VfxPackageIO_6d5107280a.resource("res://assets/vfx/extensions/source-preparation-20261020/sources/6d5107280a9cdbf9b441/counterspell.gd").new()
	result.fragment_settings = style.duplicate(true)
	result.fragment_settings.succeeded = true
	var visual := PreparedFragments.new()
	visual.settings = result.fragment_settings.duplicate(true)
	visual.prepare()
	result.fragments = visual
	result.fragments.name = "OriginalFiniteCounterspellFragments"
	result.add_child(result.fragments)
	result.fragments.sample(-1.0)
	result.hide()
	return result


func source_bindings() -> Dictionary:
	return fragments.source_bindings()


func has_verified_stable_paths() -> bool:
	return fragments.stable_paths


func prepare_source_layer_mask(mask: int) -> void:
	preload("res://assets/vfx/extensions/late-20261020/sources/cb91ba2e7f30c0ed0811/restore.gd").layers(fragments, mask)


func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)

const VfxPackageIO_6d5107280a = preload("res://assets/vfx/extensions/source-preparation-20261020/scoped_resource_io.gd")
