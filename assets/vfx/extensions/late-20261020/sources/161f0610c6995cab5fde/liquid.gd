extends Node3D
## Exact prepared native source; per-owner field/clock/link textures carry the
## original float32 operands. Footprints and committed cells remain live.
const Conduction = preload("res://assets/vfx/extensions/late-20261020/sources/b41d635a74436d1607bc/conduction.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
const Events = preload("res://assets/vfx/extensions/late-20261020/sources/fb7d771675b2f9a86e34/committed_surface_events.gd")
var bank: Resource
var settings: Dictionary
var source_root: Node3D
var geometry: Array = []
var materials: Array = []
var plane: MeshInstance3D
var droplets: MultiMeshInstance3D
var material: ShaderMaterial
var network: Node3D
var ribbons: Array = []
var contact_groups: Array = []
var endpoint_points: Array[Vector3] = []
var electric_field_texture: ImageTexture
var network_ranges: Array = []
var network_delays := PackedFloat64Array()
var core_draws: Array[MeshInstance3D] = []
var glow_draws: Array[MeshInstance3D] = []
var interior_network := false
var network_clock := 0.0
var network_opacity := 1.0
var plumes: Array = []
var flames: Array = []
var world_process_units: Array = []
var field_texture: ImageTexture
var clock_texture: ImageTexture
var link_texture: ImageTexture
var field_image: Image
var clock_image: Image
var link_image: Image
var fluid := PackedVector4Array()
var live_particles := PackedVector4Array()
var support_points: Array[Vector3] = []
var fluid_finite := true
var edge_visibility := PackedByteArray()
var conduction_layout := {}
var conduction_fluid := PackedVector4Array()
var local_links := PackedVector4Array()
var transition_state := Events.new()
var events: Array = []
var steam_windows_by_cell := {}
var state_values := {}
var prepared_layer_mask := 0
var last_source_cursor := -INF
var previous_age := -INF
var previous_transform := Transform3D.IDENTITY
var previous_unit_scale := 1.0
var dirty := true
var links_dirty := true
var range_error := false

static func preparation_resources(input: Dictionary) -> Array:
	return [String(input.liquid_bank)]

static func make_component(input: Dictionary) -> Node3D:
	return build(input, VfxPackageIO_161f0610c6.resource("res://assets/vfx/extensions/late-20261020/sources/161f0610c6995cab5fde/liquid.gd"))

static func build(input: Dictionary, constructor: Script) -> Node3D:
	Profile.begin("liquid_component_new")
	var instance: Node3D = constructor.new()
	Profile.end("liquid_component_new")
	Profile.begin("liquid_bank_bind")
	instance.bank = VfxPackageIO_161f0610c6.resource(String(input.liquid_bank))
	assert(instance.bank != null and instance.bank.program != null, "Exact native liquid bank required")
	instance.settings = instance.bank.settings.duplicate(true)
	instance.interior_network = instance.settings.get("charge_pattern", "") == "interior_network"
	instance.network_ranges = instance.bank.layout.get("network_ranges", [])
	for edge in instance.bank.layout.get("network_edges", []): instance.network_delays.append(float(edge.get("delay",0.0)))
	Profile.end("liquid_bank_bind")
	var made: Dictionary = instance.bank.program.instantiate(instance.bank.operands, Profile.current != null)
	instance.source_root = made.root
	instance.geometry = made.geometry
	instance.materials = made.all_materials
	instance.plane = made.plane
	instance.droplets = made.droplets
	instance.material = made.main
	instance.network = made.network
	instance.ribbons = made.ribbons
	instance.edge_visibility.resize(made.ribbons.size())
	for index in made.ribbons.size():
		instance.edge_visibility[index] = int(made.ribbons[index].core.visible)
		instance.core_draws.append(made.ribbons[index].core)
		instance.glow_draws.append(made.ribbons[index].glow)
	instance.contact_groups = made.contact_groups
	instance.plumes = made.plumes
	instance.flames = made.flames
	instance.world_process_units = made.world_process_units
	Profile.begin("liquid_component_child_registration")
	instance.add_child(instance.source_root)
	Profile.end("liquid_component_child_registration")
	Profile.begin("liquid_private_textures")
	instance._initialize_textures(made)
	Profile.end("liquid_private_textures")
	if instance.bank.layout.family != "liquid_state":
		instance._replace_transition_events(instance.settings.get("events", []))
	return instance

func _initialize_textures(made: Dictionary) -> void:
	var initial := PackedVector4Array()
	initial.resize(160)
	field_image = Image.create_from_data(160, 1, false, Image.FORMAT_RGBAF, initial.to_byte_array())
	field_texture = ImageTexture.create_from_image(field_image)
	electric_field_texture = ImageTexture.create_from_image(field_image)
	var clock := PackedVector4Array([Vector4.ZERO, Vector4.ZERO])
	clock_image = Image.create_from_data(2, 1, false, Image.FORMAT_RGBAF, clock.to_byte_array())
	clock_texture = ImageTexture.create_from_image(clock_image)
	local_links.resize(2 * maxi(1, ribbons.size()))
	link_image = Image.create_from_data(2, maxi(1, ribbons.size()), false, Image.FORMAT_RGBAF, local_links.to_byte_array())
	link_texture = ImageTexture.create_from_image(link_image)
	for selected: ShaderMaterial in made.field_materials:
		selected.set_shader_parameter("factory_liquid_field_texture", electric_field_texture if selected.has_meta("factory_liquid_electric_material") else field_texture)
	for selected: ShaderMaterial in made.clock_materials:
		selected.set_shader_parameter("factory_liquid_clock_texture", clock_texture)
	for selected: ShaderMaterial in made.link_materials:
		selected.set_shader_parameter("factory_liquid_link_texture", link_texture)

func prepare_source_layer_mask(layer_mask: int) -> void:
	assert(not is_inside_tree() and layer_mask > 0)
	for piece: GeometryInstance3D in geometry:
		if piece.layers != 0 and piece.layers != layer_mask: piece.layers = layer_mask
	prepared_layer_mask = layer_mask

func has_verified_stable_paths() -> bool:
	return bank.stable_paths_verified

func source_bindings() -> Dictionary:
	return {"geometry": geometry, "materials": materials, "lights": [],
		"static_material_topology": true, "prepared_source_layer_mask": prepared_layer_mask}

func _replace_live_particles(value: PackedVector4Array) -> void:
	if value.size() != 160:
		push_error("Native liquid field requires exactly 160 source particle samples")
		return
	if value == live_particles: return
	live_particles = value.duplicate()
	dirty = true

func _replace_transition_events(value: Array) -> void:
	var allowed := ["ignite", "douse", "clear"] if bank.layout.family == "oil_liquid_reflection" else ["freeze", "thaw", "charge", "vaporize", "clear", "uncharge"]
	var error: String = transition_state.replace(value, allowed)
	if not error.is_empty():
		push_error(error)
		return
	events = transition_state.events
	steam_windows_by_cell.clear()
	for event in events:
		if event.operation not in ["vaporize", "douse"]: continue
		for admitted in event.cells:
			var cell := Vector2(admitted[0], admitted[1])
			if not steam_windows_by_cell.has(cell): steam_windows_by_cell[cell] = []
			# Array scalars retain original64-bit times, unlike Vector2 storage.
			steam_windows_by_cell[cell].append([float(event.at), float(event.get("steam_seconds", 2.0))])
	# All original state uniforms remain; this is a committed-input operation,
	# never a per-frame walk through source materials.
	transition_state.bind(material)
	for selected: ShaderMaterial in materials:
		if selected.has_meta("factory_liquid_electric_material"):
			transition_state.bind(selected)
	dirty = true

func _source_field(cursor: float) -> PackedVector4Array:
	var lower := floori(cursor)
	var upper := mini(bank.source_frames - 1, lower + 1)
	var blend := fposmod(cursor, 1.0)
	var values := PackedVector4Array()
	var source_samples: PackedVector3Array = bank.frames.particles
	values.resize(160)
	for index in 160:
		var point: Vector3 = source_samples[lower * 160 + index].lerp(source_samples[upper * 160 + index], blend)
		values[index] = Vector4(point.x, point.y, point.z, 1.0)
	return values

func _set_fluid(value: PackedVector4Array) -> void:
	if fluid == value: return
	fluid = value
	support_points.clear()
	fluid_finite = true
	for actual in fluid:
		fluid_finite = fluid_finite and actual.is_finite()
		if actual.y < .03: support_points.append(Vector3(actual.x, actual.y, actual.z))
	field_image.set_data(160, 1, false, Image.FORMAT_RGBAF, fluid.to_byte_array())
	field_texture.update(field_image)
	links_dirty = true

func _charge_can_be_visible(seconds: float) -> bool:
	if bank.layout.family == "liquid_state": return true
	for event in events:
		if float(event.at) > seconds: break
		if event.operation == "charge": return true
	return false

func _sample_electricity(seconds: float, retirement: float) -> void:
	if network == null: return
	var interior: bool = interior_network
	var charge_age := seconds - float(settings.charge_at)
	var active := _charge_can_be_visible(seconds) and charge_age >= 0.0 and retirement > .01
	network.visible = active
	if interior and support_points.size() < 2:
		network.hide()
		return
	# Preserve the original noninterior source's held network when fewer than
	# twelve supports exist: no invented age/field advance into dormant draws.
	if not active or support_points.size() < (2 if interior else 12): return
	network_clock = charge_age
	network_opacity = retirement if interior else float(bank.layout.network_settings.get("opacity", 1.0))
	if conduction_fluid != fluid:
		if interior: conduction_layout = Conduction.layout_from_actual_support(support_points,fluid,fluid_finite)
		conduction_fluid = fluid
		electric_field_texture.update(field_image)
		links_dirty = true
	var transform_now := network.global_transform
	if transform_now != previous_transform:
		previous_transform = transform_now
		links_dirty = true
	if links_dirty:
		var points: Array = []
		var branches: Array = []
		if interior:
			points = conduction_layout.get("points", [])
			branches = conduction_layout.get("edges", [])
		else:
			for index in 12:
				var angle := TAU * float(index) / 12.0
				var desired := Vector3(cos(angle) * 1.15, 0, sin(angle) * 1.15)
				var nearest: Vector3 = support_points[0]
				for actual: Vector3 in support_points:
					if actual.distance_squared_to(desired) < nearest.distance_squared_to(desired): nearest = actual
				points.append(nearest + Vector3.UP * .04)
				branches.append(Vector2i(index, (index + 1) % 12))
		var inverse := transform_now.affine_inverse()
		var source_transform := global_transform
		endpoint_points.clear()
		for point: Vector3 in points:
			# Preserve the actual source world/network inverse float32 round-trip.
			endpoint_points.append(inverse * (source_transform * point))
		for index in ribbons.size():
			var edge := Vector2i(-1, -1) if index >= branches.size() else Vector2i(branches[index])
			var valid := edge.x >= 0 and edge.y >= 0 and edge.x < endpoint_points.size() and edge.y < endpoint_points.size()
			if valid and endpoint_points[edge.x].distance_to(endpoint_points[edge.y]) > float(network_ranges[index]):
				if not range_error:
					push_error("GPU electric range exceeds prepared local detail capacity; do not clamp a valid spell")
					range_error = true
				valid = false
			if bool(edge_visibility[index]) != valid:
				core_draws[index].visible = valid
				glow_draws[index].visible = valid
				edge_visibility[index] = int(valid)
			if valid:
				var start := endpoint_points[edge.x]
				var target := endpoint_points[edge.y]
				local_links[index * 2] = Vector4(start.x, start.y, start.z, network_delays[index])
				local_links[index * 2 + 1] = Vector4(target.x, target.y, target.z, 1.0)
		link_image.set_data(2, ribbons.size(), false, Image.FORMAT_RGBAF, local_links.to_byte_array())
		link_texture.update(link_image)
		links_dirty = false
	if not interior: _sample_contacts(charge_age)

func _sample_contacts(seconds: float) -> void:
	# Original ring endpoint contacts, finite and native. Interior source marks
	# every endpoint contact_enabled=false and never executes this path.
	for group in contact_groups:
		for draw in group: draw.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	var contacts := {}
	for index in ribbons.size():
		if not ribbons[index].core.visible: continue
		var start := local_links[index * 2]
		var target := local_links[index * 2 + 1]
		var distance := Vector3(start.x,start.y,start.z).distance_to(Vector3(target.x,target.y,target.z))
		var reached := float(bank.layout.network_edges[index].get("delay",0.0)) + maxf(.045,distance/float(bank.layout.network_settings.get("speed",26.0)))
		if seconds >= reached:
			var endpoint := int(bank.layout.network_edges[index].to)
			contacts[endpoint] = maxf(float(contacts.get(endpoint,-INF)),reached)
	for index in contacts:
		var age := seconds - float(contacts[index])
		var envelope := (1.0-smoothstep(.20,.72,age))*smoothstep(0.0,.025,age)*network_opacity
		if envelope < .001: continue
		for draw_index in contact_groups[index].size():
			var draw: MeshInstance3D = contact_groups[index][draw_index]
			draw.position = endpoint_points[index]
			draw.scale = Vector3.ONE * [.72,.40,.85][draw_index] * (1.0+age*.25)
			draw.set_instance_shader_parameter("factory_liquid_contact_alpha",envelope*[.55,.42,.18][draw_index])

func _sample_emitters(seconds: float, retirement: float) -> void:
	for index in plumes.size():
		var active := false
		var plume: GPUParticles3D = plumes[index]
		if not support_points.is_empty():
			var point: Vector3 = support_points[(index * 13) % support_points.size()]
			plume.position = point + Vector3.UP * .03
			var cell := Vector2(floor(point.x + .5), floor(point.z + .5))
			var windows: Variant = steam_windows_by_cell.get(cell)
			if windows != null:
				for window in windows:
					var age := seconds - float(window[0])
					if age >= 0.0 and age < float(window[1]): active = true
		if plume.emitting != active: plume.emitting = active
	for index in flames.size():
		var strength := 0.0
		if not support_points.is_empty():
			var point: Vector3 = support_points[(index * 13 + 4) % support_points.size()]
			flames[index].position = point + Vector3.UP * .025
			var state: Vector4 = transition_state.state_at(Vector2(point.x, point.z), seconds)
			strength = state.z * (1.0 - state.w) * retirement
		var emitter: GPUParticles3D = flames[index]
		var active := strength > .01
		if active and not emitter.emitting: emitter.restart()
		if emitter.emitting != active: emitter.emitting = active
		emitter.visible = active
		emitter.material_override.set_shader_parameter("emitter_envelope", clampf(strength, 0.0, 1.0))

func sample(seconds: float) -> void:
	if not is_finite(seconds): return
	var unit_scale := global_basis.get_scale().x
	if unit_scale != previous_unit_scale:
		for record in world_process_units:
			for uniform in record.values:
				record.material.set_shader_parameter(uniform, record.values[uniform] * unit_scale)
		previous_unit_scale = unit_scale
	if seconds == previous_age and not dirty and (network == null or network.global_transform == previous_transform): return
	previous_age = seconds
	var freeze_at := float(settings.get("freeze_at", 6.0))
	var source_time := minf(seconds, freeze_at)
	var cursor := clampf(source_time * bank.source_fps, 0.0, bank.source_frames - 1.0)
	if not live_particles.is_empty():
		_set_fluid(live_particles)
	elif cursor != last_source_cursor:
		_set_fluid(_source_field(cursor))
	last_source_cursor = cursor
	var thaw := smoothstep(float(settings.get("thaw_at", 8.0)), float(settings.get("thaw_at", 8.0)) + .75, seconds)
	var remove_at := float(settings.get("remove_at", 10.0))
	var retirement := 1.0 - smoothstep(remove_at, remove_at + .6, seconds)
	material.set_shader_parameter("freeze_fraction", float(seconds >= freeze_at))
	material.set_shader_parameter("transition_seconds", maxf(0.0, seconds - freeze_at))
	material.set_shader_parameter("thaw_fraction", thaw)
	material.set_shader_parameter("retirement", retirement)
	_sample_electricity(seconds, retirement)
	var clocks := PackedVector4Array([Vector4(source_time, seconds, network_clock, retirement), Vector4(seconds, seconds, network_opacity, 0.0)])
	clock_image.set_data(2, 1, false, Image.FORMAT_RGBAF, clocks.to_byte_array())
	clock_texture.update(clock_image)
	_sample_emitters(seconds, retirement)
	state_values = {"source_frame": cursor, "frozen": seconds >= freeze_at and thaw < 1.0,
		"thaw": thaw, "retirement": retirement, "source_particles": 160,
		"coverage": "original density smoothstep(.48,.66), independent of material state"}
	if bank.layout.family != "liquid_state":
		state_values.transition_cell_records = transition_state.contacts.size()
		state_values.footprint_owner = "source density; retained through freeze, thaw and charge; consumed locally on vaporize"
	if bank.layout.family == "oil_liquid_reflection": state_values.fire_emitters = flames.size()
	dirty = false

func refresh_live_inputs(seconds: float) -> void:
	# Opt-in held-age input refresh. Only this component's committed operands
	# and source state are updated; no native particle/animation advance here.
	sample(seconds)

func capture_observation() -> Dictionary:
	return state_values.duplicate(true)

const VfxPackageIO_161f0610c6 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
