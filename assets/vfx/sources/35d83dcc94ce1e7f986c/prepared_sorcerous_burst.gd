extends "res://assets/vfx/sources/e4239bb3cbe524a9967c/sorcerous_burst.gd"
const Draws = preload("res://assets/vfx/sources/1ce921e2e0d834153ef2/prepared_draws.gd")

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.prepared_draws)]

static func make_component(input: Dictionary) -> Node3D:
	assert(input.get("element", "") in ["acid", "cold", "fire", "lightning", "poison", "psychic", "thunder"])
	var node: Node3D = VfxPackageIO_35d83dcc94.resource("res://assets/vfx/sources/35d83dcc94ce1e7f986c/prepared_sorcerous_burst.gd").new()
	node.specification = input.duplicate(true)
	node.launch_seconds = float(input.get("launch_seconds", .3))
	node.travel_seconds = float(input.get("travel_seconds", .38))
	return node

func prepare() -> void:
	var bank := Draws.obtain(specification.prepared_draws)
	materials = Draws.material_copies(bank)
	pivot = Node3D.new()
	pivot.name = "CompactElementalBolt"
	add_child(pivot)
	heads = Draws.group(bank, "heads", pivot, materials)
	fragments = Draws.group(bank, "fragments", self, materials)
	wake = Draws.group(bank, "wake", self, materials)[0]
	native_front = bank.constants.native_front
	# Prepare the exact native path program before source binding discovery.
	if specification.get("gpu_paths", false):
		var points: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
		var widths: Array[float] = [0., 0.]
		preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd").assign(wake, points, widths, Color.WHITE, Vector2(0, 1), true)

func source_bindings() -> Dictionary:
	return {"geometry": Array(heads) + Array(fragments) + [wake], "materials": Array(materials), "static_material_topology": true}

const VfxPackageIO_35d83dcc94 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
