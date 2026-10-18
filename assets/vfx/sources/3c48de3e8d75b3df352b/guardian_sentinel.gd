extends "res://assets/vfx/sources/ef597adb81184ef7186b/spectral_guardian.gd"
## Original upper-knight rig/attack; live recipient determines the model facing.
var live_endpoints: Array=[]
static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/3c48de3e8d75b3df352b/guardian_sentinel.gd",input)
func set_live_endpoints(value: Array) -> void:
	live_endpoints=value
func sample(seconds: float) -> void:
	super.sample(seconds)
	if live_endpoints.size()<2 or not is_instance_valid(model):return
	var local: Vector3=subject.global_transform.affine_inverse()*live_endpoints[1].point
	var direction:=Vector2(local.x,local.z)
	# The imported upper-knight model's front is +Z. Reapplying the historical
	# recorder's PI rotation would aim the native model away from its recipient.
	if not direction.is_zero_approx():model.rotation.y=atan2(direction.x,direction.y)
