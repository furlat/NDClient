extends Node3D
## Compact inward folding notation at the actual source hand. Slot restoration
## and encounter admission are supplied observations, never solved by artwork.

const Geometry = preload("res://assets/vfx/sources/3a462df332f8b5fc50ce/study_geometry.gd")
var settings: Dictionary = {}
var live_state: Dictionary = {}
var endpoints: Array = []
var observed: Dictionary = {}
var fold: Node3D
var strokes: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var age_seconds: float = 0.0


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_70c05cebd9.resource("res://assets/vfx/sources/70c05cebd9bbb511e6b9/arcane_recovery.gd").new()
	effect.settings = input.duplicate(true)
	effect.prepare()
	return effect


func prepare() -> void:
	fold = Node3D.new()
	fold.name = "HandOwnedFoldedNotation"
	add_child(fold)
	var colors: Array = settings.palette
	for index in 6:
		var material: ShaderMaterial = Geometry.ink(Color(colors[index % colors.size()]), 0.18)
		var stroke: MeshInstance3D = Geometry.piece(fold, "ConvergingQuill" + str(index), ArrayMesh.new(), material)
		strokes.append(stroke)
		materials.append(material)
	fold.visible = false


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func set_operation_state(value: Dictionary) -> bool:
	if str(value.get("operation_uuid", "")) != str(settings.operation_uuid):
		return false
	live_state = value.duplicate(true)
	sample(age_seconds)
	return true


func sample(seconds: float) -> void:
	age_seconds = seconds
	observed = Geometry.observation(settings, live_state, seconds)
	var accepted: bool = str(observed.get("outcome", "")) == "accepted"
	var opacity: float = Geometry.fade(seconds, float(settings.seconds), observed)
	if not accepted:
		opacity = 0.0
	if endpoints.is_empty():
		opacity = 0.0
	else:
		fold.position = global_transform.affine_inverse() * endpoints[0].point
	fold.visible = opacity > 0.001
	var contraction: float = smoothstep(0.18, 1.12, seconds)
	for index in strokes.size():
		strokes[index].mesh = stroke_mesh(index, contraction)
		materials[index].set_shader_parameter("opacity", opacity)
		materials[index].set_shader_parameter("source_seconds", seconds)


func stroke_mesh(index: int, contraction: float) -> ArrayMesh:
	var points := PackedVector3Array()
	var angle: float = TAU * float(index) / 6.0
	for step in 17:
		var along: float = float(step) / 16.0
		var radial: float = lerpf(0.29 - along * 0.16, 0.055 + along * 0.025, contraction)
		var turn: float = angle + along * 0.52
		points.append(Vector3(cos(turn) * radial, sin(along * PI) * 0.065 + (along - 0.5) * 0.08, sin(turn) * radial))
	return Geometry.ribbon(points, lerpf(0.038, 0.023, contraction))


func capture_observation() -> Dictionary:
	return {"study": "wizard_arcane_recovery", "operation_uuid": settings.operation_uuid, "state": observed.duplicate(true), "live_endpoints": endpoints.size(), "source_hand_local": fold.position, "native_strokes": strokes.size(), "visible": fold.visible, "slot_mutation": false, "rule_solver": false, "optical_lights": 0}

const VfxPackageIO_70c05cebd9 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
