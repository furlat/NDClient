extends Node3D
## A pointed liquid arrow, measured recipient residue and separately owned patch.
## Outcomes/tick admission/topology come from public facts, never this sampler.
const Materials = preload("res://assets/vfx/sources/0f15a3f72a38e511db8c/acid_sickness_materials.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const GpuRibbon = preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd")
const Ribbon = preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")

var specification: Dictionary = {}
var endpoints: Array = []
var recipient_geometry: Dictionary = {}
var admitted_cells: Array = []
var pivot: Node3D
var arrow_parts: Array[MeshInstance3D] = []
var droplets: Array[MeshInstance3D] = []
var trail: MeshInstance3D
var patch: MeshInstance3D
var materials: Array[ShaderMaterial] = []
var launch_seconds: float = 0.3
var travel_seconds: float = 0.5
var last_tip := Vector3.ZERO
var last_recipient := Vector3.ZERO
var last_source := Vector3.ZERO
var condition_allowed: bool = true


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_cfd9b5e288.resource("res://assets/vfx/sources/cfd9b5e2882e480dfcd1/acid_arrow.gd").new()
	effect.specification = input.duplicate(true)
	effect.launch_seconds = float(input.get("launch_seconds", 0.3))
	effect.travel_seconds = float(input.get("travel_seconds", 0.5))
	if input.phase == "patch":
		effect.set_admitted_cells(input.get("admitted_cells", []))
	if input.phase in ["residue", "tick"]:
		effect.condition_allowed = input.get("attack_outcome", "") == "hit" and bool(input.get("condition_admitted", false))
		if input.phase == "tick":
			effect.condition_allowed = effect.condition_allowed and bool(input.get("factual_delayed_tick", false))
	return effect


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func set_entity_geometry(value: Dictionary) -> void:
	recipient_geometry = value


func set_delivery_timing(launch: float, travel: float) -> void:
	launch_seconds = maxf(0.0, launch)
	travel_seconds = maxf(0.001, travel)


func set_admitted_cells(value: Array) -> void:
	assert(not value.is_empty() and value.size() <= 32, "Acid patch requires 1–32 supplied local cells")
	admitted_cells = value.duplicate(true)
	if patch != null:
		_update_patch_topology()


func prepare() -> void:
	var colors: Array = specification.palette
	for key in ["head_material", "core_material", "trail_material", "droplet_material"]:
		var material: ShaderMaterial = Materials.load_selected(specification[key], colors, 0.12)
		_source_opacity_response(material, float(specification.get("opacity_response", {}).get(key, 1.0)))
		if specification.phase == "delivery":
			var exposure: float = float(specification.get("delivery_exposure", {}).get(key, 1.0))
			assert(is_finite(exposure) and exposure > 0.0, "Delivery exposure must be finite and positive")
			material.set_shader_parameter("native_palette_exposure", exposure)
		material.set_shader_parameter("emission_strength", 0.6)
		material.set_shader_parameter("displacement_scale", 0.012 if key == "head_material" else 0.0)
		material.set_shader_parameter("billboard", false)
		materials.append(material)
	pivot = Node3D.new()
	pivot.name = "LiquidArrow"
	add_child(pivot)
	arrow_parts.append(Materials.draw(pivot, "PointedArrowHead", _arrow_head(), materials[0]))
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.016
	shaft.bottom_radius = 0.011
	shaft.height = 0.3
	shaft.radial_segments = 8
	arrow_parts.append(Materials.draw(pivot, "LiquidShaft", shaft, materials[1]))
	arrow_parts[1].position.y = -0.29
	trail = Materials.draw(self, "DropletWake", null, materials[2])
	var bead := SphereMesh.new()
	bead.radius = 0.035
	bead.height = 0.07
	bead.radial_segments = 12
	bead.rings = 6
	for index in 12:
		droplets.append(Materials.draw(self, "AcidDrop" + str(index), bead, materials[3]))
	if specification.phase == "patch":
		_prepare_patch(colors)


func _source_opacity_response(material: ShaderMaterial, exponent: float) -> void:
	# Shape masks retain real zeroes and native flow. Change their selected alpha
	# response before the lifecycle envelope, without adding a bright fill/light.
	var code: String = material.shader.code.replace("shader_type spatial;", "shader_type spatial;\nuniform float acid_opacity_exponent=1.0;")
	code = code.replace("ALPHA *= projectile_envelope;", "ALPHA=pow(clamp(ALPHA,0.0,1.0),acid_opacity_exponent);\nALPHA *= projectile_envelope;")
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(material, shader)
	material.set_shader_parameter("acid_opacity_exponent", clampf(exponent, 0.45, 1.0))


func _arrow_head() -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 4:
		var angle: float = float(index) * PI * 0.5
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-sin(angle), 0.0, cos(angle))
		var point := Vector3.ZERO
		var shoulder: Vector3 = radial * 0.09 - Vector3.UP * 0.22
		var notch: Vector3 = -Vector3.UP * 0.145
		for face in [1.0, -1.0]:
			var vertices: Array[Vector3] = [point, shoulder + side * face * 0.008, notch]
			if face < 0.0:
				vertices.reverse()
			for vertex in vertices:
				var along: float = clampf(-vertex.y / 0.22, 0.0, 1.0)
				builder.set_uv(Vector2(0.97 - along * 0.2, along))
				builder.add_vertex(vertex)
	builder.generate_normals()
	return builder.commit()


func _prepare_patch(colors: Array) -> void:
	var material: ShaderMaterial = Materials.load_selected(specification.patch_material, colors, 0.0)
	# Select the original two cellular-flow masks. Public topology owns the edge;
	# the donor's circular showcase mask cannot override supplied admitted cells.
	material.set_shader_parameter("mask1_radial", false)
	material.set_shader_parameter("mask2_radial", false)
	# Native Burn plus cubic alpha retained only isolated bright veins in v45.
	# The source shader's Screen operator retains both cellular masks as a film.
	material.set_shader_parameter("mask2_blend_mode", 5)
	material.set_shader_parameter("use_mask3", false)
	material.set_shader_parameter("displacement_scale", 0.0)
	material.set_shader_parameter("emission_strength", 0.12)
	_source_opacity_response(material, float(specification.get("patch_opacity_exponent", 0.8)))
	var code: String = material.shader.code.replace("shader_type spatial;", "shader_type spatial;\nvarying vec2 acid_local_xz;\nuniform vec2 acid_admitted_cells[32];\nuniform vec4 acid_open_edges[32];\nuniform int acid_cell_count=0;")
	code = SourceMaterials.finish_function(code, "vertex", "\nacid_local_xz=VERTEX.xz;\n")
	code = SourceMaterials.finish_fragment(code, """
	// The native cellular field supplies one continuous perimeter variation.
	// Only exposed edges/corners can lose coverage; occupied joins stay full.
	float acid_perimeter_mask=texture(mask1_texture,acid_local_xz*0.43+mask1_scroll*projectile_clock_seconds*0.16).r;
	float acid_edge_width=0.07+0.04*acid_perimeter_mask;
	float acid_corner_radius=0.16+0.04*acid_perimeter_mask;
	float acid_membership=0.0;
	for(int acid_index=0;acid_index<32;acid_index++) {
		if(acid_index>=acid_cell_count) break;
		vec2 acid_relative=acid_local_xz-acid_admitted_cells[acid_index];
		vec2 acid_distance=abs(acid_relative);
		float acid_inside=1.0-step(0.50001,max(acid_distance.x,acid_distance.y));
		vec4 acid_edges=acid_open_edges[acid_index];
		float acid_edge_x=acid_relative.x<0.0?acid_edges.x:acid_edges.y;
		float acid_edge_z=acid_relative.y<0.0?acid_edges.z:acid_edges.w;
		float acid_soft_x=mix(1.0,smoothstep(0.0,acid_edge_width,0.5-acid_distance.x),acid_edge_x);
		float acid_soft_z=mix(1.0,smoothstep(0.0,acid_edge_width,0.5-acid_distance.y),acid_edge_z);
		vec2 acid_corner=max(acid_distance-vec2(0.5-acid_corner_radius),vec2(0.0));
		float acid_round=1.0-smoothstep(acid_corner_radius-acid_edge_width*0.45,acid_corner_radius,length(acid_corner));
		acid_round=mix(1.0,acid_round,acid_edge_x*acid_edge_z);
		acid_membership=max(acid_membership,acid_inside*acid_soft_x*acid_soft_z*acid_round);
	}
	ALPHA*=acid_membership;
	""")
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(material, shader)
	materials.append(material)
	patch = Materials.draw(self, "AdmittedAcidSurface", null, material)
	patch.top_level = true
	_update_patch_topology()


func _update_patch_topology() -> void:
	var cells := PackedVector2Array()
	var edges := PackedVector4Array()
	var membership: Dictionary = {}
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for cell in admitted_cells:
		var point := Vector2(float(cell[0]), float(cell[1]))
		cells.append(point)
		membership[point] = true
		minimum = minimum.min(point - Vector2.ONE * 0.5)
		maximum = maximum.max(point + Vector2.ONE * 0.5)
	for point in cells:
		edges.append(Vector4(0.0 if membership.has(point + Vector2.LEFT) else 1.0,
			0.0 if membership.has(point + Vector2.RIGHT) else 1.0,
			0.0 if membership.has(point + Vector2.UP) else 1.0,
			0.0 if membership.has(point + Vector2.DOWN) else 1.0))
	var count: int = cells.size()
	while cells.size() < 32:
		cells.append(Vector2.ZERO)
		edges.append(Vector4.ZERO)
	var plane := PlaneMesh.new()
	plane.size = maximum - minimum
	plane.center_offset = Vector3((minimum.x + maximum.x) * 0.5, 0.018, (minimum.y + maximum.y) * 0.5)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	patch.mesh = plane
	patch.material_override.set_shader_parameter("acid_admitted_cells", cells)
	patch.material_override.set_shader_parameter("acid_open_edges", edges)
	patch.material_override.set_shader_parameter("acid_cell_count", count)


func sample(seconds: float) -> void:
	if pivot == null:
		prepare()
	for draw in arrow_parts + droplets:
		draw.hide()
	trail.hide()
	if patch != null:
		patch.hide()
	for material in materials:
		Materials.clock(material, seconds, 0.0)
	if endpoints.is_empty():
		return
	var phase: String = specification.phase
	if phase == "patch":
		_sample_patch(seconds)
		return
	if endpoints.size() < 2:
		return
	var inverse: Transform3D = global_transform.affine_inverse()
	var hand: Vector3 = inverse * endpoints[0].point
	var recipient: Vector3 = inverse * endpoints[1].point
	var source: Vector3 = inverse * endpoints[2].point if endpoints.size() >= 3 else hand
	last_recipient = recipient
	last_source = source
	if phase in ["residue", "tick"]:
		_sample_residue(seconds, inverse, phase == "tick")
		return
	if phase == "impact":
		_sample_impact(seconds, recipient, source, inverse)
		return
	var direction: Vector3 = (recipient - source).normalized()
	if direction.is_zero_approx():
		return
	var preparation: bool = seconds < launch_seconds
	var progress: float = clampf((seconds - launch_seconds) / travel_seconds, 0.0, 1.0)
	var envelope: float = smoothstep(0.0, maxf(launch_seconds, 0.001), seconds) if preparation else 1.0 - smoothstep(0.0, 0.1, seconds - launch_seconds - travel_seconds)
	if envelope <= 0.001:
		return
	pivot.position = hand if preparation else source.lerp(recipient, progress)
	pivot.basis = Basis(Quaternion(Vector3.UP, direction))
	pivot.scale = Vector3.ONE * (0.35 + 0.65 * envelope if preparation else 1.0)
	last_tip = pivot.position
	for draw in arrow_parts:
		draw.show()
	Materials.clock(materials[0], seconds, envelope * 0.9)
	Materials.clock(materials[1], seconds, envelope * 0.75)
	if preparation or progress <= 0.001:
		return
	var length_fraction: float = minf(0.65 / maxf(source.distance_to(recipient), 0.001), progress)
	var points: Array[Vector3] = []
	var widths: Array[float] = []
	for index in 16:
		var weight: float = float(index) / 15.0
		points.append(source.lerp(recipient, progress - length_fraction * (1.0 - weight)))
		widths.append(0.026 * sin(weight * PI))
	GpuRibbon.assign(trail, points, widths)
	trail.show()
	Materials.clock(materials[2], seconds, envelope * 0.5)
	for index in 4:
		var behind: float = length_fraction * (0.25 + float(index) * 0.18)
		droplets[index].position = source.lerp(recipient, maxf(0.0, progress - behind)) - Vector3.UP * float(index * index) * 0.003
		droplets[index].scale = Vector3.ONE * (0.65 - float(index) * 0.1)
		droplets[index].show()
	Materials.clock(materials[3], seconds, envelope * 0.7)


func _sample_impact(seconds: float, recipient: Vector3, source: Vector3, inverse: Transform3D) -> void:
	var envelope: float = smoothstep(0.0, 0.025, seconds) * (1.0 - smoothstep(0.16, 0.6, seconds))
	var backward: Vector3 = (source - recipient).normalized()
	var side: Vector3 = backward.cross(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = Vector3.RIGHT
	var ground_height: float = (inverse * endpoints[3].point).y if endpoints.size() > 3 else recipient.y - 0.8
	for index in droplets.size():
		var angle: float = float(index) * 2.39996
		var speed: float = 0.32 + float(index % 4) * 0.12
		var offset: Vector3 = (side * cos(angle) + Vector3.UP * (0.25 + absf(sin(angle))) + backward * sin(angle) * 0.25) * seconds * speed
		offset.y -= 0.55 * seconds * seconds
		droplets[index].position = recipient + offset
		droplets[index].position.y = maxf(ground_height + 0.025, droplets[index].position.y)
		droplets[index].scale = Vector3.ONE * (0.55 + float(index % 3) * 0.2)
		droplets[index].visible = envelope > 0.001
	Materials.clock(materials[3], seconds, envelope * 0.8)
	last_tip = recipient


func _sample_residue(seconds: float, inverse: Transform3D, ticking: bool) -> void:
	var points: Array = recipient_geometry.get("points", [])
	if not condition_allowed or points.is_empty():
		return
	var envelope: float = smoothstep(0.0, 0.03, seconds) if ticking else smoothstep(0.0, 0.08, seconds)
	if ticking:
		envelope *= 1.0 - smoothstep(0.16, 0.55, seconds)
	var center: Vector3 = inverse * recipient_geometry.get("origin", endpoints[1].point)
	var local_points: Array = []
	if ticking:
		# A short corrosion response groups actual measured points near contact.
		# It does not create another projectile, hit or synthetic body shell.
		for point in points:
			if point.position.distance_to(endpoints[1].point) < 0.36:
				local_points.append(point)
		if not local_points.is_empty():
			points = local_points
	for index in droplets.size():
		var point: Dictionary = points[(index * 173 + 31) % points.size()]
		var normal: Vector3 = (inverse.basis * point.normal).normalized()
		droplets[index].position = inverse * point.position + normal * 0.02
		if ticking:
			droplets[index].position += normal * seconds * 0.45 - Vector3.UP * seconds * seconds * 0.12
		var size: float = (2.1 if ticking else 1.1) + float(index % 4) * 0.12
		droplets[index].scale = Vector3(0.8, 1.0, 0.8) * size
		droplets[index].visible = envelope > 0.001 and droplets[index].position.y > center.y + 0.05
	Materials.clock(materials[3], seconds, envelope * (0.9 if ticking else 0.6))


func _sample_patch(seconds: float) -> void:
	var origin: Vector3 = endpoints[0].point
	patch.global_transform = Transform3D(Basis.IDENTITY, origin)
	var birth: float = float(specification.get("birth_seconds", 0.22))
	var retire: float = float(specification.get("retire_at_seconds", INF))
	var envelope: float = smoothstep(0.0, birth, seconds)
	if is_finite(retire):
		envelope *= 1.0 - smoothstep(retire, retire + 0.65, seconds)
	patch.visible = envelope > 0.001
	Materials.clock(materials[4], seconds, envelope * 0.8)


func capture_observation() -> Dictionary:
	return {"phase": specification.phase, "native_source_materials": 4,
		"tip": last_tip, "recipient": last_recipient, "source": last_source,
		"recipient_surface_points": recipient_geometry.get("points", []).size(),
		"condition_allowed": condition_allowed, "admitted_cells": admitted_cells,
		"factual_delayed_tick": specification.get("factual_delayed_tick", false),
		"optical_lights": 0, "applies_damage_or_condition": false,
		"patch_owner_is_separate": specification.phase == "patch"}

const VfxPackageIO_cfd9b5e288 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
