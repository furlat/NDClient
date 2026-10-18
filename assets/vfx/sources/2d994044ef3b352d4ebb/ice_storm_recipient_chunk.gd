extends "res://assets/vfx/sources/268862551a2a334c0e23/ice_storm_irregular_chunk.gd"
## Contact pieces follow the original source's downward release at body height.
## Ground impacts retain its upward/outward scatter. No invented cold condition.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/2d994044ef3b352d4ebb/ice_storm_recipient_chunk.gd", input)


func shatter(node: Node) -> void:
	super.shatter(node)
	if settings.contact:
		for body in bodies:
			body.linear_velocity.y = -0.9 - rng.randf()
