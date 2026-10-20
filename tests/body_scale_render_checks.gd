extends "res://tests/native_vampiric_touch_render_checks.gd"
## Real original size lifecycles through the actual player renderer. Uniform
## model scale changes the whole outfit; no shader, sheet or optical pixels change.
const Conditions=preload("res://presentation/conditions.gd")
const RecordingMedia=preload("res://studio/recording_media.gd")
const Sockets=preload("res://presentation/spell_placement.gd")
const ShadowMath=preload("res://presentation/canvas_shadows.gd")
const Capture="res://.runtime/body-scale-captures"
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("BODY_SCALE_RENDER_FAIL ",label)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(Capture)
    var cases:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema16/body-scale/cases.json"))
    for case in cases.cases:
        for seat in case.perspectives:await lifecycle(case,seat)
    finish()

func advance_to(world:Node,at:float)->bool:
    var plan:Dictionary={}
    var publications:int=0;var retries:int=0;var last:Dictionary={}
    var deadline:int=Time.get_ticks_msec()+45000
    while world.timeline.display_ms<at-.000001 and Time.get_ticks_msec()<deadline:
        # Match Studio's parent request before the child Play process spends
        # the shared frame allowance, then observe the resulting native draw.
        await process_frame
        if plan.is_empty():plan=world.timeline.replay_plan(at)
        var prepared:bool=world.timeline.replay_prepare(plan)
        if prepared:
            if not world.can_publish_replay_advance(plan):
                world.timeline.replay_cancel_preparation();plan={};retries+=1
            else:
                if not world.publish_replay_advance(plan):
                    check(false,"Prepared BodyScale boundary rejects publication at "+str(at));return false
                plan={};publications+=1
        last={"at":at,"display_ms":world.timeline.display_ms,"prepared":prepared,
            "current":world.timeline.current.get("id",""),"waiting_for_media":world.timeline.waiting_for_media,
            "waiting_for_world":world.timeline.waiting_for_world,"errors":world.presentation_errors,"media":world.media_issue}
        await RenderingServer.frame_post_draw
    check(is_equal_approx(world.timeline.display_ms,at),"Actual ordered size boundaries reach "+str(at)+": "+str(last))
    evidence.append({"kind":"replay_publication","target_ms":at,"publications":publications,"retries":retries,"last":last})
    if not is_equal_approx(world.timeline.display_ms,at):return false
    return await settle(world)

func dimensions(world:Node,actor:String)->Dictionary:
    var visual:Dictionary=world.visual_actors[actor]
    var factor:float=visual.sampled_pose.body_scale.factor
    var source_nodes:Array=visual.entries.filter(func(entry):return entry.role!="shadow" and entry.node.is_visible_in_tree())
    var body:Dictionary=source_nodes.filter(func(entry):return entry.actor_layer.slot=="body")[0]
    var foot:Vector3=Play.Placement.contact(visual.row)
    # Pick a genuinely opaque texel rather than infer opacity at a body centre.
    var image:Image=world.source_images[body.texture_path]
    var uv:Vector4=Play.SourceMaterial.value(body,"frame_uv")
    var found:bool=false;var target:Vector2i=Vector2i.ZERO
    var cell:Vector2i=Vector2i(visual.row.get("cell_width",world.rigs[visual.row.rig].cell_width),world.rigs[visual.row.rig].cell_height)
    for y in cell.y:
        for x in cell.x:
            if image.get_pixel(int(uv.x*image.get_width())+x,int(uv.y*image.get_height())+y).a>.9:
                target=Vector2i(x,y);found=true;break
        if found:break
    check(found,"Actual displayed body frame contains an opaque picking witness")
    if found:
        var source_local:Vector3=Vector3(target.x+.5-body.pivot.x,body.pivot.y-target.y-.5,0)*float(body.scale)/Play.Placement.PIXELS_PER_UNIT
        var screen:Vector2=world.camera.unproject_position(body.node.global_transform*source_local)
        check(world._entry_contains(body,screen),"Actual opaque source texel is selectable through the scaled model")
    var operations:Array=visual.sampled_pose.body_scale.owners
    check(source_nodes.all(func(entry):return is_equal_approx(entry.node.global_basis.z.length(),factor)),"All actual outfit layers, including equipment, use one shared XYZ scale")
    check(source_nodes.all(func(entry):return entry.placement.scale==visual.row.scale and entry.scale==body.scale),"Scale does not mutate original source/mesh scale")
    var shadow:Array=ShadowMath._snapshots(source_nodes,world.camera)
    check(not shadow.is_empty() and shadow.all(func(value):return value.model.is_equal_approx(Basis.from_scale(Vector3.ONE*factor))),"Actual shadow inputs consume the same displayed model scale")
    var native_shadows:Dictionary=world.generated_shadows.actors.get(actor,{})
    check(not native_shadows.is_empty() and native_shadows.get("shown",false),"Actual resized actor owns a current visible native shadow helper")
    if not native_shadows.is_empty() and native_shadows.get("shown",false):
        for snapshot in native_shadows.snapshots:
            var caster:MeshInstance3D=native_shadows.casters[snapshot.id]
            var shape:Dictionary=snapshot.caster_shape
            check(caster.custom_aabb==shape.local_bounds and shape.local_points.size()==8,"Actual native caster owns unscaled local bounds for all eight source corners")
            var world_bounds:AABB=caster.transform*caster.custom_aabb
            for i in shape.local_points.size():
                var point:Vector3=caster.transform*shape.local_points[i]
                var expected:Vector3=shape.points[i]+snapshot.position-native_shadows.geometry[0]
                check(caster.custom_aabb.has_point(shape.local_points[i]) and world_bounds.has_point(point) and point.is_equal_approx(expected),"Actual caster culling contains source corner "+str(i)+" after exactly one support-pivot model transform")
    var socket:Dictionary=Sockets.pose_point(world,visual.row,"body_center")
    check(socket.ready and socket.point.is_finite(),"Existing actual body socket resolves on the resized outfit")
    return {"factor":factor,"owners":operations.duplicate(true),"body":body,"source_count":source_nodes.size(),"source_units":Play.SourceMaterial.value(body,"component_units"),
        "contact":foot,"socket":socket.point,"sources":source_nodes.map(func(entry):return [entry.texture_path,entry.node.mesh.get_instance_id(),Play.SourceMaterial.value(entry,"component_units")])}

func compare_neutral(world:Node,view:SubViewport,owner:Dictionary,label:String)->void:
    world.set_process(false);await frame();await frame()
    var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
    var before:Image=view.get_texture().get_image()
    var entries:Array=world.visual_actors[owner.actor_uuid].entries.filter(func(entry):return entry.node.is_visible_in_tree())
    var models:Array=entries.map(func(entry):return entry.node.transform)
    var factor:float=world.visual_actors[owner.actor_uuid].sampled_pose.body_scale.factor
    var contact:Vector3=Play.Placement.contact(world.visual_actors[owner.actor_uuid].row)
    for entry in entries:
        entry.node.basis=entry.node.basis.scaled_local(Vector3.ONE/factor)
        entry.node.position=contact+(entry.node.position-contact)/factor
    await frame();await frame()
    var plain:Image=view.get_texture().get_image()
    var pixels:int=changed(before,plain)
    check(pixels>0,label+" actual uniform size changes the rendered body pixels")
    for i in entries.size():entries[i].node.transform=models[i]
    await frame();await frame()
    check(changed(before,view.get_texture().get_image())==0,label+" restoring the exact sampled models restores the framebuffer")
    check(var_to_bytes(world.timeline.state)==canonical,label+" optical control never changes canonical occupancy/state")
    before.save_png(Capture.path_join(label+"-scaled.png"));plain.save_png(Capture.path_join(label+"-neutral-control.png"))
    evidence.append({"label":label,"condition_uuid":owner.id,"factor":factor,"changed_pixels":pixels})
    world.set_process(true)

func lifecycle(case:Dictionary,seat:Dictionary)->void:
    var label:String=case.id.get_file().trim_suffix("_lifecycle")+"-"+seat.id
    var factor:float=.75 if case.id.ends_with("reduce_lifecycle") else 1.175
    var index:Dictionary=Recording.read(seat.journal)
    check(index.ok,label+" original unchanged recording compiles")
    if not index.ok:return
    var lives:Array=index.rows.filter(func(row):return row.kind=="condition" and row.owner.condition.behavior_id=="condition.spell.enlarge_reduce")
    check(lives.size()==1,label+" one actual size UUID owns application/removal")
    if lives.size()!=1:return
    # Studio prepares every crossed group's original immutable closure. This
    # admits sources, never their future canonical state or presentation clock.
    var media:Dictionary=RecordingMedia.plan(index)
    check(media.errors.is_empty(),label+" actual recording has complete immutable media closures")
    if not media.errors.is_empty():return
    Play.Catalog.adopt_snapshot(index.cache,media.source_files)
    var owner:Dictionary=lives[0].owner
    var held:float=minf(float(owner.end_ms)-1.0,float(owner.start_ms)+500.0)
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.media_warmup.encounter_override=media
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows)
    world.native_startup_requested_ms=maxf(0,owner.start_ms-1.0)
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    world.install_playback(Recording.restore(index,maxf(0,owner.start_ms-1.0)))
    if not await settle(world):view.queue_free();await frame();return
    if not await advance_to(world,held):view.queue_free();await frame();return
    var actor:String=owner.actor_uuid
    check(is_equal_approx(world.visual_actors[actor].sampled_pose.body_scale.factor,factor),label+" actual membership changes the current displayed scale")
    world.camera_focus=Play.Placement.contact(world.visual_actors[actor].row);world.camera.size=4.0;world.initial_focus=true;world.position_camera();world.grid_visible=false
    for quarter in 4:
        if quarter!=world.quarter:world.request_view(quarter)
        var deadline:int=Time.get_ticks_msec()+45000
        while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
        check(world.quarter==quarter and world.world_quarter==quarter and not world.rotation_pending(),label+" actual prepared camera quarter publishes: "+str(quarter))
        if world.quarter!=quarter or world.rotation_pending():break
        if not await settle(world):break
        var measured:Dictionary=dimensions(world,actor)
        check(measured.owners.any(func(value):return value.condition_uuid==owner.id and is_equal_approx(value.factor,factor)),label+" actual view selects the original owner/factor")
        var trace:String="condition:"+owner.id+":bodyScale"
        check(world.component_renderer.pending_evidence.any(func(value):return value.trace_track_id==trace and value.visible),label+" exact selected UUID receives its actual body-scale draw witness")
        await compare_neutral(world,view,owner,label+"-q"+str(quarter))
    if await advance_to(world,index.presentation_end_ms):
        check(world.visual_actors[actor].sampled_pose.body_scale=={"factor":1.0,"owners":[]},label+" actual concentration removal restores neutral outfit")
        check(world.timeline.state.actors[actor].conditions.all(func(member):return member.condition_uuid!=owner.id),label+" original owner is actually removed, not hidden by a test")
    for at in [held,index.presentation_end_ms,held]:
        world.install_playback(Recording.restore(index,at))
        if not await settle(world):break
        var expected:float=factor if at==held else 1.0
        check(is_equal_approx(world.visual_actors[actor].sampled_pose.body_scale.factor,expected),label+" ordinary seek/loop restores the actual condition prefix")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+" lifecycle/view/seek introduces no presentation errors")
    view.queue_free();await frame();await frame()
func finish()->void:
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual both-seat Enlarge/Reduce application/removal through ordinary preparation/publication, whole outfit model/optical inputs, true pixel picking, four native cameras, selected UUID witnesses and seek/loop. No lighting/source retune or backend occupancy change."}
    FileAccess.open("res://generated/body_scale_render_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("BODY_SCALE_RENDER ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
