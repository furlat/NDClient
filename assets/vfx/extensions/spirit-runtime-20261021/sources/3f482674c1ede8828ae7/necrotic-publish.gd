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
var draw_8: RID
var local_8: Transform3D
var draw_9: RID
var local_9: Transform3D
var draw_10: RID
var local_10: Transform3D
var draw_11: RID
var local_11: Transform3D
var draw_12: RID
var local_12: Transform3D
var draw_13: RID
var local_13: Transform3D
var draw_14: RID
var local_14: Transform3D
var draw_15: RID
var local_15: Transform3D
var draw_16: RID
var local_16: Transform3D
var draw_17: RID
var local_17: Transform3D
var draw_18: RID
var local_18: Transform3D
var draw_19: RID
var local_19: Transform3D
var draw_20: RID
var local_20: Transform3D
var draw_21: RID
var local_21: Transform3D
var draw_22: RID
var local_22: Transform3D
var draw_23: RID
var local_23: Transform3D
var draw_24: RID
var local_24: Transform3D
var draw_25: RID
var local_25: Transform3D
var draw_26: RID
var local_26: Transform3D
var draw_27: RID
var local_27: Transform3D
var draw_28: RID
var local_28: Transform3D
var draw_29: RID
var local_29: Transform3D
var draw_30: RID
var local_30: Transform3D
var draw_31: RID
var local_31: Transform3D
var draw_32: RID
var local_32: Transform3D
var draw_33: RID
var local_33: Transform3D
var draw_34: RID
var local_34: Transform3D
var draw_35: RID
var local_35: Transform3D
var draw_36: RID
var local_36: Transform3D
var draw_37: RID
var local_37: Transform3D
var draw_38: RID
var local_38: Transform3D
var draw_39: RID
var local_39: Transform3D
var draw_40: RID
var local_40: Transform3D
var draw_41: RID
var local_41: Transform3D
var draw_42: RID
var local_42: Transform3D
var draw_43: RID
var local_43: Transform3D
var draw_44: RID
var local_44: Transform3D
var draw_45: RID
var local_45: Transform3D
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
	draw_8 = instances[8]
	local_8 = local[8]
	draw_9 = instances[9]
	local_9 = local[9]
	draw_10 = instances[10]
	local_10 = local[10]
	draw_11 = instances[11]
	local_11 = local[11]
	draw_12 = instances[12]
	local_12 = local[12]
	draw_13 = instances[13]
	local_13 = local[13]
	draw_14 = instances[14]
	local_14 = local[14]
	draw_15 = instances[15]
	local_15 = local[15]
	draw_16 = instances[16]
	local_16 = local[16]
	draw_17 = instances[17]
	local_17 = local[17]
	draw_18 = instances[18]
	local_18 = local[18]
	draw_19 = instances[19]
	local_19 = local[19]
	draw_20 = instances[20]
	local_20 = local[20]
	draw_21 = instances[21]
	local_21 = local[21]
	draw_22 = instances[22]
	local_22 = local[22]
	draw_23 = instances[23]
	local_23 = local[23]
	draw_24 = instances[24]
	local_24 = local[24]
	draw_25 = instances[25]
	local_25 = local[25]
	draw_26 = instances[26]
	local_26 = local[26]
	draw_27 = instances[27]
	local_27 = local[27]
	draw_28 = instances[28]
	local_28 = local[28]
	draw_29 = instances[29]
	local_29 = local[29]
	draw_30 = instances[30]
	local_30 = local[30]
	draw_31 = instances[31]
	local_31 = local[31]
	draw_32 = instances[32]
	local_32 = local[32]
	draw_33 = instances[33]
	local_33 = local[33]
	draw_34 = instances[34]
	local_34 = local[34]
	draw_35 = instances[35]
	local_35 = local[35]
	draw_36 = instances[36]
	local_36 = local[36]
	draw_37 = instances[37]
	local_37 = local[37]
	draw_38 = instances[38]
	local_38 = local[38]
	draw_39 = instances[39]
	local_39 = local[39]
	draw_40 = instances[40]
	local_40 = local[40]
	draw_41 = instances[41]
	local_41 = local[41]
	draw_42 = instances[42]
	local_42 = local[42]
	draw_43 = instances[43]
	local_43 = local[43]
	draw_44 = instances[44]
	local_44 = local[44]
	draw_45 = instances[45]
	local_45 = local[45]
func publish_root(world: Transform3D) -> int:
	RenderingServer.instance_set_transform(draw_0, world * local_0)
	RenderingServer.instance_set_transform(draw_1, world * local_1)
	RenderingServer.instance_set_transform(draw_2, world * local_2)
	RenderingServer.instance_set_transform(draw_3, world * local_3)
	RenderingServer.instance_set_transform(draw_4, world * local_4)
	RenderingServer.instance_set_transform(draw_5, world * local_5)
	RenderingServer.instance_set_transform(draw_6, world * local_6)
	RenderingServer.instance_set_transform(draw_7, world * local_7)
	RenderingServer.instance_set_transform(draw_8, world * local_8)
	RenderingServer.instance_set_transform(draw_9, world * local_9)
	RenderingServer.instance_set_transform(draw_10, world * local_10)
	RenderingServer.instance_set_transform(draw_11, world * local_11)
	RenderingServer.instance_set_transform(draw_12, world * local_12)
	RenderingServer.instance_set_transform(draw_18, world * local_18)
	RenderingServer.instance_set_transform(draw_19, world * local_19)
	RenderingServer.instance_set_transform(draw_20, world * local_20)
	RenderingServer.instance_set_transform(draw_21, world * local_21)
	RenderingServer.instance_set_transform(draw_22, world * local_22)
	RenderingServer.instance_set_transform(draw_23, world * local_23)
	RenderingServer.instance_set_transform(draw_24, world * local_24)
	RenderingServer.instance_set_transform(draw_25, world * local_25)
	RenderingServer.instance_set_transform(draw_26, world * local_26)
	RenderingServer.instance_set_transform(draw_27, world * local_27)
	RenderingServer.instance_set_transform(draw_33, world * local_33)
	RenderingServer.instance_set_transform(draw_34, world * local_34)
	RenderingServer.instance_set_transform(draw_35, world * local_35)
	RenderingServer.instance_set_transform(draw_36, world * local_36)
	RenderingServer.instance_set_transform(draw_37, world * local_37)
	RenderingServer.instance_set_transform(draw_38, world * local_38)
	RenderingServer.instance_set_transform(draw_39, world * local_39)
	RenderingServer.instance_set_transform(draw_40, world * local_40)
	RenderingServer.instance_set_transform(draw_41, world * local_41)
	RenderingServer.instance_set_transform(draw_42, world * local_42)
	RenderingServer.instance_set_transform(draw_43, world * local_43)
	RenderingServer.instance_set_transform(draw_44, world * local_44)
	RenderingServer.instance_set_transform(draw_45, world * local_45)
	return 36
func publish_first_wing(world: Transform3D) -> int:
	RenderingServer.instance_set_transform(draw_13, world * local_13)
	RenderingServer.instance_set_transform(draw_14, world * local_14)
	RenderingServer.instance_set_transform(draw_15, world * local_15)
	RenderingServer.instance_set_transform(draw_16, world * local_16)
	RenderingServer.instance_set_transform(draw_17, world * local_17)
	return 5
func publish_second_wing(world: Transform3D) -> int:
	RenderingServer.instance_set_transform(draw_28, world * local_28)
	RenderingServer.instance_set_transform(draw_29, world * local_29)
	RenderingServer.instance_set_transform(draw_30, world * local_30)
	RenderingServer.instance_set_transform(draw_31, world * local_31)
	RenderingServer.instance_set_transform(draw_32, world * local_32)
	return 5
