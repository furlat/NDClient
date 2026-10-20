extends "res://assets/vfx/extensions/continuation42-20261020/sources/a79f812dc5413c9a1bcf/hunters_mark.gd"
## Actual original quarry/owner/hit sampler and measured body/item geometry.
## Only its two source material extractions and fixed ribbon topology are ready.
const Readiness = preload("res://assets/vfx/extensions/followup-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
const FastMeasuredSurface = preload("res://assets/vfx/extensions/continuation42-20261020/sources/6a54923fc76acb58b29e/measured_surface.gd")
var bank: Resource
const QUERY_CAPACITY := 32
var contact_queries: Dictionary = {}
var contact_order: Array = []
var patch_queries: Dictionary = {}
var patch_order: Array = []

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.hunters_mark_bank)]

static func make_component(input: Dictionary) -> Node3D:
	var path := str(input.hunters_mark_bank)
	assert(Readiness.resources.has(path),"Prepare exact Hunter source Resources before construction")
	var prepared: Resource = Readiness.resources[path]
	assert(prepared.interface_ready and prepared.material_parameters == input.material)
	assert(prepared.windup == (input.phase == "windup"))
	var effect: Node3D = VfxPackageIO_b383d717f6.resource("res://assets/vfx/extensions/continuation42-20261020/sources/b383d717f6c20a7ed205/field.gd").new()
	effect.bank = prepared
	effect.configure(input)
	# Existing source opt-in: missing revisions retain conservative exact work.
	effect.settings.prepared_geometry_queries = true
	Profile.begin("hunters_mark_private_materials")
	var body: ShaderMaterial = prepared.private_material(0)
	var source: ShaderMaterial = prepared.private_material(1)
	Profile.end("hunters_mark_private_materials")
	Profile.begin("hunters_mark_four_source_draws")
	effect.mark = effect.make_mesh("ActualQuarryForkedTrackingCuts",body)
	effect.weapon_cut = effect.make_mesh("ActualQualifiedWeaponFootprint",source)
	for index in 2:
		effect.forks.append(effect.make_mesh("SourceHandTrackingFork"+str(index),source))
	if prepared.windup:
		# Same native empty atlas and original shared two-fork row allocation.
		# No hand/encounter coordinates are supplied until the actual input call.
		var image := Image.create(64,32,false,Image.FORMAT_RGBAF)
		var texture := ImageTexture.create_from_image(image)
		source.set_meta("gpu_path_atlas",{"image":image,"texture":texture,"rows":0})
		source.set_shader_parameter("gpu_path_points",texture)

	Profile.end("hunters_mark_four_source_draws")
	return effect

func source_bindings() -> Dictionary:
	return {"geometry":meshes,"materials":materials,"lights":[],"players":[],
		"static_material_topology":true,"static_geometry_layers":true}

func has_verified_stable_paths() -> bool:
	return meshes.size() == 4 and materials.size() == 2

func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)

func measured_mark(node: MeshInstance3D) -> bool:
	var hit := contact()
	if hit.is_empty():
		return false
	var patch := recipient_patch()
	var measured := FastMeasuredSurface.build(patch,"recipient_patch",hit.position,.012)
	if measured.cells == 0:
		return false
	node.global_transform = Transform3D(Basis.IDENTITY,patch.origin)
	node.mesh = measured.mesh
	node.show()
	return true

func measure_weapon() -> Dictionary:
	if weapon.is_empty():
		return {}
	var hand: Vector3 = endpoints[0].point if not endpoints.is_empty() else weapon.origin
	measurement = FastMeasuredSurface.build(weapon,str(settings.render_slot),hand,.006)
	return measurement

func contact() -> Dictionary:
	var surface := recipient_surface()
	var pose := GeometryKey.from_surface(surface)
	if pose.is_empty() or surface.get("points",[]).is_empty() or endpoints.size() < 2:
		return super.contact()
	# The original nearest-point reduction uses absolute f32 operands. Retain
	# actual origin and endpoint, rather than equating translated differences.
	var key: Array = [pose,surface.get("origin",Vector3.ZERO),endpoints[1].point,surface.points.size()]
	if contact_queries.has(key):
		var selected: Dictionary = surface.points[int(contact_queries[key])]
		return {"position":selected.position+selected.normal*.012,"normal":selected.normal.normalized()}
	# Do not inherit the original single-entry cache's relative-position key.
	cached_contact_key = []
	cached_contact_index = -1
	var result := super.contact()
	if cached_contact_index >= 0:
		_remember(contact_queries,contact_order,key,cached_contact_index)
	return result

func recipient_patch() -> Dictionary:
	var surface := recipient_surface()
	var pose := GeometryKey.from_surface(surface)
	if pose.is_empty() or surface.get("points",[]).is_empty():
		return super.recipient_patch()
	# Height thresholds subtract this exact absolute origin. No inverse/root
	# transform participates in this source reduction; the live mesh owner is
	# positioned by the inherited sampler after the unchanged measured build.
	var key: Array = [pose,surface.get("origin",Vector3.ZERO),surface.points.size()]
	if patch_queries.has(key):
		var record: Dictionary = patch_queries[key]
		var patch: Dictionary = record.patch
		for index in record.indices.size():
			var current: Dictionary = surface.points[int(record.indices[index])]
			patch.points[index].position = current.position
			patch.points[index].normal = current.normal
		return patch
	cached_patch_key = []
	cached_patch_indices = []
	var result := super.recipient_patch()
	_remember(patch_queries,patch_order,key,{"indices":cached_patch_indices.duplicate(),"patch":result})
	return result

func _remember(records: Dictionary, order: Array, key: Array, value: Variant) -> void:
	if order.size() == QUERY_CAPACITY:
		records.erase(order.pop_front())
	var immutable_key := key.duplicate(true)
	records[immutable_key] = value
	order.append(immutable_key)

const VfxPackageIO_b383d717f6 = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
