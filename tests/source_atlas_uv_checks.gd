extends SceneTree
## Float32 source-boundary regression and native shader parser admission.
## The native scene integration suite separately checks rendered coverage.
var checks := 0
var failures: Array = []
var samples: Array = []

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); push_error(label)

func f32(value: float) -> float:
    return PackedFloat32Array([value])[0]

func _initialize() -> void:
    for path in ["canvas_received.gdshader", "canvas_capped_modular.gdshader",
            "canvas_capped_environment.gdshader", "canvas_capped_water.gdshader",
            "native_scene_support.gdshader"]:
        var shader: Shader = load("res://presentation/" + path)
        var fields := {}
        for parameter in shader.get_shader_uniform_list(): fields[parameter.name] = true
        check(shader.get_mode() == Shader.MODE_SPATIAL, path + ": shared include parses as spatial shader")
        check(fields.has("received") and fields.has("source_crop") and fields.has("atlas_region"), path + ": existing receiving address remains bindable")
    # Values immediately below original source boundaries. Adding the atlas
    # origin rounds the atlas address onto the next texel, whereas raw UV still
    # selects the preceding source texel. Test the actual single precision steps.
    for atlas_x in [129, 1025, 4097]:
        for item in [[42, 0.3281249701976776], [68, 0.5312499403953552], [75, 0.5859374403953552]]:
            var boundary: int = item[0]
            var uv: float = item[1]
            var crop := f32(40.0 / 128.0)
            var width := f32(52.0 / 128.0)
            var origin := f32(float(atlas_x) / 8192.0)
            var size := f32(52.0 / 8192.0)
            var cell := f32(f32(uv - crop) / width)
            var atlas_pixel := floorf(f32(f32(origin + f32(cell * size)) * 8192.0))
            var selected := f32(crop + f32(f32(f32(f32(atlas_pixel + 0.5) - f32(origin * 8192.0)) / f32(size * 8192.0)) * width))
            var raw_pixel := int(floorf(f32(uv * 128.0)))
            var selected_pixel := int(floorf(f32(selected * 128.0)))
            var label := "atlas%d/source%d" % [atlas_x, boundary]
            check(raw_pixel == boundary - 1, label + ": raw quad UV reproduces preceding texel")
            check(int(atlas_pixel) == atlas_x + boundary - 40, label + ": atlas read admits following texel")
            check(selected_pixel == boundary, label + ": recovered source UV agrees with atlas coverage")
            check(selected == float(boundary + 0.5) / 128.0, label + ": recovery samples its texel centre")
            samples.append({"atlas_x":atlas_x, "uv":uv, "raw_source_pixel":raw_pixel,
                "atlas_pixel":atlas_pixel, "selected_source_pixel":selected_pixel})
    var report := {"checks":checks, "failures":failures, "samples":samples,
        "qualification":"Float32 address regression and native shader parsing only; rendered zoom/coverage remains in the native scene integration suite"}
    FileAccess.open("res://generated/source_atlas_uv_checks.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
    print("SOURCE_ATLAS_UV_CHECKS ", checks, " failures=", failures.size())
    quit(0 if failures.is_empty() else 1)
