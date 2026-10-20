extends "res://assets/vfx/sources/5d2781cac4ec7582d670/chromatic_orb_surface.gd"
## Original ground shader/topology/sample; no material extraction per owner.
var prepared_cells: Array = []
var prepared_topology: Dictionary = {}


func configure_patch(input: Dictionary, source_material: ShaderMaterial, layer_mask: int) -> void:
	specification = input.duplicate(true)
	surface_admitted = bool(input.surface_admitted)
	if plane == null:
		material = source_material
		plane = MeshInstance3D.new()
		plane.name = "ObservedSuppliedSurface"
		plane.material_override = material
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plane.hide()
		plane.top_level = true
		plane.layers = layer_mask
		add_child(plane)
	# Original set_patch_states creates a new transparent child on each call.
	# Retain its native zero state while reusing actual immutable geometry.
	material.set_shader_parameter("orb_burst_seconds",0.0)
	material.set_shader_parameter("orb_burst_envelope",0.0)
	set_admitted_cells(input.admitted_cells)


func _update_topology() -> void:
	if not prepared_topology.is_empty() and admitted_cells == prepared_cells:
		# The original geometry depends only on the current supplied cells. Reuse
		# its exact native mesh for repeated state/position/removal changes, while
		# resetting source-owned local edge arrays before cross-owner joining.
		for name: String in prepared_topology:
			material.set_shader_parameter(name,prepared_topology[name])
		return
	super._update_topology()
	prepared_cells = admitted_cells.duplicate(true)
	for name in ["observed_cells","observed_open_edges","observed_cell_count"]:
		prepared_topology[name] = material.get_shader_parameter(name)


func prepare() -> void:
	assert(plane != null and material != null,"Prepared ground has no hidden extraction fallback")
