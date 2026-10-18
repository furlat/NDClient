extends Node3D
## Native donor composition. No stage, clock scheduler, palette pass or exporter here.
const MaterialRules = preload("res://assets/vfx/sources/95fc365541b49f145767/donor_material_rules.gd")
const MaterialValues = preload("res://assets/vfx/sources/4cf3ab04971b48284d54/shader_material.gd")
var donor: Node3D
var parameters: Dictionary
var animation_started: bool = false

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_1752326f3c.resource("res://assets/vfx/sources/1752326f3c319b8e5b52/native_scene_effect.gd").new()
	component.parameters = input.duplicate(true)
	var scene: PackedScene = VfxPackageIO_1752326f3c.resource(input.scene)
	if scene == null:
		component.free()
		return null
	component.donor = scene.instantiate()
	component.donor.name = "Donor"
	component.add_child(component.donor)
	var scale_values: Array = input.get("scale", [1, 1, 1])
	component.donor.scale = Vector3(scale_values[0], scale_values[1], scale_values[2])
	var position_values: Array = input.get("position", [0, 0, 0])
	component.position = Vector3(position_values[0], position_values[1], position_values[2])
	for node_path in input.get("node_properties", {}):
		var target: Node = component.donor.get_node_or_null(NodePath(node_path))
		if target == null:
			push_error("Missing authored node override: " + str(node_path))
			component.free()
			return null
		for property in input.node_properties[node_path]:
			if not property in target:
				push_error("Missing authored property: " + str(property))
				component.free()
				return null
			target.set(property, MaterialValues.uniform_value(input.node_properties[node_path][property]))
	return component

func _ready() -> void:
	# Composition has applied the selected facing before entering the tree.
	# Authored offsets rotate with that facing, while position remains world-relative.
	var offset: Array = parameters.get("local_offset", [0, 0, 0])
	position += basis * Vector3(offset[0], offset[1], offset[2])

func sample(_seconds: float) -> void:
	# First explicit sample happens after insertion and shared emitter seeding.
	if animation_started:
		return
	animation_started = true
	MaterialRules.apply(donor, parameters.get("material_rules", []))
	for specification in parameters.get("native_animations", []):
		var player: AnimationPlayer = donor.get_node_or_null(NodePath(specification.path))
		if player == null or not player.has_animation(specification.clip):
			push_error("Missing explicitly selected native animation")
			return
		player.play(specification.clip)

const VfxPackageIO_1752326f3c = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
