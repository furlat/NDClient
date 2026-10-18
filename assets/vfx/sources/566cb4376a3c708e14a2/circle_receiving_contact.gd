extends "res://assets/vfx/sources/2db9d8f5be6686ffedf1/blight.gd"
## Circle's original selected necrotic receiving source, independently fitted
## to a supplied damaged actor. No area query, rule, victim layout or condition.
const ReceivingFrame = preload("res://assets/vfx/sources/02d90ce9caaa3a5e1100/receiving_frame.gd")
var receiving_surface: Dictionary = {}
var receiving_endpoints: Array = []
var receiving_frame: Dictionary = {}
var connected_triangles: int = 0
var admitted: bool = false
var fitted_key: Array=[]
var fitted_origin:=Vector3.ZERO
var fitted_root:=Vector3.ZERO
var geometry_builds:=0

static func make_component(input: Dictionary) -> Node3D:
	assert(input.has("application"))
	var application: Dictionary = input.application
	for key in ["application_id","target_actor","damage_applied","save_succeeded","damage_type"]:
		assert(application.has(key), "Circle receiving application lacks " + key)
	assert(not str(application.application_id).is_empty())
	assert(application.damage_type == "necrotic")
	return construct("res://assets/vfx/sources/566cb4376a3c708e14a2/circle_receiving_contact.gd", input)

func set_entity_geometry(value: Dictionary) -> void:
	receiving_surface = value

func set_live_endpoints(value: Array) -> void:
	receiving_endpoints = value
	for endpoint in value:
		if endpoint.has("surface"):
			receiving_surface = endpoint.surface

func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	# The isolated author scene animates a demonstration lamp after component
	# sampling. Remove only those isolated lamp tracks; leave particle tracks
	# and every source-library resource untouched.
	for player in subject.find_children("*", "AnimationPlayer", true, false):
		for clip in player.get_animation_list():
			var animation: Animation = player.get_animation(clip)
			for index in range(animation.get_track_count()-1,-1,-1):
				if str(animation.track_get_path(index)).begins_with("OmniLight3D:"):
					animation.remove_track(index)
	# The exact source donor, seal, flakes, shader/noise, masks and lifecycle
	# remain. Only the donor's capsule proxy is replaced with actual current
	# connected receiving pixels; no human proxy or enclosing cage is rendered.
	coating.name = "CurrentReceivingSurface"
	coating.mesh = ArrayMesh.new()
	admitted = bool(parameters.application.damage_applied)
	visible = admitted

func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	var strength: float = .55 if bool(parameters.application.save_succeeded) else 1.0
	for material in materials:
		material.set_shader_parameter("support_envelope", float(material.get_shader_parameter("support_envelope")) * strength)

func update_geometry() -> void:
	# Native Init can re-enable the donor lamp after construction. Circle has no
	# disclosed illumination; preserve the original source geometry/material,
	# but never turn that author-example lamp into optical light.
	for light in find_children("*", "Light3D", true, false):
		light.visible = false
		light.light_energy = 0.0
	visible = admitted
	if not admitted:
		return
	if receiving_surface.is_empty():
		coating.hide()
		sigil.hide()
		subject.hide()
		for flake in flakes:flake.hide()
		return
	assert(receiving_surface.get("actor", "") == parameters.application.target_actor, "Circle receiving surface must belong to supplied application actor")
	var pose: Array=preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(receiving_surface)
	var key: Array=[pose,global_basis]
	var rebuild: bool=pose.is_empty() or key!=fitted_key
	if rebuild:
		receiving_frame = ReceivingFrame.measure(receiving_surface)
	else:
		receiving_frame.origin=receiving_surface.origin
		coating.position=global_basis.inverse()*(receiving_surface.origin-fitted_origin-(global_position-fitted_root))
	if receiving_frame.is_empty() or receiving_endpoints.is_empty():
		coating.hide()
		sigil.hide()
		subject.hide()
		for flake in flakes:
			flake.hide()
		return
	if rebuild:
		fitted_key=key
		fitted_origin=receiving_surface.origin
		fitted_root=global_position
		geometry_builds+=1
		var points: Array = receiving_surface.points
		var indexed: Dictionary = {}
		for point in points:
			indexed[point.pixel] = point
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		connected_triangles = 0
		for pixel in indexed:
			var adjacent: Array = [pixel,pixel+Vector2i.RIGHT,pixel+Vector2i.DOWN,pixel+Vector2i.ONE]
			for triangle in [[0,1,2],[1,3,2]]:
				if not triangle.all(func(index: int) -> bool: return indexed.has(adjacent[index])):
					continue
				for index in triangle:
					var point: Dictionary = indexed[adjacent[index]]
					tool.set_uv(point.uv)
					tool.set_normal((global_basis.inverse() * point.normal).normalized())
					tool.add_vertex(to_local(point.position + point.normal * .006))
				connected_triangles += 1
		if connected_triangles > 0:
			coating.mesh = tool.commit()
			coating.transform = Transform3D.IDENTITY
			coating.show()
		else:
			coating.hide()
	# Source point registration is actual current body support, independent for
	# each admitted actor. Native source sizes/UV/noise/time remain explicit.
	var centre: Vector3 = receiving_endpoints[0].point
	subject.position = to_local(centre)
	subject.show()
	var fitted_scale: float = float(receiving_frame.height) / 2.35
	var axes := Basis(receiving_frame.side, receiving_frame.up, receiving_frame.normal)
	var seal_centre: Vector3 = centre + receiving_frame.up * (receiving_frame.height * .149) + receiving_frame.normal * .012
	sigil.transform = global_transform.affine_inverse() * Transform3D(axes.scaled(Vector3.ONE * fitted_scale), seal_centre)
	sigil.show()
	for flake in flakes:
		flake.show()

func capture_observation() -> Dictionary:
	var frame_observation: Dictionary = receiving_frame.duplicate(false)
	frame_observation.erase("points")
	return {"circle_receiving": {"application_id":parameters.application.application_id,
		"actor":parameters.application.target_actor,"damage_applied":parameters.application.damage_applied,
		"save_succeeded":parameters.application.save_succeeded,"admitted":admitted,
		"source_alpha":.55 if bool(parameters.application.save_succeeded) else 1.0,
		"receiving_actor":receiving_surface.get("actor",""),"receiving_points":receiving_surface.get("points",[]).size(),
		"connected_triangles":connected_triangles,"source_clock":float(tick)/float(parameters.simulation_hz),
		"optical_lights":find_children("*","Light3D",true,false).filter(func(light:Light3D)->bool:return light.visible).size(),
		"effective_visible":is_visible_in_tree(),"coating_visible":coating.visible,"seal_visible":sigil.visible,"donor_visible":subject.visible,
		"current_frame":frame_observation,"rules_evaluated":false}}
