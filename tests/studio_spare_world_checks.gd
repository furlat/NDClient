extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
## Reuse one hidden native host across different real authoritative prefixes.
const Recording=preload("res://studio/recording.gd")
const Play=preload("res://play.gd")
const ReplayPanes=preload("res://studio/replay_panes.gd")
var checks=0
var failures:Array=[]
var evidence:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("SPARE_WORLD_FAIL ",label)
func settle(world:Node)->bool:
    var deadline=Time.get_ticks_msec()+90000
    while not world.playback_prepared() and Time.get_ticks_msec()<deadline:await process_frame
    check(world.playback_prepared(),"Actual hidden host reaches full world/media readiness")
    return world.playback_prepared()
func settle_view(world:Node,target:int)->bool:
    var deadline=Time.get_ticks_msec()+90000
    while (world.rotation_pending() or not world.playback_prepared()) and Time.get_ticks_msec()<deadline:await process_frame
    var ready:bool=not world.rotation_pending() and world.quarter==target and world.world_quarter==target and world.playback_prepared()
    check(ready,"Reused source and camera publish the requested quarter together: "+str(target))
    return ready
func wall_sources(world:Node,label:String)->Dictionary:
    var sources:Dictionary={};var visible:int=0
    for entry in world.static_entries:
        if entry.placement.kind!="wall" or entry.source_role!=1:continue
        var row:Dictionary=entry.placement
        var expected:=Basis.IDENTITY
        if row.has("affine"):
            var a:=Vector2(row.affine[0],row.affine[1]);var b:=Vector2(row.affine[2],row.affine[3])
            if row.get("ground_projection",false):
                a=Play.Placement.project(Play.Placement.rotate_grid(Vector2(a.x/128.+a.y/64.,a.y/64.-a.x/128.),world.quarter),0,0)
                b=Play.Placement.project(Play.Placement.rotate_grid(Vector2(b.x/128.+b.y/64.,b.y/64.-b.x/128.),world.quarter),0,0)
            expected=Basis(Vector3(a.x,-a.y,0),Vector3(-b.x,b.y,0),Vector3(0,0,1))
        var actual:Basis=world.camera.global_basis.inverse()*entry.node.global_basis
        check(actual.is_equal_approx(expected),label+" actual wall retains its authored image plane in the published camera: "+entry.id)
        var selected:Dictionary=Play.Catalog.environment_role(Play.Catalog.environment(row,world.quarter,world.catalog_cache),entry.source_role)
        check(not selected.is_empty(),label+" wall has an actual selected source: "+entry.id)
        var registration:Dictionary={}
        for key in ["path","rect","native_size","pivot","scale"]:
            registration[key]=entry.record.get(key)
            check(entry.record.get(key)==selected.get(key),label+" wall source "+key+" belongs to the published quarter: "+entry.id)
        sources[entry.id]=registration
        if entry.node.is_visible_in_tree():visible+=1
    check(not sources.is_empty() and visible>0,label+" includes real visible wall sources")
    return sources
func capture_view(world:Node,view:SubViewport,name:String)->String:
    world.claim_receiving();world._publish_receiving()
    await process_frame;await RenderingServer.frame_post_draw
    var path:String="res://.captures/studio/spare-world/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var image:Image=view.get_texture().get_image()
    var background:Color=image.get_pixel(0,0)
    var scene_visible:bool=false
    for y in range(0,image.get_height(),8):
        for x in range(0,image.get_width(),8):
            if image.get_pixel(x,y)!=background:scene_visible=true;break
        if scene_visible:break
    check(scene_visible,"Wall capture contains the admitted scene rather than an empty camera: "+name)
    check(image.save_png(path)==OK,"Actual wall viewport capture is saved: "+name)
    return path
func reused_quarter(index:Dictionary,world:Node3D,view:SubViewport)->Dictionary:
    # Keep the original melee prefix checks. This independent, unchanged Gallery
    # prefix supplies actual walls for the camera/source reuse regression.
    index=Fixtures.read("gallery")
    check(index.ok,"Actual walled Gallery recording indexes for camera reuse")
    if not index.ok:return {}
    var walled:Dictionary=ReplayPanes.prepare(root,Recording.restore(index,0),index,world,{},0,true,true)
    if not await settle(walled.world):ReplayPanes.discard(walled);return {}
    world=walled.world;view=walled.viewport
    world.timeline.paused=true
    var wall_entries:Array=world.static_entries.filter(func(entry):return entry.placement.kind=="wall" and entry.source_role==1)
    check(not wall_entries.is_empty(),"Gallery supplies actual wall placements for camera framing")
    if wall_entries.is_empty():ReplayPanes.discard(walled);return {}
    var bounds:=AABB(Play.Placement.contact(wall_entries[0].placement),Vector3.ZERO)
    for entry in wall_entries:bounds=bounds.expand(Play.Placement.contact(entry.placement))
    world.camera_focus=bounds.get_center();world.camera.size=maxf(8.0,bounds.size.length()+4.0)
    world.initial_focus=true;world.position_camera()
    check(world.quarter==0 and world.world_quarter==0,"Regression starts with the genuinely published q0 spare")
    var before:String=await capture_view(world,view,"q0-before")
    var q0:Dictionary=wall_sources(world,"Original q0 spare")
    world.publishes_receiving=false
    var reference:Dictionary=ReplayPanes.prepare(root,Recording.restore(index,0),index,world,{},0,true,true)
    reference.world.timeline.paused=true
    if not await settle(reference.world):ReplayPanes.discard(reference);ReplayPanes.discard(walled);return {}
    reference.world.request_view(1)
    if not await settle_view(reference.world,1):ReplayPanes.discard(reference);ReplayPanes.discard(walled);return {}
    var fresh:Dictionary=wall_sources(reference.world,"Fresh q1 reference")
    var fresh_capture:String=await capture_view(reference.world,reference.viewport,"q1-fresh")
    var reference_timeline:RefCounted=reference.world.timeline
    var reference_state:PackedByteArray=var_to_bytes(reference_timeline.state)
    var restored:RefCounted=Recording.restore(index,0)
    var canonical:PackedByteArray=var_to_bytes(restored.state)
    var spare:Dictionary={"world":world,"viewport":view,"index":index,"frozen":[]}
    var candidate:Dictionary=ReplayPanes.prepare(root,restored,index,reference.world,spare,0,true,true)
    candidate.world.publishes_receiving=false
    check(candidate.reused and candidate.world==world,"Actual replay preparation reuses the old q0 spare")
    check(candidate.world.quarter==0 and candidate.world.world_quarter==0 and candidate.world.requested_quarter==1,
        "Requested q1 cannot relabel retained q0 camera/source membership before prepared publication")
    check(reference.world.timeline==reference_timeline and var_to_bytes(reference_timeline.state)==reference_state and reference.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,
        "Preparing another quarter retains the exact paused displayed reference and viewport")
    if not await settle_view(candidate.world,1):ReplayPanes.discard(reference);ReplayPanes.discard(walled);return {}
    var reused:Dictionary=wall_sources(candidate.world,"Reused q1 spare")
    check(reused==fresh,"Reused q1 walls select the same complete original source registrations as fresh q1")
    check(var_to_bytes(restored.state)==canonical and restored.state==Recording.restore(index,0).state,
        "Quarter publication leaves the exact restored canonical prefix unchanged")
    check(reference.world.timeline==reference_timeline and var_to_bytes(reference_timeline.state)==reference_state,
        "Candidate rotation never advances or replaces the displayed reference Timeline")
    reference.world.publishes_receiving=false;candidate.world.publishes_receiving=true
    var after:String=await capture_view(candidate.world,candidate.viewport,"q1-reused")
    check(candidate.world.presentation_errors.is_empty() and candidate.world.media_issue.is_empty(),"Quarter-reused host has no renderer/media errors")
    ReplayPanes.discard(reference)
    ReplayPanes.discard(candidate)
    return {"q0_wall_sources":q0.size(),"fresh_q1_wall_sources":fresh.size(),"reused_q1_wall_sources":reused.size(),
        "captures":{"q0_before":before,"q1_fresh":fresh_capture,"q1_reused":after},"canonical_unchanged":var_to_bytes(restored.state)==canonical}
func run()->void:
    var index=Fixtures.read("melee")
    check(index.ok,"Actual melee recording indexes")
    if not index.ok:finish();return
    var initial=Recording.restore(index,0)
    var terminal=Recording.restore(index,index.presentation_end_ms)
    check(initial.world_revision!=terminal.world_revision,"Real recording changes authoritative world state between the two loop prefixes")
    if DisplayServer.get_name()=="headless":finish();return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(640,480)
    var view=SubViewport.new();view.size=Vector2i(640,480);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    view.add_child(world);world.install_playback(terminal)
    if not await settle(world):view.queue_free();await process_frame;finish();return
    var table=world.light_table
    var textures=world.textures.duplicate();var prepared=world.world_prepared_count
    var old_epoch=world.timeline.initialization_revision
    view.audio_listener_enable_3d=true
    check(not world.try_reset_hidden_playback(initial) and world.timeline==terminal,"An audible displayed host is rejected without replacing its Timeline")
    view.audio_listener_enable_3d=false
    var measurements=[]
    for at in [0.0,index.presentation_end_ms,0.0]:
        var restored=Recording.restore(index,at)
        var started=Time.get_ticks_usec()
        var accepted=world.try_reset_hidden_playback(restored)
        var install_ms=(Time.get_ticks_usec()-started)/1000.0
        check(accepted,"Hidden spare accepts another real prefix")
        check(world.world_revision<0 and world.world_prepare_epoch<0 and not world.media_initial_ready and not world.component_renderer.ready,"Full reset cannot reuse stale geometry/media/component readiness")
        check(restored.world_changes.full and restored.world_changes_consumed==-1,"Different prefix keeps its initial dirty envelope for normal full preparation")
        check(world.frame_evidence.is_empty() and world.component_renderer.audio.voices.is_empty() and world.component_renderer.handles.is_empty() and world.component_renderer.blood.flights.is_empty(),"Old submitted frames, audio and native effect owners are absent before new preparation")
        var ready_started=Time.get_ticks_msec()
        if not await settle(world):break
        measurements.append({"at_ms":at,"install_ms":install_ms,"ready_ms":Time.get_ticks_msec()-ready_started,"world_revision":world.world_revision})
        check(world.light_table==table and world.publishes_receiving,"The same receiving light table survives full-prefix preparation")
        var shared=0
        for path in textures:
            if world.textures.get(path)==textures[path]:shared+=1
        check(shared>0,"Original immutable GPU source handles remain shared with the retained host")
        check(world.timeline==restored and world.timeline.state==Recording.restore(index,at).state,"Prepared hidden state equals the independently restored authoritative prefix")
        check(world.world_revision==restored.world_revision and world.world_prepare_epoch==restored.initialization_revision,"Published world proof belongs to the new prefix and epoch")
        check(not restored.world_changes.full and restored.world_changes_consumed==restored.world_revision,"Normal world preparation consumes the new initial envelope exactly once")
    check(world.world_prepared_count>=prepared+3 and world.timeline.initialization_revision==old_epoch+3,"Three reused-prefix installs each perform normal preparation with distinct epochs")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),"Repeated hidden-host preparation reports no renderer/media errors")
    evidence={"native":true,"prefixes":measurements,"retained_source_count":textures.size(),"new_world_preparations":world.world_prepared_count-prepared}
    evidence.reused_quarter=await reused_quarter(index,world,view)
    view.queue_free();await process_frame;await process_frame
    finish()
func finish()->void:
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Three actual initial/terminal prefix restores in one hidden native host, original light-table/source reuse, full world preparation, new epochs, no stale audio/native owners and audible-host rejection. Studio keeps the visible/spare publication boundary. Reusing a q0 spare after the reference publishes q1 preserves the original prefix while actual wall source registration and authored billboard planes publish together; original/fresh/reused viewport captures are saved."}
    var path="res://generated/studio_spare_world_native_checks.json" if evidence.get("native",false) else "res://generated/studio_spare_world_checks.json"
    FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_SPARE_WORLD ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
