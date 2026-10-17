extends SceneTree
const Preview=preload("res://presentation/native_effect_preview.gd")
const Lighting=preload("res://presentation/lighting_2d.gd")
const LightTable=preload("res://presentation/light_table.gd")
var passed=0
var failures:Array=[]
var cases:Array=[]
func check(value:bool,label:String)->void:
    if value:passed+=1
    else:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func count_alpha(image:Image)->int:
    var count=0
    for y in image.get_height():
        for x in image.get_width():
            if image.get_pixel(x,y).a>0:count+=1
    return count
func max_alpha_difference(a:Image,b:Image)->float:
    var error=0.0
    for y in a.get_height():
        for x in a.get_width():error=maxf(error,absf(a.get_pixel(x,y).a-b.get_pixel(x,y).a))
    return error
func run()->void:
    DirAccess.make_dir_recursive_absolute("res://.captures/native-effects/blood")
    var main=SubViewport.new();main.size=Vector2i(768,768);main.own_world_3d=true;main.transparent_bg=true
    main.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(main)
    var owner=Node3D.new();main.add_child(owner)
    var camera=Camera3D.new();owner.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=6.0;camera.current=true
    # Room lights come from the shared light table, as in play.
    var world_lights=Lighting.new()
    var cookie:Texture2D=world_lights._source_cookie({"outer":6.0,"very_bright_radius_feet":10,"bright_radius_feet":20})
    while cookie==null:
        await process_frame;cookie=world_lights._source_cookie({"outer":6.0,"very_bright_radius_feet":10,"bright_radius_feet":20})
    for i in 3:await process_frame
    var table=LightTable.new()
    for quarter in 4:
        var basis=Basis(Vector3.UP,quarter*PI*.5)*Basis.looking_at(Vector3(-6,-sqrt(24.0),-6))
        camera.basis=basis;camera.position=Vector3(0,.9*.816496580927726,0)+basis.z*12.
        for id in ["blood.hit_a1","blood.hit_a2","blood.deposit_a1"]:
            var preview=Preview.new();owner.add_child(preview)
            check(preview.configure(id,{},73).is_empty(),id+" selected source builds")
            check(preview.bind_receiving().is_empty(),id+" source materials bind table receiving")
            var record=preview.record;var ppu=float(record.pixels_per_unit)
            var top_left=Vector3(-record.pivot[0]/ppu,record.pivot[1]/ppu,0)
            var origin=camera.unproject_position(basis*top_left)
            var pixel_scale=(camera.unproject_position(basis*Vector3.RIGHT)-camera.unproject_position(Vector3.ZERO)).length()/ppu
            var context={"screen_origin":origin,"pixel_scale":pixel_scale,"light_cap":1.0,"source_basis":Basis(Vector3.UP,.4),"supports":[]}
            # One registered torch near the source, as Lighting2D.project() builds it.
            var at:Vector2=camera.unproject_position(Vector3.ZERO)+Vector2(40,-70)
            var light={"id":"registered_fixture","screen_position":at,"texture":cookie,"texture_scale":2.0*300.0/cookie.get_width(),
                "cookie_scale":Vector2.ONE*2.0,"offset":Vector2.ZERO,"height":56.0*pixel_scale,"energy":.9,"color":Lighting.TORCH_COLOUR,"enabled":true}
            table.publish([light],func(_texture):return null)
            var age=.2 if id!="blood.deposit_a1" else 2.0
            if id=="blood.deposit_a1":
                var missing=preview.sample(age,basis,Vector3.ZERO,1.0,[],context)
                check(not missing.ready and not missing.error.is_empty(),"Depth-reading source rejects missing published support")
                context.supports=[Transform3D(Basis.from_scale(Vector3(3,1,3)),Vector3.ZERO)]
            var sample=preview.sample(age,basis,Vector3.ZERO,1.0,[],context)
            var deadline=Time.get_ticks_msec()+10000
            while not sample.ready and sample.error.is_empty() and Time.get_ticks_msec()<deadline:
                await process_frame;await RenderingServer.frame_post_draw
                sample=preview.sample(age,basis,Vector3.ZERO,1.0,[],context)
            if not sample.ready:print("UNPREPARED ",id," q",quarter," sample=",sample," handleage=",preview.handle.get("age")," pending=",preview.handle.get("pending")," drawn=",preview.sampled_age," requested=",preview.requested_age," keys=",preview._rendered_key==preview._requested_render_key)
            check(sample.error.is_empty() and sample.ready,id+" accepts explicit receiving registration and completes bounded native seek")
            await process_frame;await RenderingServer.frame_post_draw
            # The source and receiving views are texture dependencies. A second
            # unchanged sample also proves paused pixels and source age stability.
            preview.sample(age,basis,Vector3.ZERO,1.0,[],context)
            await process_frame;await RenderingServer.frame_post_draw
            var colour=preview.viewport.get_texture().get_image()
            var normal=preview.receiving.normal.get_texture().get_image()
            var final_image=main.get_texture().get_image()
            var covered=count_alpha(colour)
            check(covered>0,id+" actual selected source has native coverage in q"+str(quarter))
            check(count_alpha(normal)>0,id+" original normal pass has coverage")
            check(preview.sample_ready and preview.surface.visible,id+" source publishes its rendered requested age")
            var name="q%d-%s"%[quarter,id.replace(".","-")]
            colour.save_png("res://.captures/native-effects/blood/"+name+"-colour.png")
            preview.receiving.depth.get_texture().get_image().save_png("res://.captures/native-effects/blood/"+name+"-depth.png")
            normal.save_png("res://.captures/native-effects/blood/"+name+"-normal.png")
            final_image.save_png("res://.captures/native-effects/blood/"+name+"-lit.png")
            light.energy=0.0;table.publish([light],func(_texture):return null)
            var changed_light=preview.sample(age,basis,Vector3.ZERO,1.0,[],context)
            check(changed_light.ready,id+" a changed room light needs no new native capture")
            await process_frame;await RenderingServer.frame_post_draw
            var dark=main.get_texture().get_image()
            var same_normal=preview.receiving.normal.get_texture().get_image()
            check(normal.get_data()==same_normal.get_data(),id+" receiving light does not alter source normal capture")
            check(max_alpha_difference(final_image,dark)==0.0,id+" light energy leaves final coverage unchanged")
            check(final_image.get_data()!=dark.get_data(),id+" actual final output responds to native light")
            cases.append({"id":id,"quarter":quarter,"source_covered_pixels":covered,"capture":name})
            preview.close();preview.free()
    main.free()
    var report={"passed":passed,"failed":failures.size(),"failures":failures,"cases":cases,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Selected native blood sources with controlled native2D lights and explicit flat support planes; original shader colour/coverage/normal/roughness, no donor light. Composition-normal/Canvas specular is an explicit receiving adaptation, not donor3D PBR equivalence."}
    var file=FileAccess.open("res://generated/native_effect_receiving_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    print(JSON.stringify(report));quit(1 if failures.size() else 0)
