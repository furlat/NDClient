extends Node3D
## Native prepared cloud, with only its review lifetime replaced by real owner.
const Prepared=preload("res://assets/vfx/sources/e4ffdd01f03112e032d6/prepared_cloud_cohorts.gd")
const Readiness=preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const POLICY="actual_spatial_owner"
var source: Node3D
var owner_uuid := ""
var state := {}
var state_error := ""
var placement_valid := false
var last_owner_tick := 0
var owner_sampled := false
var history_invalid := false

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.get("prepared_cloud_bank",""))]

static func immutable_error(input: Dictionary, bank: Resource) -> String:
	if input.get("owner_lifetime_policy")!=POLICY or not input.get("owner_uuid") is String or input.owner_uuid.is_empty():
		return "Actual spatial owner and explicit source lifetime policy required"
	if bank.construction_program==null or bank.node_specs.is_empty():
		return "Prepared typed native cloud construction is required; no donor/scene fallback"
	if not input.get("state",{}) is Dictionary or not input.get("review_states",[]) is Array:
		return "Owner examples must retain their actual empty Dictionary/Array shapes"
	if not input.get("state",{}).is_empty() or not input.get("review_states",[]).is_empty():
		return "Review owner examples are not construction admission"
	for name in bank.parameters:
		if input.get(name)!=bank.parameters[name]:
			return "Immutable prepared cloud input changed: "+str(name)
	for name in input:
		if not bank.parameters.has(name) and name not in ["prepared_cloud_bank","owner_uuid","owner_lifetime_policy","state","review_states","profile_cloud_construction"]:
			return "Unknown prepared source operand: "+str(name)
	return ""

static func make_component(input: Dictionary) -> Node3D:
	var bank: Resource=Readiness.resources.get(str(input.get("prepared_cloud_bank","")))
	if bank==null or not bank.immutable_interface_prepared or not immutable_error(input,bank).is_empty():
		return null
	var original: Dictionary=bank.parameters.duplicate(true)
	original.prepared_cloud_bank=input.prepared_cloud_bank
	if input.has("profile_cloud_construction"):
		original.profile_cloud_construction=input.profile_cloud_construction
	# The unchanged prepared constructor retains its FULL immutable equality
	# guard, exact native construction/restarts and occurrence-private materials.
	var native: Node3D=Prepared.make_component(original)
	if native==null:
		return null
	var node: Node3D=VfxPackageIO_6d60a32ff7.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/6d60a32ff7fdc84a19fa/field.gd").new()
	node.owner_uuid=input.owner_uuid
	node.source=native
	native.name="NativeCloud"
	node.add_child(native)
	# Only the private settings copy loses review retirement. The bank and
	# original parameters remain exact; shaders and all artistic inputs stay.
	native.settings.erase("retire_begin_seconds")
	for material: ShaderMaterial in native.mats:
		material.set_shader_parameter("cloud_retirement",0.0)
	node.hide()
	return node

func prepare_source_layer_mask(value: int) -> void:
	source.prepare_source_layer_mask(value)

func source_bindings() -> Dictionary:
	return source.source_bindings()

func set_owner_state(value: Dictionary) -> bool:
	var valid: bool=value.get("owner_uuid") is String and value.owner_uuid==owner_uuid
	for name in ["present","observed","suppressed"]:
		valid=valid and typeof(value.get(name))==TYPE_BOOL
	var age: Variant=value.get("owner_age_seconds")
	valid=valid and typeof(age) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(age)) and float(age)>=0.0
	if not valid:
		state={}
		state_error="Current actual spatial owner state required"
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
	var owner_age:=float(state.owner_age_seconds)
	var desired:=int(round(owner_age*float(source.parameters.simulation_hz)))
	# Native emission delta is owned by the existing SourceSampler. It must
	# receive this SAME real owner clock, not a frozen or modulo display age.
	if int(round(seconds*float(source.parameters.simulation_hz)))!=desired:
		history_invalid=true
		state_error="Sample clock must be actual spatial owner age for native particles"
		hide()
		return
	if owner_sampled and desired<last_owner_tick:
		history_invalid=true
		state_error="Backward native particle seek requires source recreation/replay"
		hide()
		return
	source.sample(owner_age)
	last_owner_tick=desired
	owner_sampled=true
	visible=placement_valid and state.present and state.observed and not state.suppressed

func capture_observation() -> Dictionary:
	return {"owner_uuid":owner_uuid,"visible":visible,"state_error":state_error,"owner_sampled":owner_sampled,
		"owner_tick":last_owner_tick,"history_invalid":history_invalid,"lifetime_policy":POLICY,
		"review_retirement_key_present":source.settings.has("retire_begin_seconds"),"source":source.capture_observation(),
		"arbitrary_particle_seeking_qualified":false}

const VfxPackageIO_6d60a32ff7 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
