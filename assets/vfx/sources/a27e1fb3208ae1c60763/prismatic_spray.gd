extends Node3D
## A supplied cone and admitted per-recipient color outcomes. No dice, target
## discovery, saves, damage/condition creation, petrification or death solver.

const StreakShader = preload("res://assets/vfx/sources/c98fc86951ff72e19703/spectral_streak.gdshader")

var settings: Dictionary = {}
var endpoints: Array = []
var live_outcomes: Array = []
var live_supplied: bool = false
var cast_present: bool = true
var rays: Array[MeshInstance3D] = []
var ray_materials: Array[ShaderMaterial] = []
var contacts: Array[MeshInstance3D] = []
var contact_materials: Array[ShaderMaterial] = []
var observed: Dictionary = {}
var age_seconds: float = 0.0


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_a27e1fb320.resource("res://assets/vfx/sources/a27e1fb3208ae1c60763/prismatic_spray.gd").new()
	effect.settings = input.duplicate(true)
	effect.prepare()
	return effect


func prepare() -> void:
	assert(settings.palette.size() == 7, "Every explicit actual Spray rules color is required")
	assert(is_equal_approx(float(settings.length_cells), 12.0), "Current supplied 60-foot Spray source contract is 12 five-foot cells")
	assert(str(settings.color7_treatment) == "violet rule result, neutral visual treatment", "Color7 retains its rules identity with the explicit neutral filament palette decision")
	cast_present = bool(settings.get("cast_present", true))
	for index in 21:
		var mesh: MeshInstance3D = _piece("SpectralConeRay" + str(index), index % 7, index)
		rays.append(mesh)
		ray_materials.append(mesh.material_override)
	for index in int(settings.recipient_capacity) * 2:
		var mesh: MeshInstance3D = _piece("AdmittedRecipientColor" + str(index), 0, index)
		contacts.append(mesh)
		contact_materials.append(mesh.material_override)
	visible = false


func _piece(label: String, color_index: int, noise_index: int) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = ArrayMesh.new()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = StreakShader
	material.set_shader_parameter("authored_noise", VfxPackageIO_a27e1fb320.resource(settings.noise_texture))
	material.set_shader_parameter("ray_color", Color(settings.palette[color_index]))
	material.set_shader_parameter("ray_shadow", Color(settings.shadows[color_index]))
	material.set_shader_parameter("ray_index", float(noise_index))
	mesh.material_override = material
	add_child(mesh)
	return mesh


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func set_recipient_outcomes(cast_uuid: String, source_uuid: String, values: Array) -> bool:
	if cast_uuid != str(settings.cast_uuid) or source_uuid != str(settings.source_uuid):
		return false
	if values.size() > int(settings.recipient_capacity):
		return false
	var recipients: Dictionary = {}
	for outcome in values:
		if not outcome is Dictionary or str(outcome.get("recipient_uuid", "")).is_empty():
			return false
		if recipients.has(outcome.recipient_uuid):
			return false
		if settings.recipient_bindings.get(outcome.recipient_uuid, -1) != outcome.get("endpoint_index"):
			return false
		recipients[outcome.recipient_uuid] = true
		if not outcome.get("colors") is Array or outcome.colors.is_empty() or outcome.colors.size() > 2:
			return false
		var colors: Dictionary = {}
		for color in outcome.colors:
			if typeof(color) != TYPE_INT or color < 1 or color > 7 or colors.has(color):
				return false
			colors[color] = true
		if typeof(outcome.get("endpoint_index")) != TYPE_INT or outcome.endpoint_index < 3:
			return false
		if typeof(outcome.get("application_admitted")) != TYPE_BOOL or typeof(outcome.get("at_seconds")) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	live_outcomes = values.duplicate(true)
	live_supplied = true
	sample(age_seconds)
	return true


func set_cast_presence(cast_uuid: String, source_uuid: String, present: bool) -> bool:
	if cast_uuid != str(settings.cast_uuid) or source_uuid != str(settings.source_uuid):
		return false
	cast_present = present
	sample(age_seconds)
	return true


func _strip(points: PackedVector3Array, width: float, normal: Vector3) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size() - 1):
		for corner in [Vector2i(index, 0), Vector2i(index, 1), Vector2i(index + 1, 1), Vector2i(index, 0), Vector2i(index + 1, 1), Vector2i(index + 1, 0)]:
			var along: float = float(corner.x) / float(points.size() - 1)
			var tangent: Vector3 = (points[mini(corner.x + 1, points.size() - 1)] - points[maxi(0, corner.x - 1)]).normalized()
			var across: Vector3 = tangent.cross(normal).normalized()
			if across.length() < 0.1:
				across = Vector3.RIGHT
			surface.set_uv(Vector2(float(corner.y), along))
			surface.set_normal(normal)
			surface.add_vertex(points[corner.x] + across * width * sin(along * PI) * (float(corner.y) - 0.5))
	return surface.commit()


func sample(seconds: float) -> void:
	age_seconds = seconds
	if endpoints.size() < 3:
		visible = false
		return
	var source: Vector3 = endpoints[0].point
	var ground: Vector3 = endpoints[1].point
	var aim: Vector3 = endpoints[2].point
	var direction: Vector3 = Vector3(aim.x - ground.x, 0.0, aim.z - ground.z).normalized()
	if direction.is_zero_approx():
		visible = false
		return
	var inverse: Transform3D = global_transform.affine_inverse()
	var side: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var reach: float = smoothstep(0.0, 0.5, seconds)
	var envelope: float = smoothstep(0.0, 0.08, seconds) * (1.0 - smoothstep(0.72, 1.18, seconds))
	visible = cast_present and seconds >= 0.0 and seconds < float(settings.seconds)
	var minimum_y: float = INF
	for index in rays.size():
		var sector: float = (float(index) + 0.5) / float(rays.size()) - 0.5
		minimum_y=minf(minimum_y,_write_ray(index,source,ground,direction,side,inverse,reach))
		ray_materials[index].set_shader_parameter("source_seconds", seconds)
		ray_materials[index].set_shader_parameter("opacity", envelope * 0.85)
		rays[index].visible = envelope > 0.001
	var outcomes: Array = live_outcomes if live_supplied else settings.get("supplied_outcomes", [])
	var active_contacts: Array = []
	for piece in contacts:
		piece.visible = false
	var next: int = 0
	for outcome in outcomes:
		if not bool(outcome.get("application_admitted", false)) or outcome.endpoint_index >= endpoints.size():
			continue
		var contact_age: float = seconds - float(outcome.at_seconds)
		var opacity: float = smoothstep(0.0, 0.055, contact_age) * (1.0 - smoothstep(0.16, 0.42, contact_age))
		for color in outcome.colors:
			if next >= contacts.size():
				break
			var recipient: Vector3 = endpoints[outcome.endpoint_index].point
			_write_contact(next,recipient,direction,side,inverse,color)
			contacts[next].visible = contact_age >= 0.0 and opacity > 0.001
			contact_materials[next].set_shader_parameter("source_seconds", contact_age)
			contact_materials[next].set_shader_parameter("ray_color", Color(settings.palette[int(color) - 1]))
			contact_materials[next].set_shader_parameter("ray_shadow", Color(settings.shadows[int(color) - 1]))
			contact_materials[next].set_shader_parameter("opacity", opacity)
			if contacts[next].visible:
				active_contacts.append({"recipient_uuid": outcome.recipient_uuid, "color": color, "supplied_result": outcome.get("result", "unspecified")})
			next += 1
	observed = {"study": "prismatic_spray", "cast_uuid": settings.cast_uuid, "source_uuid": settings.source_uuid,
		"source_hand_world": source, "aim_world": aim, "length_cells": settings.length_cells,
		"live_endpoints": endpoints.size(), "rays": rays.size(), "active_contacts": active_contacts,
		"minimum_geometry_y": minimum_y, "ground_y": ground.y, "visible": visible,
		"ray_visible": envelope > 0.001 and visible, "violet_meaning": "actual color7/WIS/Blinded rule retains identity; neutral silver/charcoal filament visual treatment",
		"purple_rendered": false, "seventh_outcome_included": true, "color7_treatment": settings.color7_treatment,
		"random_rolls": false, "condition_creation": false, "damage_creation": false, "death_creation": false}


func capture_observation() -> Dictionary:
	return observed.duplicate(true)

func _write_ray(index: int, source: Vector3, ground: Vector3, direction: Vector3, side: Vector3, inverse: Transform3D, reach: float) -> float:
	var minimum:=INF
	var sector: float=(float(index)+.5)/float(rays.size())-.5
	var points := PackedVector3Array()
	for step in 25:
		var along: float = float(step) / 24.0
		var distance: float = along * float(settings.length_cells) * reach
		var fan: float = sector * distance
		var drift: float = sin(along * PI) * sin(float(index) * 1.7 + along * 3.0) * distance * 0.008
		var world_point: Vector3 = ground + direction * distance + side * (fan + drift) + (source - ground) * (1.0 - along)
		world_point.y = lerpf(source.y, ground.y + 0.16 + float(index % 3) * 0.32, along) + sin(along * PI) * float(index % 3) * 0.22
		minimum = minf(minimum, world_point.y)
		points.append(inverse * world_point)
	rays[index].mesh = _strip(points, 0.045 if index % 7 == 6 else 0.08 + float(index % 3) * 0.035, Vector3.UP if index % 2 == 0 else side)
	return minimum

func _write_contact(next: int, recipient: Vector3, direction: Vector3, side: Vector3, inverse: Transform3D, color: int) -> void:
	var points := PackedVector3Array()
	for step in 13:
		var along: float = float(step) / 12.0
		var local: Vector3 = side * (along - 0.5) * 0.58 + Vector3.UP * (sin(along * PI) * 0.28 + float(next % 2) * 0.18 - 0.09)
		points.append(inverse * (recipient + local + direction * (float(next % 2) - 0.5) * 0.16))
	contacts[next].mesh = _strip(points, 0.065 if color == 7 else 0.10, direction)

const VfxPackageIO_a27e1fb320 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
