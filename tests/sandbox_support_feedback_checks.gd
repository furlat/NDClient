extends "res://tests/sandbox_choreography_checks.gd"
## Actual native casts/holds and local interception demonstration; no SDK outcomes.
var folder="res://.captures/support-feedback"

func save(world:Node,label:String)->Image:
    world.get_viewport().get_texture().get_image().save_png(folder+"/"+label+".png")
    var result:Image=world.effect_layer.viewport.get_texture().get_image()
    result.save_png(folder+"/"+label+"-source.png")
    return result

func pixels(image:Image)->int:
    var total=0
    for y in range(0,image.get_height(),2):
        for x in range(0,image.get_width(),2):
            var c=image.get_pixel(x,y)
            if c.a*maxf(c.r,maxf(c.g,c.b))>.025:total+=1
    return total

func visible_source(world:Node,cue:Dictionary,label:String)->void:
    var handle:Dictionary=world.handles[cue.id]
    check(handle.root.visible,label+": actual source occurrence is active")
    var before=world.effect_layer.viewport.get_texture().get_image()
    handle.root.hide();await frame()
    var without=world.effect_layer.viewport.get_texture().get_image()
    var changed=cut_pixels(before,without)
    handle.root.show();await frame()
    check(changed>2,label+": native occurrence contributes visible pixels (%d)"%changed)
    observations.append({"sample":label,"visible_pixel_samples":changed,"age":handle.age})

func held_opacity(world:Node,cue:Dictionary,label:String)->void:
    var before=save(world,label+"-hold")
    check(not world.handles[cue.id].opacity_bindings.is_empty(),label+": authored opacity uses an existing native shader control")
    var full=cue.duplicate(true);full.erase("opacity_keys");full.erase("fade_out_seconds")
    # The comparison is the same native age, camera, lights and simulation.
    # Only the explicitly authored opacity is removed.
    for piece in world.handles[cue.id].geometry:piece.node.transparency=0.0
    world._sample_controls(world.handles[cue.id],full,world.elapsed)
    await frame();await frame()
    var opaque=world.effect_layer.viewport.get_texture().get_image()
    var changed=cut_pixels(before,opaque)
    check(changed>2,label+": hold opacity changes actual native pixels (%d)"%changed)
    world._sample_controls(world.handles[cue.id],cue,world.elapsed)
    await frame();await frame()
    check(cut_pixels(before,world.effect_layer.viewport.get_texture().get_image())==0,label+": paused hold restores its exact sampled pixels")
    observations.append({"sample":label,"opacity_changed_pixel_samples":changed})

func isolated_support(world:Node)->void:
    for choice in [["mage_armor","lifecycle",2.1],["sanctuary","lifecycle",2.1]]:
        select(world,choice[0])
        for index in world.source_clips.size():
            if world.source_clips[index].phase==choice[1]:
                world.select_phase(index+1);pause(world);break
        await advance(world,choice[2])
        var clip:Dictionary=world.active_clips.isolated
        var cue:Dictionary=clip.placement.duplicate(true)
        cue.merge({"id":"isolated","clip":clip,"role":"attached","begin":0.0,"end":world._isolated_seconds(clip)},true)
        await visible_source(world,cue,choice[0]+" isolated "+choice[1])
        await held_opacity(world,cue,choice[0]+"-isolated-"+choice[1])
        zero_room_spill(world,choice[0]+" isolated "+choice[1])

func zero_room_spill(world:Node,label:String)->void:
    check(world.source_lighting.effect_sources.all(func(source):return is_zero_approx(float(source.energy))),label+": native decorative lights add no room energy")
    for page in world.source_lighting._pages:
        for light in page.get("effect_nodes",{}).values():check(not light.enabled,label+": no decorative PointLight2D remains enabled")

func support(world:Node,id:String,view:int)->void:
    select(world,id)
    var cue:Dictionary=world.cue_plan.cues[0]
    await advance(world,cue.begin+.3)
    await visible_source(world,cue,id+" activation")
    save(world,"%s-v%d-activation"%[id,view])
    zero_room_spill(world,id+" activation")
    await advance(world,cue.begin+2.1)
    if id=="false_life":
        check(not world.handles[cue.id].root.visible,"False Life: application has retired after the authored crossfade")
        cue=world.cue_plan.cues.filter(func(value):return value.clip.phase=="sustain")[0]
        var mesh:MeshInstance3D=world.handles[cue.id].root.get_node("effect/Donor/Mesh")
        check(is_equal_approx(mesh.mesh.height,1.6) and is_equal_approx(mesh.mesh.radius,.65),"False Life: actual smaller native sustain envelope is used")
        check(world.handles[cue.id].emitters.all(func(emitter):return emitter.layers==0),"False Life: sustain does not retain application particle clouds")
    await visible_source(world,cue,id+" held")
    await held_opacity(world,cue,"%s-v%d"%[id,view])
    zero_room_spill(world,id+" held")
    check(world.playbacks[world.staging_spec.recipient].clip=="Idle",id+": support hold does not invent a damage reaction")
    await advance(world,world.duration)
    check(world.handles.values().all(func(handle):return not handle.root.visible),id+": all finite preview phases retire")

func shield(world:Node,view:int)->void:
    select(world,"shield")
    var flight:Dictionary=world.cue_plan.cues.filter(func(cue):return cue.role=="flight")[0]
    var hit:Dictionary=world.cue_plan.cues.filter(func(cue):return cue.clip.phase=="hit_E")[0]
    check(flight.to.distance_to(world._target_point("caster"))<.001,"Shield: incoming probe terminates at the protected caster")
    check(flight.from.distance_to(world._target_point("target"))<.001,"Shield: incoming probe starts at the other actor")
    check(is_equal_approx(hit.begin,flight.contact),"Shield: actual native hit occurs at probe contact")
    check(flight.launch>world.release+1.0,"Shield: activation precedes the incoming example")
    await advance(world,(flight.launch+flight.contact)*.5)
    await visible_source(world,flight,"Shield incoming")
    save(world,"shield-v%d-incoming"%view)
    check(not world.handles[hit.id].root.visible,"Shield: contact source is absent before the probe arrives")
    await advance(world,hit.begin+.12)
    await visible_source(world,hit,"Shield intercepted contact")
    var donor:Node3D=world.handles[hit.id].root.get_node("effect/Donor")
    var expected:Vector3=(hit.from-hit.to).normalized();expected.y=0;expected=expected.normalized()
    var actual:Vector3=(donor.global_basis*Vector3.UP).normalized()
    check(actual.dot(expected)>.999,"Shield: native contact normal faces the incoming source")
    check(world.playbacks.caster.clip!="TakeDamage" and world.playbacks.target.clip!="TakeDamage","Shield: interception example does not create a damage result")
    zero_room_spill(world,"Shield")
    save(world,"shield-v%d-contact"%view)
    await advance(world,world.duration)
    check(world.handles.values().all(func(handle):return not handle.root.visible),"Shield: probe, hit and shield close")

func sacred(world:Node,view:int)->void:
    select(world,"sacred_flame")
    var cue:Dictionary=world.cue_plan.cues[0]
    await advance(world,world.arrival+.12)
    var handle:Dictionary=world.handles[cue.id]
    for name in ["floorflash","floorflash2"]:
        check(handle.root.get_node("effect/Donor/"+name).layers==0,"Sacred Flame: opaque base layer remains excluded during source animation")
    check(is_equal_approx(handle.root.global_basis.get_scale().x*22.5,2.7),"Sacred Flame: full native column has cantrip-sized2.7-cell height")
    await visible_source(world,cue,"Sacred Flame descending source")
    check(world.playbacks.target.clip=="TakeDamage","Sacred Flame: actual contact retains the authored recipient reaction")
    save(world,"sacred_flame-v%d-contact"%view)
    await advance(world,world.release+.8)
    save(world,"sacred_flame-v%d-active"%view)
    await advance(world,world.duration)
    check(world.handles.values().all(func(value):return not value.root.visible),"Sacred Flame: full native tail retires")

func burning(world:Node,view:int)->void:
    select(world,"burning_hands")
    var cue:Dictionary=world.cue_plan.cues[0]
    await advance(world,world.release+.03)
    var first:Vector3=core(world.handles[cue.id],cue).global_position
    check(first.distance_to(world.source_start)<.001,"Burning Hands: native fire starts at actual maximum-extension release socket")
    var until=minf(cue.end-.03,world.spell.lead_in_seconds+world.cast_duration+.2)
    await advance(world,until)
    check(world.playbacks.caster.clip=="Idle","Burning Hands: witness includes the returning idle hand")
    check(core(world.handles[cue.id],cue).global_position.distance_to(first)<.001,"Burning Hands: cone does not follow the returning hand")
    await visible_source(world,cue,"Burning Hands fixed cone")
    save(world,"burning_hands-v%d-recovery"%view)
    await advance(world,world.duration)
    check(world.handles.values().all(func(value):return not value.root.visible),"Burning Hands: native cone and tail retire")

func shocking(world:Node,view:int)->void:
    select(world,"shocking_grasp")
    var hand:Dictionary=world.cue_plan.cues.filter(func(cue):return cue.role=="cast")[0]
    var target:Dictionary=world.cue_plan.cues.filter(func(cue):return cue.role=="attached")[0]
    check(hand.id!=target.id,"Shocking Grasp: the two real occurrences have independent owners")
    await advance(world,world.release-.1)
    await visible_source(world,hand,"Shocking Grasp hand buildup")
    check(core(world.handles[hand.id],hand).global_position.distance_to(world._preparation_point())<.001,"Shocking Grasp: original hand occurrence follows the actual casting hand")
    check(not world.handles[target.id].root.visible,"Shocking Grasp: recipient source does not appear during hand buildup")
    save(world,"shocking_grasp-v%d-hand"%view)
    await advance(world,world.arrival+.09)
    check(not world.handles[hand.id].root.visible,"Shocking Grasp: original hand occurrence ends at release")
    await visible_source(world,target,"Shocking Grasp recipient")
    contact_feedback(world,world.cue_plan.contacts[0],"Shocking Grasp")
    save(world,"shocking_grasp-v%d-contact"%view)
    await advance(world,world.duration)
    check(world.handles.values().all(func(value):return not value.root.visible),"Shocking Grasp: no native source remains after its tail")

func run(world:Node)->void:
    DirAccess.make_dir_recursive_absolute(folder)
    for view in 4:
        world.rotate_view(view-world.quarter)
        # False Life's body-conforming replacement has its own native fixture.
        for id in ["mage_armor","sanctuary"]:await support(world,id,view)
        await shield(world,view)
        await sacred(world,view)
        await burning(world,view)
        await shocking(world,view)
    world.rotate_view(-world.quarter)
    await isolated_support(world)
    check(world.presentation_errors.is_empty(),"All selected native sources and character poses are available")
    var report={"checks":checks,"failures":failures,"observations":observations}
    FileAccess.open("res://.runtime/sandbox-support-feedback-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SANDBOX_SUPPORT_FEEDBACK ",JSON.stringify(report))
    get_tree().quit(0 if failures.is_empty() else 1)
