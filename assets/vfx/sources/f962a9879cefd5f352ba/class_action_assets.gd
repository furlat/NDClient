extends RefCounted
## Immutable assets from the original class-action source. No actor/owner data.
static var programs: Dictionary = {}
static var noise_texture: NoiseTexture2D
static var core_texture: ImageTexture
static var core_mesh: QuadMesh
static var mote_meshes: Dictionary = {}


static func program(path: String, billboard: bool = false) -> Shader:
	var key := path + ("/billboard" if billboard else "")
	if not programs.has(key):
		var code := VfxPackageIO_f962a9879c.text(path)
		if billboard:
			code = code.replace("void fragment(){", "void vertex(){ MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]); }\nvoid fragment(){")
		var shader := Shader.new()
		shader.code = code
		programs[key] = shader
	return programs[key]


static func noise() -> NoiseTexture2D:
	if noise_texture == null:
		var texture := NoiseTexture2D.new()
		texture.width = 256
		texture.height = 256
		texture.seamless = true
		texture.seamless_blend_skirt = .2
		texture.generate_mipmaps = true
		var source := FastNoiseLite.new()
		source.noise_type = 3
		source.frequency = .018
		source.fractal_type = 2
		source.fractal_octaves = 4
		source.fractal_gain = .55
		texture.noise = source
		noise_texture = texture
	return noise_texture


static func glow_texture() -> ImageTexture:
	if core_texture == null:
		var image := Image.new()
		image.load_png_from_buffer(VfxPackageIO_f962a9879c.bytes("res://assets/vfx/sources/0153d00f65f7d8626351/texture.res"))
		core_texture = ImageTexture.create_from_image(image)
	return core_texture


static func glow_mesh() -> QuadMesh:
	if core_mesh == null:
		core_mesh = QuadMesh.new()
		core_mesh.size = Vector2(.38, .38)
	return core_mesh


static func mote_mesh(arc: bool) -> SphereMesh:
	if not mote_meshes.has(arc):
		var mesh := SphereMesh.new()
		mesh.radius = .013 if arc else .018
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 4
		mesh.rings = 2
		mote_meshes[arc] = mesh
	return mote_meshes[arc]

const VfxPackageIO_f962a9879c = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
