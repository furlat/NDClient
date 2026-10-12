extends "res://tests/native_2d_source_checks.gd"
# The original 16-frame torch on the production Canvas->3D path. The input files
# are never rewritten; the zero-pedestal control retains their original alpha.
const Flame = preload("res://presentation/canvas_fixture_flame.gdshader")
const Output = preload("res://presentation/canvas_received.gdshader")
const Media = preload("res://presentation/media_warmup.gd")
var frame_results: Array = []

func atlas(material: ShaderMaterial) -> SubViewport:
    var view=page(false)
    material.set_shader_parameter("source_crop",Vector4(0,0,1,1))
    material.set_shader_parameter("atlas_cell_size",Vector2(256,256))
    var node=sprite(view,material,Transform2D.IDENTITY)
    node.region_enabled=true;node.region_rect=Rect2(0,0,256,256)
    node.region_filter_clip_enabled=false
    return view

func output(view: SubViewport, original: ShaderMaterial=null) -> SubViewport:
    var result=SubViewport.new();result.size=Vector2i(320,320);result.own_world_3d=true
    result.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(result)
    var environment=WorldEnvironment.new();environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_COLOR
    environment.environment.background_color=Color8(8,14,23)
    result.add_child(environment)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=2.5;camera.position=Vector3(0,0,3);result.add_child(camera)
    var material=original
    if material==null:
        material=ShaderMaterial.new();material.shader=Output
        material.set_shader_parameter("received",view.get_texture())
        material.set_shader_parameter("atlas_region",Vector4(0,0,.5,.5))
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(2,2)
    node.material_override=material;result.add_child(node)
    return result

func cpu_blend(source: Color, background: Color) -> Color:
    var linear=source.srgb_to_linear();var back=background.srgb_to_linear()
    var mixed=Color(linear.r*source.a+back.r*(1-source.a),linear.g*source.a+back.g*(1-source.a),linear.b*source.a+back.b*(1-source.a),1)
    return mixed.linear_to_srgb()

func rgb_error(a: Color,b: Color) -> int:
    return maxi(absi(a.r8-b.r8),maxi(absi(a.g8-b.g8),absi(a.b8-b.b8)))

func run() -> void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var one=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE)
    white=ImageTexture.create_from_image(one)
    var probe=SourceProbe.new();root.add_child(probe);probe.hide()
    probe.camera=Camera3D.new();probe.add_child(probe.camera)
    var assets: Dictionary=Catalog.read_file("assets.json",probe.catalog_cache)
    var authored: Dictionary=assets.animations["torch.flame"]
    check(authored.frames.size()==16 and float(authored.fps)==10,"Original torch has16 authored frames at10FPS")
    for frame in authored.frames:
        var path: String=assets.resources[frame].path
        var decoded={}
        Media._decode({"path":path,"absolute":Catalog.media_path(path),"fixture":true},decoded)
        check(not decoded.has("error"),"Original torch frame prepares: "+frame)
        if decoded.has("error"):quit(1);return
        probe.source_images[path]=decoded.image
        probe.fixture_frame_energy[path]=decoded.energy
        probe.fixture_frame_centroids[path]=decoded.emission_centroid
    var row={"id":"actual-torch-padding","kind":"object","position":[0,0],"base_height_steps":0,"lit_animation":"torch.flame"}
    probe._add_fixture_flame(row)
    var entry: Dictionary=probe.entries.back()
    check(is_equal_approx(entry.material.get_shader_parameter("alpha_pedestal"),1.0/255.0),"Production torch registration binds only its measured padding pedestal")
    check(entry.record==assets.resources[authored.frames[0]],"Production flame keeps original registration/pivot/scale")
    var corrected=ShaderMaterial.new();corrected.shader=Flame
    for uniform in entry.material.shader.get_shader_uniform_list():
        corrected.set_shader_parameter(uniform.name,entry.material.get_shader_parameter(uniform.name))
    # Leave alpha_pedestal unbound: native default0 must preserve other effects.
    var before=ShaderMaterial.new();before.shader=Flame
    before.set_shader_parameter("frames",entry.material.get_shader_parameter("frames"))
    var a=atlas(before);var b=atlas(corrected)
    var out_a=output(a);var out_b=output(b)
    var direct_material: ShaderMaterial=entry.material.duplicate()
    var direct=output(null,direct_material)
    DirAccess.make_dir_recursive_absolute("res://.captures/torch-padding")
    for index in authored.frames.size():
        before.set_shader_parameter("frame_index",index);corrected.set_shader_parameter("frame_index",index)
        direct_material.set_shader_parameter("frame_index",index)
        var source: Image=probe.source_images[assets.resources[authored.frames[index]].path]
        var raw=(await capture(a)).get_region(Rect2i(0,0,256,256))
        var fixed=(await capture(b)).get_region(Rect2i(0,0,256,256))
        var image_before=await capture(out_a);var image_after=await capture(out_b);var image_direct=await capture(direct)
        var background=image_after.get_pixel(0,0)
        var border_values={};var border_pixels:=0;var leaked_border:=0;var original_border:=0
        var source_rgb_errors:=0;var original_alpha_errors:=0;var fixed_alpha_errors:=0;var alpha_rounding_differences:=0
        var glow_pixels:=0;var lost_glow:=0;var opaque_changes:=0;var blend_max:=0;var direct_max:=0
        for y in 256:
            for x in 256:
                var original=source.get_pixel(x,y);var uncorrected=raw.get_pixel(x,y);var actual=fixed.get_pixel(x,y)
                var expected_alpha=0 if original.a8<=1 else roundi((original.a8-1)*255.0/254.0)
                if original.a8>0 and rgb_error(original,uncorrected)>0:source_rgb_errors+=1
                if original.a8>1 and rgb_error(original,actual)>0:source_rgb_errors+=1
                if uncorrected.a8!=original.a8:original_alpha_errors+=1
                if actual.a8!=expected_alpha:alpha_rounding_differences+=1
                # Native render-target quantization can choose either adjacent
                # byte near a midpoint. The continuous subtraction is bounded
                # by one source alpha byte; its zero/full-opacity endpoints and
                # all positive glow are checked independently and exactly.
                if actual.a8<maxi(0,original.a8-1) or actual.a8>original.a8 or (original.a8<=1 and actual.a8!=0):fixed_alpha_errors+=1
                if original.a8>1:
                    glow_pixels+=1
                    if actual.a8==0:lost_glow+=1
                var p=Vector2i(x+32,y+32)
                var rendered=image_after.get_pixelv(p)
                blend_max=maxi(blend_max,rgb_error(rendered,cpu_blend(actual,background)))
                direct_max=maxi(direct_max,rgb_error(rendered,image_direct.get_pixelv(p)))
                if original.a8==255 and image_before.get_pixelv(p)!=rendered:opaque_changes+=1
                if x==0 or y==0 or x==255 or y==255:
                    border_pixels+=1;border_values[original.a8]=true
                    if rendered!=background:leaked_border+=1
                    if image_before.get_pixelv(p)!=background:original_border+=1
        var label="Frame"+str(index)+": "
        check(border_values.keys().all(func(value):return value<=1),label+"source border contains only alpha0/1")
        check(original_border>0,label+"uncorrected original reproduces visible rectangle on dark background")
        check(leaked_border==0,label+"every corrected border pixel equals background exactly")
        check(source_rgb_errors==0 and original_alpha_errors==0,label+"source RGB and zero-pedestal alpha remain byte exact")
        check(fixed_alpha_errors==0,label+"native alpha changes by at most one byte with exact padding removal")
        check(glow_pixels>10000 and lost_glow==0,label+"all original alpha>1 glow survives")
        check(opaque_changes==0,label+"opaque rendered flame stays byte exact")
        check(blend_max<=1,label+"full-frame dark-background composition matches independent linear source-over: "+str(blend_max))
        check(direct_max<=1,label+"workshop and Canvas-to3D flame agree within native transfer precision: "+str(direct_max))
        frame_results.append({"frame":index,"source":assets.resources[authored.frames[index]].path,"border_alpha":border_values.keys(),"border_pixels":border_pixels,"uncorrected_changed_border":original_border,"corrected_changed_border":leaked_border,"glow_pixels":glow_pixels,"lost_glow":lost_glow,"opaque_changes":opaque_changes,"source_rgb_errors":source_rgb_errors,"original_alpha_errors":original_alpha_errors,"corrected_alpha_errors":fixed_alpha_errors,"nearest_integer_alpha_differences":alpha_rounding_differences,"blend_max_rgb_bytes":blend_max,"direct_max_rgb_bytes":direct_max})
        if index==6:
            image_before.save_png("res://.captures/torch-padding/frame06-before.png")
            image_after.save_png("res://.captures/torch-padding/frame06-after.png")
            fixed.save_png("res://.captures/torch-padding/frame06-receiving.png")
    var report={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"frames":frame_results,"scope":"Original16 torch.flame sheets, actual registration and production Canvas/spatial shaders. One-byte alpha padding removed continuously; no source RGB/file/clock changes. Partial alpha changes by at most1byte; native rounding differences from CPU nearest integer are separately recorded. Border/background, original default alpha/RGB and opaque comparisons exact. No positive alpha>1 glow lost. Remaining quantized glow bands are not asserted fixed. Native final linear blend allows at most1RGBbyte."}
    FileAccess.open("res://generated/torch_padding_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("TORCH_PADDING_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
