extends RefCounted
## Private exact draw operands; no runtime array lookup or diagnostic mirror writes.
var draw_0: RID
var local_0: Transform3D
var draw_1: RID
var local_1: Transform3D
var draw_2: RID
var local_2: Transform3D
var draw_3: RID
var local_3: Transform3D
var draw_4: RID
var local_4: Transform3D
var draw_5: RID
var local_5: Transform3D
var draw_6: RID
var local_6: Transform3D
var draw_7: RID
var local_7: Transform3D
func bind(instances: Array[RID], local: Array[Transform3D]) -> void:
	draw_0 = instances[0]
	local_0 = local[0]
	draw_1 = instances[1]
	local_1 = local[1]
	draw_2 = instances[2]
	local_2 = local[2]
	draw_3 = instances[3]
	local_3 = local[3]
	draw_4 = instances[4]
	local_4 = local[4]
	draw_5 = instances[5]
	local_5 = local[5]
	draw_6 = instances[6]
	local_6 = local[6]
	draw_7 = instances[7]
	local_7 = local[7]
func publish_root(world: Transform3D) -> int:
	RenderingServer.instance_set_transform(draw_0, world * local_0)
	RenderingServer.instance_set_transform(draw_1, world * local_1)
	RenderingServer.instance_set_transform(draw_2, world * local_2)
	RenderingServer.instance_set_transform(draw_5, world * local_5)
	RenderingServer.instance_set_transform(draw_6, world * local_6)
	RenderingServer.instance_set_transform(draw_7, world * local_7)
	return 6
func publish_first_wing(world: Transform3D) -> int:
	RenderingServer.instance_set_transform(draw_3, world * local_3)
	return 1
func publish_second_wing(world: Transform3D) -> int:
	RenderingServer.instance_set_transform(draw_4, world * local_4)
	return 1
