extends SceneTree
## Matched production captures: existing native radial profile and ambient calibration.
const Studio=preload("res://studio/studio.gd")
const RangeProfile=preload("res://presentation/resources/light_range_profile.gd")
const Calibrated=preload("res://authoring/presentation/light_ranges.tres")
const DIRECTORY="res://.captures/studio/light-calibration"
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("LIGHT_CALIBRATION_FAIL ",label)
## Ambient as the lit sprites read it (play.gd _publish_receiving): under the
## HDR cap the receiving canvas saw CanvasModulate after Godot's sRGB conversion.
func ambient_global(world:Node,value:float)->float:
    var hdr:bool=world.light_cap_enabled and not world.normals_visible
    return Color(value,value,value).linear_to_srgb().srgb_to_linear().r if hdr else value
## Read the light_ambient global back through a 1px HDR probe (the green
## channel is a constant control for the probe's own colour transfer).
var probe:SubViewport
func published_ambient()->float:
    if probe==null:
        probe=SubViewport.new();probe.size=Vector2i(1,1);probe.disable_3d=true;probe.use_hdr_2d=true
        probe.transparent_bg=true;probe.render_target_update_mode=SubViewport.UPDATE_ALWAYS
        var rect=ColorRect.new();rect.size=Vector2(1,1)
        var shader=Shader.new();shader.code="shader_type canvas_item;render_mode unshaded,blend_disabled;global uniform float light_ambient;void fragment(){COLOR=vec4(light_ambient,0.30,0.0,1.0);}"
        var material=ShaderMaterial.new();material.shader=shader;rect.material=material
        probe.add_child(rect);root.add_child(probe)
    await process_frame;await RenderingServer.frame_post_draw
    var colour:Color=probe.get_texture().get_image().get_pixel(0,0)
    check(absf(colour.g-.30)<.001,"Ambient probe reads shader values without transfer")
    return colour.r
func near(a:float,b:float)->bool:
    return absf(a-b)<.001
func settle(studio:Control)->bool:
    var deadline=Time.get_ticks_msec()+120000
    while (studio.index.is_empty() or studio.loader!=null or studio.seeker!=null or studio.installing or studio.requested_seek>=0 or studio.world.rotation_pending()) and Time.get_ticks_msec()<deadline:await process_frame
    var ready=not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and not studio.world.rotation_pending()
    check(ready,"Recorded world/seek is ready")
    return ready
func capture_pair(studio:Control,label:String,point:Vector2i)->void:
    var state=studio.world.timeline.state.duplicate(true)
    var time=studio.world.timeline.display_ms
    var source_before=Studio.Play.Lighting.resolve(state)
    var original_profile=studio.world.source_lighting.range_profile
    for strength in [.43,1.0]:
        studio.world.set_light_strength(strength,false)
        for profile_name in ["before","after"]:
            var profile=RangeProfile.new()
            profile.very_bright_edge=.65 if profile_name=="before" else Calibrated.very_bright_edge
            profile.bright_edge=.25 if profile_name=="before" else Calibrated.bright_edge
            studio.world.source_lighting.range_profile=profile
            studio.world.source_lighting.sync(state)
            var ambient_value=.18 if profile_name=="before" else Studio.Play.LIGHT_AMBIENT
            # Same global play.gd publishes; it is republished only when cap/Normals change.
            RenderingServer.global_shader_parameter_set(&"light_ambient",ambient_global(studio.world,ambient_value))
            # Light table uploads and their texture consumers span draw frames.
            for _i in 4:await process_frame;await RenderingServer.frame_post_draw
            var picture=studio.viewport.get_texture().get_image()
            var name=label+"-"+profile_name+"-strength"+str(strength)
            var path=DIRECTORY.path_join(name+".png");picture.save_png(path)
            var pixel=Vector2i(studio.world.camera.unproject_position(Vector3(point.x+.30,0,point.y+.30)).round())
            var area=Rect2i(pixel-Vector2i(3,3),Vector2i(7,7)).intersection(Rect2i(Vector2i.ZERO,picture.get_size()))
            var rgb=Vector3.ZERO;var count=0
            for y in range(area.position.y,area.end.y):
                for x in range(area.position.x,area.end.x):
                    var c=picture.get_pixel(x,y);rgb+=Vector3(c.r8,c.g8,c.b8);count+=1
            if count>0:rgb/=count
            check(studio.world.timeline.state==state and is_equal_approx(studio.world.timeline.display_ms,time),label+": profile changes preserve authoritative state and display time")
            check(Studio.Play.Lighting.resolve(state)==source_before,label+": disclosed source positions/radii unchanged")
            check(studio.world.presentation_errors.is_empty() and studio.world.media_issue.is_empty(),label+": no renderer/source errors")
            evidence.append({"scene":label,"profile":profile_name,"ambient":ambient_value,"strength":strength,"fire_flicker":studio.world.fire_light_flicker,
                "time_ms":time,"camera_size":studio.world.camera.size,"quarter":studio.world.quarter,"cap":studio.world.light_cap_enabled,
                "tile":str(point),"level":state.tiles.get("%d,%d"%[point.x,point.y],{}).get("resolved_light"),
                "sample_rgb":[rgb.x,rgb.y,rgb.z],"path":path})
    studio.world.source_lighting.range_profile=original_profile
    studio.world.source_lighting.sync(state)
    studio.world.receiving_globals=[];studio.world._publish_receiving()
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1600,900)
    DirAccess.make_dir_recursive_absolute(DIRECTORY)
    var studio=Studio.new();root.add_child(studio)
    if not await settle(studio):await finish(studio);return
    check(studio.active_directory=="res://.runtime/studio-cases/jump-seed3-v2/amber/journal","Capture starts from the exact real Jump recording")
    if not failures.is_empty():await finish(studio);return
    studio.loop_enabled=false;studio.world.timeline.paused=true
    # In-memory cap/Normals only; the saved settings are never written.
    var world=studio.world
    var expected:float=Studio.Play.LIGHT_AMBIENT
    world._publish_receiving()
    check(near(await published_ambient(),ambient_global(world,expected)),"Creation uses the calibrated native ambient")
    var cap:bool=world.light_cap_enabled
    world.light_cap_enabled=false;world._publish_receiving()
    check(near(await published_ambient(),expected),"Uncapped native ambient preserves calibration")
    world.light_cap_enabled=true;world._publish_receiving()
    check(near(await published_ambient(),ambient_global(world,expected)),"Capped native ambient preserves calibration under HDR conversion")
    world.light_cap_enabled=cap;world._publish_receiving()
    world.set_normals_visible(true);world._publish_receiving()
    check(near(await published_ambient(),expected),"Normals toggle preserves native ambient calibration")
    world.set_normals_visible(false);world._publish_receiving()
    check(near(await published_ambient(),ambient_global(world,expected)),"Returning to colour preserves native ambient calibration")
    studio.world.camera.size=6;studio.world.position_camera()
    studio._seek(1087.0)
    if await settle(studio):await capture_pair(studio,"jump",Vector2i(4,6))
    studio._load("res://.runtime/studio-cases/hide-light-schema9-seed3/amber/journal")
    if not await settle(studio):await finish(studio);return
    var descriptor:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(studio.active_directory.get_base_dir().path_join("case.json")))
    for probe in descriptor.light_probes:
        if probe.label not in ["dim","bright","very_bright"]:continue
        var boundary=0.0
        for item in studio.index.groups:
            if item.group.operation_sequence==probe.sequence:boundary=maxf(boundary,item.start_ms+item.group.duration_ms)
        studio._seek(boundary+.01)
        if not await settle(studio):break
        check(studio.world.timeline.state.tiles["4,6"].resolved_light==probe.world_resolved_light,"Real "+probe.label+" source boundary is unchanged")
        await capture_pair(studio,probe.label,Vector2i(4,6))
    await finish(studio)
func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Same paused real Jump and Hide/light scene, camera, native renderer, normal height, cap and saved flicker; compares old radial profile/ambient with calibrated production values at saved .43 and default1 strength. Source/state checks are authoritative; sampled framebuffer RGB only documents appearance. Native ambient is visual readability, not a light category."}
    FileAccess.open("res://generated/studio_light_calibration_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("LIGHT_CALIBRATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
