extends "res://assets/vfx/sources/9632af18c96679529624/chromatic_orb.gd"
const Draws = preload("res://assets/vfx/sources/1ce921e2e0d834153ef2/prepared_draws.gd")

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.prepared_draws)]

static func make_component(input: Dictionary) -> Node3D:
	assert(input.get("element", "") in ["acid", "cold", "fire", "lightning", "poison", "thunder"])
	assert(input.get("side", "") in ["creature", "ground"])
	assert(not (input.element == "thunder" and input.side == "ground"))
	var node: Node3D = VfxPackageIO_cca131f018.resource("res://assets/vfx/sources/cca131f01848c92f1da4/prepared_chromatic_orb.gd").new()
	node.specification = input.duplicate(true)
	node.launch_seconds = float(input.get("launch_seconds", .3))
	node.travel_seconds = float(input.get("travel_seconds", .52))
	return node

func prepare() -> void:
	var bank := Draws.obtain(specification.prepared_draws)
	materials = Draws.material_copies(bank)
	pivot = Node3D.new()
	pivot.name = "FormedElementalOrb"
	add_child(pivot)
	shells = Draws.group(bank, "shells", pivot, materials)
	splinters = Draws.group(bank, "splinters", self, materials)

const VfxPackageIO_cca131f018 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
