extends Resource
## A short enhancement wake. The equipped blade itself belongs to the renderer.
@export var element := ""
@export var variant_id := ""
@export var strength := "medium"
@export var history_seconds := .075
@export var outer_blade_fraction := .30
@export var maximum_reach_cells := .16
@export var mesh: Mesh
@export var material: ShaderMaterial
@export var provenance: Array = []
@export var art_status := "native_candidate_not_human_approved"


func prepare_immutable_interface() -> void:
	# Explicit pre-publication reflection, never a hidden occurrence/node.
	# Native ShaderMaterial caches its uniform/property interface here so the
	# first private duplicate need not discover it inside an attack constructor.
	# This asserts no GPU/image qualification when run on a dummy renderer.
	if material != null:
		material.get_property_list()


func validate() -> PackedStringArray:
	var issues := PackedStringArray()
	if element not in ["fire", "ice", "electric"] or variant_id.is_empty():
		issues.append("Explicit source-backed swing family/variant required")
	if strength not in ["lesser", "medium", "greater"]:
		issues.append("Unknown artistic strength")
	if not is_finite(history_seconds) or history_seconds < .025 or history_seconds > .10:
		issues.append("A swing wake must retain at most100 ms")
	if not is_finite(outer_blade_fraction) or outer_blade_fraction < .20 or outer_blade_fraction > .35:
		issues.append("Only the outer20–35% of the exact blade may contribute")
	if not is_finite(maximum_reach_cells) or maximum_reach_cells <= 0.0 or maximum_reach_cells > .25:
		issues.append("A swing wake must remain within.25 cells of the current exact outer edge")
	if mesh == null or material == null or material.shader == null or provenance.is_empty():
		issues.append("Prepared mesh, material/program and original source lineage required")
	return issues
