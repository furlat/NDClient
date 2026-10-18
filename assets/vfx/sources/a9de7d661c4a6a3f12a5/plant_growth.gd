extends Node3D
## Low living vegetation composed across supplied cells. The native curved
## mesh, bark/noise growth material and sway remain, without a wall/entangle.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Palette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
const Clusters = preload("res://assets/vfx/sources/454cb6585d2ccf36c7c1/vegetation_clusters.gd")

var specification: Dictionary = {}
var groups: Array = []
var removal_times: Dictionary = {}
var current_seconds := 0.0
static var shared_leaf_mesh: ArrayMesh

static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_a9de7d661c.resource("res://assets/vfx/sources/a9de7d661c4a6a3f12a5/plant_growth.gd").new()
	effect.specification = input.duplicate(true)
	effect.prepare()
	return effect

func prepare() -> void:
	var donor: Node3D = VfxPackageIO_a9de7d661c.resource(specification.source_scene).instantiate()
	var source: MeshInstance3D = donor.get_node(specification.source_node)
	var clusters := Clusters.separate(source.mesh)
	var original: ShaderMaterial = source.material_override
	var code: String = original.shader.code.replace("TIME", "growth_clock_seconds")
	code = code.replace("cull_back", "cull_disabled")
	code = code.replace("instance uniform", "uniform")
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float growth_clock_seconds=0.0;\nuniform float cue_opacity=1.0;\n")
	code = SourceMaterials.finish_fragment(code, "\nALPHA *= cue_opacity;\n")
	var shader := Shader.new()
	shader.code = code
	var geometry_fill := DirectionalLight3D.new()
	geometry_fill.name = "NativeVegetationGeometryFill"
	geometry_fill.rotation_degrees = Vector3(-55, -30, 0)
	geometry_fill.light_energy = .85
	geometry_fill.set_meta("factory_light_role", "geometry_only")
	add_child(geometry_fill)
	for index in specification.cells.size():
		var cell: Array = specification.cells[index]
		var material: ShaderMaterial = original.duplicate(true)
		SourceMaterials.replace_shader(material, shader)
		for uniform in specification.native_uniforms:
			material.set_shader_parameter(uniform, specification.native_uniforms[uniform])
		Palette.apply(material, specification.colours, {"quantize": false, "emission_gain": 0.0})
		var leaf_material := ShaderMaterial.new()
		leaf_material.shader = VfxPackageIO_a9de7d661c.resource("res://assets/vfx/sources/1459a0c06573a639081f/plant_leaf.gdshader")
		leaf_material.set_shader_parameter("native_leaf", VfxPackageIO_a9de7d661c.resource(specification.leaf_texture))
		leaf_material.set_shader_parameter("leaf_tint", Color(specification.leaf_tint))
		var group := {"cell": cell, "draws": [], "material": material, "leaf_material": leaf_material, "index": index}
		for variant in int(specification.get("clumps_per_cell", 6)):
			var pivot := Node3D.new()
			pivot.name = "LivingCell%dBranch%d" % [index, variant]
			var seed := float(index * int(specification.get("clumps_per_cell", 6)) + variant) * 2.39996
			pivot.position = Vector3(cell[0] + cos(seed) * .21, .025, cell[1] + sin(seed) * .21)
			pivot.rotation.y = seed
			add_child(pivot)
			var draw := MeshInstance3D.new()
			draw.mesh = clusters[(index * 7 + variant * 3) % clusters.size()]
			var bounds := draw.mesh.get_aabb()
			var centre := bounds.get_center()
			draw.material_override = material
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var scale_variation := .95 + .15 * sin(seed * 3.13)
			var height_scale := (float(specification.get("height_cells", .5)) + .16 * sin(seed * 2.13)) / bounds.size.y
			draw.scale = Vector3.ONE * height_scale * scale_variation
			draw.position = -Vector3(centre.x * draw.scale.x, bounds.position.y * draw.scale.y, centre.z * draw.scale.z)
			pivot.add_child(draw)
			var positions: PackedVector3Array = draw.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for leaf_index in 5:
				var desired_height: float = bounds.position.y + bounds.size.y * (.16 + .17 * leaf_index)
				var support := positions[0]
				var score := INF
				for point in positions:
					var distance := absf(point.y - desired_height)
					if distance < score:
						support = point
						score = distance
				var leaf := MeshInstance3D.new()
				leaf.mesh = _leaf_mesh()
				leaf.material_override = leaf_material
				leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				leaf.position = draw.position + support * draw.scale
				var angle := seed + leaf_index * 2.39996
				var leaf_direction := Vector3(cos(angle) * .8, .55, sin(angle) * .8).normalized()
				var leaf_side := leaf_direction.cross(Vector3.UP).normalized()
				leaf.basis = Basis(leaf_side, leaf_direction, leaf_side.cross(leaf_direction).normalized())
				pivot.add_child(leaf)
			group.draws.append(pivot)
		groups.append(group)
	donor.free()

func set_removed_cells(cells: Array, observed_at_seconds: float) -> void:
	for cell in cells:
		var key := Vector2i(cell[0], cell[1])
		if not removal_times.has(key):
			removal_times[key] = observed_at_seconds

func sample(seconds: float) -> void:
	current_seconds = seconds
	for event in specification.get("observed_removals", []):
		if seconds >= float(event.at_seconds):
			set_removed_cells(event.cells, float(event.at_seconds))
	for group in groups:
		var key := Vector2i(group.cell[0], group.cell[1])
		var delay := fposmod(sin(float(group.index) * 73.13) * 321.41, 1.0) * .30
		var growth := smoothstep(0.0, .65, seconds - delay)
		var removal := smoothstep(0.0, .70, seconds - float(removal_times[key])) if removal_times.has(key) else 0.0
		group.material.set_shader_parameter("growth_clock_seconds", seconds)
		group.material.set_shader_parameter("DisolverSTEP", lerpf(1.0, -.2, growth) if removal == 0.0 else lerpf(-.2, 1.05, removal))
		group.leaf_material.set_shader_parameter("growth_clock_seconds", seconds)
		group.leaf_material.set_shader_parameter("plant_presence", growth * (1.0 - removal))
		var geometry_state: Vector2=Vector2(growth,removal)
		if group.get("geometry_state",Vector2(-1,-1))!=geometry_state:
			for pivot in group.draws:
				pivot.visible = growth > 0.0 and removal < 1.0
				pivot.scale.y = .10 + .90 * growth
			group.geometry_state=geometry_state

func _leaf_mesh() -> ArrayMesh:
	if shared_leaf_mesh!=null:
		return shared_leaf_mesh
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for station in 5:
		var u := float(station) / 4.0
		for edge in [-1.0, 1.0]:
			vertices.append(Vector3(edge * .047, u * .18, sin(u * PI) * .018))
			normals.append(Vector3.BACK)
			uv.append(Vector2((edge + 1.0) * .5, 1.0 - u))
		if station > 0:
			var start := (station - 1) * 2
			indices.append_array(PackedInt32Array([start, start + 1, start + 2, start + 1, start + 3, start + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	shared_leaf_mesh=mesh
	return mesh

func capture_observation() -> Dictionary:
	return {"supplied_cells": specification.cells.size(), "removed_cells": removal_times.size(),
		"seconds": current_seconds, "auto_regrowth": false, "walking_cost_solver": false,
		"concentration_owner": false, "adds_entangled_condition": false, "optical_lights": 0}

const VfxPackageIO_a9de7d661c = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
