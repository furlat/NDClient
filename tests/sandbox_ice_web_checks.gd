extends "res://tests/sandbox_choreography_checks.gd"
## Original native trail clock and source alpha, through the real sandbox.
var capture_dir="res://.captures/ice-web-feedback"

func step_to(world:Node,time:float,step:float)->void:
    while world.elapsed<time:
        await get_tree().process_frame
        world.elapsed=minf(time,world.elapsed+step)
        world._sample_frame(step)
        await RenderingServer.frame_post_draw
    await frame()

func save(world:Node,name:String)->Image:
    world.get_viewport().get_texture().get_image().save_png(capture_dir+"/"+name+".png")
    return world.effect_layer.viewport.get_texture().get_image()

func visible_pixels(image:Image)->int:
    var total=0
    for y in range(0,image.get_height(),2):
        for x in range(0,image.get_width(),2):
            var c=image.get_pixel(x,y)
            if maxf(c.r,maxf(c.g,c.b))>.025:total+=1
    return total

func run(world:Node)->void:
    DirAccess.make_dir_recursive_absolute(capture_dir)
    for view in 4:
        world.rotate_view(view-world.quarter)
        for speed in [4.0,16.0]:
            select(world,"ice_knife")
            world.flight_speed=speed;world.restart();pause(world)
            var cue:Dictionary=world.cue_plan.cues.filter(func(c):return c.role=="flight")[0]
            var handle:Dictionary=world.handles[cue.id]
            var trail:GPUParticles3D=handle.root.get_node("effect/Donor/GPUTrail3D")
            var step=1.0/30.0 if speed==4.0 else 1.0/60.0
            await step_to(world,world.release-.01,step)
            check(not trail.visible,"Ice view%d speed%.0f: held hand does not draw flight history"%[view,speed])
            check(core(handle,cue).global_position.distance_to(world._preparation_point())<.001,"Ice: held native core remains at actual hand")
            await step_to(world,world.release,step)
            check(trail.visible,"Ice: native ribbon activates at release")
            check(is_zero_approx(handle.motion_age),"Ice: release starts a fresh motion clock")
            check(trail.amount==9 and trail.fixed_fps==75 and is_equal_approx(float(trail.get("length_seconds")),.12),"Ice: selected short history uses the native trail's original 75-Hz mechanism")
            var offset:Vector2=trail.get("_uv_offset")
            var until=minf(world.arrival-.005,world.release+.2)
            await step_to(world,until,step)
            var expected:Vector2=(offset+Vector2(trail.get("scroll"))*(until-world.release)).posmod(1.0)
            check(Vector2(trail.get("_uv_offset")).is_equal_approx(expected),"Ice: native texture clock follows elapsed motion at both flight speeds")
            check(absf(handle.motion_age-(until-world.release))<.00001,"Ice: motion age is independent of source-light retiming")
            check(core(handle,cue).global_position.distance_to(world.source_start.lerp(world.source_end,(until-world.release)/(world.arrival-world.release)))<.001,"Ice: native core stays on its flight path")
            var image=save(world,"ice-v%d-speed%.0f-flight"%[view,speed])
            trail.hide();await frame()
            var hidden=world.effect_layer.viewport.get_texture().get_image()
            check(cut_pixels(image,hidden)>2,"Ice: actual native ribbon contributes visible flight pixels")
            save(world,"ice-v%d-speed%.0f-without-trail"%[view,speed])
            trail.show();await frame()
            var paused=world.effect_layer.viewport.get_texture().get_image()
            world._sample_frame(0.0);await frame();await frame()
            check(paused.get_data()==world.effect_layer.viewport.get_texture().get_image().get_data(),"Ice: paused native source pixels remain fixed")
            await step_to(world,world.duration,step)
            check(world.handles.values().all(func(h):return not h.root.visible),"Ice: all source tails retire")
            observations.append({"spell":"ice_knife","view":view,"flight_speed":speed,"source_age":handle.age,"motion_age":handle.motion_age})
            # Repeat the same actual path with the donor's original duration.
            # This control isolates excessive history from palette/core geometry.
            world.restart();pause(world)
            var old_trail:GPUParticles3D=world.handles[cue.id].root.get_node("effect/Donor/GPUTrail3D")
            old_trail.set("length_seconds",.56)
            await step_to(world,until,step)
            var old=save(world,"ice-v%d-speed%.0f-original-history"%[view,speed])
            check(cut_pixels(image,old)>5,"Ice: shortening native history changes the actual long-ribbon pixels")
        select(world,"web")
        var flight:Dictionary=world.cue_plan.cues.filter(func(c):return c.role=="flight")[0]
        var ground:Dictionary=world.cue_plan.cues.filter(func(c):return c.role=="area")[0]
        var ring:GPUParticles3D=world.handles[flight.id].root.get_node("effect/Donor/rings3")
        var material:StandardMaterial3D=ring.material_override
        await step_to(world,world.arrival+.35,1.0/60.0)
        check(material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and material.blend_mode==BaseMaterial3D.BLEND_MODE_ADD,"Web: native ring uses its authored additive texture/particle alpha")
        var corrected=save(world,"web-v%d-corrected"%view)
        material.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
        await frame();await frame()
        var old=save(world,"web-v%d-old-opaque-ring"%view)
        check(cut_pixels(old,corrected)>16,"Web: corrected ring changes the actual opaque-donut pixels")
        material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
        await frame()
        world.handles[flight.id].root.hide()
        await step_to(world,ground.begin+1.8,1.0/60.0)
        world.handles[flight.id].root.hide();await frame()
        for cue in world.cue_plan.cues:
            if cue.id!=ground.id:world.handles[cue.id].root.hide()
        await frame()
        var net=save(world,"web-v%d-ground-only"%view)
        check(visible_pixels(net)>50,"Web: separate ground source retains visible interior network")
        observations.append({"spell":"web","view":view,"ring_changed_pixels":cut_pixels(old,corrected),"ground_pixel_samples":visible_pixels(net)})
    check(world.presentation_errors.is_empty(),"No missing selected source or character media")
    var report={"checks":checks,"failures":failures,"observations":observations}
    FileAccess.open("res://.runtime/sandbox-ice-web-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SANDBOX_ICE_WEB ",JSON.stringify(report))
    get_tree().quit(0 if failures.is_empty() else 1)
