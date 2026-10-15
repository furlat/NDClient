extends "res://tests/sandbox_choreography_checks.gd"
## Real native playback of the next twenty capabilities, not fabricated events.
const EXPECTED=["aid","bless","bane","command","cure_wounds","healing_word","guidance","resistance","light","thaumaturgy","true_strike","mage_armor","sanctuary","shield","shield_of_faith","false_life","sacred_flame","shocking_grasp","burning_hands","thunderwave"]
var capture_dir="res://.captures/native-batch"
var sampled_energy=0.0
var top_pixels=0

func pixels(world:Node)->int:
    var image:Image=world.effect_layer.viewport.get_texture().get_image()
    image.resize(360,225)
    var count=0
    sampled_energy=0.0
    top_pixels=0
    for y in image.get_height():
        for x in image.get_width():
            var c=image.get_pixel(x,y)
            var linear=c.srgb_to_linear()
            sampled_energy+=maxf(linear.r,maxf(linear.g,linear.b))
            if maxf(c.r,maxf(c.g,c.b))>.025:
                count+=1
                if y<25:top_pixels+=1
    return count

func step_to(world:Node,time:float)->void:
    while world.elapsed<time:
        await get_tree().process_frame
        world.elapsed=minf(time,world.elapsed+1./30.)
        world._sample_frame(1./30.)
        await RenderingServer.frame_post_draw
    await frame()

func sample_capture(world:Node,id:String,view:int,label:String)->int:
    world.get_viewport().get_texture().get_image().save_png(capture_dir+"/%s-v%d-%s.png"%[id,view,label])
    return pixels(world)

func run(world:Node)->void:
    DirAccess.make_dir_recursive_absolute(capture_dir)
    var selected:Array=EXPECTED.duplicate()
    var views=[0,1,2,3]
    var isolated=true
    var phase_only=false
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--batch-spells="):selected=Array(argument.trim_prefix("--batch-spells=").split(","))
        if argument=="--batch-one-view":views=[0];isolated=false
        if argument=="--batch-phases-only":phase_only=true
    var registered=world.library.spells.filter(func(s):return s.has("batch")).map(func(s):return s.id)
    check(registered.size()==20,"Twenty additional spell capabilities are registered")
    for id in EXPECTED:check(id in registered,id+": available in the spell selector")
    check(world.spell.spell_id=="fire_bolt","Library expansion preserves the initial Fire Bolt selection")
    for id in selected:
        for view in ([] if phase_only else views):
            world.rotate_view(view-world.quarter)
            select(world,id)
            var owner:String=world.staging_spec.get("recipient","target")
            check(world.cue_plan.contacts.all(func(c):return c.target==owner),id+": recipient ownership")
            check(is_equal_approx(world.arrival,world.release+float(world.staging_spec.get("contact_after_release",0))),id+": authored contact does not depend on imaginary flight")
            await step_to(world,.05)
            if id==selected[0]:world.effect_layer.viewport.get_texture().get_image().save_png(capture_dir+"/raw-idle.png")
            check(pixels(world)==0,id+": native effect absent before cast")
            sample_capture(world,id,view,"idle")
            var peak=0
            var samples=[]
            var phases=[["apply",world.release+.25],["active",world.release+.8],["hold",minf(world.duration-.25,world.release+1.65)],["ending",world.duration-world.spell.tail_seconds-.04],["contact",world.arrival+.015]]
            phases.sort_custom(func(a,b):return a[1]<b[1])
            for phase in phases:
                await step_to(world,phase[1])
                var visible=sample_capture(world,id,view,phase[0])
                if id=="sacred_flame" and phase[0]=="active":
                    check(top_pixels==0,"Sacred Flame: full beam fits below preview controls")
                var optical=0.0
                for source in world.source_lighting.effect_sources:
                    if source.visible:optical+=source.energy
                peak=maxi(peak,visible);samples.append({"phase":phase[0],"time":world.elapsed,"pixels":visible,"energy":sampled_energy,"light_energy":optical})
                if phase[0]=="contact":contact_feedback(world,world.cue_plan.contacts[0],id)
                if world.recipe.get("damage")==null:
                    check(world.playbacks.target.clip!="TakeDamage" and world.playbacks.target2.clip!="TakeDamage",id+": support/control does not cause a damage reaction")
            check(peak>5,id+" view%d: selected native composition is visible"%view)
            if id in ["light","command","sanctuary"]:
                var ending=samples.filter(func(s):return s.phase=="ending")[0]
                check(ending.energy<maxf(1.0,samples.map(func(s):return s.energy).max()*.1),id+": visible close finishes before retirement")
                check(ending.light_energy<maxf(.01,samples.map(func(s):return s.light_energy).max()*.1),id+": light closes with geometry")
            var ages=world.handles.values().map(func(h):return h.age)
            world._process(.25);await frame()
            check(ages==world.handles.values().map(func(h):return h.age),id+": pause freezes source clocks")
            await step_to(world,world.duration)
            check(pixels(world)==0,id+" view%d: no stale effect after the clip"%view)
            check(world.handles.values().all(func(h):return not h.root.visible),id+": all native instances retire")
            observations.append({"spell":id,"view":view,"owner":owner,"duration":world.duration,"samples":samples,"peak":peak})
            var loops:int=world.loop_count
            world.loop=true;world.playing=true;world._process(.01);pause(world)
            check(world.loop_count==loops+1 and is_zero_approx(world.elapsed),id+": actual loop restarts at zero")
            await step_to(world,.05)
            check(pixels(world)==0,id+": recast starts clean")
            check(world.presentation_errors.is_empty(),id+": no missing presentation media")
            print("SANDBOX_BATCH_PROGRESS ",id," view",view," peak=",peak)
        if isolated:
            select(world,id)
            for i in world.source_clips.size():
                world.select_phase(i+1);pause(world)
                var isolated_peak=0
                for t in [.08,.3,.8,1.6]:
                    await step_to(world,minf(world.duration-world.spell.tail_seconds-.01,t))
                    isolated_peak=maxi(isolated_peak,pixels(world))
                check(not world.handles.is_empty(),id+": source phase can be inspected independently")
                check(isolated_peak>0,id+": isolated phase%d visibly renders"%i)
                var handle:Dictionary=world.handles.isolated
                var placement:Dictionary=world.active_clips.isolated.placement
                var recipient:String=world.staging_spec.get("recipient","target")
                var expected:Vector3
                match placement.attachment:
                    "caster_hand":expected=world._preparation_point()
                    "caster_ground":expected=world.get_node("Caster").global_position
                    "recipient_body":expected=world._target_point(recipient)
                    "recipient_ground":expected=world.get_node(world.actor_markers[recipient]).global_position
                check(core(handle,placement).global_position.distance_to(expected)<.001,id+": isolated source uses its authored attachment")
                sample_capture(world,id,world.quarter,"isolated%d"%i)
                await step_to(world,world.duration)
                check(pixels(world)==0,id+": isolated phase retires")
            world.select_phase(0);pause(world)
    var report={"checks":checks,"failures":failures,"observations":observations}
    FileAccess.open("res://.runtime/sandbox-batch-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SANDBOX_BATCH ",JSON.stringify({"checks":checks,"failures":failures,"spells":selected.size(),"views":views.size()}))
    get_tree().quit(0 if failures.is_empty() else 1)
