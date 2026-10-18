extends "res://assets/vfx/sources/038f154b06649f707e70/live_network.gd"
## Immutable GPU main/fork, hand and measured body ribbons; source materials stay.
## CPU supplies clocks/endpoints and uploads actual geometry only when it changes.
const Ribbon = preload("res://assets/vfx/sources/a15ee27956ee27b7e1c4/electric_ribbon.gd")
var banks: Array = []
var range_error := false
var body_draws: Array = []
var body_data: Array = []
var body_uploads := 0

var link_uniform_keys: Dictionary = {}
var common_uniform_key: Array = []


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_c43d754ae6.resource("res://assets/vfx/sources/c43d754ae69cc0329592/electric_network.gd").new()
	node.settings = input.duplicate(true)
	node._build()
	return node


func _build() -> void:
	super._build()
	for index in ribbons.size():
		var paths: Array = settings.get("gpu_shape_banks", [])
		var path: String = paths[index % paths.size()] if not paths.is_empty() else "factory-path:authoring/gpu-electric-v370/banks/" + ("heavy" if settings.get("heavy", false) else "chain") + "-%d.res" % (int(settings.get("seed",47291))+index*773)
		var bank: Resource = VfxPackageIO_c43d754ae6.resource(path)
		assert(bank != null and bank.primary_lanes == (5 if settings.get("heavy", false) else 1))
		banks.append(bank)
		for kind in ["core", "glow"]:
			var draw: MeshInstance3D = ribbons[index][kind]
			draw.name = "Electric"+kind.capitalize()+str(index)
			draw.mesh = Ribbon.mesh(bank, kind == "glow")
			draw.custom_aabb = AABB(Vector3.ONE * -70.0, Vector3.ONE * 140.0)
			Ribbon.prepare(draw.material_override, bank, kind == "glow")
	contact_arcs.name = "MeasuredContactArcs"
	hand_arcs.name = "SourceHandCoils"
	hand_arcs.mesh = Ribbon.auxiliary_mesh("hand")
	hand_arcs.custom_aabb = AABB(Vector3.ONE*-70.0,Vector3.ONE*140.0)
	Ribbon.prepare_auxiliary(hand_arcs.material_override,"hand")
	var contact_material: ShaderMaterial = contact_arcs.material_override.duplicate(true)
	for index in contact_draws.size():
		var draw: MeshInstance3D = contact_arcs if index == 0 else _draw(contact_material.duplicate(true))
		draw.name = "MeasuredContactArcs%d" % index
		draw.mesh = Ribbon.auxiliary_mesh("contact")
		draw.custom_aabb = AABB(Vector3.ONE*-70.0,Vector3.ONE*140.0)
		Ribbon.prepare_auxiliary(draw.material_override,"contact")
		draw.hide()
		body_draws.append(draw)
		body_data.append({})
	# The parent creates this off-tree CPU drawing helper. Its functions are no
	# longer used by this constructor and its native resources need no lifetime.
	drawer.free()
	drawer = null


func set_link_edges(value: Array) -> bool:
	if value.size() > ribbons.size():
		return false
	for index in ribbons.size():
		ribbons[index].edge = value[index].duplicate(true) if index < value.size() else {"from": -1, "to": -1}
	return true


func sample(seconds: float) -> void:
	last_paths.clear()
	contact_state.clear()
	for material in materials:
		material.set_shader_parameter("electric_clock", seconds)
	# All ribbons, hand coils and measured contact arcs have immutable meshes.
	# Target geometry data changes only with actual pose/view/scale/layer inputs.
	for draw in body_draws:
		draw.hide()
	for group in contact_draws:
		for draw in group:
			draw.material_override.set_shader_parameter("alpha_mult", 0.0)
	var contacts := {}
	var windows := PackedVector4Array()
	for window in settings.get("secondary_windows", []):
		windows.append(Vector4(window[0], window[1], window[2], 0))
	var common: Array = [float(settings.get("speed", 26.0)), float(settings.get("width", .32)),
		bool(settings.get("persistent", false)), float(settings.get("opacity", 1.0)), windows,
		float(settings.get("link_width_gain", 1.0)),
		1.0 if settings.get("heavy", false) else float(settings.get("fork_width_gain", 1.0)),
		settings.get("plane_y", 1.0e20) if settings.get("plane_y") != null else 1.0e20]
	if common != common_uniform_key:
		common_uniform_key = common.duplicate(true)
		for ribbon in ribbons:
			for kind in ["core", "glow"]:
				var material: ShaderMaterial = ribbon[kind].material_override
				material.set_shader_parameter("gpu_speed", common[0])
				material.set_shader_parameter("gpu_width", common[1])
				material.set_shader_parameter("gpu_persistent", common[2])
				material.set_shader_parameter("gpu_opacity", common[3])
				material.set_shader_parameter("gpu_secondary_mode", windows.size() == 4)
				if windows.size() == 4:
					material.set_shader_parameter("gpu_secondary_windows", windows)
				material.set_shader_parameter("gpu_link_width_gain", common[5])
				material.set_shader_parameter("gpu_fork_width_gain", common[6])
				material.set_shader_parameter("gpu_plane_y", common[7])
	for index in ribbons.size():
		var ribbon: Dictionary = ribbons[index]
		var edge: Dictionary = ribbon.edge
		var valid: bool = int(edge.from) >= 0 and int(edge.to) >= 0 and int(edge.from) < endpoints.size() and int(edge.to) < endpoints.size()
		for kind in ["core", "glow"]:
			ribbon[kind].visible = valid
		if not valid:
			continue
		var start := _local_point(int(edge.from))
		var target := _local_point(int(edge.to))
		var distance := start.distance_to(target)
		if distance > float(banks[index].reference_length_cells):
			if not range_error:
				push_error("GPU electric range exceeds prepared local detail capacity; do not clamp a valid spell")
				range_error = true
			for kind in ["core", "glow"]:
				ribbon[kind].hide()
			continue
		var delay: float = edge.get("delay", 0.0)
		var travel := maxf(.045, distance / float(settings.get("speed", 26.0)))
		var link_key := [start, target, delay]
		if link_uniform_keys.get(index) != link_key:
			link_uniform_keys[index] = link_key
			for kind in ["core", "glow"]:
				var material: ShaderMaterial = ribbon[kind].material_override
				material.set_shader_parameter("gpu_link_from", start)
				material.set_shader_parameter("gpu_link_to", target)
				material.set_shader_parameter("gpu_edge_delay", delay)
		if seconds >= delay + travel and settings.get("contact_from_edges", true):
			contacts[edge.to] = maxf(float(contacts.get(edge.to, -INF)), delay+travel)
		last_paths.append({"edge": index, "start": start, "target": target,
			"reveal": clampf((seconds-delay)/travel, 0.0, 1.0), "geometry_owner": "GPU static ribbon"})
	for contact in settings.get("contact_schedule", []):
		if seconds >= float(contact.at):
			contacts[contact.endpoint] = maxf(float(contacts.get(contact.endpoint, -INF)), float(contact.at))
	for index in contacts:
		if int(index)<endpoints.size() and endpoints[index].get("contact_enabled", true):
			_contact(int(index), seconds-float(contacts[index]))
	var amount := smoothstep(-.28, -.04, seconds)*(1.0-smoothstep(.12, .45, seconds)) if settings.get("charge_coil", true) else 0.0
	amount *= float(settings.get("opacity", 1.0))
	if endpoints.size() < 2:
		amount = 0.0
	hand_arcs.material_override.set_shader_parameter("alpha_mult", amount)
	if not endpoints.is_empty():
		hand_arcs.material_override.set_shader_parameter("gpu_hand_origin", _local_point(0))


func _contact(index: int, age: float) -> void:
	var envelope := (1.0-smoothstep(.20,.72,age))*smoothstep(0.0,.025,age)*float(settings.get("opacity",1.0))
	if envelope < .001:
		return
	contact_state.append({"endpoint":index,"age":age,"strength":envelope})
	if index < contact_draws.size():
		var gain: float = settings.get("contact_scale_gain", 1.0)
		for draw_index in contact_draws[index].size():
			var draw: MeshInstance3D = contact_draws[index][draw_index]
			draw.position = _local_point(index)
			draw.scale = Vector3.ONE*[.72,.40,.85][draw_index]*(1.0+age*.25)*gain
			draw.material_override.set_shader_parameter("alpha_mult",envelope*[.55,.42,.18][draw_index])
	var surface: Dictionary = endpoints[index].get("surface",{})
	var points: Array = surface.get("points",[])
	if points.is_empty() or index >= body_draws.size():
		return
	var key: Array = surface.get("gpu_geometry_key",[])
	if key.is_empty() or body_data[index].get("key") != key or body_data[index].get("count") != points.size():
		_prepare_body_data(index,surface,points,key)
	var draw: MeshInstance3D = body_draws[index]
	var material: ShaderMaterial = draw.material_override
	material.set_shader_parameter("gpu_contact_points",body_data[index].texture)
	material.set_shader_parameter("gpu_contact_count",points.size())
	material.set_shader_parameter("gpu_contact_origin",surface.get("origin",endpoints[index].point))
	material.set_shader_parameter("gpu_contact_to_local",Projection(global_transform.affine_inverse()))
	material.set_shader_parameter("gpu_contact_age",age)
	material.set_shader_parameter("alpha_mult",envelope*.8)
	draw.show()


func _prepare_body_data(index: int, surface: Dictionary, points: Array, key: Array) -> void:
	var width := mini(256,points.size())
	var rows := ceili(float(points.size())/width)
	var image := Image.create(width,rows*2,false,Image.FORMAT_RGBAF)
	var origin: Vector3 = surface.get("origin",endpoints[index].point)
	for number in points.size():
		var point: Vector3 = points[number].position-origin
		var normal: Vector3 = points[number].normal
		image.set_pixel(number%width,(number/width)*2,Color(point.x,point.y,point.z,1))
		image.set_pixel(number%width,(number/width)*2+1,Color(normal.x,normal.y,normal.z,1))
	var texture: ImageTexture = body_data[index].get("texture")
	if texture != null and Vector2i(texture.get_size()) == image.get_size():
		texture.update(image)
	else:
		texture = ImageTexture.create_from_image(image)
	body_data[index] = {"texture":texture,"count":points.size(),"key":key.duplicate(true)}
	body_uploads += 1


func capture_observation() -> Dictionary:
	return {"primary_and_fork_geometry": "GPU deformation of shared immutable meshes", "endpoints": endpoints.size(),
		"edges": ribbons.size(), "range_error": range_error, "maximum_range_cells": banks[0].reference_length_cells if not banks.is_empty() else 0.0,
		"remaining_cpu_geometry": "No per-frame mesh generation; actor point/normal data texture updates on pose/view/scale/layer changes",
		"body_geometry_uploads": body_uploads,
		"source_materials_and_layers_retained": true, "fixed_encounter_baked": false}

const VfxPackageIO_c43d754ae6 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
