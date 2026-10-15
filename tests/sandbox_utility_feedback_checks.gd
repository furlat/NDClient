extends "res://tests/sandbox_choreography_checks.gd"
## Real-window qualification of support source registration and the explicitly
## authored offline True Strike follow-up. No server outcomes are synthesized.
const SPELLS=["aid","bless","cure_wounds","healing_word","guidance","resistance","light","thaumaturgy","shield_of_faith","true_strike"]
const TIMES={"aid":[.5,2.1],"bless":[.4,2.1],"cure_wounds":[.45,.8],"healing_word":[.25,.65],"guidance":[.22,.5],"resistance":[.25,.55],"light":[.4,1.2],"thaumaturgy":[.12,.22],"shield_of_faith":[.8,1.2],"true_strike":[.15,.22]}
const BodySurface=preload("res://sandbox/body_surface.gd")
var folder="res://.captures/utility-feedback"

func screenshot(world:Node,label:String)->Image:
    var image:Image=world.get_viewport().get_texture().get_image()
    image.save_png(folder+"/"+label+".png")
    return image

func difference(before:Image,after:Image)->Dictionary:
    var changed=0
    var brighter=0
    var energy=0.0
    # Measure actual final RGB. Additive source cards can have zero coverage;
    # alpha-weighting this diagnostic would falsely call them invisible.
    for y in range(0,before.get_height(),2):
        for x in range(0,before.get_width(),2):
            var a=before.get_pixel(x,y);var b=after.get_pixel(x,y)
            var delta=Vector3(a.r-b.r,a.g-b.g,a.b-b.b)
            if absf(delta.x)+absf(delta.y)+absf(delta.z)>.05:changed+=1
            var luminance=delta.dot(Vector3(.2126,.7152,.0722))
            if luminance>.01:brighter+=1
            energy+=luminance
    return {"changed":changed,"brighter":brighter,"signed_luminance":energy}

func settle()->void:
    await frame();await frame()

func visible_source(world:Node,cue:Dictionary,label:String)->void:
    var handle:Dictionary=world.handles[cue.id]
    check(handle.root.visible,label+": actual native source is active")
    var before=screenshot(world,label)
    handle.root.hide();await settle()
    var off:Image=world.get_viewport().get_texture().get_image()
    var result=difference(before,off)
    check(result.changed>1,label+": native source changes actual final pixels (%d)"%result.changed)
    check(result.brighter>0,label+": native source contributes visible colour, not only an opaque black card")
    handle.root.show();await settle()
    observations.append({"sample":label,"source_seconds":handle.age,"pixel_difference":result})

func registration(world:Node,cue:Dictionary,label:String)->void:
    var handle:Dictionary=world.handles[cue.id]
    var id:String=world.spell.spell_id
    if id in ["aid","bless"]:
        var mesh:MeshInstance3D=handle.root.get_node("effect/Donor/Mesh")
        var bottom:Vector3=mesh.global_transform*Vector3(0,mesh.get_aabb().position.y,0)
        check(absf(bottom.y-cue.ground.y)<.0001,label+": native envelope base meets the recipient floor")
    if id in ["cure_wounds","healing_word"]:
        var donor:Node3D=handle.root.get_node("effect/Donor")
        check(donor.global_position.distance_to(world._target_point(cue.target))<.001,label+": healing source is on the actual torso socket")
        if id=="healing_word":check(donor.get_node("verticalflash").global_position.distance_to(world._target_point(cue.target))<.001,label+": visible healing pulse is centered on the torso")
    if id in ["guidance","thaumaturgy"]:
        var mesh:MeshInstance3D=handle.root.get_node("effect/Donor/MeshInstance3D")
        check(mesh.mesh is SphereMesh,label+": streaks use actual 3D source geometry")
        check(not bool(mesh.material_override.get_shader_parameter("billboard")),label+": source material does not turn its geometry into a billboard")
        var size=mesh.get_aabb().size*mesh.global_basis.get_scale().abs()
        check(size.x>0 and size.y>0 and size.z>0,label+": actual source extent remains nonzero on all axes")
    if id=="shield_of_faith":
        check(absf(handle.root.get_node("effect/Donor/shield_effect").global_position.y-cue.ground.y-.4875)<.0001,label+": shield center stays at waist height")
        for name in ["external_base_ring","verticalflash2","muzzle2"]:
            check(handle.root.get_node("effect/Donor/"+name).layers==0,label+": excluded donor wind/burst stays absent: "+name)

func visible_body_surface(world:Node,cue:Dictionary,label:String)->void:
    var samples:Array=BodySurface.samples(world,world.elapsed)
    check(samples.size()==1,label+": original sustain material is active on the recipient")
    if samples.size()!=1:return
    check(not world.handles[cue.id].root.visible,label+": sustain source cylinder and particles stay hidden")
    check(samples[0].actor_uuid==cue.target,label+": body pattern belongs to the authored recipient")
    var before=screenshot(world,label)
    var strength:float=cue.body_surface.strength
    cue.body_surface.strength=0.0;world._sample_frame(0.0);await settle()
    var result=difference(before,world.get_viewport().get_texture().get_image())
    check(result.changed>1 and result.brighter>0,label+": body sustain contributes actual coloured receiving pixels")
    cue.body_surface.strength=strength;world._sample_frame(0.0);await settle()
    check(difference(before,world.get_viewport().get_texture().get_image()).changed==0,label+": body sustain restores exact paused pixels")
    observations.append({"sample":label,"body_surface_strength":samples[0].body_surface_strength,"source_clock":samples[0].body_surface_clock,"pixel_difference":result})

func no_room_spill(world:Node,label:String)->void:
    check(world.source_lighting.effect_sources.all(func(source):return is_zero_approx(float(source.energy))),label+": nonluminous support adds no decorative room-light energy")
    for page in world.source_lighting._pages:
        for light in page.get("effect_nodes",{}).values():check(not light.enabled,label+": decorative PointLight2D remains disabled")

func quiet_hold(world:Node,cue:Dictionary,label:String)->void:
    var before=screenshot(world,label+"-quiet")
    var full:Dictionary=cue.duplicate(true);full.erase("opacity_keys")
    for piece in world.handles[cue.id].geometry:piece.node.transparency=0.0
    world._sample_controls(world.handles[cue.id],full,world.elapsed)
    await settle()
    var full_frame:Image=world.get_viewport().get_texture().get_image()
    full_frame.save_png(folder+"/"+label+"-unattenuated-reference.png")
    var result=difference(full_frame,before)
    check(result.brighter>1 and result.signed_luminance>0,label+": authored quiet hold reduces actual visible native intensity at the same age")
    world._sample_controls(world.handles[cue.id],cue,world.elapsed);await settle()
    var restored=difference(before,world.get_viewport().get_texture().get_image())
    check(restored.changed==0,label+": paused quiet hold restores its exact pixels")
    observations.append({"sample":label,"quiet_hold_comparison":result})

func light_evidence(world:Node,cue:Dictionary,label:String)->void:
    var handle:Dictionary=world.handles[cue.id]
    var emitter:OmniLight3D=handle.root.get_node("effect/Donor/Light")
    var orb:Node3D=handle.root.get_node("effect/Donor/Glow")
    check(emitter.global_position.distance_to(orb.global_position)<.0001,label+": optical source and visible orb share their position")
    check(is_equal_approx(emitter.global_position.y-cue.ground.y,1.41),label+": actual source is at authored head height")
    var active:Array=world.source_lighting.effect_sources.filter(func(source):return source.visible and source.energy>0)
    check(active.size()==1,label+": one real luminous source is admitted")
    if active.size()==1:
        check(active[0].world_position.distance_to(orb.global_position)<.0001,label+": 2D normal light uses that actual optical position")
        check(is_equal_approx(active[0].radius,8),label+": optical radius uses source-unit conversion once")
    var lit=screenshot(world,label+"-lit")
    world.staging_spec.decorative_light_multiplier=0.0;world._sample_frame(0.0);await settle()
    var unlit=screenshot(world,label+"-source-light-off")
    var result=difference(lit,unlit)
    check(result.brighter>2 and result.signed_luminance>0,label+": actual PointLight2D source visibly illuminates the native receiving scene")
    world.staging_spec.decorative_light_multiplier=1.0;world._sample_frame(0.0);await settle()
    observations.append({"sample":label,"optical_on_off":result,"native_energy":emitter.light_energy,"native_height":emitter.global_position.y})

func follow_up(world:Node,label:String)->void:
    check(world.feedback.actions.size()==1,label+": one explicitly authored offline follow-up")
    if world.feedback.actions.is_empty():return
    var action:Dictionary=world.feedback.actions[0]
    var before=float(action.track.start_ms)/1000.0-.015
    await advance(world,before)
    check(world.playbacks.caster.clip=="Idle" and world.playbacks.target.clip=="Idle",label+": buff precedes the attack and recipient reaction")
    screenshot(world,label+"-before-attack")
    await advance(world,float(action.contact_ms)/1000.0+.015)
    check(world.playbacks.caster.clip=="Attack6",label+": caster visibly plays the authored native attack")
    check(world.playbacks.target.clip=="TakeDamage",label+": receiver plays the explicit contact reaction")
    check(world.feedback.layers.is_empty() and not action.layers.is_empty(),label+": disabled cast remains absent and childAttack owns the magic layer")
    var entries:Array=world.visual_actors.caster.entries.filter(func(entry):return not entry.actor_layer.get("effect",{}).is_empty() and entry.node.visible)
    check(not entries.is_empty(),label+": actual actor effect-layer entries are displayed during the follow-up")
    var before_layers=screenshot(world,label+"-attack-contact")
    for entry in entries:entry.node.hide()
    await settle()
    var result=difference(before_layers,world.get_viewport().get_texture().get_image())
    check(result.changed>0,label+": actual child-attack layer contributes final framebuffer pixels")
    for entry in entries:entry.node.show()
    await settle()
    observations.append({"sample":label,"attack_seconds":world.elapsed,"clip":world.playbacks.caster.clip,"receiver":world.playbacks.target.clip,"magic_layer_pixels":result})

func run(world:Node)->void:
    DirAccess.make_dir_recursive_absolute(folder)
    var selected:Array=SPELLS.duplicate()
    var views:Array=[0,1,2,3]
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--utility-spells="):selected=Array(argument.trim_prefix("--utility-spells=").split(","))
        if argument=="--utility-one-view":views=[0]
    for id in selected:
        for view in views:
            world.rotate_view(view-world.quarter)
            select(world,id)
            var cue:Dictionary=world.cue_plan.cues[0]
            var label="%s-v%d"%[id,view]
            await advance(world,.05)
            check(world.handles.values().all(func(handle):return not handle.root.visible),label+": native sources are absent in initial idle")
            for index in TIMES[id].size():
                await advance(world,cue.begin+float(TIMES[id][index]))
                var phase="activation" if index==0 else "active"
                var body_cues:Array=world.cue_plan.cues.filter(func(value):return value.has("body_surface") and world.elapsed>=value.begin and world.elapsed<value.end)
                if body_cues.is_empty():
                    await visible_source(world,cue,label+"-"+phase)
                    registration(world,cue,label+"-"+phase)
                else:
                    check(not world.handles[cue.id].root.visible,label+": completed native application no longer forms a cage")
                    await visible_body_surface(world,body_cues[0],label+"-"+phase)
                if id!="light":no_room_spill(world,label+"-"+phase)
                if id!="true_strike":check(world.playbacks.target.clip!="TakeDamage" and world.playbacks.target2.clip!="TakeDamage",label+": support source does not invent a damage reaction")
            if id=="aid":await quiet_hold(world,cue,label)
            if id=="bless":screenshot(world,label+"-quiet")
            if id=="light":await light_evidence(world,cue,label)
            if id=="true_strike":await follow_up(world,label)
            var source_end:float=world.cue_plan.cues.map(func(value):return value.end).max()
            await advance(world,source_end-.015)
            screenshot(world,label+"-ending")
            if id=="light":check(world.source_lighting.effect_sources.all(func(source):return source.energy<.03),label+": Light energy closes with the visible orb")
            await advance(world,world.duration)
            check(world.handles.values().all(func(handle):return not handle.root.visible),label+": all finite native phases retire")
            check(world.playbacks.caster.clip=="Idle" and world.playbacks.target.clip=="Idle",label+": both actor poses restore after the demonstration")
            check(world.presentation_errors.is_empty(),label+": no presentation-media errors")
            screenshot(world,label+"-complete")
            var old_loop:int=world.loop_count
            world.loop=true;world.playing=true;world._process(.01);pause(world)
            check(world.loop_count==old_loop+1 and is_zero_approx(world.elapsed),label+": loop restarts the complete authored fixture")
            print("SANDBOX_UTILITY_PROGRESS ",id," view",view)
    var report={"checks":checks,"failures":failures,"observations":observations}
    FileAccess.open("res://.runtime/sandbox-utility-feedback-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SANDBOX_UTILITY_FEEDBACK ",JSON.stringify({"checks":checks,"failures":failures,"spells":selected.size(),"views":views.size()}))
    get_tree().quit(0 if failures.is_empty() else 1)
