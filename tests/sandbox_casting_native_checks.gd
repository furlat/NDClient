extends "res://tests/sandbox_choreography_checks.gd"
## Exercise the real selector, delivered body/magic sheets and native handoff.
func run(world:Node)->void:
    DirAccess.make_dir_recursive_absolute("res://.captures/casting")
    var index=world.spells.find_custom(func(value):return value.spell_id=="fire_bolt")
    for variant in world.cast_variants:
        if variant.id=="authored" or variant.status!="available":continue
        for view in 4:
            world.rotate_view(view-world.quarter)
            world.select_spell(index,variant.id);pause(world)
            var label="%s-v%d"%[variant.id,view]
            check(world.recipe.cast.actionClip==variant.id,label+": selector applies the chosen body clip")
            var flight:Dictionary=world.cue_plan.cues.filter(func(cue):return cue.role=="flight")[0]
            await advance(world,world.release+.00001)
            check(world.playbacks.caster.clip==variant.id,label+": displayed body uses the selected animation at release")
            check(world._preparation_point().distance_to(world.source_start)<.001,label+": current hand and release socket agree in actual scene space")
            if variant.id=="Special1":
                var left:Vector3=world.socket_samples["release/hand"].point
                var right:Vector3=world.socket_samples["release/other_hand"].point
                var midpoint:Vector3=(left+right)*.5
                var clearance:Vector3=world.source_start-midpoint
                var forward:Vector3=(world.get_node("Target").position-world.get_node("Caster").position)*Vector3(1,0,1)
                check(clearance.length()>.001 and clearance.normalized().dot(forward.normalized())>.9999,
                    label+": release is centered between both resolved hands with only forward clearance")
                check(world.source_start.distance_to(left)>.05 and world.source_start.distance_to(right)>.05,
                    label+": invocation does not launch from either single hand")
            check(core(world.handles[flight.id],flight).global_position.distance_to(world.source_start)<.002,label+": native projectile leaves that hand")
            check(world.displayed_components.any(func(sample):return sample.kind=="sprite_layer" and sample.actor_uuid=="caster" and sample.clip==variant.id),label+": matching magic layer is present at release")
            world.get_viewport().get_texture().get_image().save_png("res://.captures/casting/"+label+"-release.png")
            var release_position:Vector3=world.source_start
            var contact:float=flight.contact
            world.rotate_view(1);await frame()
            check(is_equal_approx(flight.contact,contact),label+": camera rotation preserves contact time")
            check(world._preparation_point().distance_to(world.source_start)<.001,label+": rotated hand and release remain registered")
            world.rotate_view(-1);await frame()
            check(world.source_start.distance_to(release_position)<.001,label+": rotating back restores the same release point")
            await advance(world,flight.contact+.05)
            check(world.playbacks.target.clip=="TakeDamage",label+": delivery retains the receiving reaction")
            await advance(world,world.duration)
            check(world.handles.values().all(func(handle):return not handle.root.visible),label+": all native phases retire")
            observations.append({"profile":variant.id,"view":view,"release":world.release,"duration":world.duration,"socket":world.socket_samples.get("release",{})})
    world.flight_speed=6.5
    world.camera.size=8.25
    world.place_marker("Target",Vector3(3,0,1));pause(world)
    world.select_spell(index,"Attack5");pause(world)
    check(is_equal_approx(world.flight_speed,6.5) and is_equal_approx(world.camera.size,8.25)
        and world.get_node("Target").position.is_equal_approx(Vector3(3,0,1)),"Changing only the casting pose preserves target placement, zoom and flight speed")
    world.spells[index].casting_profile="authored"
    world.select_spell(index);pause(world)
    check(world.recipe==JSON.parse_string(FileAccess.get_file_as_string(world.spell.choreography)),"Authored choice restores the exact original Fire Bolt recipe")
    check(world.presentation_errors.is_empty(),"Casting alternatives have no presentation errors")
    var report={"checks":checks,"failures":failures,"observations":observations,"scope":"Offline native selector/body/magic/release continuity across the five established spell poses and four views. Original per-spell assignments remain the default."}
    FileAccess.open("res://.runtime/sandbox-casting-native-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SANDBOX_CASTING_NATIVE ",JSON.stringify({"checks":checks,"failures":failures}))
    get_tree().quit(0 if failures.is_empty() else 1)
