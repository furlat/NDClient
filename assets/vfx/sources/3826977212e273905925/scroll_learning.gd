extends "res://assets/vfx/sources/047f9394e131b7624102/scroll_learning.gd"
const GPUPaths = preload("res://assets/vfx/sources/dd57e643cd33d5e2c463/wizard_ribbons.gd")


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_3826977212.resource("res://assets/vfx/sources/3826977212e273905925/scroll_learning.gd").new()
	effect.settings = input.duplicate(true)
	effect.prepare()
	return effect


func prepare() -> void:
	super.prepare()
	for index in strokes.size():
		GPUPaths.prepare(strokes[index], 2, index, 12)
		var image := Image.create(13, 2, false, Image.FORMAT_RGBAF)
		for station in 13:
			var along := float(station) / 12.0
			var from := source_stroke(index, along)
			var to := target_stroke(index, along)
			image.set_pixel(station, 0, Color(from.x, from.y, from.z, 1))
			image.set_pixel(station, 1, Color(to.x, to.y, to.z, 1))
		ink_materials[index].set_shader_parameter("gpu_stroke_points", ImageTexture.create_from_image(image))


func stroke_mesh(index: int, transfer: float) -> ArrayMesh:
	ink_materials[index].set_shader_parameter("gpu_wizard_motion", transfer)
	return strokes[index].mesh

const VfxPackageIO_3826977212 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
