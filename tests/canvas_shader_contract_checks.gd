extends SceneTree
# Admission of the existing source-material packets to native Canvas shaders.
# Pixel/normal response is validated by the integrated native renderer lane.
var checks = 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("CANVAS_SHADER_FAIL ",label)

func _initialize() -> void:
    var cases = [
        ["res://presentation/canvas_environment.gdshader",["colour_texture","colour_rect","source_tint","selection_mask","selection_kind",
            "rgba_min","rgba_max","door_leaf_partition","door_depth_texture","door_frame_depth",
            "geometry_texture","geometry_rect","normal_texture","normal_rect","normal_to_local","local_normal_to_world","world_to_canvas",
            "current_visibility","use_instance_visibility"]],
        ["res://presentation/canvas_water.gdshader",["mask_texture","ripple_texture","displayed_time_seconds","origin","placement_origin",
            "canvas_instance_origin","world_to_canvas","camera_quarter","image_scale","shallow_color","deep_color","tint",
            "alpha_cutoff","overall_alpha","current_visibility","use_instance_visibility"]],
        ["res://presentation/canvas_fixture_flame.gdshader",["frames","frame_index"]],
    ]
    for item in cases:
        var shader: Shader = load(item[0])
        check(shader!=null and shader.get_mode()==Shader.MODE_CANVAS_ITEM,"Native Canvas shader: "+item[0])
        var uniforms = {}
        if shader!=null:
            for parameter in shader.get_shader_uniform_list(): uniforms[parameter.name] = true
        check(item[1].all(func(name):return uniforms.has(name)),"Existing source packet fields remain bindable: "+item[0])
    for family in ["environment","modular","water"]:
        var shader: Shader=load("res://presentation/canvas_received_"+family+".gdshader")
        var fields={}
        for parameter in shader.get_shader_uniform_list():fields[parameter.name]=true
        check(shader.get_mode()==Shader.MODE_SPATIAL and fields.has("received") and fields.has("wall_opacity") and fields.has("wall_mask_texture"),"Spatial output owns illumination cap and final coverage: "+family)
    var report = {"checks":checks,"failures":failures,"scope":"Headless native shader parser and source-uniform contract; no rendered pixel/lighting claim."}
    FileAccess.open("res://generated/canvas_shader_contract_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
