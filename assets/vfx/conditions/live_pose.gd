extends RefCounted
## Explicit current anchors for maintained objects. Missing context hides the
## occurrence; there is no saved caster/target fixture or guessed gameplay aim.
var entries: Array = []
var specification: Dictionary = {}
var visual: Node3D
var admitted := false
var last_endpoints: Array = []


func configure(root: Node3D, settings: Dictionary) -> void:
	visual = root
	specification = settings
	for path in settings.nodes:
		var node: Node3D = visual.get_node(path)
		entries.append({"node":node,"basis":node.global_basis})
	visual.hide()


func update(endpoints: Array) -> void:
	last_endpoints = endpoints
	var required := 2 if specification.mode == "gaze" else 1
	if endpoints.size() < required:
		admitted = false
		visual.hide()
		return
	for endpoint in endpoints:
		if not endpoint is Dictionary or not endpoint.get("point") is Vector3:
			admitted = false
			visual.hide()
			return
	var source: Vector3 = endpoints[0].point
	var offset: Array = specification.get("offset",[0,0,0])
	var position := source+Vector3(offset[0],offset[1],offset[2])
	for entry in entries:
		entry.node.global_position = position
		if specification.mode == "gaze":
			var direction: Vector3 = endpoints[1].point-position
			if direction.is_zero_approx():
				admitted = false
				visual.hide()
				return
			var camera: Camera3D = visual.get_viewport().get_camera_3d()
			var view: Vector3 = camera.global_basis.z if camera != null else direction.normalized()
			var normal := view.lerp(direction.normalized(),float(specification.camera_blend)).normalized()
			entry.node.look_at(position+normal,Vector3.UP,true)
			entry.node.scale = entry.basis.get_scale()
	admitted = true
	visual.show()
