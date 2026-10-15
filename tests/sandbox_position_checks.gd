extends SceneTree
## Inspect actual native nodes after the real Sequence/isolated placement paths.
## These are geometric assertions, not claims about artistic scale or particles.
var checks:=0
var failures:Array=[]
var observations:Array=[]
const SPELLS=["magic_missile","fireball","ray_of_frost","eldritch_blast","guiding_bolt","ice_knife","produce_flame"]

func _initialize()->void:
    root.unfocusable=true
    root.position=Vector2i(-16000,-16000)
    create_timer(180.0).timeout.connect(func():push_error("Position checks exceeded finite budget");quit(1))
    run.call_deferred()

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);push_error(label)

func pause(world:Node)->void:
    world.playing=false;world.loop=false;world.set_process(false)

func sample(world:Node,time:float)->void:
    while world.elapsed<time:
        await process_frame
        var step:float=minf(1.0/60.0,time-world.elapsed)
        world.elapsed+=step
        world._sample_frame(step)
        await RenderingServer.frame_post_draw
    await process_frame
    world._sample_frame(0.0)
    await RenderingServer.frame_post_draw

func near(actual:Vector3,expected:Vector3,label:String)->void:
    var error=actual.distance_to(expected)
    check(error<.002,label)
    observations.append({"label":label,"error_world_units":error})

func core(handle:Dictionary,cue:Dictionary)->Node3D:
    return handle.root.get_node(cue.origin_path)

func run()->void:
    DirAccess.make_dir_recursive_absolute("res://.captures/positions")
    var world:Node=load("res://spell-sandbox.tscn").instantiate()
    root.add_child(world);pause(world)
    Engine.max_fps=60
    check(world.fixture_ready,"Real offline fixture prepares")
    for id in SPELLS:
        var index:int=world.spells.find_custom(func(spell):return spell.spell_id==id)
        for view in 4:
            world.rotate_view(view-world.quarter)
            world.select_spell(index);pause(world)
            var registered:Array=world.cue_plan.cues.filter(func(cue):return cue.has("origin_path"))
            check(not registered.is_empty(),id+" has an explicit native core")
            # Sort the probes so the source AnimationPlayers never need an
            # unsupported backward seek within the same instance.
            var probes:Array=[]
            var captured:Dictionary={}
            for cue in registered:
                if cue.role in ["cast","flight"]:
                    probes.append({"time":cue.launch-.0001,"cue":cue,"point":"hand"})
                    probes.append({"time":cue.launch,"cue":cue,"point":"release"})
                    if cue.role=="flight":probes.append({"time":(cue.launch+cue.contact)*.5,"cue":cue,"point":"flight"})
                elif cue.role=="impact":probes.append({"time":cue.begin+.03,"cue":cue,"point":"target"})
            probes.sort_custom(func(a,b):return a.time<b.time)
            for probe in probes:
                await sample(world,probe.time)
                var cue:Dictionary=probe.cue
                var expected:Vector3=world._preparation_point() if probe.point=="hand" else cue.to if probe.point=="target" else cue.from
                if probe.point=="flight":
                    var side:Vector3=(cue.to-cue.from).normalized().cross(Vector3.UP).normalized()
                    expected=cue.from.lerp(cue.to,.5)+side*cue.bend.x+Vector3.UP*cue.bend.y
                near(core(world.handles[cue.id],cue).global_position,expected,"%s/v%d/%s Sequence %s core"%[id,view,cue.id,probe.point])
                if id in ["magic_missile","fireball","ray_of_frost"] and cue.role=="flight" and cue.index==0 and not captured.has(probe.point):
                    captured[probe.point]=true
                    world.get_viewport().get_texture().get_image().save_png("res://.captures/positions/%s-v%d-%s.png"%[id,view,probe.point])
            if id=="fireball":
                world.restart();pause(world)
                var cast:Dictionary=world.cue_plan.cues.filter(func(cue):return cue.role=="cast")[0]
                await sample(world,world.release-.0001)
                var mesh:MeshInstance3D=world.handles[cast.id].root.get_node("formation/Source/Donor/FireTorch_AC8")
                var tail:Vector3=mesh.global_basis*mesh.mesh.get_aabb().get_center()
                var aim:Vector3=(world.source_end-world.source_start).normalized()
                check(tail.normalized().dot(aim)<-.99,"Fireball/v%d: native charging flame trails opposite launch, not sideways"%view)
            # The selected phase must retain the same native core contract.
            # Testing the original independent sources catches an isolated-only
            # path that leaves export offsets in place despite Sequence passing.
            var seen:Dictionary={}
            for cue in registered:
                if seen.has(cue.clip.id):continue
                seen[cue.clip.id]=true
                var phase_index:int=world.source_clips.find_custom(func(clip):return clip.id==cue.clip.id)+1
                world.select_phase(phase_index);pause(world)
                await sample(world,0.0)
                var expected:Vector3=world._preparation_point() if cue.role=="cast" else world.source_end if cue.role in ["impact","strike"] else world.source_start
                near(core(world.handles.isolated,cue).global_position,expected,"%s/v%d/%s isolated core"%[id,view,cue.clip.id])
            world.select_phase(0);pause(world)
    check(world.presentation_errors.is_empty(),"Placement probes add no presentation errors")
    var report={"checks":checks,"failures":failures,"observations":observations,
        "scope":"Actual scene native core positions in Sequence and isolated phases, all four camera views; Fireball native tail direction. Source transforms sampled through real runtime. No gameplay events or visual-quality claims."}
    FileAccess.open("res://.runtime/sandbox-position-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SANDBOX_POSITIONS ",JSON.stringify({"checks":checks,"failures":failures}))
    world.queue_free();await process_frame
    quit(0 if failures.is_empty() else 1)
