extends Node
## Native Windows boundary check: local controls -> actual rendered spell frames.
var failures: Array = []
var checks := 0
var captures: Array = []

func check(value: bool, message: String) -> void:
    checks += 1
    if not value: failures.append(message); push_error(message)

func frame() -> void:
    await get_tree().process_frame
    await RenderingServer.frame_post_draw

func at(world: Node, seconds: float) -> void:
    var deadline = Time.get_ticks_msec()+10000
    while world.elapsed<seconds and Time.get_ticks_msec()<deadline: await frame()
    check(world.elapsed>=seconds,"Playback reaches requested time")
    world.playing = false
    await frame()
    await frame()

func run(world: Node) -> void:
    DirAccess.make_dir_recursive_absolute("res://.captures/spell-sandbox")
    check(world.fixture_ready,"Fixture starts without renderer errors")
    if not world.fixture_ready: finish(world); return
    world.loop = false
    check(world.session==null,"Sandbox starts without a backend session")
    check(RenderingServer.get_current_rendering_method()=="forward_plus","Native Forward+ renderer")
    await frame();await frame()
    for helper in world.generated_shadows.actors.values():
        var shadow=helper.viewport.get_texture().get_image()
        var lit_edge=false
        for y in shadow.get_height():
            if shadow.get_pixel(shadow.get_width()-1,y).r>.9:lit_edge=true;break
        check(lit_edge,"Helper final column is not an unlit cluster strip")
    var texture_count = world.textures.size()
    # The helper must align coverage to Forward+'s quarter-resolution raster.
    for dimensions in [Vector2(1,10),Vector2(257,245),Vector2(258,246)]:
        var aligned=world.GeneratedShadows._sampling_rect(Rect2(Vector2.ZERO,dimensions),1.0)
        check(int(aligned.size.x)%4==0 and int(aligned.size.y)%4==0,"Clipped helpers preserve complete native light coverage")
    for quarter in 4:
        world.rotate_view(quarter-world.quarter)
        for phase in ["Cast","Travel","Impact"]:
            for index in world.source_clips.size():
                if world.source_clips[index].phase==phase.to_lower(): world.select_phase(index+1);break
            await at(world,0.2)
            var handle: Dictionary = world.handles["isolated"]
            check(handle.root.get_world_3d()==world.get_world_3d(),"Effect uses main World3D")
            var native = world.get_viewport().get_texture().get_image()
            var name = "q%d-%s"%[quarter,phase.to_lower()]
            native.save_png("res://.captures/spell-sandbox/"+name+".png")
            world.get_node("Effects").hide()
            await frame()
            var baseline = world.get_viewport().get_texture().get_image()
            var changed := 0
            for y in range(150,native.get_height()):
                for x in native.get_width():
                    var a = native.get_pixel(x,y); var b = baseline.get_pixel(x,y)
                    if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>0.02: changed += 1
            check(changed>20,name+" has visible native effect pixels")
            captures.append({"sample":name,"changed_pixels":changed})
            world.get_node("Effects").show()
    world.phase_mode = "Sequence"
    world.restart()
    await at(world,world.release+0.1)
    var paused: float = world.elapsed
    for i in 8: await frame()
    check(is_equal_approx(world.elapsed,paused),"Pause holds shared visual clock")
    world.restart()
    check(world.elapsed==0,"Recast starts immediately at zero")
    world.playing = false
    world.place_marker("Target",Vector3(-2,1.5,0))
    await frame()
    check(is_equal_approx(world.visual_actors.target.row.base_height_steps*world.Placement.HEIGHT_UNIT,1.5),"Target height independent of caster in same cell")
    check(is_zero_approx(world.visual_actors.caster.row.base_height_steps),"Caster remains at its own height")
    world.place_marker("Target",Vector3(2,0,0))
    world.loop = true
    world.rate = 2
    world.restart()
    var count: int = world.loop_count
    var deadline = Time.get_ticks_msec()+12000
    while world.loop_count<count+2 and Time.get_ticks_msec()<deadline: await frame()
    check(world.loop_count>=count+2,"Sequence loops twice within its finite duration")
    check(world.elapsed<world.duration,"Loop clock stays inside clip")
    check(world.textures.size()==texture_count,"Controls and replay do not load additional sprite textures")
    check(world.presentation_errors.is_empty(),"No rendering errors during controls/playback")
    finish(world)

func finish(world: Node) -> void:
    var report = {"checks":checks,"failures":failures,"startup_ms":world.startup_ms,
        "textures":world.textures.size(),"captures":captures,"scope":"Offline presentation fixture only; no gameplay/event, pixelation, VFX light or sprite-depth certification"}
    FileAccess.open("res://.runtime/spell-sandbox-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SPELL_SANDBOX_CHECKS ",JSON.stringify(report))
    get_tree().quit(0 if failures.is_empty() else 1)
