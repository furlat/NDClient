extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/626243423bc6a35d0b0e/gust_strands.gd"
## Original native fronts/rolled GPU strands with explicit actual line reach.
const Restore = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/6d7cfd14f2efee6263e2/restore.gd")
var owner_reach := 0.0
var gust_mat_specs: Array = []


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = Restore.make("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/9fb1dbf8703cc15a6b8c/leaf.gd", input)
	var actual: Array = node.get_meta("prepared_timed_materials")
	for specification: Dictionary in node.gust_mat_specs:
		node.mats.append({"mat": actual[int(specification.material_index)],
			"gain": specification.gain, "phase": specification.phase})
	for strip: MeshInstance3D in node.strands:
		node.gpu_gust_meshes.append(strip.mesh)
	return node


func _ready() -> void:
	Restore.start(self)


func source_bindings() -> Dictionary:
	return Restore.bindings(self)


func advance_lifecycle(_delta: float) -> void:
	# Keep the original arithmetic, order, onset, native fronts and strand
	# shaping. Only review retirement and the fixed24-unit reach are replaced.
	tick += 1
	var t := float(tick) / 144.0
	var travel := clampf((t - .08) * 16.0, 0.0, owner_reach)
	var onset := smoothstep(0.0, .16, t)
	head.position = (
		direction * (travel - 2.4)
		+ Vector3.UP * .90
		+ (hand - Vector3.UP * .9) * (1.0 - smoothstep(0.0, 4.0, travel))
	)
	head.visible = t < 1.7
	body.position = (
		direction * (travel - 1.66)
		+ Vector3.UP * .18
		+ (hand - Vector3.UP * .9) * (1.0 - smoothstep(0.0, 4.0, travel))
	)
	body.visible = head.visible
	for item: Dictionary in mats:
		item.mat.set_shader_parameter("source_clock", t + float(item.phase) * .19)
		var gain: float = float(item.gain) * onset
		if float(item.phase) <= 0.0:
			gain *= 1.0 - smoothstep(1.45, 1.65, t)
		else:
			gain *= lerpf(1.0, .80, smoothstep(1.4, 1.85, t))
		item.mat.set_shader_parameter("opacity", gain)
	for index: int in strands.size():
		var reach := owner_reach if t > 1.5 else travel
		strands[index].mesh = ribbon_mesh(index, reach, t)
	# These are the exact original GPU operands. No CPU mesh is regenerated.
	var reach := owner_reach if t > 1.5 else travel
	for strip: MeshInstance3D in strands:
		strip.material_override.set_shader_parameter("gpu_gust_time", t)
		strip.material_override.set_shader_parameter("gpu_gust_reach", reach)
		strip.material_override.set_shader_parameter("gpu_gust_hand", hand)
		strip.material_override.set_shader_parameter("gpu_gust_direction", direction)
		strip.material_override.set_shader_parameter("gpu_gust_across", across)
