extends "res://assets/vfx/sources/28daeb3e9bac6c2f277f/command_crest_transport.gd"
## Register the front of the actual source half-sphere at the receiving plane.
## Putting its centre there sends the entire open crest beyond the endpoint
## clip, making a correctly timed transport disappear just before contact.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/9fdc49fe466f72842b32/command_crest_contact.gd", input)


func _update_crest() -> void:
	super._update_crest()
	if crest == null or not transport_ready or endpoints.size() < 2:
		return
	var bounds: AABB = crest.mesh.get_aabb()
	var forward_extent := 0.0
	for index in 8:
		forward_extent = maxf(forward_extent, (crest.basis*bounds.get_endpoint(index)).z)
	var progress := clampf(crest_age/float(settings.native_travel_seconds), 0.0, 1.0)
	crest.position.z -= forward_extent*progress


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.crest_contact_registration = "front of actual source mesh reaches supplied face plane; not mesh origin"
	return result
