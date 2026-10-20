extends "res://assets/vfx/sources/3236cda460f27e781de6/recovery_strips.gd"
## Exact accepted Second Wind source; successful self-heal admission stays live.
const Restore = preload("res://assets/vfx/extensions/continuation42-20261020/sources/c0afafcb85ad41652932/restore.gd")
const GeometryKey = preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd")
var bank: Resource
var fit_cache := {}
var fit_order: Array = []


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.prepared_strips_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_f5859b5963.resource("res://assets/vfx/extensions/continuation42-20261020/sources/f5859b5963c2be706668/recovery.gd").new()
	node.bank = Restore.ready_bank(input)
	node.settings = input.duplicate(true)
	node.settings.erase("prepared_strips_bank")
	assert(is_equal_approx(float(input.source_seconds), 1.5))
	assert(node.set_owner_projection(input.owner_projection))
	node._build()
	node.sample(0.0)
	return node


func _build() -> void:
	Restore.build(self, bank)


func build_strip(_index: int, _seconds: float) -> ArrayMesh:
	return bank.strip_mesh


func _fit_actual_geometry() -> void:
	if geometry.get("points", []).is_empty():
		return
	var revision: Array = GeometryKey.from_surface(geometry)
	if revision.is_empty():
		super._fit_actual_geometry()
		return
	# Preserve absolute world operands and the actual original reduction. A
	# local pose key alone cannot justify reusing a translated/rotated fit.
	var key: Array = [revision, geometry.get("origin", Vector3.ZERO),
		global_transform.affine_inverse(), geometry.points.size()]
	if fit_cache.has(key):
		fit.scale = fit_cache[key].scale
		fit.position.y = fit_cache[key].y
		return
	super._fit_actual_geometry()
	var frozen: Array = key.duplicate(true)
	fit_cache[frozen] = {"scale": fit.scale, "y": fit.position.y}
	fit_order.append(frozen)
	if fit_order.size() > 64:
		fit_cache.erase(fit_order.pop_front())


func source_bindings() -> Dictionary:
	return Restore.bindings(self)

const VfxPackageIO_f5859b5963 = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
