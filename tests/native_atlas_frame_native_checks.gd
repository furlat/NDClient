extends "res://tests/native_atlas_lifecycle_checks.gd"
## Extend the native lifecycle suite with actual modular UV-frame pixels.
func tracked_material_checks(atlas:RefCounted,world:World,entry:Dictionary,source:Image)->void:
    await super.tracked_material_checks(atlas,world,entry,source)
    var sheet=Image.create(128,64,false,Image.FORMAT_RGBA8)
    sheet.blit_rect(source,Rect2i(0,0,64,64),Vector2i.ZERO)
    for y in 64:
        for x in 64:
            var c=source.get_pixel(x,y)
            sheet.set_pixel(x+64,y,Color(c.b,c.r,c.g,c.a))
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(2,2)
    node.position=Vector3(0,2.1,0);world.add_child(node)
    var material=ShaderMaterial.new();material.shader=ActorSource
    material.set_shader_parameter("sheet",ImageTexture.create_from_image(sheet))
    material.set_shader_parameter("frame_uv",Vector4(0,0,.5,1))
    material.set_shader_parameter("material_cell_size",Vector2(64,64))
    material.set_shader_parameter("condition_alpha",.65)
    material.set_shader_parameter("tint",Vector3(.8,1,.7))
    node.material_override=material
    var actor={"node":node,"material":material,"cell":Vector2(64,64),"placement":{"id":"modular-frame-fixture","kind":"actor"},"role":"body","source_version":1}
    world.entries.append(actor);world.actor_entries=[actor]
    sync_scene(atlas,world,true,false,sparse([actor]))
    for cap in [0.0,1.0]:
        atlas.set_light_cap(cap);sync_scene(atlas,world)
        var before=await capture(world.get_viewport())
        var previous:int=actor.source_version;actor.source_version+=1
        actor.source_frame_change={"base_version":previous,"version":actor.source_version,"source":material,"shader":material.shader}
        material.set_shader_parameter("frame_uv",Vector4(.5 if cap==0 else 0,0,.5,1))
        sync_scene(atlas,world)
        check(atlas.last_reconcile_phases.get("material_frame_copies",0)==(1 if cap==0 else 2),"Actual modular frame uses only UV copies with cap="+str(cap))
        await native_frame_oracle(atlas,world,actor,"modular-frame-cap-"+str(cap),before)
    # Drop one sampled version while condition data also changes: only a full
    # copy can restore all state when this receiver next becomes current.
    actor.source_version+=2
    actor.source_frame_change={"base_version":actor.source_version-1,"version":actor.source_version,"source":material,"shader":material.shader}
    material.set_shader_parameter("frame_uv",Vector4(.5,0,.5,1));material.set_shader_parameter("condition_alpha",.9)
    sync_scene(atlas,world)
    check(atlas.last_reconcile_phases.get("material_frame_copies",0)==0,"Skipped native frame version never accepts a partial copy")
    await native_frame_oracle(atlas,world,actor,"modular-missed-version",null)
    atlas.set_light_cap(0);var id=node.get_instance_id();world.entries.pop_back();world.actor_entries=[];node.queue_free()
    sync_scene(atlas,world,true,false,sparse([],[id]))

func native_frame_oracle(atlas:RefCounted,world:World,actor:Dictionary,label:String,before:Image)->void:
    var first=await capture(world.get_viewport())
    var receiver:Dictionary=row_receiver(atlas,actor)
    var crop=Rect2i(receiver.position,receiver.crop.pixels.size)
    var first_cell=atlas.viewport.get_texture().get_image().get_region(crop).get_data()
    var id:int=actor.node.get_instance_id()
    for group in atlas.source_groups[id].values():group.version=-1
    actor.erase("received_source_key");atlas.material_dirty[id]=true
    sync_scene(atlas,world)
    var complete=await capture(world.get_viewport())
    check(first.get_data()==complete.get_data(),label+": first fast-path final framebuffer equals forced complete copy exactly")
    check(first_cell==atlas.viewport.get_texture().get_image().get_region(crop).get_data(),label+": first fast-path receiving pixels equal forced complete copy exactly")
    if before!=null:check(before.get_data()!=first.get_data(),label+": actual frame changes visible pixels")
    first.save_png("res://.captures/atlas-lifecycle/"+label+".png")
