extends SceneTree
# The light table against native PointLight2D receiving. Two pages of the same
# size: one white receiver lit by native lights configured exactly as the
# receiving pages configure them (Lighting2D.project), and one unshaded item
# evaluating light_table.gdshaderinc for the same pixels and normals. Both store
# irradiance (white source), in HDR and LDR. No production scene is involved.
const Lighting2D = preload("res://presentation/lighting_2d.gd")
const NativeSourceLights = preload("res://presentation/native_source_lights.gd")
const LightTable = preload("res://presentation/light_table.gd")
const AMBIENT := 0.30
const SIZE := Vector2i(512, 384)
const PROBE_NORMAL = '''
vec3 probe_normal(vec2 p) {
    if (p.y > 320.0) return vec3(0.0, 0.0, 1.0);
    vec2 d = (p - vec2(256.0, 160.0)) / 200.0;
    return normalize(vec3(d.x, d.y, 0.55 + 0.3 * sin(p.x * 0.05)));
}
varying vec2 screen_pixel;
void vertex() { screen_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
'''
const NATIVE = '''shader_type canvas_item;
render_mode blend_disabled;
''' + PROBE_NORMAL + '''
void fragment() {
    LIGHT_VERTEX = vec3(screen_pixel, 0.0);
    NORMAL = probe_normal(screen_pixel);
    COLOR = vec4(1.0);
}'''
const TABLE = '''shader_type canvas_item;
render_mode blend_disabled, unshaded;
#include "res://presentation/light_table.gdshaderinc"
uniform float ambient;
''' + PROBE_NORMAL + '''
void fragment() {
    COLOR = vec4(table_light(screen_pixel, normalize(probe_normal(screen_pixel)), vec3(1.0), ambient), 1.0);
}'''

var checks := 0
var failures: Array = []
var report: Dictionary = {}

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); print("LIGHT_TABLE_FAIL ", label)

func _initialize() -> void: run.call_deferred()

# The node inputs Lighting2D.project() writes: texture_scale, scale, offset.
func node_inputs(source: Dictionary) -> Dictionary:
    var texture: Texture2D = source.texture
    var scale := Vector2(1, source.ellipse)
    source.texture_scale = source.diameter / texture.get_width()
    source.cookie_scale = scale
    source.offset = (source.cookie_position - source.screen_position) / scale
    source.span = Vector2(texture.get_size()) * source.texture_scale * scale
    return source

func lights() -> Array:
    var world := Lighting2D.new()
    var spells := NativeSourceLights.new()
    var near: Texture2D = world._source_cookie({"outer": 6.0, "very_bright_radius_feet": 10, "bright_radius_feet": 20})
    var far: Texture2D = world._source_cookie({"outer": 8.0, "very_bright_radius_feet": 0, "bright_radius_feet": 20})
    var spell: Texture2D = spells._effect_cookie("", 1.0)
    var ellipse := 0.57735
    # Positions, cookie centres (support points), spans, heights as project() builds them.
    return [
        node_inputs({"id": "torch-a", "screen_position": Vector2(140.3, 120.7), "cookie_position": Vector2(140.3, 150.2), "texture": near,
            "diameter": 300.4, "ellipse": ellipse, "height": 79.19, "energy": 2.0 * 0.93, "color": Lighting2D.TORCH_COLOUR, "enabled": true}),
        node_inputs({"id": "torch-b", "screen_position": Vector2(330.6, 90.1), "cookie_position": Vector2(330.6, 128.9), "texture": far,
            "diameter": 420.0, "ellipse": ellipse, "height": 79.19, "energy": 1.6, "color": Lighting2D.TORCH_COLOUR, "enabled": true}),
        node_inputs({"id": "white", "screen_position": Vector2(420, 260), "cookie_position": Vector2(420, 280.5), "texture": near,
            "diameter": 260.0, "ellipse": ellipse, "height": 79.19, "energy": 2.0, "color": Color.WHITE, "enabled": true}),
        node_inputs({"id": "spell", "screen_position": Vector2(250.25, 230.75), "cookie_position": Vector2(250.25, 230.75), "texture": spell,
            "diameter": 240.0, "ellipse": 1.0, "height": 31.3, "energy": 3.5, "color": Color(0.35, 0.55, 0.95), "enabled": true}),
        node_inputs({"id": "off", "screen_position": Vector2(60, 330), "cookie_position": Vector2(60, 330), "texture": spell,
            "diameter": 200.0, "ellipse": 1.0, "height": 20.0, "energy": 2.0, "color": Color.WHITE, "enabled": false}),
    ]

func page(hdr: bool, shader_code: String, sources: Array, native: bool) -> SubViewport:
    # The canvas shader sees CanvasModulate after Godot's HDR conversion.
    var modulate := Color(AMBIENT, AMBIENT, AMBIENT).linear_to_srgb() if hdr else Color(AMBIENT, AMBIENT, AMBIENT)
    var view := SubViewport.new()
    view.size = SIZE; view.disable_3d = true; view.transparent_bg = true; view.use_hdr_2d = hdr
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    root.add_child(view)
    if native:
        var ambient := CanvasModulate.new()
        # As the receiving pages: Godot converts CanvasModulate under HDR only.
        ambient.color = modulate
        view.add_child(ambient)
        for source in sources:
            var light := PointLight2D.new()
            var texture: Texture2D = source.texture
            light.texture = texture
            light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
            light.position = source.screen_position
            light.scale = source.cookie_scale
            light.offset = source.offset
            light.texture_scale = source.texture_scale
            light.height = source.height
            light.energy = source.energy
            light.color = source.color
            light.enabled = source.enabled
            view.add_child(light)
    var rect := ColorRect.new()
    rect.size = Vector2(SIZE)
    var material := ShaderMaterial.new()
    var shader := Shader.new(); shader.code = shader_code
    material.shader = shader
    if not native: material.set_shader_parameter("ambient", modulate.srgb_to_linear().r if hdr else modulate.r)
    rect.material = material
    view.add_child(rect)
    return view

func floats(image: Image) -> Image:
    var copy := image.duplicate()
    copy.convert(Image.FORMAT_RGBAF)
    return copy

func compare(hdr: bool, native: Image, table: Image) -> Dictionary:
    var a := floats(native); var b := floats(table)
    var worst := 0.0; var worst_at := Vector2i(-1, -1); var over := 0
    var limit := 1.0 / 512.0 if hdr else 0.5 / 255.0
    for y in SIZE.y:
        for x in SIZE.x:
            var p := a.get_pixel(x, y); var q := b.get_pixel(x, y)
            var error := maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b)))
            if hdr: error /= maxf(1.0, maxf(p.r, maxf(p.g, p.b)))
            if error > worst: worst = error; worst_at = Vector2i(x, y)
            if error > limit: over += 1
    var lit := 0; var brightest := 0.0
    for y in range(0, SIZE.y, 4):
        for x in range(0, SIZE.x, 4):
            var p := a.get_pixel(x, y)
            brightest = maxf(brightest, p.r)
            if p.r > AMBIENT + 0.01: lit += 1
    var sample := a.get_pixel(worst_at.x, worst_at.y) if worst_at.x >= 0 else Color()
    var other := b.get_pixel(worst_at.x, worst_at.y) if worst_at.x >= 0 else Color()
    return {"hdr": hdr, "worst": worst, "worst_at": [worst_at.x, worst_at.y], "native": [sample.r, sample.g, sample.b],
        "table": [other.r, other.g, other.b], "pixels_over_limit": over, "limit": limit,
        "lit_samples": lit, "samples": (SIZE.x / 4) * (SIZE.y / 4), "brightest": brightest}

func run() -> void:
    var sources := lights()
    # GradientTexture2D generates its image on the render thread.
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    var images := {}
    for source in sources: images[source.texture.get_rid()] = source.texture
    var retained := {}
    for rid in images:
        var image: Image = images[rid].get_image().duplicate()
        image.convert(Image.FORMAT_RGBA8)
        retained[rid] = image
    var table := LightTable.new()
    table.publish(sources, func(texture: Texture2D) -> Image: return retained.get(texture.get_rid()))
    check(table.issues.is_empty(), "Table publishes every prepared light: " + str(table.issues))
    check(table.count == 4 and table.ids == PackedStringArray(["torch-a", "torch-b", "white", "spell"]), "Disabled lights stay out of the table")
    var results := []
    for hdr in [true, false]:
        var native_view := page(hdr, NATIVE, sources, true)
        var table_view := page(hdr, TABLE, sources, false)
        for i in 2: await process_frame
        await RenderingServer.frame_post_draw
        var result := compare(hdr, native_view.get_texture().get_image(), table_view.get_texture().get_image())
        results.append(result)
        print("LIGHT_TABLE ", JSON.stringify(result))
        check(result.lit_samples > result.samples / 3 and result.brightest > (1.0 if hdr else 0.9), "Native page is lit, hdr=" + str(hdr))
        check(result.pixels_over_limit == 0, "Table irradiance equals native PointLight2D receiving, hdr=" + str(hdr))
        native_view.queue_free(); table_view.queue_free()
    report = {"checks": checks, "failures": failures, "comparisons": results}
    print("LIGHT_TABLE_REPORT ", JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
