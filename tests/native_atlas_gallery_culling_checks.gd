extends SceneTree
## Discarded candidate benchmark (not production optimization).
## Actual Gallery inputs; normal Play owns state, source clocks and camera.
## Timed work is only alternating exhaustive/indexed culling, with no readbacks.
const Recording=preload("res://studio/recording.gd")
const Media=preload("res://studio/recording_media.gd")
const Play=preload("res://play.gd")
const Profile=preload("res://frame_profile.gd")
const Candidate=preload("res://tests/native_atlas_culling_candidate.gd")
var candidate=Candidate.new()
var world:Node3D
var frames:Array=[]
var failures:Array=[]
var caster:String
var checks:int=0
func _initialize()->void:run.call_deferred()
func ready()->bool:return not world.rotation_pending() and world.playback_prepared()
func healthy()->bool:return world.media_issue.is_empty() and world.presentation_errors.is_empty()
func follow()->void:
    var actor:Dictionary=world.visual_actors.get(caster,{})
    for entry in actor.get("entries",[]):
        if entry.role!="shadow" and entry.node.visible:
            var position:Vector3=Play.Placement.contact(actor.row)
            if world.camera_focus!=position:world.camera_focus=position;world.position_camera()
            return
func exhaustive(atlas,screen:Rect2)->int:
    var live:int=0
    for row in atlas.static_receivers:
        var shown:bool=row.entry.node.is_visible_in_tree() and (atlas.plane_to_screen*row.bounds).intersects(screen)
        if row.node.visible!=shown:row.node.visible=shown
        row.view_visible=shown
        if shown:live+=1
    return live
func indexed(atlas,screen:Rect2)->int:
    var live:int=0
    for row in atlas._cull_candidates(screen).values():
        if atlas._visibility(row,screen):live+=1
    return live
func run()->void:
    if DisplayServer.get_name()=="headless":quit(2);return
    Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    root.size=Vector2i(1600,960);root.position=Vector2i(40,40);root.unfocusable=true
    var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/studio_gallery_spell_case.json"));caster=spec.caster_uuid
    var bundle=Recording.compare_case(Recording.read_case(spec));bundle=bundle.duplicate();bundle.comparison=false
    var index=Recording.view_index(bundle,"amber");index.media_preload=Media.plan(index);index.cache.merge(index.media_preload.source_files,false)
    world=Play.new();world.external_playback=true;world.catalog_cache=Play.Catalog.source_snapshot(index.cache)
    world.media_warmup.encounter_override=index.media_preload;root.add_child(world)
    world.camera.size=12;world.position_camera();world.playback_end_ms=4000
    world.install_playback(Recording.restore(index,0))
    var deadline:int=Time.get_ticks_msec()+120000
    while not ready() and healthy() and Time.get_ticks_msec()<deadline:await process_frame
    if not ready() or not healthy():failures.append("Initial preparation failed");await finish();return
    world.timeline.paused=false;deadline=Time.get_ticks_msec()+30000
    while world.timeline.display_ms<3999 and healthy() and Time.get_ticks_msec()<deadline:
        await process_frame;follow();await RenderingServer.frame_post_draw
        var atlas=candidate
        atlas.static_receivers=world.native_light_atlas.static_receivers
        atlas.plane_to_screen=world.native_light_atlas.plane_to_screen
        var index_started:int=Time.get_ticks_usec()
        atlas._cull_rebuild()
        var index_ms:float=(Time.get_ticks_usec()-index_started)/1000.0
        var screen=Rect2(Vector2.ZERO,root.get_visible_rect().size)
        var record={"display_ms":world.timeline.display_ms,"static":atlas.static_receivers.size(),"candidates":atlas._cull_candidates(screen).size(),"live":world.native_light_atlas.static_live_receivers,"index_ms":index_ms,"half_extent":[atlas.cull_half_extent.x,atlas.cull_half_extent.y]}
        # Check the real production result BEFORE either timing control writes.
        for row in atlas.static_receivers:
            var expected:bool=row.entry.node.is_visible_in_tree() and (atlas.plane_to_screen*row.bounds).intersects(screen)
            checks+=1
            if row.node.visible!=expected and failures.size()<8:failures.append("Production visibility differs at "+str(world.timeline.display_ms)+" "+row.id)
        for method in (["exhaustive","indexed"] if frames.size()%2==0 else ["indexed","exhaustive"]):
            var started:int=Time.get_ticks_usec()
            var count:int=exhaustive(atlas,screen) if method=="exhaustive" else indexed(atlas,screen)
            record[method]=(Time.get_ticks_usec()-started)/1000.0;record[method+"_live"]=count
        if record.exhaustive_live!=record.indexed_live:failures.append("Live counts differ")
        frames.append(record)
    world.timeline.paused=true
    if world.timeline.display_ms<3999:failures.append("Bounded interval did not complete")
    await finish()
func finish()->void:
    failures.append_array(world.presentation_errors)
    if not world.media_issue.is_empty():failures.append(world.media_issue)
    var report={"production_enabled":false,"checks":checks,"failures":failures,"frames":frames,"exhaustive_ms":Profile.distribution(frames.map(func(r):return r.exhaustive)),"indexed_ms":Profile.distribution(frames.map(func(r):return r.indexed)),"static_counts":Profile.distribution(frames.map(func(r):return r.static)),"candidate_counts":Profile.distribution(frames.map(func(r):return r.candidates)),"index_update_ms":Profile.distribution(frames.map(func(r):return r.index_ms)),"scope":"Actual Gallery ordinary Play0–4s at1600x960/view12 with actor follow and normal source/event clocks. Discarded index rebuilt outside the alternating CPU query timings; production retains original exhaustive visibility. No timed image readbacks. Separate existing native atlas tests qualify pixels."}
    FileAccess.open("res://.runtime/native-atlas-gallery-culling-discarded-recheck.json",FileAccess.WRITE).store_string(JSON.stringify(report))
    print("ATLAS_GALLERY_CULLING ",JSON.stringify(report.duplicate().merged({"frames":frames.size()},true)))
    world.queue_free();await process_frame;await RenderingServer.frame_post_draw;await process_frame
    quit(0 if failures.is_empty() else 1)
