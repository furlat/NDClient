extends RefCounted
## Receiving lights as one data texture. Each enabled canvas source keeps the
## exact PointLight2D inputs of the receiving pages, in viewport pixels, and the
## cookie matrix Godot 4.7.2 derives from them (renderer_viewport.cpp
## light_shader_xform, renderer_canvas_render_rd.cpp light uniforms), built
## with the same float32 Transform2D operations. Cookies are layers of one
## Texture2DArray. Both are shader globals: a light change is one small upload.
const TEXELS := 4
const FLOATS := TEXELS * 4

var rows := PackedFloat32Array() # CPU mirror, FLOATS per light, same order as the GPU rows.
var ids := PackedStringArray()
var count := 0
var issues: Array = []
var uploads := 0
var _image: Image
var _table: ImageTexture
var _cookies: Texture2DArray
var _cookie_layers: Dictionary = {} # Cookie texture RID -> array layer.
var _missing: Dictionary = {} # Cookie texture RID -> texture, not prepared at the last build.

## `sources` are canvas sources as built by Lighting2D.project(). `cookie_image`
## returns the retained RGBA8 image of a cookie texture, or null when it is not
## prepared yet; such a light is left out and reported.
func publish(sources: Array, cookie_image: Callable) -> void:
    issues.clear()
    var wanted: Dictionary = {}
    for source in sources:
        if source.enabled and source.texture != null: wanted[source.texture.get_rid()] = source.texture
    if not _same_cookies(wanted, cookie_image): _build_cookies(wanted, cookie_image)
    var next := PackedFloat32Array()
    var next_ids := PackedStringArray()
    for source in sources:
        if not source.enabled or source.texture == null: continue
        var rid: RID = source.texture.get_rid()
        if not _cookie_layers.has(rid):
            issues.append("Light table has no prepared cookie for " + str(source.id))
            continue
        var position: Vector2 = source.screen_position
        var cookie: Transform2D = _cookie_matrix(source)
        var colour: Color = source.color
        # Native colour[3] *= energy (float32); the receiver multiplies rgb by rgb·a.
        var energy: float = PackedFloat32Array([float(source.energy)])[0]
        var weight: float = PackedFloat32Array([colour.a * energy])[0]
        next.append_array([position.x, position.y, float(source.height), weight,
            cookie.x.x, cookie.y.x, cookie.origin.x, cookie.x.y,
            cookie.y.y, cookie.origin.y, float(_cookie_layers[rid]), 0.0,
            colour.r, colour.g, colour.b, 0.0])
        next_ids.append(str(source.id))
    ids = next_ids
    if next == rows and _table != null: return
    rows = next
    count = rows.size() / FLOATS
    var data := rows if count > 0 else _empty_row()
    var image := Image.create_from_data(TEXELS, maxi(count, 1), false, Image.FORMAT_RGBAF, data.to_byte_array())
    if _table == null or _image.get_size() != image.get_size():
        _table = ImageTexture.create_from_image(image)
        RenderingServer.global_shader_parameter_set(&"light_table", _table)
    else:
        _table.update(image)
    _image = image
    RenderingServer.global_shader_parameter_set(&"light_count", count)
    uploads += 1

## Inverse of light_shader_xform = node transform * Transform2D(rect size, rect position),
## where rect = (-texture size·texture_scale/2 + offset, texture size·texture_scale).
func _cookie_matrix(source: Dictionary) -> Transform2D:
    var size: Vector2 = Vector2(source.texture.get_size()) * float(source.texture_scale)
    var rect := Rect2(-(size / 2.0) + source.offset, size)
    var node := Transform2D(0.0, source.cookie_scale, 0.0, source.screen_position)
    var shape := Transform2D(Vector2(rect.size.x, 0.0), Vector2(0.0, rect.size.y), rect.position)
    return (node * shape).affine_inverse()

func _empty_row() -> PackedFloat32Array:
    var row := PackedFloat32Array()
    row.resize(FLOATS)
    return row

## Forget what was uploaded, so the next publish rewrites every global.
func invalidate() -> void:
    rows = PackedFloat32Array()
    _table = null
    _cookie_layers = {}
    _missing = {}

func _same_cookies(wanted: Dictionary, cookie_image: Callable) -> bool:
    for rid in _missing:
        if cookie_image.call(_missing[rid]) != null: return false
    for rid in wanted:
        if not _cookie_layers.has(rid) and not _missing.has(rid): return false
    return true

func _build_cookies(wanted: Dictionary, cookie_image: Callable) -> void:
    # Layers are reassigned on every rebuild; the rows are rewritten in the same call.
    var images: Array[Image] = []
    var layers: Dictionary = {}
    _missing.clear()
    for rid in wanted:
        var image: Image = cookie_image.call(wanted[rid])
        if image == null:
            _missing[rid] = wanted[rid]
            continue
        if not images.is_empty() and (image.get_size() != images[0].get_size() or image.get_format() != images[0].get_format()):
            issues.append("Light cookies differ in size or format; the table needs one layer size")
            continue
        layers[rid] = images.size()
        images.append(image)
    _cookie_layers = layers
    if images.is_empty(): return
    _cookies = Texture2DArray.new()
    _cookies.create_from_images(images)
    RenderingServer.global_shader_parameter_set(&"light_cookies", _cookies)
