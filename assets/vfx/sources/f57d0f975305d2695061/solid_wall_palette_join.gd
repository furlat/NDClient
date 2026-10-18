extends "res://assets/vfx/sources/f769e026bc612ed65875/solid_wall_palette.gd"
## A genuine quarry port follows the connected sections' growth/submersion.
var corner_port: Node3D

static func make_component(input: Dictionary) -> Node3D:
	assert(input.settings.kind == "stone")
	return construct("res://assets/vfx/sources/f57d0f975305d2695061/solid_wall_palette_join.gd", input)

func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	if settings.shape != "corner":
		return
	var old_join: MeshInstance3D
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			assert(old_join == null, "The original corner must have one explicit port")
			old_join = child
	assert(old_join != null)
	corner_port = Node3D.new()
	corner_port.name = "QuarryCornerPort"
	corner_port.position = Vector3(old_join.position.x, 0.0, old_join.position.z)
	node.add_child(corner_port)
	var rock := MeshInstance3D.new()
	rock.mesh = pillar_meshes[0]
	var bounds := rock.mesh.get_aabb()
	rock.scale = Vector3(thickness, HEIGHT, thickness) / bounds.size
	rock.position = -(bounds.position + Vector3(bounds.size.x * 0.5, 0.0, bounds.size.z * 0.5)) * rock.scale
	var material := make_material(0, false)
	material.set_shader_parameter("rock_tex", pillar_textures[0])
	material.set_shader_parameter("tint", Vector3(4.6, 4.5, 4.0))
	rock.material_override = material
	corner_port.add_child(rock)
	old_join.free()

func update_geometry() -> void:
	if corner_port == null:
		return
	corner_port.position.y = minf(panels[1].position.y, panels[2].position.y)
	corner_port.visible = panels[1].visible or panels[2].visible
