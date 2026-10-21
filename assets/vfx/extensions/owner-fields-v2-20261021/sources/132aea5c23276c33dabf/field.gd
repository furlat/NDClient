extends Node3D
## Existing12/20 prepared native modules, fitted once to actual immutable path.
const Original=preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/a6a5eaecdef7506e382d/wall.gd")
const WallInput=preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/3d0fb1a3447cac810561/input.gd")
const Readiness=preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const POLICY="actual_fire_wall_owner"
var source: Node3D
var context: Dictionary={}
var state: Dictionary={}
var admitted: Dictionary={}
var cells_valid:=false
var placement_valid:=false
var state_error:=""
var history_invalid:=false
var last_tick:=0
var sampled:=false
var source_age:=0.0
var module_positions: Array[Vector2]=[]
var module_admission: Array[bool]=[]

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.get("fire_wall_bank",""))]

static func make_component(input: Dictionary) -> Node3D:
	if input.get("owner_lifetime_policy")!=POLICY:
		return null
	for key in input:
		if key not in ["fire_wall_bank","source_form","owner_lifetime_policy","wall_uuid","anchor_position","wall_geometry"]:
			return null
	var bank: Resource=Readiness.resources.get(str(input.get("fire_wall_bank","")))
	if bank==null or not bank.interface_prepared or bank.program==null:
		return null
	var current:=WallInput.construction(input,bank)
	if not current.error.is_empty():
		return null
	var native: Node3D=Original.make_component({"fire_wall_bank":input.fire_wall_bank})
	if native==null:
		return null
	var node: Node3D=VfxPackageIO_132aea5c23.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/132aea5c23276c33dabf/field.gd").new()
	node.context=current
	node.source=native
	native.name="NativeFireWall"
	node.add_child(native)
	# Preserve every original entry/alias; replace ONLY the two review stops
	# in a private bank/data copy, never the shared prepared source.
	var private_bank: Resource=bank.duplicate(false)
	var entries: Array[Dictionary]=[]
	for entry: Dictionary in bank.entries:
		var private_entry: Dictionary=entry.duplicate(true)
		private_entry.seconds=INF
		private_entry.emission_stop=INF
		entries.append(private_entry)
	private_bank.entries=entries
	native.bank=private_bank
	node._fit_modules()
	node.hide()
	return node

func _fit_modules() -> void:
	var source_positions: Array[Vector3]=[]
	for module: Node3D in source.module_roots:
		source_positions.append(module.position)
	var minimum:=INF
	var maximum:=-INF
	for point: Vector3 in source_positions:
		minimum=minf(minimum,point.x)
		maximum=maxf(maximum,point.x)
	for index in source.module_roots.size():
		var module: Node3D=source.module_roots[index]
		var point: Vector3=source_positions[index]
		var basis: Basis=module.basis
		var location: Vector2
		if context.form=="segment":
			var direction: Vector2=(context.end-context.start).normalized()
			var factor: float=context.length/(maximum-minimum)
			location=context.start+direction*(point.x-minimum)*factor
			var turn:=Basis(Vector3.UP,-atan2(direction.y,direction.x))
			basis=turn*basis.scaled_local(Vector3(factor,context.height_ratio,context.width_ratio))
		else:
			var radius:=Vector2(point.x,point.z).length()
			var factor: float=context.radius/radius
			location=context.center+Vector2(point.x,point.z)*factor
			basis=basis.scaled_local(Vector3(factor,context.height_ratio,context.width_ratio))
		module.transform=Transform3D(basis,Vector3(location.x,point.y,location.y))
		module_positions.append(location)
		module_admission.append(false)

func prepare_source_layer_mask(value: int) -> void:
	source.prepare_source_layer_mask(value)

func source_bindings() -> Dictionary:
	return source.source_bindings()

func has_verified_stable_paths() -> bool:
	return source.has_verified_stable_paths()

func set_admitted_cells(value: Array) -> bool:
	var current:=WallInput.cells(value)
	if not current.error.is_empty():
		cells_valid=false
		admitted={}
		state_error=current.error
		hide()
		return false
	admitted=current.values
	cells_valid=true
	for index in module_positions.size():
		var point: Vector2=module_positions[index]
		var included:=false
		for cell: Vector2i in admitted:
			if absf(point.x-float(cell.x))<=.5 and absf(point.y-float(cell.y))<=.5:
				included=true
				break
		module_admission[index]=included
	return true

func set_owner_state(value: Dictionary) -> bool:
	var error:=WallInput.owner(value,context.owner)
	if not error.is_empty():
		state={}
		state_error=error
		hide()
		return false
	state=value.duplicate(true)
	if not history_invalid:
		state_error=""
	if not state.present or not state.observed or state.suppressed:
		hide()
	return true

func set_live_endpoints(value: Array) -> void:
	if value.is_empty() or not value[0] is Dictionary or not value[0].get("point") is Vector3 or not value[0].point.is_finite():
		placement_valid=false
		hide()
		return
	global_position=value[0].point
	placement_valid=true

func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)

func sample(seconds: float) -> void:
	if state.is_empty() or not is_finite(seconds) or seconds<0.0 or history_invalid:
		hide()
		return
	source_age=state.owner_age_seconds
	var hz: float=source.bank.entries[0].hz
	var desired:=roundi(source_age*hz)
	if roundi(seconds*hz)!=desired or (sampled and desired<last_tick):
		history_invalid=true
		state_error="Native fire needs the same current monotonic actual owner/sample clock"
		hide()
		return
	source.sample(source_age)
	last_tick=desired
	sampled=true
	for index in source.module_roots.size():
		source.module_roots[index].visible=cells_valid and module_admission[index]
	visible=placement_valid and cells_valid and not admitted.is_empty() and state.present and state.observed and not state.suppressed

func capture_observation() -> Dictionary:
	return {"owner_uuid":context.owner,"geometry":context.geometry,"source_age":source_age,"visible":visible,
		"state_error":state_error,"history_invalid":history_invalid,"admitted_cells":admitted.keys(),
		"module_admission":module_admission,"modules":source.module_roots.size(),
		"whole_field_or_fragment_mask":false,"source_units_per_cell":1.0,
		"review_module_expiry":false,"review_emission_stop":false,"source":source.capture_observation(),
		"arbitrary_particle_seeking_qualified":false}

const VfxPackageIO_132aea5c23 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
