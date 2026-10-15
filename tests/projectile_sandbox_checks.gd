extends Node
## Actual native renderer, all admitted spells/phases; no backend or mock effects.
var checks:=0
var failures:Array=[]
var rows:Array=[]
func check(value:bool,message:String)->void:
    checks+=1
    if not value:failures.append(message);push_error(message)
func frame()->void:
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
func run(world:Node)->void:
    DirAccess.make_dir_recursive_absolute("res://.captures/projectile-sandbox")
    world.loop=false
    check(world.session==null,"No backend session")
    check(world.spells.size()==15,"All15 existing projectile authoring entries")
    for index in world.spells.size():
        var requested_spell=""
        for argument in OS.get_cmdline_user_args():
            if argument.begins_with("--spell="):requested_spell=argument.trim_prefix("--spell=")
        if not requested_spell.is_empty() and world.spells[index].spell_id!=requested_spell:continue
        world.select_spell(index)
        world.loop=false
        for clip_index in world.source_clips.size():
            world.select_phase(clip_index+1)
            world.playing=false;world.set_process(false)
            var handle:Dictionary=world.handles.isolated
            var clip:Dictionary=world.active_clips.isolated
            var id:String=world.spell.spell_id+"/"+clip.id
            print("PROJECTILE_CHECK ",id)
            check(handle.error.is_empty(),id+" constructs")
            check(handle.root.get_world_3d()==world.get_world_3d(),id+" shares renderer World3D")
            # Observe startup, active body and later particles; a single .6s
            # sample misses short hits and particles which appear later.
            var age=0.0
            var changed=0
            var best:Image
            for requested in [.04,.16,.38,minf(1.4,world.duration*.65)]:
                var until=minf(float(requested),world.duration*.8)
                if until<=age:continue
                while age<until:
                    age+=1./60.
                    world.elapsed=age
                    world._sample_frame(1./60.)
                    # A UI/view refresh can ask for this same source age again.
                    # It must preserve particles already queued for the draw.
                    world._process(0.0)
                    await frame()
                var image=world.get_viewport().get_texture().get_image()
                handle.root.hide();world.set_process(false)
                await frame()
                var baseline=world.get_viewport().get_texture().get_image()
                var visible=0
                for y in range(160,image.get_height(),2):
                    for x in range(0,image.get_width(),2):
                        var a=image.get_pixel(x,y);var b=baseline.get_pixel(x,y)
                        if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.03:visible+=1
                if best==null or visible>changed:best=image;changed=visible
                handle.root.show()
            check(changed>5,id+" has visible source pixels")
            var file=world.spell.spell_id+"-"+str(clip_index)+".png"
            best.save_png("res://.captures/projectile-sandbox/"+file)
            world.set_process(true)
            var frozen:float=handle.age
            for i in 3:await frame()
            check(is_equal_approx(handle.age,frozen),id+" paused source clock")
            check(handle.emitters.all(func(p):return p.speed_scale==0),id+" paused GPU simulation")
            if clip.get("stage","")=="delivery":
                var packet=handle.components.effect
                check(packet.packet_contact and packet.packet_hit.visible,id+" reaches native contact after flight")
            rows.append({"spell":world.spell.spell_id,"clip":clip.id,"seconds":clip.seconds,"geometry":handle.geometry.size(),"changed_samples":changed,"capture":file})
        # One bounded sequence per spell, including every declared default stage.
        world.phase_mode="Sequence";world.rate=4;world.loop=true;world.restart()
        var loops:int=world.loop_count
        var deadline=Time.get_ticks_msec()+8000
        while world.loop_count==loops and Time.get_ticks_msec()<deadline:await frame()
        check(world.loop_count>loops,world.spell.spell_id+" completes and loops")
        world.loop=false;world.playing=false
    check(world.presentation_errors.is_empty(),"No presentation errors")
    var report={"checks":checks,"failures":failures,"sources":rows,"startup_ms":world.startup_ms,"textures":world.textures.size(),"scope":"Native offline preview coverage; not production event binding or sprite occlusion qualification"}
    FileAccess.open("res://.runtime/projectile-sandbox-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PROJECTILE_SANDBOX_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
    get_tree().quit(0 if failures.is_empty() else 1)
