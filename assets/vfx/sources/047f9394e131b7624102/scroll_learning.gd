extends Node3D
## The same native ink strokes leave a curved parchment and settle on a book.
## A committed knowledge observation admits transfer. This is ordinary item use.

const Geometry = preload("res://assets/vfx/sources/3a462df332f8b5fc50ce/study_geometry.gd")
var settings: Dictionary = {}
var live_state: Dictionary = {}
var endpoints: Array = []
var observed: Dictionary = {}
var props: Node3D
var parchment: Node3D
var book: Node3D
var book_pages: Array[MeshInstance3D] = []
var strokes: Array[MeshInstance3D] = []
var ink_materials: Array[ShaderMaterial] = []
var prop_materials: Array[StandardMaterial3D] = []
var age_seconds: float = 0.0


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_047f9394e1.resource("res://assets/vfx/sources/047f9394e131b7624102/scroll_learning.gd").new()
	effect.settings = input.duplicate(true)
	effect.prepare()
	return effect


func page_mesh(width_cells: float, depth_cells: float, curl_cells: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 24:
		for corner in [Vector2i(index, 0), Vector2i(index, 1), Vector2i(index + 1, 1), Vector2i(index, 0), Vector2i(index + 1, 1), Vector2i(index + 1, 0)]:
			var along: float = float(corner.x) / 24.0
			var depth: float = float(corner.y)
			var curl: float = pow(absf(along - 0.5) * 2.0, 7.0) * curl_cells
			surface.set_uv(Vector2(along, depth))
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3((along - 0.5) * width_cells, curl, (depth - 0.5) * depth_cells))
	return surface.commit()


func add_prop(parent: Node3D, label: String, mesh: Mesh, color: String) -> MeshInstance3D:
	var material: StandardMaterial3D = Geometry.matte(Color(color))
	prop_materials.append(material)
	return Geometry.piece(parent, label, mesh, material)


func prepare() -> void:
	props = Node3D.new()
	props.name = "ItemKnowledgeTransfer"
	add_child(props)
	parchment = Node3D.new()
	parchment.name = "AdmittedScrollDepiction"
	props.add_child(parchment)
	# Both depictions sit ahead of the palm. The earlier rearward parchment
	# was hidden by the actual torso in the first native camera.
	parchment.position = Vector3(0.0, 0.045, -0.20)
	parchment.rotation_degrees = Vector3(0.0, -12.0, 14.0)
	add_prop(parchment, "CurvedParchment", page_mesh(0.28, 0.27, 0.035), "cbb78b")
	for side in [-1.0, 1.0]:
		var roller := CylinderMesh.new()
		roller.top_radius = 0.014
		roller.bottom_radius = 0.014
		roller.height = 0.29
		roller.radial_segments = 10
		var rod: MeshInstance3D = add_prop(parchment, "ParchmentRoll" + str(side), roller, "9f774c")
		rod.position = Vector3(side * 0.14, 0.035, 0.0)
		rod.rotation.x = PI * 0.5
	book = Node3D.new()
	book.name = "BookKnowledgeDepiction"
	props.add_child(book)
	book.position = Vector3(0.19, 0.018, 0.0)
	book.rotation_degrees = Vector3(0.0, 12.0, -8.0)
	for side in [-1.0, 1.0]:
		var cover := BoxMesh.new()
		cover.size = Vector3(0.15, 0.018, 0.23)
		var cover_piece: MeshInstance3D = add_prop(book, "BoundCover" + str(side), cover, "334f63")
		cover_piece.position.x = side * 0.078
		cover_piece.rotation.z = side * -0.10
		var page: MeshInstance3D = add_prop(book, "PageStack" + str(side), page_mesh(0.14, 0.21, 0.018), "d8c9a5")
		page.position = Vector3(side * 0.075, 0.014, 0.0)
		page.rotation.z = side * -0.10
		book_pages.append(page)
	var spine := BoxMesh.new()
	spine.size = Vector3(0.018, 0.022, 0.23)
	add_prop(book, "StitchedSpine", spine, "b19b66")
	for index in 12:
		var material: ShaderMaterial = Geometry.ink(Color("14394f"), 0.0)
		# A source-prop overlay must follow its own transparent page. Object
		# distance sorting can otherwise paint the blank page over settled ink.
		# Native depth testing remains enabled for real actor/geometry occlusion.
		material.render_priority = 1
		ink_materials.append(material)
		strokes.append(Geometry.piece(props, "PersistentInkStroke" + str(index), ArrayMesh.new(), material))
	props.visible = false


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func set_operation_state(value: Dictionary) -> bool:
	if str(value.get("operation_uuid", "")) != str(settings.operation_uuid) or str(value.get("item_uuid", "")) != str(settings.item_uuid):
		return false
	live_state = value.duplicate(true)
	sample(age_seconds)
	return true


func source_stroke(index: int, along: float) -> Vector3:
	var row: int = index % 6
	var column: int = index / 6
	var x: float = -0.105 + along * (0.18 if row % 2 == 0 else 0.14)
	var z: float = -0.095 + float(row) * 0.034
	if column == 1:
		x = -0.035 + along * 0.055
		z = -0.055 + float(row % 3) * 0.054 + sin(along * PI * 2.0) * 0.014
	# Match the actual curved source parchment before lifting an admitted stroke.
	var surface_y: float = pow(absf(x / 0.28) * 2.0, 7.0) * 0.035
	return parchment.transform * Vector3(x, surface_y + 0.013, z)


func target_stroke(index: int, along: float) -> Vector3:
	var row: int = index % 6
	var x: float = -0.049 + along * (0.10 if row % 2 == 0 else 0.076)
	var z: float = -0.079 + float(row) * 0.031
	var surface_y: float = pow(absf(x / 0.14) * 2.0, 7.0) * 0.018
	var page: MeshInstance3D = book_pages[0 if index < 6 else 1]
	return book.transform * page.transform * Vector3(x, surface_y + 0.015, z)


func sample(seconds: float) -> void:
	age_seconds = seconds
	observed = Geometry.observation(settings, live_state, seconds)
	var opacity: float = Geometry.fade(seconds, float(settings.seconds), observed)
	var accepted: bool = str(observed.get("outcome", "")) == "accepted"
	var transfer: float = smoothstep(0.42, 1.30, seconds) if accepted else 0.0
	if endpoints.is_empty():
		opacity = 0.0
	else:
		props.position = global_transform.affine_inverse() * endpoints[0].point + Vector3(0.0, 0.045, 0.0)
	props.visible = opacity > 0.001
	props.scale = Vector3.ONE * lerpf(0.8, 1.0, smoothstep(0.0, 0.3, seconds))
	for material in prop_materials:
		var color: Color = material.albedo_color
		color.a = opacity
		material.albedo_color = color
	for index in strokes.size():
		var stagger: float = clampf(transfer * 1.6 - float(index) * 0.045, 0.0, 1.0)
		strokes[index].mesh = stroke_mesh(index, transfer)
		ink_materials[index].set_shader_parameter("opacity", opacity)
		var transit: float = sin(stagger * PI)
		ink_materials[index].set_shader_parameter("ink_color", Color("14394f").lerp(Color("6eafb9"), transit))
		ink_materials[index].set_shader_parameter("source_seconds", seconds)


func stroke_mesh(index: int, transfer: float) -> ArrayMesh:
	var points := PackedVector3Array()
	var stagger: float = clampf(transfer * 1.6 - float(index) * 0.045, 0.0, 1.0)
	for step in 13:
		var along: float = float(step) / 12.0
		var point: Vector3 = source_stroke(index, along).lerp(target_stroke(index, along), stagger)
		point.y += sin(stagger * PI) * (0.11 + float(index % 3) * 0.024)
		points.append(point)
	return Geometry.ribbon(points, 0.014)


func capture_observation() -> Dictionary:
	return {"study": "wizard_scroll_learning", "operation_uuid": settings.operation_uuid, "item_uuid": settings.item_uuid, "learned_spell_id": settings.learned_spell_id, "state": observed.duplicate(true), "source_hand_local": props.position, "live_endpoints": endpoints.size(), "same_ink_strokes": strokes.size(), "visible": props.visible, "props_are_review_depictions": true, "spell_cast": false, "charge_mutation": false, "book_mutation": false, "optical_lights": 0}

const VfxPackageIO_047f9394e1 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
