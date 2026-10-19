extends "res://tests/native_2d_source_checks.gd"
# The original 16-frame torch through the production lit flame shader
# (presentation/fixture_flame.gdshader), with and without the light cap. The
# input files are never rewritten; the zero-pedestal control keeps their alpha.
# Stored alpha is read from a transparent target; composition from a dark one.
const Flame = preload("res://presentation/fixture_flame.gdshader")
const Workshop = preload("res://workshop/fixture_flame_3d.gdshader")
const Media = preload("res://presentation/media_warmup.gd")
const DARK = Color8(8,14,23)
var frame_results: Array = []

func output(material: ShaderMaterial,background: Color) -> SubViewport:
    var result=SubViewport.new();result.size=Vector2i(320,320);result.own_world_3d=true;result.transparent_bg=background.a<1.0
    result.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(result)
    var environment=WorldEnvironment.new();environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_COLOR
    environment.environment.background_color=background
    result.add_child(environment)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=2.5;camera.position=Vector3(0,0,3);result.add_child(camera)
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
    var assets: Dictionary=Catalog.environment_resources(probe.catalog_cache)
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
    check(entry.material.shader==Flame,"Production torch uses the lit flame shader")
    check(is_equal_approx(entry.material.get_shader_parameter("alpha_pedestal"),1.0/255.0),"Production torch registration binds only its measured padding pedestal")
    check(entry.record==assets.resources[authored.frames[0]],"Production flame keeps original registration/pivot/scale")
    var corrected: ShaderMaterial=entry.material.duplicate()
    # Leave alpha_pedestal unbound: native default0 must preserve other effects.
    var before=ShaderMaterial.new();before.shader=Flame
    before.set_shader_parameter("frames",entry.material.get_shader_parameter("frames"))
    var workshop=ShaderMaterial.new();workshop.shader=Workshop
    for parameter in ["frames","alpha_pedestal"]:workshop.set_shader_parameter(parameter,entry.material.get_shader_parameter(parameter))
    var out_a=output(before,DARK);var out_b=output(corrected,DARK);var direct=output(workshop,DARK)
    var alpha_a=output(before,Color(0,0,0,0));var alpha_b=output(corrected,Color(0,0,0,0))
    DirAccess.make_dir_recursive_absolute("res://.captures/torch-padding")
    for cap in [0.0,1.0]:
        # Flames are emissive: no lights; the cap only selects half/byte storage.
        publish_receiving([],1.0,cap)
        for index in authored.frames.size():
            for material in [before,corrected,workshop]:material.set_shader_parameter("frame_index",index)
            var source: Image=probe.source_images[assets.resources[authored.frames[index]].path]
            var image_before=await capture(out_a);var image_after=await capture(out_b);var image_direct=await capture(direct)
            var raw=await capture(alpha_a);var fixed=await capture(alpha_b)
            var background=image_after.get_pixel(0,0)
            var border_values={};var border_pixels:=0;var leaked_border:=0;var original_border:=0
            var original_alpha_errors:=0;var fixed_alpha_errors:=0;var alpha_rounding_differences:=0
            var glow_pixels:=0;var lost_glow:=0;var opaque_changes:=0;var blend_max:=0;var direct_max:=0
            for y in 256:
                for x in 256:
                    var original=source.get_pixel(x,y)
                    var p=Vector2i(x+32,y+32)
                    var uncorrected_alpha: int=raw.get_pixelv(p).a8;var actual_alpha: int=fixed.get_pixelv(p).a8
                    var expected_alpha=0 if original.a8<=1 else roundi((original.a8-1)*255.0/254.0)
                    if uncorrected_alpha!=original.a8:original_alpha_errors+=1
                    if actual_alpha!=expected_alpha:alpha_rounding_differences+=1
                    # The continuous subtraction is bounded by one source alpha
                    # byte; its zero/full-opacity endpoints and all positive glow
                    # are checked independently and exactly.
                    if actual_alpha<maxi(0,original.a8-1) or actual_alpha>original.a8 or (original.a8<=1 and actual_alpha!=0):fixed_alpha_errors+=1
                    if original.a8>1:
                        glow_pixels+=1
                        if actual_alpha==0:lost_glow+=1
                    var rendered=image_after.get_pixelv(p)
                    var stored=Color(original.r,original.g,original.b,actual_alpha/255.0)
                    blend_max=maxi(blend_max,rgb_error(rendered,cpu_blend(stored,background)))
                    direct_max=maxi(direct_max,rgb_error(rendered,image_direct.get_pixelv(p)))
                    if original.a8==255 and image_before.get_pixelv(p)!=rendered:opaque_changes+=1
                    if x==0 or y==0 or x==255 or y==255:
                        border_pixels+=1;border_values[original.a8]=true
                        if rendered!=background:leaked_border+=1
                        if image_before.get_pixelv(p)!=background:original_border+=1
            var label="Frame"+str(index)+(" cap" if cap>0.0 else " ldr")+": "
            check(border_values.keys().all(func(value):return value<=1),label+"source border contains only alpha0/1")
            check(original_border>0,label+"uncorrected original reproduces visible rectangle on dark background")
            check(leaked_border==0,label+"every corrected border pixel equals background exactly")
            check(original_alpha_errors==0,label+"zero-pedestal stored alpha remains byte exact")
            check(fixed_alpha_errors==0,label+"stored alpha changes by at most one byte with exact padding removal")
            check(glow_pixels>10000 and lost_glow==0,label+"all original alpha>1 glow survives")
            check(opaque_changes==0,label+"opaque rendered flame stays byte exact")
            check(blend_max<=1,label+"full-frame dark-background composition of source RGB matches independent linear source-over: "+str(blend_max))
            check(direct_max<=1,label+"workshop 3D flame and lit game flame agree within native transfer precision: "+str(direct_max))
            frame_results.append({"frame":index,"cap":cap,"source":assets.resources[authored.frames[index]].path,"border_alpha":border_values.keys(),"border_pixels":border_pixels,"uncorrected_changed_border":original_border,"corrected_changed_border":leaked_border,"glow_pixels":glow_pixels,"lost_glow":lost_glow,"opaque_changes":opaque_changes,"original_alpha_errors":original_alpha_errors,"corrected_alpha_errors":fixed_alpha_errors,"nearest_integer_alpha_differences":alpha_rounding_differences,"blend_max_rgb_bytes":blend_max,"direct_max_rgb_bytes":direct_max})
            if index==6 and cap==0.0:
                image_before.save_png("res://.captures/torch-padding/frame06-before.png")
                image_after.save_png("res://.captures/torch-padding/frame06-after.png")
                fixed.save_png("res://.captures/torch-padding/frame06-transparent.png")
    probe.free()
    var report={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"frames":frame_results,"scope":"Original16 torch.flame sheets, actual registration and the production lit flame shader, light cap off (byte storage) and on (half storage). One-byte alpha padding removed continuously; no source RGB/file/clock changes. Stored alpha (transparent target) changes by at most1byte; native rounding differences from CPU nearest integer are separately recorded. Border/background, original default alpha and opaque comparisons exact. No positive alpha>1 glow lost. Dark-background composition matches linear source-over and the workshop 3D flame within1RGBbyte."}
    FileAccess.open("res://generated/torch_padding_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("TORCH_PADDING_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
