extends RefCounted
## Private retained capacity; actual used triangle operands remain unchanged.
var inverse_transform := Transform3D.IDENTITY
var vertices := PackedVector3Array()
var colours := PackedColorArray()
var coordinates := PackedVector2Array()
var used_vertices := 0
var triangle_packet: Array = []


func begin(actual_inverse: Transform3D) -> void:
	inverse_transform = actual_inverse
	used_vertices = 0


func emit_quad(points: Array, colour: Color, first_age: float, last_age: float) -> void:
	if used_vertices + 6 > vertices.size():
		var capacity := maxi(64, nearest_po2(used_vertices + 6))
		vertices.resize(capacity)
		colours.resize(capacity)
		coordinates.resize(capacity)
	var first: Vector3 = inverse_transform * points[0]
	var second: Vector3 = inverse_transform * points[1]
	var third: Vector3 = inverse_transform * points[2]
	var fourth: Vector3 = inverse_transform * points[3]
	vertices[used_vertices] = first
	vertices[used_vertices + 1] = second
	vertices[used_vertices + 2] = third
	vertices[used_vertices + 3] = first
	vertices[used_vertices + 4] = third
	vertices[used_vertices + 5] = fourth
	colours[used_vertices] = colour
	colours[used_vertices + 1] = colour
	colours[used_vertices + 2] = colour
	colours[used_vertices + 3] = colour
	colours[used_vertices + 4] = colour
	colours[used_vertices + 5] = colour
	var first_left := Vector2(0., first_age)
	var first_right := Vector2(1., first_age)
	var last_right := Vector2(1., last_age)
	var last_left := Vector2(0., last_age)
	coordinates[used_vertices] = first_left
	coordinates[used_vertices + 1] = first_right
	coordinates[used_vertices + 2] = last_right
	coordinates[used_vertices + 3] = first_left
	coordinates[used_vertices + 4] = last_right
	coordinates[used_vertices + 5] = last_left
	used_vertices += 6


func source_arrays() -> Array:
	if triangle_packet.is_empty():
		triangle_packet.resize(Mesh.ARRAY_MAX)
	triangle_packet[Mesh.ARRAY_VERTEX] = vertices.slice(0, used_vertices)
	triangle_packet[Mesh.ARRAY_COLOR] = colours.slice(0, used_vertices)
	triangle_packet[Mesh.ARRAY_TEX_UV] = coordinates.slice(0, used_vertices)
	return triangle_packet
