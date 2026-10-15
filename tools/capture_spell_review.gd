extends "res://tests/sandbox_choreography_checks.gd"
## Actual playback samples for visual review; captures are not artistic approval.
func run(world:Node)->void:
    var tag="current"
    var selected=PackedStringArray(["eldritch_blast","guiding_bolt","ice_knife","produce_flame","fire_bolt","ray_of_frost"])
    var views=PackedStringArray(["0","1","2","3"])
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--review-tag="):tag=arg.trim_prefix("--review-tag=")
        if arg.begins_with("--review-spells="):selected=arg.trim_prefix("--review-spells=").split(",")
        if arg.begins_with("--review-views="):views=arg.trim_prefix("--review-views=").split(",")
    var folder="res://.captures/spell-review/"+tag
    DirAccess.make_dir_recursive_absolute(folder)
    var rows=[]
    for id in selected:
        for view in views:
            world.rotate_view(int(view)-world.quarter)
            select(world,id)
            var moments=[
                ["charge",world.release-.08],
                ["release",world.release],
                ["travel",lerpf(world.release,world.arrival,.5)],
                ["impact",world.arrival+.06],
                ["tail",world.arrival+.4]]
            for moment in moments:
                await advance(world,moment[1])
                var prefix=folder+"/%s-v%s-%s"%[id,view,moment[0]]
                world.get_viewport().get_texture().get_image().save_png(prefix+".png")
                var data={"spell":id,"view":int(view),"phase":moment[0],"time":world.elapsed,
                    "release":world.release,"arrival":world.arrival,"preparation_begin":world.preparation_begin,
                    "source":world.source_start,"hand":world._preparation_point(),
                    "sockets":world.socket_samples.duplicate(true),"sources":world.source_lighting.effect_sources.duplicate(true),"pieces":[]}
                for cue in world.cue_plan.cues:
                    var handle=world.handles[cue.id]
                    for piece in handle.geometry:
                        var node:GeometryInstance3D=piece.node
                        if not node.visible:continue
                        data.pieces.append({"cue":cue.id,"role":cue.role,"begin":cue.begin,"end":cue.end,
                            "path":piece.path,"visible":node.is_visible_in_tree(),"world_position":node.global_position,
                            "basis":node.global_basis,"bounds":node.get_aabb() if node is MeshInstance3D else node.visibility_aabb})
                rows.append(data)
                if moment[0]=="travel":
                    world.EffectLayer.colours(world.effect_layer,{},false)
                    await frame()
                    world.get_viewport().get_texture().get_image().save_png(prefix+"-native.png")
                    world.EffectLayer.colours(world.effect_layer,world.library.spells[world.selected_spell].get("palette",{}),world.spell_colours)
            print("SPELL_REVIEW_CAPTURE ",id," view ",view)
    FileAccess.open(folder+"/measurements.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
    print("SPELL_REVIEW_COMPLETE ",folder)
    get_tree().quit()
