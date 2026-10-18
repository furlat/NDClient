extends RefCounted
## Opt-in source conversion. All original head, static-tail and spark layers stay.
const GpuRibbon = preload("res://assets/vfx/sources/09a18d9a8151c1d3c2c4/GPUTrail3D.gd")


static func apply(subject: Node3D) -> void:
	for old in subject.find_children("*", "MeshInstance3D", true, false):
		var script: Script = old.get_script()
		if script == null or not VfxPackageIO_021a579c09.has_source_suffix(script.resource_path, "/Trail3D.gd"):
			continue
		assert(old.material_override is ShaderMaterial, "CPU trail has no preserved source material")
		var ribbon := GpuRibbon.new()
		ribbon.name = old.name
		ribbon.transform = old.transform
		ribbon.visible = old.visible
		ribbon.layers = old.layers
		ribbon.cast_shadow = old.cast_shadow
		ribbon.sorting_offset = old.sorting_offset
		ribbon.source_material = old.material_override.duplicate(true)
		ribbon.source_start = old.startColor
		ribbon.source_end = old.endColor
		ribbon.source_acceleration = old.scaleAcceleration
		ribbon.fromWidth = old.fromWidth
		ribbon.toWidth = old.toWidth
		ribbon.fixed_fps = 60
		ribbon.length = maxi(4, int(ceil(float(old.lifespan) * 60.0)) + 2)
		ribbon.length_seconds = float(old.lifespan)
		var parent: Node = old.get_parent()
		var index := old.get_index()
		parent.remove_child(old)
		parent.add_child(ribbon)
		parent.move_child(ribbon, index)
		old.free()

const VfxPackageIO_021a579c09 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
