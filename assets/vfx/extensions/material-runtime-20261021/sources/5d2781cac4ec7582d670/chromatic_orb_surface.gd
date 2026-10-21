extends Node3D
## Separate observed-surface occurrence. Supplied cells own all membership.
const Materials = preload("res://assets/vfx/sources/782125cbcfc15cad7fd7/orb_burst_materials.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")

var specification: Dictionary = {}
var endpoints: Array = []
var admitted_cells: Array = []
var surface_admitted: bool = false
var plane: MeshInstance3D
var material: ShaderMaterial


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_5d2781cac4.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/5d2781cac4ec7582d670/chromatic_orb_surface.gd").new()
	node.specification = input.duplicate(true)
	node.surface_admitted = bool(input.get("surface_admitted", false))
	if node.surface_admitted:
		node.set_admitted_cells(input.get("admitted_cells", []))
	return node


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func set_surface_presence(value: bool) -> void:
	surface_admitted = value
	if not value and plane != null:
		plane.hide()


func set_admitted_cells(value: Array) -> void:
	assert(not value.is_empty() and value.size() <= 32, "Observed surface requires 1–32 supplied cells")
	admitted_cells = value.duplicate(true)
	if plane != null:
		_update_topology()


func prepare() -> void:
	var original: ShaderMaterial
	if specification.has("source_material"):
		original = VfxPackageIO_5d2781cac4.resource(specification.source_material)
	else:
		var donor: Node3D = VfxPackageIO_5d2781cac4.resource(specification.source_scene).instantiate()
		var selected: MeshInstance3D = donor.get_node(specification.source_node)
		original = selected.material_override if selected.material_override != null else selected.mesh.surface_get_material(0)
		material = Materials.extract(original, [], 0.0)
		donor.free()
	if material == null:
		material = Materials.extract(original, [], 0.0)
	# Native supported controls are explicit recipe data. Original texture/mask
	# resources and colours are preserved, with no spell-name/material inference.
	for key in specification.get("native_parameters", {}):
		material.set_shader_parameter(key, specification.native_parameters[key])
	var perimeter: Texture2D = material.get_shader_parameter(specification.perimeter_texture_parameter)
	assert(perimeter != null, "Observed surface needs its selected original mask")
	var code: String = material.shader.code.replace("shader_type spatial;", """shader_type spatial;
varying vec2 observed_local_xz;
uniform sampler2D observed_perimeter_texture;
uniform vec2 observed_cells[32];
uniform vec4 observed_open_edges[32];
uniform int observed_cell_count=0;
uniform float observed_emission_gain=0.1;
uniform float observed_alpha_response=1.0;
uniform float observed_source_contrast=0.0;
uniform float observed_base_film=0.0;
""")
	code = SourceMaterials.finish_function(code, "vertex", "\nobserved_local_xz=VERTEX.xz;\n")
	code = SourceMaterials.finish_fragment(code, """
	float observed_noise=texture(observed_perimeter_texture,observed_local_xz*0.43+vec2(orb_burst_seconds*0.008)).r;
	float observed_width=0.09+0.03*observed_noise;
	float observed_inset=0.015+0.14*observed_noise;
	float observed_radius=0.22+0.06*observed_noise;
	float observed_membership=0.0;
	for(int i=0;i<32;i++){
		if(i>=observed_cell_count)break;
		vec2 observed_relative=observed_local_xz-observed_cells[i];
		vec2 observed_distance=abs(observed_relative);
		float observed_inside=1.0-step(0.50001,max(observed_distance.x,observed_distance.y));
		vec4 observed_edges=observed_open_edges[i];
		float observed_edge_x=observed_relative.x<0.0?observed_edges.x:observed_edges.y;
		float observed_edge_z=observed_relative.y<0.0?observed_edges.z:observed_edges.w;
		float observed_soft_x=mix(1.0,smoothstep(observed_inset,observed_inset+observed_width,0.5-observed_distance.x),observed_edge_x);
		float observed_soft_z=mix(1.0,smoothstep(observed_inset,observed_inset+observed_width,0.5-observed_distance.y),observed_edge_z);
		vec2 observed_corner=max(observed_distance-vec2(0.5-observed_radius),vec2(0.0));
		float observed_round=1.0-smoothstep(observed_radius-observed_width*0.45,observed_radius,length(observed_corner));
		observed_round=mix(1.0,observed_round,observed_edge_x*observed_edge_z);
		observed_membership=max(observed_membership,observed_inside*observed_soft_x*observed_soft_z*observed_round);
	}
	// Mask response precedes the occurrence envelope so birth/death stay finite.
	ALPHA=max(observed_base_film,pow(clamp(ALPHA/max(orb_burst_envelope,0.0001),0.0,1.0),observed_alpha_response))*orb_burst_envelope*observed_membership;
	float observed_native_pattern=texture(observed_perimeter_texture,observed_local_xz*0.8+vec2(orb_burst_seconds*0.008)).r;
	float observed_material_weight=mix(1.0,0.35+0.65*observed_native_pattern*observed_native_pattern,observed_source_contrast);
	ALBEDO*=observed_material_weight;
	ALPHA*=mix(1.0,0.5+0.5*observed_native_pattern,observed_source_contrast);
	EMISSION*=observed_emission_gain;
""")
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(material, shader)
	material.set_shader_parameter("observed_perimeter_texture", perimeter)
	material.set_shader_parameter("observed_alpha_response", float(specification.get("alpha_response", 1.0)))
	material.set_shader_parameter("observed_emission_gain", float(specification.get("emission_gain", 0.1)))
	material.set_shader_parameter("observed_source_contrast", float(specification.get("source_contrast", 0.0)))
	material.set_shader_parameter("observed_base_film", float(specification.get("base_film", 0.0)))
	plane = Materials.draw(self, "ObservedSuppliedSurface", null, material)
	plane.top_level = true
	if not admitted_cells.is_empty():
		_update_topology()


func _update_topology() -> void:
	var profiling := Profile.current != null
	if profiling:
		Profile.begin("trail_ground_cell_edge_operands")
	var cells := PackedVector2Array()
	var edges := PackedVector4Array()
	var members: Dictionary = {}
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for cell in admitted_cells:
		var point := Vector2(float(cell[0]), float(cell[1]))
		cells.append(point)
		members[point] = true
		minimum = minimum.min(point - Vector2.ONE * 0.5)
		maximum = maximum.max(point + Vector2.ONE * 0.5)
	for point in cells:
		edges.append(Vector4(0.0 if members.has(point + Vector2.LEFT) else 1.0,
			0.0 if members.has(point + Vector2.RIGHT) else 1.0,
			0.0 if members.has(point + Vector2.UP) else 1.0,
			0.0 if members.has(point + Vector2.DOWN) else 1.0))
	var count: int = cells.size()
	while cells.size() < 32:
		cells.append(Vector2.ZERO)
		edges.append(Vector4.ZERO)
	if profiling:
		Profile.end("trail_ground_cell_edge_operands")
		Profile.begin("trail_ground_native_plane")
	var mesh := PlaneMesh.new()
	mesh.size = maximum - minimum
	mesh.center_offset = Vector3((minimum.x + maximum.x) * 0.5, 0.018, (minimum.y + maximum.y) * 0.5)
	mesh.subdivide_width = 24
	mesh.subdivide_depth = 24
	plane.mesh = mesh
	if profiling:
		Profile.end("trail_ground_native_plane")
		Profile.begin("trail_ground_topology_upload")
	material.set_shader_parameter("observed_cells", cells)
	material.set_shader_parameter("observed_open_edges", edges)
	material.set_shader_parameter("observed_cell_count", count)
	if profiling:
		Profile.end("trail_ground_topology_upload")


func sample(seconds: float) -> void:
	if plane == null:
		prepare()
	plane.hide()
	Materials.clock(material, seconds, 0.0)
	if not surface_admitted or admitted_cells.is_empty() or endpoints.is_empty():
		return
	plane.global_transform = Transform3D(Basis.IDENTITY, endpoints[0].point)
	var envelope: float = smoothstep(0.0, float(specification.get("birth_seconds", 0.22)), seconds)
	var retire: float = float(specification.get("retire_at_seconds", INF))
	if is_finite(retire):
		envelope *= 1.0 - smoothstep(retire, retire + 0.65, seconds)
	plane.visible = envelope > 0.001
	Materials.clock(material, seconds, envelope * float(specification.get("opacity", 0.65)))


func capture_observation() -> Dictionary:
	return {"observed_surface_kind": specification.get("observed_surface_kind", ""),
		"surface_admitted": surface_admitted, "admitted_cells": admitted_cells,
		"separate_surface_owner": true, "computes_membership": false,
		"applies_damage_or_condition": false, "optical_lights": 0,
		"original_masks_and_colors": true, "current_presence": plane.visible if plane != null else false}

const VfxPackageIO_5d2781cac4 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
