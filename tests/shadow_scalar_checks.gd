extends SceneTree
# Synthetic visibility values isolate numeric transport through the actual
# helper light shader and production shadow composite. No invented art/outcome.
const Shadows=preload("res://presentation/canvas_shadows.gd")
var checks=0
var failures=[]
var samples=[]
var helper:SubViewport
var output:SubViewport
var probe_material:ShaderMaterial
var sample_material:ShaderMaterial
var composite:ShaderMaterial
var output_quad:MeshInstance3D
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("SHADOW_SCALAR_FAIL ",label)
func _initialize()->void:run.call_deferred()
func viewport()->SubViewport:
    var result=SubViewport.new();result.size=Vector2i(32,32);result.world_3d=World3D.new()
    result.render_target_update_mode=SubViewport.UPDATE_ALWAYS;result.msaa_3d=Viewport.MSAA_DISABLED
    root.add_child(result)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;camera.position.z=3
    var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.WHITE
    environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_energy=0
    camera.environment=environment;result.add_child(camera);camera.current=true
    return result
func quad(parent:Node,material:ShaderMaterial,z:float=0)->MeshInstance3D:
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(2,2);node.position.z=z
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.material_override=material;parent.add_child(node);return node
func material(code:String)->ShaderMaterial:
    var shader=Shader.new();shader.code=code
    var result=ShaderMaterial.new();result.shader=shader;return result
func image_after_frames(view:SubViewport)->Image:
    await process_frame;await RenderingServer.frame_post_draw
    await process_frame;await RenderingServer.frame_post_draw
    return view.get_texture().get_image()
func run()->void:
    if DisplayServer.get_name()=="headless":quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    helper=viewport();output=viewport()
    var code=FileAccess.get_file_as_string("res://presentation/shadow_visibility.gdshader")
    var expression="float visibility=falloff>0.000001 ? clamp(ATTENUATION/falloff,0.0,1.0) : 1.0;"
    check(code.contains(expression),"Known visibility input uses the unchanged production scalar-output path")
    code=code.replace("uniform float helper_range;","uniform float helper_range;\nuniform float test_visibility;\nuniform bool test_edge;")
    code=code.replace(expression,"float visibility=test_edge ? clamp((world_position.x+0.75)/1.5,0.0,1.0) : test_visibility;")
    probe_material=material(code);probe_material.set_shader_parameter("helper_position",Vector3(0,0,1));probe_material.set_shader_parameter("helper_range",4.0)
    quad(helper,probe_material)
    var lamp=OmniLight3D.new();lamp.position.z=1;lamp.omni_range=4;lamp.light_energy=1;helper.add_child(lamp)
    var sampler_line=""
    for line in FileAccess.get_file_as_string("res://presentation/shadow_composite.gdshader").split("\n"):
        if line.begins_with("uniform sampler2D visibility_map"):sampler_line=line.replace("visibility_map","scalar_map")
    check(not sampler_line.is_empty(),"Scalar probe uses the production visibility sampler's native hints")
    sample_material=material("shader_type spatial; render_mode unshaded,fog_disabled; "+sampler_line+" void fragment(){ALBEDO=vec3(texture(scalar_map,UV).r);}")
    sample_material.set_shader_parameter("scalar_map",helper.get_texture())
    output_quad=quad(output,sample_material)
    composite=ShaderMaterial.new();composite.shader=Shadows.COMPOSITE
    composite.set_shader_parameter("visibility_map",helper.get_texture());composite.set_shader_parameter("source_count",1);composite.set_shader_parameter("dominant_index",0)
    var cookie=Image.create(1,1,false,Image.FORMAT_RGBA8);cookie.fill(Color.WHITE)
    composite.set_shader_parameter("cookie_atlas",ImageTexture.create_from_image(cookie))
    var data=Image.create(3,1,false,Image.FORMAT_RGBAF)
    data.set_pixel(0,0,Color(16,16,64,64));data.set_pixel(1,0,Color(0,0,1,1));data.set_pixel(2,0,Color(1,0,0,0))
    composite.set_shader_parameter("source_data",ImageTexture.create_from_image(data))
    for level in [0.0,0.125,0.25,0.5,0.75,1.0]:
        probe_material.set_shader_parameter("test_visibility",level)
        output_quad.material_override=sample_material
        var numeric=await image_after_frames(output)
        var transported=numeric.get_pixel(16,16).srgb_to_linear().r
        check(absf(transported-level)<=0.006,"Numeric visibility survives helper texture sampling at"+str(level))
        output_quad.material_override=composite
        var image=await image_after_frames(output)
        var expected=Color(1-214.0/255*(1-level),0,0).linear_to_srgb().r
        var actual=image.get_pixel(16,16).r
        check(absf(actual-expected)<=1.5/255,"Native linear source-over uses exact fractional visibility at"+str(level))
        samples.append({"input":level,"sampled_linear":transported,"composite_expected_srgb":expected,"composite_actual":actual})
    probe_material.set_shader_parameter("test_edge",true)
    output_quad.material_override=composite
    var edge=await image_after_frames(output)
    var fractional=0;var worst=0.0
    for x in 32:
        var coordinate=(float(x)+.5)/32*2-1
        var visibility=clampf((coordinate+.75)/1.5,0,1)
        if visibility<=0 or visibility>=1:continue
        var expected=Color(1-214.0/255*(1-visibility),0,0).linear_to_srgb().r
        worst=maxf(worst,absf(edge.get_pixel(x,16).r-expected));fractional+=1
    check(fractional>=20,"Fractional visibility edge covers native sample centers")
    check(worst<=1.5/255,"Production composite preserves fractional edge scalar values")
    # A native shadow-map edge complements the synthetic transport ramp. A
    # mathematical caster is deliberate test geometry, never a game asset.
    probe_material.shader=Shadows.VISIBILITY
    probe_material.set_shader_parameter("helper_position",Vector3(0,0,1))
    probe_material.set_shader_parameter("helper_range",4.0)
    lamp.shadow_enabled=true;lamp.shadow_bias=.01;lamp.shadow_normal_bias=0;lamp.shadow_blur=1.5;lamp.omni_attenuation=1.0
    helper.positional_shadow_atlas_size=2048
    for quadrant in 4:helper.set_positional_shadow_atlas_quadrant_subdiv(quadrant,Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4)
    var caster=MeshInstance3D.new();caster.mesh=BoxMesh.new();caster.mesh.size=Vector3(.43,.59,.1)
    caster.position=Vector3(.137,.097,.25);caster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY;helper.add_child(caster)
    for _frame in 6:await process_frame;await RenderingServer.frame_post_draw
    var native_composite=await image_after_frames(output)
    var native_visibility=helper.get_texture().get_image()
    native_visibility.save_png("res://.captures/shadow-scalar-visibility.png")
    var native_fractional=0;var native_blocked=0;var native_worst=0.0
    for y in 32:
        for x in 32:
            var visibility=native_visibility.get_pixel(x,y).srgb_to_linear().r
            if visibility<.99:native_blocked+=1
            if visibility>.02 and visibility<.98:native_fractional+=1
            var expected=Color(1-214.0/255*(1-visibility),0,0).linear_to_srgb().r
            native_worst=maxf(native_worst,absf(native_composite.get_pixel(x,y).r-expected))
    check(native_blocked>5,"Native depth caster creates actual blocked samples")
    check(native_fractional>0,"Native shadow filtering supplies fractional edge visibility")
    check(native_worst<=1.5/255,"Actual native shadow edge follows independent linear source-over")
    var report={"checks":checks,"failures":failures,"samples":samples,"fractional_edge_samples":fractional,"fractional_edge_max_error":worst,"native_fractional_samples":native_fractional,"native_blocked_samples":native_blocked,"native_edge_max_error":native_worst,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Known scalar inputs through actual custom-light output and production viewport sampler/composite; fractional edge ramp and native box-caster edges are labeled optical fixtures, not authored gameplay geometry."}
    FileAccess.open("res://generated/shadow_scalar_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SHADOW_SCALAR_CHECKS ",JSON.stringify(report))
    helper.queue_free();output.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
