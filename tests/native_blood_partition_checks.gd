extends "res://tests/native_effect_receiving_checks.gd"
# Finite source-plane qualification. Actual recorded actor interleaving is a
# separate scene test; no optical receiver depth is used as sorting authority.
func settle_source(preview:Node3D,age:float,basis:Basis,anchor:Vector3,context:Dictionary)->Dictionary:
    var result=preview.sample(age,basis,anchor,1.,[],context)
    var end=Time.get_ticks_msec()+10000
    while not result.ready and result.error.is_empty() and Time.get_ticks_msec()<end:
        await process_frame;await RenderingServer.frame_post_draw
        result=preview.sample(age,basis,anchor,1.,[],context)
    await process_frame;await RenderingServer.frame_post_draw
    return result
func run()->void:
    DirAccess.make_dir_recursive_absolute("res://.captures/native-effects/partition")
    var owner=Node3D.new();root.add_child(owner)
    for quarter in 4:
        var basis=Basis(Vector3.UP,quarter*PI*.5)*Basis.looking_at(Vector3(-6,-sqrt(24.),-6))
        var normal=Vector3(basis.z.x,0,basis.z.z).normalized()
        var preview=Preview.new();owner.add_child(preview)
        check(preview.configure("blood.hit_a1",{},73).is_empty(),"Original blood source configures")
        var lights=Lighting.new()
        check(preview.bind_receiving(lights).is_empty(),"Blood retains native receiving")
        var anchor=Vector3(3,1,4)
        var context={"screen_origin":Vector2.ZERO,"pixel_scale":1.,"supports":[],"source_basis":Basis.IDENTITY,"light_cap":1.}
        var sampled=await settle_source(preview,.2,basis,anchor,context)
        check(sampled.ready and sampled.error.is_empty(),"Source reaches exact held age")
        check(preview.views.size()==2 and preview.handle.emitters.size()==2,"Two partitions share the one original two-emitter simulation")
        var original=preview.views[1].viewport.get_texture().get_image()
        check(count_alpha(original)>0,"Original source has visible native coverage")
        check(count_alpha(preview.views[0].viewport.get_texture().get_image())==0,"Unbound actor plane owns no rear fragments")
        var original_bounds:Array=[]
        for row in preview.handle.emitters:original_bounds.append(row.node.capture_aabb())
        for side in [-1.,1.]:
            var foot=anchor+normal*side*20.
            check(preview.bind_actor_partition(foot,basis,anchor,1.).is_empty(),"Actor presentation plane accepts current foot")
            var fresh=preview.sample(.2,basis,anchor,1.,[],context)
            check(not fresh.ready,"Changed actor plane waits for its own native draw")
            await settle_source(preview,.2,basis,anchor,context)
            var back=preview.views[0].viewport.get_texture().get_image()
            var front=preview.views[1].viewport.get_texture().get_image()
            var selected=back if side>0 else front
            var rejected=front if side>0 else back
            check(selected.get_data()==original.get_data(),"Whole source partition preserves exact native RGBA q%d side%d"%[quarter,int(side)])
            check(count_alpha(rejected)==0,"Complementary source partition is empty at separated plane")
            check(preview.position==anchor and preview.handle.age==.2,"Moving target plane leaves impact anchor and source clock fixed")
            for i in original_bounds.size():check(preview.handle.emitters[i].node.capture_aabb()==original_bounds[i],"Actor plane changes never re-simulate detached particles")
        preview.bind_actor_partition(anchor,basis,anchor,1.)
        await settle_source(preview,.2,basis,anchor,context)
        var back=preview.views[0].viewport.get_texture().get_image()
        var front=preview.views[1].viewport.get_texture().get_image()
        back.save_png("res://.captures/native-effects/partition/q%d-back.png"%quarter)
        front.save_png("res://.captures/native-effects/partition/q%d-front.png"%quarter)
        var owned_union=0;var original_pixels=count_alpha(original)
        for y in original.get_height():
            for x in original.get_width():
                owned_union+=int(back.get_pixel(x,y).a>0 or front.get_pixel(x,y).a>0)
        check(owned_union==original_pixels,"Complementary native fragments retain exact original coverage")
        cases.append({"quarter":quarter,"original_pixels":original_pixels,"back_pixels":count_alpha(back),"front_pixels":count_alpha(front)})
        preview.close();preview.free();lights.clear_pages()
    owner.free()
    var report={"passed":passed,"failed":failures.size(),"failures":failures,"cases":cases,"scope":"Original native blood fragments split before alpha blend at declared2.5D actor ground plane; one simulation, fixed world anchor, exact full-side RGBA/union coverage. Real actor painter interleaving and scenery crossing separate."}
    FileAccess.open("res://generated/native_blood_partition_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
