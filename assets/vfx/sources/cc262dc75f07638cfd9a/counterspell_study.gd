extends Node3D
## Separate reaction root, exact triggered version/lineage, original native
## source prefix and local fragments. This is a private supplied-fact fixture.

const Fragments = preload("res://assets/vfx/sources/6e25e2b7f8fcbfdb10c7/counter_fragments.gd")
const InterruptedSource = preload("res://assets/vfx/sources/26d73abcda3a1307307d/interrupted_source.gd")

var settings: Dictionary = {}
var endpoints: Array = []
var live_observation: Dictionary = {}
var observed: Dictionary = {}
var fixture_path_snapshot: Dictionary = {}
var fragments: Node3D
var incoming: Node3D
var age_seconds: float = 0.0


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_cc262dc75f.resource("res://assets/vfx/sources/cc262dc75f07638cfd9a/counterspell_study.gd").new()
	effect.settings = input.duplicate(true)
	effect.prepare()
	return effect


func prepare() -> void:
	fragments = Fragments.make_component(settings.fragments)
	add_child(fragments)
	incoming = InterruptedSource.make_component(settings.incoming)
	add_child(incoming)
	visible = false


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func set_reaction_observation(value: Dictionary) -> bool:
	for identity in ["reaction_uuid", "triggered_event_uuid", "triggered_lineage_uuid"]:
		if str(value.get(identity, "")) != str(settings.observation[identity]):
			return false
	if typeof(value.get("succeeded")) != TYPE_BOOL:
		return false
	for point in ["source_world", "target_world", "contact_world"]:
		if not value.get(point) is Vector3:
			return false
	live_observation = value.duplicate(true)
	sample(age_seconds)
	return true


func sample(seconds: float) -> void:
	age_seconds = seconds
	observed = settings.observation.duplicate(true)
	if endpoints.size() < 3:
		visible = false
		return
	# These endpoint facts are an explicit presentation fixture of the saved
	# incoming path; this fraction is not inferred from a spell name or overlap.
	observed.source_world = endpoints[1].point
	observed.target_world = endpoints[2].point
	if seconds < float(observed.release_seconds):
		fixture_path_snapshot.clear()
	elif fixture_path_snapshot.is_empty():
		fixture_path_snapshot = {"source_world": observed.source_world, "target_world": observed.target_world}
	if not fixture_path_snapshot.is_empty():
		observed.merge(fixture_path_snapshot, true)
	observed.contact_world = observed.source_world.lerp(observed.target_world, float(observed.fixture_contact_fraction))
	if not live_observation.is_empty():
		observed = live_observation.duplicate(true)
	visible = bool(observed.get("present", true))
	if not visible:
		return
	incoming.sample_observation(seconds, observed)
	fragments.settings.succeeded = observed.succeeded
	fragments.position = global_transform.affine_inverse() * observed.contact_world
	fragments.sample(seconds - float(observed.contact_seconds))


func capture_observation() -> Dictionary:
	return {"study": "native_counterspell", "reaction_uuid": settings.observation.reaction_uuid,
		"triggered_event_uuid": settings.observation.triggered_event_uuid, "triggered_lineage_uuid": settings.observation.triggered_lineage_uuid,
		"succeeded": observed.get("succeeded", false), "live_endpoints": endpoints.size(), "visible": visible,
		"incoming_visible": incoming.visible and visible, "source_seconds": incoming.source_seconds,
		"incoming_world": incoming.sample_position, "coverage_phase": incoming.coverage_phase,
		"fragment_world": global_transform * fragments.position, "fragments_visible": fragments.fragment.visible and visible,
		"fixture_path_snapshot": fixture_path_snapshot.duplicate(true),
		"original_material_count": incoming.materials.size(), "destination_impact": false,
		"damage_event": false, "rule_solver": false, "native_mask_adaptation": "original coverage equation on each preserved native material UV; not source sprite pixel equivalence"}

const VfxPackageIO_cc262dc75f = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
