extends RefCounted
## Explicit world-space cell membership. Upload only when the supplied set
## changes; no tile lookup, spreading, suppression or gameplay inference.
const CAPACITY := 256
var materials: Array[ShaderMaterial] = []
var texture: ImageTexture
var last_cells: Array = []
var admitted := false
var uploads := 0


func configure(geometry: Array) -> void:
	for entry in geometry:
		var material: Material = entry.node.material_override
		if material is ShaderMaterial and material not in materials:
			materials.append(material)


func update(cells: Array) -> bool:
	if cells.size() > CAPACITY:
		clear()
		return false
	for cell in cells:
		if not cell is Dictionary or not cell.get("centre") is Vector3 or not cell.get("half_size") is Vector2:
			clear()
			return false
		if not cell.centre.is_finite() or not cell.half_size.is_finite() or cell.half_size.x <= 0.0 or cell.half_size.y <= 0.0:
			clear()
			return false
	if cells == last_cells:
		return admitted
	last_cells = cells.duplicate(true)
	var image := Image.create_empty(CAPACITY, 1, false, Image.FORMAT_RGBAF)
	for index in cells.size():
		var cell: Dictionary = cells[index]
		image.set_pixel(index, 0, Color(cell.centre.x, cell.centre.z, cell.half_size.x, cell.half_size.y))
	if texture == null:
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	for material in materials:
		material.set_shader_parameter("vfx_condition_cells", texture)
		material.set_shader_parameter("vfx_condition_cell_count", cells.size())
	admitted = not cells.is_empty()
	uploads += 1
	return admitted


func clear() -> void:
	last_cells = []
	admitted = false
	for material in materials:
		material.set_shader_parameter("vfx_condition_cell_count", 0)
