extends SceneTree
# Actual admitted modular outfit + original terrain; named renderer after-values
# reproduce lower-floor occlusion. This does not claim a backend move was sent.
const Player = preload("res://play.tscn")
var checks := 0
var failures: Array = []
var evidence: Array = []
func check(ok: bool,label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("SCENERY_RENDER_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func capture() -> Image:
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func changed(a: Color,b: Color) -> bool:
    return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.012
func source_alpha(scene:Node,entry:Dictionary,screen:Vector2)->float:
    var transform:Transform3D=entry.node.global_transform
    var normal=transform.basis.z.normalized()
    var point:Variant=Plane(normal,normal.dot(transform.origin)).intersects_ray(scene.camera.project_ray_origin(screen),scene.camera.project_ray_normal(screen))
    if point==null:return 0.0
    var local:Vector3=transform.affine_inverse()*point
    var mesh:QuadMesh=entry.node.mesh
    var uv=Vector2((local.x-mesh.center_offset.x)/mesh.size.x+.5,.5-(local.y-mesh.center_offset.y)/mesh.size.y)
    if uv.x<0 or uv.y<0 or uv.x>=1 or uv.y>=1:return 0.0
    var rect:Array=entry.record.get("rect",[0,0,entry.cell.x,entry.cell.y])
    return scene.source_images[entry.record.path].get_pixelv(Vector2i(rect[0]+uv.x*entry.cell.x,rect[1]+uv.y*entry.cell.y)).a
func prepare(scene: Node) -> void:
    scene.timeline.current={};scene.timeline.queue=[]
    scene.timeline.revision+=1;scene.timeline.world_revision+=1
    scene._prepare_media()
    var deadline=Time.get_ticks_msec()+60000
    while (not scene._environment_media_ready() or not scene.MediaWarmup.ready(scene.media_warmup,scene.media_plan.required)) and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        scene._warm_media();scene._prepare_media();await process_frame
    check(scene.media_issue.is_empty() and scene._environment_media_ready(),"Exact original fixture art is asynchronously ready")
    scene._sync_world();scene.world_revision=scene.timeline.world_revision
    scene.displayed_samples={};scene._sync_actors();scene._sample_actors()
    scene._sync_scenery(true);scene.update_wall_visibility();scene._sort_draws()
func run() -> void:
    if DisplayServer.get_name()=="headless": print("SCENERY_RENDER_CHECKS requires native graphics");quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(480,400)
    var scene=Player.instantiate();scene.timeline.paused=true;root.add_child(scene)
    var deadline=Time.get_ticks_msec()+60000
    while (not scene.session.recording_ready or not scene._environment_media_ready() or not scene.MediaWarmup.ready(scene.media_warmup,scene.media_plan.required)) and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    await scene.presentation_updated
    scene.session.close();scene.set_process(false);scene.hud.hide()
    check(not scene.timeline.state.is_empty() and scene.session.issue.is_empty(),"Admitted real Crypt initial snapshot and original outfit load")
    if scene.timeline.state.is_empty():scene.queue_free();quit(1);return
    var canonical:Dictionary=scene.timeline.state.duplicate(true)
    var actor_id:String=scene.timeline.state.audience.controlled[0]
    var actor:Dictionary=scene.timeline.state.actors[actor_id].duplicate(true)
    actor.last_visual_position=[0,0]
    var first:Dictionary=scene.timeline.state.tiles.values()[0].duplicate(true)
    var floor=first.duplicate(true);floor.tile_uuid="fixture-upper";floor.elevation_steps=0
    var support=first.duplicate(true);support.tile_uuid="fixture-lower";support.position=[0,0];support.elevation_steps=-1
    scene.timeline.state.actors={actor_id:actor};scene.timeline.state.objects={}
    scene.timeline.state.senses.entities={};scene.timeline.state.senses.objects={}
    scene.camera_focus=Vector3(0,-.3,0);scene.camera.size=3.1
    for child in scene.get_children():
        if child is WorldEnvironment:
            child.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
            child.environment.ambient_light_color=Color.WHITE;child.environment.ambient_light_energy=1
    for quarter in range(4):
        var point:Vector2=scene.Placement.rotate_grid(Vector2(1,1),posmod(4-quarter,4))
        floor.position=[point.x,point.y]
        scene.timeline.state.tiles={"0,0":support,scene.WorldRows.cell_key(floor.position):floor}
        scene.timeline.state.senses.visible=[[0,0],floor.position]
        scene.quarter=quarter;scene.position_camera()
        await prepare(scene)
        check(scene.ground_groups.is_empty(),"q%d below-zero support disables only unsafe background batches"%quarter)
        var bodies:Array=scene.actor_entries.filter(func(entry):return entry.node.visible and entry.role!="shadow")
        var upper:Dictionary={}
        for entry in scene.static_entries:
            if entry.placement.id==floor.tile_uuid and entry.role=="terrain":upper=entry
        check(not upper.is_empty() and not bodies.is_empty(),"q%d original floor and modular body are present"%quarter)
        if upper.is_empty() or bodies.is_empty():continue
        for entry in scene.actor_entries:
            if entry.role=="shadow":entry.node.visible=false
        for entry in scene.static_entries:
            if entry!=upper:entry.node.visible=false
        scene.static_order_dirty=true;scene.draw_order_dirty=true;scene._sort_draws()
        var both=await capture()
        for entry in bodies:entry.node.visible=false
        var floor_only=await capture()
        upper.node.visible=false
        var blank=await capture()
        for entry in bodies:entry.node.visible=true
        var actor_only=await capture()
        upper.node.visible=true
        var overlap=0;var wrong=0;var pick_wrong=0;var exposed=0
        for y in range(both.get_height()):
            for x in range(both.get_width()):
                var at=Vector2i(x,y)
                var a=changed(actor_only.get_pixelv(at),blank.get_pixelv(at))
                var f=changed(floor_only.get_pixelv(at),blank.get_pixelv(at))
                if a and not f:exposed+=1
                if not(a and f):continue
                overlap+=1
                var alpha=source_alpha(scene,upper,Vector2(x+.5,y+.5))
                # Authored edge pixels are genuinely translucent (63/255 and
                # 194/255 in this source). Compatibility blends these output
                # colour values directly; preserve their source-over remainder.
                var expected=floor_only.get_pixelv(at)
                if alpha<.999:
                    expected=expected+(actor_only.get_pixelv(at)-blank.get_pixelv(at))*(1-alpha)
                if changed(both.get_pixelv(at),expected):wrong+=1
                if overlap%11==0 and scene.pick_world(Vector2(x+.5,y+.5)).get("kind")!="ground":pick_wrong+=1
        check(overlap>5 and exposed>5,"q%d native original sprite pixels actually overlap and remain partly exposed"%quarter)
        check(wrong==0,"q%d floor owns overlapping lower-actor pixels (%d wrong)"%[quarter,wrong])
        check(pick_wrong==0,"q%d floor owns picking over the lower actor (%d wrong)"%[quarter,pick_wrong])
        evidence.append({"quarter":quarter,"overlap_pixels":overlap,"wrong_pixels":wrong,"wrong_picks":pick_wrong})
        if quarter==0:
            DirAccess.make_dir_recursive_absolute("res://.captures/scenery")
            both.save_png("res://.captures/scenery/below-floor.png")
            var identities=scene.static_entries.map(func(entry):return entry.node.get_instance_id())
            scene.timeline.state.senses.visible=[[0,0]];scene.timeline.revision+=1;scene.timeline.world_revision+=1
            scene._sync_scenery();var remembered=await capture()
            check(changed(remembered.get_pixelv(Vector2i(240,230)),both.get_pixelv(Vector2i(240,230))) or remembered.get_data()!=both.get_data(),"Remembered scenery changes visible pixels")
            check(scene.static_entries.map(func(entry):return entry.node.get_instance_id())==identities,"Sight-only styling preserves native node identity")
            check(upper.material.get_shader_parameter("current_visibility")==0.0,"Lost sight selects remembered floor material without changing alpha")
            remembered.save_png("res://.captures/scenery/remembered-floor.png")
        support=support.duplicate(true);support.elevation_steps=0;scene.timeline.state.tiles={"0,0":support};scene.timeline.state.senses.visible=[[0,0]]
        await prepare(scene)
        check(not scene.ground_groups.is_empty(),"q%d removing lower support restores batching"%quarter)
        support=support.duplicate(true);support.elevation_steps=-1
    scene.timeline.state=canonical
    var report={"checks":checks,"failures":failures,"cases":evidence,"scope":"Native original modular/floor pixels plus actual production picking at four views; typed negative-height and visibility after-values on an admitted real snapshot."}
    var file=FileAccess.open("res://generated/scenery_render_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    print("SCENERY_RENDER_CHECKS ",JSON.stringify(report));scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
