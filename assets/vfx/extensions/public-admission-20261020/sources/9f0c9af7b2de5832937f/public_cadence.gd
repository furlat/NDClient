extends "res://assets/vfx/extensions/public-admission-20261020/sources/672c1ceae061a45e68c9/runtime.gd"
## Read the disclosed condition readiness, never its private action registration.
const Interface = preload("res://assets/vfx/extensions/followup-20261020/sources/0fb7351681180386b03a/condition_pose_interface.gd")
const GATE_SCHEMA := "vfxfactory.public_condition_readiness.v1"
var publication_ready := false
var publication_breath := ""
var has_publication := false
var public_interface: Resource


static func preparation_resources(input: Dictionary) -> Array:
	return [input.readiness_interface]


static func make_component(input: Dictionary) -> Node3D:
	assert(input.get("event_gate", {}).get("schema", "") == GATE_SCHEMA)
	var node: Node3D = VfxPackageIO_9f0c9af7b2.resource("res://assets/vfx/extensions/public-admission-20261020/sources/9f0c9af7b2de5832937f/public_cadence.gd").new()
	node.parameters = input.duplicate(true)
	return node


func _ready() -> void:
	super._ready()
	if not construction_error.is_empty():
		return
	public_interface = VfxPackageIO_9f0c9af7b2.resource(parameters.readiness_interface)
	assert(public_interface != null and public_interface.scene != null)
	for entry: Dictionary in handle.geometry:
		var material: ShaderMaterial = entry.node.material_override
		assert(material != null and public_interface.bind_private(material, entry.path),
			"Readiness retains its exact native condition shader and condition-owned clock")


func set_event_binding(value: Dictionary) -> void:
	if value != event_binding:
		has_publication = false
		publication_ready = false
		publication_breath = ""
	super.set_event_binding(value)


func _finite_age(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= 0.0


func set_event_state(value: Dictionary) -> void:
	event_state = value
	event_admitted = false
	if parameters.get("event_gate", {}).get("schema", "") != GATE_SCHEMA:
		return
	if value.get("observed") is not bool or not value.observed or value.get("ready") is not bool:
		return
	for field in ["condition_uuid", "source_actor_uuid"]:
		if not event_binding.get(field) is String or event_binding[field].is_empty():
			return
		if value.get(field) != event_binding[field]:
			return
	if not value.get("observation_revision") is int:
		return
	var revision: int = value.observation_revision
	if revision < 0 or revision < event_cursor:
		return
	if not _finite_age(value.get("owner_age_seconds")) or not _finite_age(value.get("phase_age_seconds")):
		return
	var breath: Variant = value.get("breath_type")
	if breath is not String or breath != parameters.event_gate.match.breath_type:
		return
	# A publication revision names one observed semantic ready value. Optical
	# mouth revisions/clocks may refresh it, but cannot rewrite a retired fact.
	if has_publication and revision == event_cursor and (value.ready != publication_ready or breath != publication_breath):
		return
	if not value.ready:
		event_cursor = revision
		publication_ready = false
		publication_breath = breath
		has_publication = true
		return
	if value.has("active") and (value.active is not bool or not value.active):
		return
	if value.has("suppressed") and (value.suppressed is not bool or value.suppressed):
		return
	if receiving == null or not receiving.admitted_geometry:
		return
	var surface: Variant = receiving.get("current_surface")
	if surface is not Dictionary or surface.is_empty():
		return
	if surface.get("actor") != value.source_actor_uuid or surface.get("region_id") != "mouth":
		return
	var actual_revision: Variant = surface.get("region_revision", surface.get("gpu_geometry_key"))
	if actual_revision == null or not value.has("mouth_surface_revision") or value.mouth_surface_revision != actual_revision:
		return
	event_cursor = revision
	publication_ready = true
	publication_breath = breath
	has_publication = true
	event_admitted = true

const VfxPackageIO_9f0c9af7b2 = preload("res://assets/vfx/extensions/public-admission-20261020/scoped_resource_io.gd")
