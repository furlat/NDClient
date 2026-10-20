extends Node3D
## Original cell growth/removal floats; exact native geometry on GPU instances.
const Bank = preload("res://assets/vfx/sources/865718f90c7baf4af9f0/bank.gd")
var bank: Resource
var specification: Dictionary = {}
var removal_times: Dictionary = {}
var current_seconds := 0.0
var cell_indices: Dictionary = {}
var state_image: Image
var state_texture: ImageTexture
var state_values: PackedVector4Array = []
var draw_materials: Array[ShaderMaterial] = []
var process_materials: Array[ShaderMaterial] = []
var geometry: Array[GPUParticles3D] = []
var fill: DirectionalLight3D
var last_seconds := NAN
var state_revision := 0
var sampled_revision := -1
var state_uploads := 0
var prepared_source_layer_mask := 0

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.plant_growth_bank)]

static func make_component(input: Dictionary) -> Node3D:
	var source: Resource = VfxPackageIO_7293bb14b2.resource(str(input.plant_growth_bank))
	assert(source is Bank, "Prepare the complete native Plant Growth source bank")
	var actual: Dictionary = input.duplicate(true)
	actual.erase("plant_growth_bank")
	actual.erase("observed_removals")
	var expected: Dictionary = source.source_settings.duplicate(true)
	expected.erase("observed_removals")
	assert(actual == expected, "Plant source topology/palette variant needs explicit preparation")
	var component: Node3D = VfxPackageIO_7293bb14b2.resource("res://assets/vfx/sources/7293bb14b2857cfa08b7/growth.gd").new()
	component.bank = source
	component.specification = input.duplicate(true)
	component._build()
	return component

func _build() -> void:
	bank.prepare_immutable_interface()
	state_image = Image.create(bank.cells.size(), 1, false, Image.FORMAT_RGBAF)
	state_values.resize(bank.cells.size())
	for index in bank.cells.size():
		var cell: Array = bank.cells[index]
		var key := Vector2i(cell[0], cell[1])
		assert(not cell_indices.has(key), "Prepared source has duplicate cell coordinates")
		cell_indices[key] = index
		state_values[index] = Vector4(.1, 1., 0., 0.)
		state_image.set_pixel(index, 0, Color(.1, 1., 0., 0.))
	state_texture = ImageTexture.create_from_image(state_image)
	draw_materials.assign([bank.stem_material.duplicate(false), bank.leaf_material.duplicate(false)])
	for index in bank.draws.size():
		var source: Dictionary = bank.draws[index]
		var material := ShaderMaterial.new()
		material.shader = bank.process_shader
		material.set_shader_parameter("native_instance_transforms", source.transforms)
		material.set_shader_parameter("plant_cell_states", state_texture)
		process_materials.append(material)
		var draw := GPUParticles3D.new()
		draw.name = "OriginalLeaves" if source.kind == "leaf" else "OriginalStemCluster%02d" % index
		draw.amount = int(source.count)
		draw.lifetime = 86400.0
		draw.one_shot = true
		draw.explosiveness = 1.0
		draw.preprocess = 1.0 / 60.0
		draw.fixed_fps = 60
		draw.interpolate = false
		draw.local_coords = true
		draw.use_fixed_seed = true
		draw.seed = 628103
		draw.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.visibility_aabb = source.bounds
		draw.draw_pass_1 = source.mesh
		draw.material_override = draw_materials[1 if source.kind == "leaf" else 0]
		draw.process_material = material
		geometry.append(draw)
		add_child(draw)
	fill = DirectionalLight3D.new()
	fill.name = "NativeVegetationGeometryFill"
	for field: String in bank.light_properties:
		fill.set(field, bank.light_properties[field])
	add_child(fill)

func set_removed_cells(cells: Array, observed_at_seconds: float) -> void:
	for cell in cells:
		var key := Vector2i(cell[0], cell[1])
		if not removal_times.has(key):
			removal_times[key] = observed_at_seconds
			state_revision += 1

func sample(seconds: float) -> void:
	current_seconds = seconds
	for event: Dictionary in specification.get("observed_removals", []):
		if seconds >= float(event.at_seconds):
			set_removed_cells(event.cells, float(event.at_seconds))
	if seconds == last_seconds and sampled_revision == state_revision:
		return
	var changed := false
	for index in bank.cells.size():
		var cell: Array = bank.cells[index]
		var key := Vector2i(cell[0], cell[1])
		var growth := smoothstep(0.0, .65, seconds - bank.delays[index])
		var removal := smoothstep(0.0, .70, seconds - float(removal_times[key])) if removal_times.has(key) else 0.0
		# These are the original CPU results, packed to the same float32 values
		# consumed by original Node transforms and shader uniforms. No GPU
		# smoothstep approximation or inferred removal duration is introduced.
		var value := Vector4(.10 + .90 * growth,
			lerpf(1.0, -.2, growth) if removal == 0.0 else lerpf(-.2, 1.05, removal),
			growth * (1.0 - removal), 1.0 if growth > 0.0 and removal < 1.0 else 0.0)
		if value != state_values[index]:
			state_values[index] = value
			state_image.set_pixel(index, 0, Color(value.x, value.y, value.z, value.w))
			changed = true
	if changed:
		state_texture.update(state_image)
		state_uploads += 1
	for material: ShaderMaterial in draw_materials:
		material.set_shader_parameter("growth_clock_seconds", seconds)
	last_seconds = seconds
	sampled_revision = state_revision

func prepare_source_layer_mask(layer_mask: int) -> void:
	assert(not is_inside_tree() and layer_mask > 0)
	for draw: GPUParticles3D in geometry:
		draw.layers = layer_mask
	fill.layers = layer_mask
	fill.light_cull_mask = layer_mask
	prepared_source_layer_mask = layer_mask

func source_bindings() -> Dictionary:
	return {"geometry": Array(geometry), "materials": Array(draw_materials), "lights": [fill],
		"static_material_topology": true, "prepared_source_layer_mask": prepared_source_layer_mask}

func capture_observation() -> Dictionary:
	return {"supplied_cells": bank.cells.size(), "removed_cells": removal_times.size(),
		"seconds": current_seconds, "auto_regrowth": false, "walking_cost_solver": false,
		"concentration_owner": false, "adds_entangled_condition": false,
		"original_stem_instances": bank.provenance.stem_instances,
		"original_leaf_instances": bank.provenance.leaf_instances,
		"gpu_carriers": geometry.size(), "state_uploads": state_uploads,
		"private_state_texture": true, "per_frame_mesh_generation": false,
		"arbitrary_seek_qualified": false, "human_approval_inferred": false}

const VfxPackageIO_7293bb14b2 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
