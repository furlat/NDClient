extends "res://assets/vfx/extensions/continuation42-20261020/sources/5c6209274c246f81af5f/bank.gd"
## Reuse the exact source material restoration; Hex owns its18-station topology.
@export var claws_enabled := false

func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	Clock.ensure_pool()
	Bindings.methods(VfxPackageIO_300e6f88d0.resource("res://assets/vfx/extensions/continuation42-20261020/sources/441b62157b8c78a83a18/field.gd"))
	for material: ShaderMaterial in materials:
		material.get_rid()
		material.get_property_list()
		material.shader.get_shader_uniform_list()
	if ribbon != null:
		ribbon.get_rid()
		preload("res://assets/vfx/extensions/continuation42-20261020/sources/34e0f9ed9a909885cd97/path_ribbon.gd").templates[[18,Color.WHITE,Vector2(0,1),false]] = ribbon
	interface_ready = true

const VfxPackageIO_300e6f88d0 = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
