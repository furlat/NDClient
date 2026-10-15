extends "res://tests/sandbox_choreography_checks.gd"
## Final painted receiver, with native effects/light held at the same contact.
func difference(a:Image,b:Image,rect:Rect2i)->int:
    var count=0
    for y in range(maxi(0,rect.position.y),mini(a.get_height(),rect.end.y)):
        for x in range(maxi(0,rect.position.x),mini(a.get_width(),rect.end.x)):
            var p=a.get_pixel(x,y);var q=b.get_pixel(x,y)
            if maxf(absf(p.r-q.r),maxf(absf(p.g-q.g),absf(p.b-q.b)))>.04:count+=1
    return count

func run(world:Node)->void:
    var folder="res://.captures/feedback"
    DirAccess.make_dir_recursive_absolute(folder)
    for view in 4:
        world.rotate_view(view-world.quarter)
        for id in ["fire_bolt","ice_knife","chill_touch"]:
            select(world,id)
            var contact:Dictionary=world.cue_plan.contacts[0]
            var hold_seconds=float(world.feedback.flash.holdMs)/1000.0
            var duration_seconds=float(world.feedback.flash.durationMs)/1000.0
            check(hold_seconds>0.0 and duration_seconds>hold_seconds,id+": authored flash has a finite hold and fade")
            await advance(world,contact.time+hold_seconds*.5)
            var at:Vector2=world.camera.unproject_position(world.get_node("Target").global_position)
            var rect=Rect2i(Vector2i(at)-Vector2i(65,145),Vector2i(130,165))
            world.spell_hit_flash=true;world._sample_frame(0);await frame();await frame()
            var on=world.get_viewport().get_texture().get_image()
            check(world.playbacks.target.clip=="TakeDamage",id+": body reacts during flash")
            check(float(body_material(world,"target").get_shader_parameter("flash_strength"))>.99,id+": authored hold survives the impact frame")
            world.spell_hit_flash=false;world._sample_frame(0);await frame();await frame()
            var off=world.get_viewport().get_texture().get_image()
            var changed=difference(on,off,rect)
            check(changed>60,id+" view%d: receiver material visibly changes final pixels (%d)"%[view,changed])
            check(world.playbacks.target.clip=="TakeDamage",id+": toggle preserves receiving animation")
            check(float(body_material(world,"target").get_shader_parameter("flash_strength"))==0,id+": toggle clears body material immediately")
            on.save_png(folder+"/%s-v%d-on.png"%[id,view])
            off.save_png(folder+"/%s-v%d-off.png"%[id,view])
            world.spell_hit_flash=true;world._sample_frame(0);await frame();await frame()
            var restored_on=world.get_viewport().get_texture().get_image()
            check(difference(on,restored_on,rect)<10,id+": paused toggle restores identical material")
            await advance(world,contact.time+lerpf(hold_seconds,duration_seconds,.5))
            check(is_equal_approx(float(body_material(world,"target").get_shader_parameter("flash_strength")),.5),id+": authored hold-to-end midpoint is half strength")
            var late=world.get_viewport().get_texture().get_image()
            world.spell_hit_flash=false;world._sample_frame(0);await frame();await frame()
            var late_off=world.get_viewport().get_texture().get_image()
            check(difference(late,late_off,rect)>30,id+": material remains visible in final pixels after the impact peak")
            late.save_png(folder+"/%s-v%d-late-on.png"%[id,view])
            late_off.save_png(folder+"/%s-v%d-late-off.png"%[id,view])
            world.spell_hit_flash=true;world._sample_frame(0)
            await advance(world,world.cue_plan.contacts.back().time+duration_seconds+.01)
            check(float(body_material(world,"target").get_shader_parameter("flash_strength"))==0,id+": flash retires at its authored duration")
            observations.append({"spell":id,"view":view,"changed_receiver_pixels":changed,"duration_ms":world.feedback.flash.durationMs,"hold_ms":world.feedback.flash.holdMs,"hold_sample_ms":hold_seconds*500.0,"fade_sample_ms":lerpf(hold_seconds,duration_seconds,.5)*1000.0})
    var policy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/feedback.json"))
    for index in world.spells.size():
        world.select_spell(index);pause(world)
        check(world.feedback.layers.all(func(layer):return layer.category in ["Magic1","Magic2","Magic3"]),world.spell.spell_id+": only hand magic casting layers")
        if world.recipe.get("damage")!=null:
            check(world.feedback.flash.durationMs==policy.hit_flash.durationMs,world.spell.spell_id+": damage uses the shared authored flash duration")
            check(world.feedback.flash.holdMs==policy.hit_flash.holdMs,world.spell.spell_id+": damage uses the shared authored flash hold")
    select(world,"fire_bolt")
    world.feedback.flash.enabled=false
    await advance(world,world.arrival+float(world.feedback.flash.holdMs)/2000.0)
    check(float(body_material(world,"target").get_shader_parameter("flash_strength"))==0,"Disabled authored hit flash remains absent")
    for id in ["fire_bolt","chill_touch","ice_knife"]:
        select(world,id)
        var cue:Dictionary=world.cue_plan.cues.filter(func(value):return value.role in ["impact","strike","area"])[0]
        for index in world.source_clips.size():
            if world.source_clips[index].id==cue.clip.id:world.select_phase(index+1);pause(world);break
        var contact_at:float=cue.source_contact if cue.role=="strike" else 0.0
        if contact_at>.01:
            await advance(world,contact_at-.01)
            check(world.playbacks.target.clip=="Idle",id+": isolated strike waits for actual source contact")
        await advance(world,contact_at+float(world.feedback.flash.holdMs)/2000.0)
        check(world.playbacks.target.clip=="TakeDamage",id+": isolated impact also shows recipient reaction")
        check(float(body_material(world,"target").get_shader_parameter("flash_strength"))>.99,id+": isolated impact also shows receiver flash")
    var report={"checks":checks,"failures":failures,"observations":observations}
    FileAccess.open("res://.runtime/sandbox-feedback-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SANDBOX_FEEDBACK_CHECKS ",JSON.stringify(report))
    get_tree().quit(0 if failures.is_empty() else 1)
