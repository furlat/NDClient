extends "res://assets/vfx/extensions/cloud-body-speed-20261021/sources/c19fb6c081fb50b97c27/component.gd"
## Same private native source; consume only its existing optional optical view.
const TypedPacket = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/72d702816e1c9c2291d8/packet.gd")
var typed_frame := false
var typed_frames := 0
var legacy_frames := 0


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.prepared_patch_frame_bank)]


static func make_component(input: Dictionary) -> Node3D:
	return make_frame_component(VfxPackageIO_6e801bbcee.resource("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/6e801bbcee540821f1cf/component.gd"), input)


func _pack_frame() -> Dictionary:
	var packet := TypedPacket.pack(self)
	typed_frame = bool(packet.get("typed", false))
	if typed_frame:
		typed_frames += 1
	else:
		legacy_frames += 1
	return packet


func _frame_constants(packet: Dictionary, orientation_only: bool = false) -> PackedByteArray:
	var constants: PackedByteArray = super._frame_constants(packet, orientation_only)
	constants.encode_u32(12, 1 if typed_frame else 0)
	return constants

const VfxPackageIO_6e801bbcee = preload("res://assets/vfx/extensions/cloud-body-speed-20261021/scoped_resource_io.gd")
