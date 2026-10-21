extends RefCounted
## Optional version1 optical transport, produced in the actual source pixel
## append loop. It is not a gameplay fact, pose prediction or support cache.
const GeometryKey = preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd")
const FIELD := "factory_optical_points_v1"
var points: Array = []
var positions := PackedVector3Array()
var normals := PackedVector3Array()
var origin := Vector3.ZERO
var geometry_key: Array = []
var complete := false


static func finish(packet: Dictionary, actual_positions: PackedVector3Array, actual_normals: PackedVector3Array) -> RefCounted:
	var view := preload("res://assets/vfx/extensions/speed-completion-20261021/sources/24740997d533fc6e3ec5/point_view.gd").new()
	view.points = packet.points
	view.positions = actual_positions
	view.normals = actual_normals
	view.origin = packet.origin
	view.geometry_key = GeometryKey.from_surface(packet).duplicate(true)
	view.complete = view.positions.size() == view.points.size() and view.normals.size() == view.points.size()
	return view


func matches(packet: Dictionary) -> bool:
	# Unknown, changed, keyless and externally replaced data keep the original
	# Dictionary path. Never infer a typed optical certificate from a boolean.
	return complete and not geometry_key.is_empty() and is_same(points, packet.get("points")) \
		and positions.size() == points.size() and normals.size() == points.size() \
		and origin == packet.get("origin", Vector3.ZERO) and geometry_key == GeometryKey.from_surface(packet)
