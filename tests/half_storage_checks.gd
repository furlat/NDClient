extends SceneTree
# How this GPU stores float colour into an RGBA16F render target, against
# shader-side emulations: round-to-nearest (packHalf2x16) and toward zero.
const PROBE = '''shader_type canvas_item;
render_mode blend_disabled, unshaded;
uniform int mode = 0;
float toward_zero(float v) {
    uint bits = packHalf2x16(vec2(v, 0.0)) & 0xFFFFu;
    if (unpackHalf2x16(bits).x > v) bits -= 1u;
    return unpackHalf2x16(bits).x;
}
void fragment() {
    vec2 p = floor(FRAGCOORD.xy);
    float v = 0.25 + (p.x + p.y * 512.0) * 0.0000071 + 0.0000003 * sin(p.x);
    vec3 c = vec3(v, v * 1.37, v * 2.11);
    if (mode == 1) c = vec3(unpackHalf2x16(packHalf2x16(vec2(c.r, 0.0))).x, unpackHalf2x16(packHalf2x16(vec2(c.g, 0.0))).x, unpackHalf2x16(packHalf2x16(vec2(c.b, 0.0))).x);
    if (mode == 2) c = vec3(toward_zero(c.r), toward_zero(c.g), toward_zero(c.b));
    COLOR = vec4(c, 1.0);
}'''

func _initialize() -> void: run.call_deferred()

func page(mode: int) -> SubViewport:
    var view := SubViewport.new(); view.size = Vector2i(512, 512); view.disable_3d = true; view.use_hdr_2d = true
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var rect := ColorRect.new(); rect.size = Vector2(512, 512)
    var material := ShaderMaterial.new(); var shader := Shader.new(); shader.code = PROBE
    material.shader = shader; material.set_shader_parameter("mode", mode); rect.material = material
    view.add_child(rect)
    return view

func run() -> void:
    var views := [page(0), page(1), page(2)]
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    var first: Image = views[0].get_texture().get_image()
    print("HALF_STORAGE_FORMAT ", first.get_format(), " ", Image.FORMAT_RGBAH)
    var images := views.map(func(v): return v.get_texture().get_image().get_data())
    var result := {}
    for i in [1, 2]:
        var same := 0
        var a: PackedByteArray = images[0]; var b: PackedByteArray = images[i]
        for k in range(0, a.size(), 2):
            if a[k] == b[k] and a[k + 1] == b[k + 1]: same += 1
        result[["", "nearest", "toward_zero"][i]] = float(same) / float(a.size() / 2)
    print("HALF_STORAGE ", JSON.stringify(result))
    quit()
