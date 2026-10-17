extends RefCounted
## Receiving lights as one data texture. Each enabled canvas source keeps the
## exact PointLight2D inputs of the receiving pages, in viewport pixels, and the
## cookie matrix Godot 4.7.2 derives from them (renderer_viewport.cpp
## light_shader_xform, renderer_canvas_render_rd.cpp light uniforms), built
## with the same float32 Transform2D operations. Cookies are layers of one
## texture array, copied in on the GPU once per cookie and kept (no readback).
## Both are shader globals: a light change is one small upload.
const TEXELS := 4
const FLOATS := TEXELS * 4

var rows := PackedFloat32Array() # CPU mirror, FLOATS per light, same order as the GPU rows.
var ids := PackedStringArray()
var count := 0
var issues: Array = []
var uploads := 0
var _image: Image
var _table: ImageTexture
const COOKIE_SIZE := 256
static var _cookie_publisher := 0 # Identity of the table whose array is bound.
var _identity := 0
const COOKIE_LAYERS := 64
var _rd: RenderingDevice
var _cookie_rd: RID
var _cookies: TextureLayered # Texture2DArrayRD; Texture2DArray on the Compatibility path.
var _cookie_layers: Dictionary = {} # Cookie texture RID -> array layer, kept once copied.
var _cookie_images: Array[Image] = [] # Compatibility path only: one image per layer.

## `sources` are canvas sources as built by Lighting2D.project(). `cookie_image`
## returns the RGBA8 image of a cookie texture; it is only used where there is no
## RenderingDevice (Compatibility). A cookie not generated yet leaves its light
## out for that frame and is reported.
func publish(sources: Array, cookie_image: Callable) -> void:
    issues.clear()
    var next := PackedFloat32Array()
    var next_ids := PackedStringArray()
    for source in sources:
        if not source.enabled or source.texture == null: continue
        var layer: int = _cookie_layer(source.texture, cookie_image)
        if layer < 0:
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
            cookie.y.y, cookie.origin.y, float(layer), 0.0,
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
    if _cookies != null: _publish_cookies()

## The array layer holding this cookie, copying it in on first use.
func _cookie_layer(texture: Texture2D, cookie_image: Callable) -> int:
    var rid: RID = texture.get_rid()
    if _cookie_layers.has(rid): return _cookie_layers[rid]
    if _cookie_layers.size() >= COOKIE_LAYERS:
        # Full: start over; the cookies still in use are copied again this frame.
        _cookie_layers = {}; _cookie_images = []
    if _rd == null: _rd = RenderingServer.get_rendering_device()
    if _rd != null: return _copy_cookie(rid)
    var image: Image = cookie_image.call(texture)
    if image == null: return -1
    if image.get_size() != Vector2i(COOKIE_SIZE, COOKIE_SIZE):
        issues.append("Light cookie is not %dx%d" % [COOKIE_SIZE, COOKIE_SIZE]); return -1
    var layer := _cookie_images.size()
    _cookie_images.append(image)
    var images := Texture2DArray.new()
    images.create_from_images(_cookie_images)
    _cookies = images
    _publish_cookies()
    _cookie_layers[rid] = layer
    return layer

## GPU copy of a generated RGBA8 cookie into the next layer: no readback.
func _copy_cookie(rid: RID) -> int:
    if not _cookie_rd.is_valid():
        var format := RDTextureFormat.new()
        format.texture_type = RenderingDevice.TEXTURE_TYPE_2D_ARRAY
        format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
        format.width = COOKIE_SIZE; format.height = COOKIE_SIZE; format.array_layers = COOKIE_LAYERS
        format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
        _cookie_rd = _rd.texture_create(format, RDTextureView.new(), [])
        var array := Texture2DArrayRD.new()
        array.texture_rd_rid = _cookie_rd
        _cookies = array
        _publish_cookies()
    var source: RID = RenderingServer.texture_get_rd_texture(rid)
    if not source.is_valid(): return -1
    var format: RDTextureFormat = _rd.texture_get_format(source)
    # A GradientTexture2D still holding its placeholder is not generated yet.
    if format.width != COOKIE_SIZE or format.height != COOKIE_SIZE: return -1
    if format.format != RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM:
        issues.append("Light cookie format %d is not RGBA8" % format.format); return -1
    var layer := _cookie_layers.size()
    _rd.texture_copy(source, _cookie_rd, Vector3.ZERO, Vector3.ZERO, Vector3(COOKIE_SIZE, COOKIE_SIZE, 1), 0, 0, 0, layer)
    _cookie_layers[rid] = layer
    return layer

func _init() -> void:
    _identity = get_instance_id()

func _publish_cookies() -> void:
    RenderingServer.global_shader_parameter_set(&"light_cookies", _cookies)
    _cookie_publisher = _identity

func _notification(what: int) -> void:
    if what != NOTIFICATION_PREDELETE or not _cookie_rd.is_valid(): return
    # Unbind before freeing, unless another table (another world) owns the global.
    if _cookie_publisher == _identity:
        RenderingServer.global_shader_parameter_set(&"light_cookies", null)
        _cookie_publisher = 0
    _cookies = null
    _rd.free_rid(_cookie_rd)
