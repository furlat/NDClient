extends "res://assets/vfx/sources/62383d07549e9c732af2/direct_blade_material.gd"
## Prepared source adapter against current public actor_layers/entity_geometry.
## Exact item admission comes from weapon_binding + the matching measured slot.
## A source pose without authored hilt/tip metadata is explicitly unsupported.
const AttachedFire = preload("res://assets/vfx/sources/5261bc001ca60829a1a9/sheet_source_layers.gd")
const SwingWake = preload("res://assets/vfx/sources/3a6c7e27908861f4c602/component.gd")
const MaskEdge = preload("res://assets/vfx/sources/d2dce11aa90afe21c2fd/element_exterior.gd")
var settings: Dictionary = {}
var receiver_programs: Resource
var native_presets: Resource
var profiles: Dictionary = {}
var raw_layers: Dictionary = {}
var source_layers: Node3D
var exterior: Node3D
var wake: Node3D
var prepared_revision: Array = []
var prepared_pose: Dictionary = {}
var prepared_attachment: Dictionary = {}
var adapter_error := "no_current_receiver"

static func preparation_resources(input: Dictionary) -> Array:
	var result: Array = [input.noise, input.receiver_programs, input.axes]
	if input.has("auxiliary_preset"):
		result.append(input.auxiliary_preset)
	if input.has("pure_preset"):
		result.append(input.pure_preset)
	if input.has("native_presets"):
		result.append(input.native_presets)
	if input.has("wake_style"):
		result.append(input.wake_style)
	if input.get("element") in ["ice", "electric"]:
		result.append_array(ElementBindings.SOURCES.values())
	if input.get("element") == "fire":
		result.append("res://assets/vfx/sources/685f3368cf7e1f336f2e/fire_layers.tscn")
	return result

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_b030caea4f.resource("res://assets/vfx/sources/b030caea4fa2359738f0/equipped_treatment.gd").new()
	component.settings = input.duplicate(true)
	component.source_noise = VfxPackageIO_b030caea4f.resource(str(input.noise))
	component.element = str(input.element)
	component.variant_id = str(input.variant_id)
	component.artistic_strength = str(input.artistic_strength)
	component.strength = {"lesser": .5, "medium": .74, "greater": .95}[component.artistic_strength]
	component.receiver_programs = VfxPackageIO_b030caea4f.resource(str(input.receiver_programs))
	if input.has("auxiliary_preset"):
		component.auxiliary_preset = VfxPackageIO_b030caea4f.resource(str(input.auxiliary_preset))
	component.appearance_mode = str(input.get("appearance_mode", "enhanced"))
	if input.has("pure_preset"):
		component.pure_preset = VfxPackageIO_b030caea4f.resource(str(input.pure_preset))
	if input.has("native_presets"):
		component.native_presets = VfxPackageIO_b030caea4f.resource(str(input.native_presets))
	# Pure authored data is prepared once, shared read-only across occurrences.
	component.profiles = _prepared_profiles(str(input.axes))
	return component

static func _prepared_profiles(path: String) -> Dictionary:
	var bank: Resource = VfxPackageIO_b030caea4f.resource(path)
	assert(bank != null and not bank.profiles.is_empty(), "Exact authored pose bank must be prepared before construction")
	return bank.profiles

func _ready() -> void:
	if element == "fire":
		source_layers = AttachedFire.new()
		source_layers.variant_id = variant_id
		source_layers.artistic_strength = artistic_strength
		if native_presets != null:
			source_layers.prepared_scene = native_presets.fire[variant_id + ":" + artistic_strength]
			source_layers.prepared_layers = native_presets.fire_layers[variant_id + ":" + artistic_strength]
		add_child(source_layers)
	elif element in ["ice", "electric"] and settings.get("exterior", false):
		exterior = MaskEdge.new()
		exterior.variant_id = str(settings.get("exterior_variant", variant_id))
		exterior.artistic_strength = artistic_strength
		if native_presets != null:
			exterior.material_preset = native_presets.exterior[exterior.variant_id + ":" + artistic_strength]
		add_child(exterior)

	if settings.has("wake_style"):
		wake = SwingWake.make_component({"style": settings.wake_style})
		add_child(wake)
		wake.set_root_path(global_transform)

func set_root_path(value: Transform3D) -> void:
	super.set_root_path(value)
	if is_instance_valid(wake):
		wake.set_root_path(value)

func set_actor_layers(value: Dictionary) -> void:
	raw_layers = value
	# The production renderer observes shader changes around this setter. Install
	# only the disabled prepared program here; actual optical/pose admission and
	# enabled decoration still happen together in sample(). A pending optical
	# readback must not defer this structural notification until a later sample.
	if not _receiver_identity_valid():
		return
	for layer in raw_layers.get("layers", []):
		if layer.get("slot") == binding.render_slot and layer.get("node") is MeshInstance3D \
			and is_instance_valid(layer.node) and layer.get("material") is ShaderMaterial:
			_hook(layer.material)

func _receiver_identity_valid() -> bool:
	return _binding_valid() and raw_layers.get("actor_uuid") == binding.get("holder_uuid") \
		and surface.get("actor", surface.get("actor_uuid")) == binding.get("holder_uuid") \
		and surface.get("item_uuid") == binding.get("item_uuid")

func _hook(material: ShaderMaterial) -> bool:
	if material.shader == null:
		adapter_error = "actual_receiver_has_no_source_shader"
		return false
	if material.shader.get_meta("factory_actor_material", "") == "weapon_layers":
		return true
	var key := material.shader.code.sha256_text()
	if not receiver_programs.programs.has(key):
		adapter_error = "actual_receiver_program_needs_offline_preparation:" + key
		return false
	if not receiver_programs.uniforms.has(key) or not receiver_programs.default_textures.has(key):
		adapter_error = "actual_receiver_interface_needs_offline_preparation:" + key
		return false
	var program: Shader = receiver_programs.programs[key]
	var names: Array = receiver_programs.uniforms[key]
	for required in ["sheet", "frame_uv", "component_units", "component_normal"]:
		if required not in names:
			adapter_error = "actual_receiver_interface_missing:" + required
			return false
	var parameters: Dictionary = {}
	var defaults: Dictionary = receiver_programs.default_textures[key]
	for name in names:
		var value: Variant = material.get_shader_parameter(name)
		if value != null:
			parameters[name] = value
		elif defaults.has(name):
			parameters[name] = defaults[name]
	# The Factory atlas uses this witness when a displayed material changes
	# program. Preserve any existing valid witness/specification.
	if not material.has_meta("factory_original_shader"):
		material.set_meta("factory_original_shader", material.shader)
	if not material.has_meta("factory_material_specification"):
		material.set_meta("factory_material_specification", {})
	program.set_meta("factory_actor_material", "weapon_layers")
	material.shader = program
	for name in parameters:
		material.set_shader_parameter(name, parameters[name])
	return true

func _actual_profile(material: ShaderMaterial) -> Dictionary:
	var current_uv: Variant = material.get_shader_parameter("frame_uv")
	if not current_uv is Vector4:
		adapter_error = "actual_receiver_frame_interface_missing"
		return {}
	var uv: Vector4 = current_uv
	var sheet: Texture2D = material.get_shader_parameter("sheet")
	var source_path := sheet.resource_path if sheet != null else ""
	var selected: Dictionary = {}
	for key in surface.get("pose_key", []):
		if not key is Array or key.size() < 2 or not key[0] is String:
			continue
		var source: String = key[0]
		if not source_path.is_empty() and source != source_path:
			continue
		var frame: Variant = null
		if key[1] is Vector4:
			# Preserved Factory optical sampler's explicitly known old shape.
			frame = key[1]
		elif key.size() == 8 and key[1] is String and key[7] is Array \
			and not key[7].is_empty() and key[7][0] is Vector4:
			# Current receiving entity_surface._source_key: path, profile,
			# five admitted image identities, then optical pose (frame first).
			frame = key[7][0]
		if frame == null or not frame.is_equal_approx(uv) or uv.z <= 0.0 or uv.w <= 0.0:
			continue
		var frame_key := [source.get_base_dir().get_file(), source.get_file().get_basename(),
			roundi(uv.y / uv.w), roundi(uv.x / uv.z)]
		if profiles.has(frame_key):
			if not selected.is_empty() and selected != profiles[frame_key]:
				adapter_error = "current_source_pose_axis_is_ambiguous"
				return {}
			selected = profiles[frame_key]
	return selected

func _endpoint(node: MeshInstance3D, pixel: Vector2, pivot: Vector2, units: float) -> Dictionary:
	var nearest: Dictionary = {}
	var distance := INF
	for point in surface.get("points", []):
		var current := (Vector2(point.pixel) + Vector2(.5, .5)).distance_squared_to(pixel)
		if current < distance:
			distance = current
			nearest = point
	var depth := 0.
	if not nearest.is_empty():
		depth = (node.global_transform.affine_inverse() * nearest.position).z
	var local := Vector3((pixel.x - pivot.x) * units, (pivot.y - pixel.y) * units, depth)
	return {"position": node.global_transform * local, "local_position": local,
		"depth_reference_distance_pixels": sqrt(distance),
		"depth_source": "exact_supported_pixel" if distance < .01 else "nearest_single_supported_pixel" if not nearest.is_empty() else "unknown_sprite_plane"}

func _refresh_attachment_pose() -> void:
	if prepared_attachment.is_empty():
		return
	var node: Variant = prepared_attachment.node.get_ref()
	if not is_instance_valid(node):
		prepared_pose.visible_frame = false
		return
	# Geometry/source revisions are translation-independent. Refresh these two
	# authored anchors from the live draw transform even on a hot source pose.
	prepared_pose.near = node.global_transform * prepared_attachment.near
	prepared_pose.far = node.global_transform * prepared_attachment.far
	prepared_pose.normal = node.global_basis.z.normalized()
	prepared_pose.visible_frame = node.is_visible_in_tree() and prepared_pose.raw_colour_pixels > 0
	prepared_pose.base_depth.position = prepared_pose.near
	prepared_pose.tip_depth.position = prepared_pose.far

func _prepare_current_receiver() -> bool:
	if not _receiver_identity_valid():
		adapter_error = "exact_item_receiver_not_admitted"
		return false
	if surface.has("ready") and not surface.ready:
		adapter_error = "exact_item_optical_source_not_ready:" + str(surface.get("reason", ""))
		return false
	var revision: Array = [raw_layers.get("revision", []), surface.get("gpu_geometry_key", []), binding.item_uuid, binding.holder_uuid]
	if not prepared_revision.is_empty() and revision == prepared_revision:
		_refresh_attachment_pose()
		return prepared_pose.get("visible_frame", false) and not actor_layers.get("layers", []).is_empty()
	var packet := {"actor_uuid": binding.holder_uuid, "layers": []}
	prepared_pose = {}
	prepared_attachment = {}
	for layer in raw_layers.get("layers", []):
		if layer.get("slot") != binding.render_slot or not layer.get("node") is MeshInstance3D \
			or not is_instance_valid(layer.get("node")) \
			or not layer.get("material") is ShaderMaterial:
			continue
		var node: MeshInstance3D = layer.node
		var material: ShaderMaterial = layer.material
		if node.mesh == null or not node.is_visible_in_tree():
			continue
		adapter_error = "current_source_pose_has_no_authored_axis"
		var profile := _actual_profile(material)
		if profile.is_empty():
			continue
		var mask_only: bool = profile.get("source_mask_only", false)
		# A steady material finish needs surviving source pixels, not a guessed
		# hilt or hidden head. Directional exterior/flow/wakes still need the
		# separately admitted endpoints. Fire already has an explicit stationary
		# axis-invalid surface finish; auxiliary families use their own palette.
		var mask_finish := appearance_mode == "enhanced" and (element == "fire" \
			or (auxiliary_preset != null and int(auxiliary_preset.get_shader_parameter("weapon_auxiliary_family")) in [1, 3, 4, 5]))
		if mask_only and not mask_finish:
			adapter_error = "material_only_source_has_no_qualified_finish"
			continue
		var units: float = material.get_shader_parameter("component_units")
		if units <= 0.0 or not _hook(material):
			continue
		var bounds: AABB = node.mesh.get_aabb()
		var pivot := Vector2(-bounds.position.x / units, bounds.end.y / units)
		var hilt_tip := Vector4.ZERO
		if not mask_only:
			hilt_tip = Vector4(profile.base_pixel[0] / 128., profile.base_pixel[1] / 128.,
				profile.tip_pixel[0] / 128., profile.tip_pixel[1] / 128.)
		var candidates: Array = [material]
		var active: Material = node.get_active_material(0)
		if active is ShaderMaterial and active != material:
			if not _hook(active):
				continue
			candidates.append(active)
		for receiver: ShaderMaterial in candidates:
			packet.layers.append({"item_uuid": binding.item_uuid, "slot": binding.render_slot,
				"node": node, "material": receiver, "source": material.get_shader_parameter("sheet"),
				"frame": material.get_shader_parameter("frame_uv"), "normal": material.get_shader_parameter("component_normal"),
				"normal_valid": material.get_shader_parameter("component_normal_valid"), "source_mask_only": mask_only,
				"blade_axis": {"hilt_tip": hilt_tip, "axis_valid": not mask_only}})
		if mask_only:
			# This is material admission on original pixels, not an exterior pose.
			# Zero-length endpoints disable attached particles/edge/wake; no fake
			# source axis or actor-hand proxy is published.
			prepared_pose = {"item_uuid": binding.item_uuid, "holder_uuid": binding.holder_uuid,
				"visible_frame": true, "raw_colour_pixels": profile.alpha_pixels, "near": Vector3.ZERO,
				"far": Vector3.ZERO, "normal": node.global_basis.z.normalized(), "axis_status": "source_mask_only",
				"frame_key": [profile.category, profile.clip, int(profile.row), int(profile.frame)], "source_mask_only": true}
			continue
		var near := _endpoint(node, Vector2(profile.base_pixel[0], profile.base_pixel[1]), pivot, units)
		var far := _endpoint(node, Vector2(profile.tip_pixel[0], profile.tip_pixel[1]), pivot, units)
		prepared_pose = {"item_uuid": binding.item_uuid, "holder_uuid": binding.holder_uuid,
			"near": near.position, "far": far.position, "normal": node.global_basis.z.normalized(),
			"visible_frame": node.visible and profile.alpha_pixels > 0, "raw_colour_pixels": profile.alpha_pixels,
			"supported_points": surface.get("points", []).size(), "swing_active": false,
			"frame_key": [profile.category, profile.clip, int(profile.row), int(profile.frame)],
			"axis_status": profile.axis_status, "base_depth": near, "tip_depth": far}
		prepared_attachment = {"node": weakref(node), "near": near.local_position, "far": far.local_position}
		_refresh_attachment_pose()
	actor_layers = packet
	prepared_revision = revision
	if packet.layers.is_empty():
		return false
	adapter_error = ""
	return true

func sample(seconds: float) -> void:
	if not _prepare_current_receiver():
		_hide(adapter_error)
		if is_instance_valid(source_layers):
			source_layers.set_weapon_binding({})
			source_layers.sample(seconds)
		if is_instance_valid(exterior):
			exterior.set_weapon_binding({})
			exterior.sample(seconds)
		if is_instance_valid(wake):
			wake.set_weapon_binding({})
			wake.sample(seconds)
		return
	var age := float(owner_state.get("source_age_seconds", owner_state.get("owner_age_seconds", seconds)))
	super.sample(age)
	if bound_materials.is_empty():
		# Direct ownership admission covers the complete appearance. A rejected
		# second owner must not leave duplicate fire/edge/wake geometry active.
		if is_instance_valid(source_layers):
			source_layers.set_weapon_binding({})
			source_layers.sample(age)
		if is_instance_valid(exterior):
			exterior.set_weapon_binding({})
			exterior.sample(age)
		if is_instance_valid(wake):
			wake.set_weapon_binding({})
			wake.sample(age)
		return
	if is_instance_valid(source_layers):
		source_layers.set_weapon_binding(binding)
		source_layers.set_sheet_pose(prepared_pose)
		source_layers.sample(age)
	if is_instance_valid(exterior):
		exterior.set_weapon_binding(binding)
		exterior.set_actor_layers(actor_layers)
		exterior.sample(age)
	if is_instance_valid(wake):
		wake.set_weapon_binding(binding)
		wake.set_sheet_pose(prepared_pose)
		wake.sample(age)

func clear() -> void:
	if is_instance_valid(source_layers):
		source_layers.clear()
	if is_instance_valid(exterior):
		exterior.clear()
	if is_instance_valid(wake):
		wake.clear()
	prepared_revision.clear()
	prepared_attachment.clear()
	raw_layers = {}
	super.clear()

func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result.adapter_error = adapter_error
	result.public_inputs = ["weapon_binding", "entity_geometry", "actor_layers", "owner_state", "root_path"]
	result.attached_fire = source_layers.capture_observation() if is_instance_valid(source_layers) else {}
	result.swing_wake = wake.capture_observation() if is_instance_valid(wake) else {}
	result.exterior = exterior.capture_observation() if is_instance_valid(exterior) else {}
	return result

func source_bindings() -> Dictionary:
	var geometry := []
	var source_materials := []
	if is_instance_valid(source_layers):
		for particle in source_layers.flames.get_children():
			geometry.append(particle)
			if particle.material_override is ShaderMaterial:
				source_materials.append(particle.material_override)
	if is_instance_valid(exterior):
		geometry.append(exterior.prepared_draw)
		source_materials.append(exterior.prepared_material)
	if is_instance_valid(wake):
		var declared: Dictionary = wake.source_bindings()
		geometry.append_array(declared.geometry)
		source_materials.append_array(declared.materials)
	return {"geometry": geometry, "materials": source_materials, "lights": [], "static_material_topology": true}

const VfxPackageIO_b030caea4f = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
