extends SceneTree
# Light cookies generated off the main thread equal GradientTexture2D's bytes:
# the world range cookies (cubic, with bright/very bright stops) and the spell
# attenuation cookies (65 linear stops). The reference is read back once here.
const LightCookies = preload("res://presentation/light_cookies.gd")
const Lighting2D = preload("res://presentation/lighting_2d.gd")
const NativeSourceLights = preload("res://presentation/native_source_lights.gd")

var checks := 0
var failures: Array = []

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); print("LIGHT_COOKIE_FAIL ", label)

func _initialize() -> void: run.call_deferred()

func reference(gradient: Gradient) -> GradientTexture2D:
    var texture := GradientTexture2D.new()
    texture.width = LightCookies.SIZE; texture.height = LightCookies.SIZE
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.fill_from = Vector2(.5, .5); texture.fill_to = Vector2(1, .5)
    texture.gradient = gradient
    return texture

func run() -> void:
    var world := Lighting2D.new()
    var spells := NativeSourceLights.new()
    var gradients := {
        "near": world._range_gradient(0.4, 0.8),
        "far": world._range_gradient(0.0, 0.6),
        "full": world._range_gradient(1.0, 1.0),
        "spell 0": spells._attenuation_gradient(0.0),
        "spell 1": spells._attenuation_gradient(1.0),
        "spell 2.5": spells._attenuation_gradient(2.5),
    }
    var pending := {}
    var references := {}
    for name in gradients:
        pending[name] = LightCookies.start(gradients[name])
        references[name] = reference(gradients[name])
    for i in 3: await process_frame
    var results := {}
    for name in gradients:
        var texture: Texture2D = null
        var deadline := Time.get_ticks_msec() + 20000
        while texture == null and Time.get_ticks_msec() < deadline:
            texture = LightCookies.texture(pending[name])
            if texture == null: await process_frame
        check(texture != null, "Cookie generates: " + name)
        if texture == null: continue
        var made: PackedByteArray = (texture.get_meta(&"cookie_image") as Image).get_data()
        var expected: Image = references[name].get_image()
        expected.convert(Image.FORMAT_RGBA8)
        var want: PackedByteArray = expected.get_data()
        var differing := 0; var worst := 0
        for k in want.size():
            var d: int = absi(int(made[k]) - int(want[k]))
            if d > 0: differing += 1; worst = maxi(worst, d)
        results[name] = {"differing_bytes": differing, "worst": worst}
        check(differing == 0, "Generated cookie equals GradientTexture2D: " + name + " " + str(results[name]))
    # A retiring preview may never poll its range cookie again. Own a real
    # worker result without asking texture(), which would upload/claim it.
    var closing := NativeSourceLights.new()
    var unpolled:Dictionary=LightCookies.start(closing._range_gradient(.4,.8))
    closing._range_cookies[Vector4(.4,.8,closing.range_profile.very_bright_edge,closing.range_profile.bright_edge)]=unpolled
    check(unpolled.task>=0 and unpolled.texture==null,"Terminal owner retains a real unpolled range-cookie task")
    closing.close()
    check(unpolled.task==-1 and unpolled.image!=null and not unpolled.image.is_empty() and unpolled.texture==null,
        "Terminal close joins range-cookie generation without uploading its texture")
    check(closing._range_cookies.is_empty(),"Terminal close releases its range-cookie owners")
    closing.close()
    check(unpolled.task==-1 and unpolled.texture==null and closing._range_cookies.is_empty(),
        "A second terminal close does not reclaim or upload the cookie again")
    print("LIGHT_COOKIE_REPORT ", JSON.stringify({"checks": checks, "failures": failures, "results": results}))
    quit(0 if failures.is_empty() else 1)
