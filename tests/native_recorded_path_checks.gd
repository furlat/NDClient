extends SceneTree
## Actual installed recordings and GPU path reader: the current root must not
## interpolate toward an unwritten transform. No art or full-cast qualification.
const Baked=preload("res://presentation/baked_effect.gd")
const Effects=preload("res://presentation/effect_package.gd")
const CLIPS=["projectile-windups/fireball_travel/default/cast/travel","spells/scorching_ray/back/lifecycle"]
const LAYER=1<<19
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
var output:String="res://.runtime/native-recorded-path-checks.json"

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->bool:
    checks+=1
    if not value:failures.append(label);printerr("NATIVE_RECORDED_PATH_FAIL ",label)
    return value
func frame()->void:
    await process_frame;await RenderingServer.frame_post_draw
func transform_at(placement:Dictionary,seconds:float)->Transform3D:
    var basis:Basis=Basis.from_euler(Vector3(.1,.35+seconds*.07,-.08)).scaled_local(Vector3(.8,1.1,.9))
    return Transform3D(basis,placement.origin+placement.velocity*seconds)
func view()->SubViewport:
    var viewport=SubViewport.new();viewport.size=Vector2i(64,64);viewport.own_world_3d=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    var camera=Camera3D.new();camera.cull_mask=LAYER;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=100
    viewport.add_child(camera);root.add_child(viewport)
    camera.look_at_from_position(Vector3(40,30,45),Vector3(10,0,5))
    return viewport
func probe()->Dictionary:
    var viewport=SubViewport.new();viewport.size=Vector2i(5,1);viewport.use_hdr_2d=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    var shader=Shader.new()
    shader.code="shader_type canvas_item;\n#include \"res://presentation/baked_path.gdshaderinc\"\n" \
        +"global uniform sampler2D baked_effect_clock;\nuniform float seconds;uniform mat4 expected_transform;uniform int actual_slot;\n" \
        +"void fragment(){int c=int(floor(UV.x*5.0));if(c<4){mat4 p=baked_root_at(seconds);" \
        +"COLOR=vec4((p[c].xyz-expected_transform[c].xyz)/64.0+vec3(0.5),1.0);}" \
        +"else{float age=texelFetch(baked_effect_clock,ivec2(actual_slot,0),0).r;COLOR=vec4(vec3(age-seconds+0.5),1.0);}}"
    var material=ShaderMaterial.new();material.shader=shader
    var rect=ColorRect.new();rect.size=Vector2(5,1);rect.material=material
    viewport.add_child(rect);root.add_child(viewport)
    return {"viewport":viewport,"material":material}
func bind_probe(value:Dictionary,handle:Dictionary,seconds:float,expected:Transform3D)->void:
    value.material.set_shader_parameter("root_history",handle.history)
    value.material.set_shader_parameter("seconds",seconds)
    value.material.set_shader_parameter("expected_transform",Projection(expected))
    value.material.set_shader_parameter("actual_slot",handle.slot)
func read_probe(value:Dictionary,label:String)->Dictionary:
    var image:Image=value.viewport.get_texture().get_image();var errors:Array=[]
    for column in 4:
        var pixel:Color=image.get_pixel(column,0)
        errors.append(((Vector3(pixel.r,pixel.g,pixel.b)-Vector3.ONE*.5)*64.0).length())
    var clock_error:float=absf(image.get_pixel(4,0).r-.5)
    check(errors.all(func(error):return error<.04),label+": GPU origin and all Basis columns retain supplied current transform")
    check(clock_error<.001,label+": actual shared clock retains supplied source age")
    return {"basis_errors":errors.slice(0,3),"origin_error":errors[3],"clock_error":clock_error}
func sample(handle:Dictionary,cue:Dictionary,placement:Dictionary,seconds:float)->void:
    handle.root.global_transform=transform_at(placement,seconds)
    Baked.sample(handle,seconds)
    Baked.follow(handle,cue,seconds,func(at:float)->Transform3D:return transform_at(placement,at))
    handle.root.show()
func bindings(handle:Dictionary,label:String)->void:
    check(not handle.path_materials.is_empty(),label+": actual recording has GPU path consumers")
    for material in handle.path_materials:
        check(material.get_shader_parameter("root_history")==handle.history and material.get_shader_parameter("clock_slot")==handle.slot,
            label+": actual process material binds its own history and clock")
    for draw in handle.trail_draws:
        check(draw.node.process_material==draw.process and draw.process in handle.path_materials,label+": actual ribbon uses that bound process")
func recorded_case(clip:Dictionary,bundle:Resource,placement:Dictionary)->void:
    var label:String=str(clip.id)+"/"+str(placement.id)
    var viewport:SubViewport=view();var holder=Node3D.new();viewport.add_child(holder)
    var handle:Dictionary=Baked.make(holder,bundle,clip,LAYER)
    if not check(handle.error.is_empty(),label+": installed recording constructs"):
        Effects.close(handle);viewport.free();return
    var observed:Dictionary=probe();var cue:Dictionary={"role":"attached","source_rate":1.0,"end":3.0}
    var end:float=float(bundle.frames-1)/float(bundle.rate)
    var jump:float=minf(end-.001,(floor(minf(end*.5,2.0)*60.0)+.37)/60.0)
    var rows:Array=[]
    # Chronological fractional frames, a meaningful jump, then backward and
    # forward again. Each observation is held through a second actual draw.
    for seconds in [0.0,1.0/144.0,2.0/144.0,jump,1.0/144.0,2.0/144.0]:
        sample(handle,cue,placement,seconds);bindings(handle,label)
        bind_probe(observed,handle,seconds,transform_at(placement,seconds))
        await frame();var first:Dictionary=read_probe(observed,label+" at "+str(seconds))
        await frame();var held:Dictionary=read_probe(observed,label+" held at "+str(seconds))
        rows.append({"seconds":seconds,"first":first,"held":held})
    var kept:PackedByteArray=handle.history_image.get_data()
    var twin:Dictionary=Baked.make(holder,bundle,clip,LAYER)
    if check(twin.error.is_empty(),label+": simultaneous recorded owner constructs"):
        var other:Dictionary={"origin":Vector3(-11,2,9),"velocity":Vector3(-2,.1,1)}
        sample(twin,cue,other,jump);bindings(twin,label+" twin")
        check(twin.history!=handle.history and twin.slot!=handle.slot and handle.history_image.get_data()==kept,
            label+": simultaneous owner preserves first history and owns another clock slot")
        bind_probe(observed,twin,jump,transform_at(other,jump))
        await frame();await frame();read_probe(observed,label+" twin")
        bind_probe(observed,handle,2.0/144.0,transform_at(placement,2.0/144.0))
        await frame();read_probe(observed,label+" original after twin")
    evidence.append({"clip":clip.id,"recording":bundle.resource_path,"placement":placement.id,"observations":rows})
    var handles:Array=[handle,twin];var roots:Array=handles.map(func(value):return weakref(value.root) if value.root!=null else null)
    for value in handles:Effects.close(value)
    check(roots.all(func(reference):return reference==null or reference.get_ref()==null),label+": both occurrence roots retire")
    observed.viewport.free();viewport.free();await frame()
func run()->void:
    root.title="NDClient · Recorded trail GPU check";root.unfocusable=true;root.size=Vector2i(480,112)
    var notice=Label.new();notice.position=Vector2(16,16)
    notice.text="Recorded trail GPU check\nChecking the installed playback path.\nThis window closes when the check finishes.";root.add_child(notice)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    if not check(DisplayServer.get_name()!="headless" and RenderingServer.get_current_rendering_method()=="forward_plus","Native Forward+ renderer is required"):
        quit(2);return
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
    create_timer(180).timeout.connect(func():printerr("Recorded path native deadline");quit(2))
    # This isolated test loads only the two first variants. Do not re-enable
    # queued optional variants just as the process is shutting down.
    Baked.background_allowed=false
    var placements:Array=[{"id":"translated-positive","origin":Vector3(36,.8,7),"velocity":Vector3(3,.2,1)},
        {"id":"translated-negative","origin":Vector3(-6,1.1,-4),"velocity":Vector3(-1,-.1,-4)}]
    for id in CLIPS:
        var clip:Dictionary=Effects.clip(id)
        if not check(not clip.is_empty(),id+": installed clip resolves"):continue
        var bundle:Variant;var deadline:int=Time.get_ticks_msec()+60000
        while Time.get_ticks_msec()<deadline:
            bundle=Baked.ready_for(clip,0,true)
            if bundle!=null:break
            await frame()
        if not check(bundle is Resource and bundle.moving,id+": original moving recording and VAT textures load"):continue
        for placement in placements:await recorded_case(clip,bundle,placement)
    check(evidence.size()==4,"Both installed moving families exercise both translated paths")
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual client recorded player, installed raw bundles and GPU path include; supplied current origin/Basis/clock at fractional times, held draws, jump/backward seek and independent owner. Float-image precision; no full-cast choreography, historical anchor alignment, performance or art approval."}
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_RECORDED_PATH ",JSON.stringify({"checks":checks,"failures":failures,"cases":evidence.size(),"output":output}))
    quit(0 if failures.is_empty() else 1)
