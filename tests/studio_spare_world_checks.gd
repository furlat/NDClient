extends SceneTree
## Reuse one hidden native host across different real authoritative prefixes.
const Recording=preload("res://studio/recording.gd")
const Play=preload("res://play.gd")
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
func run()->void:
    var index=Recording.read("res://.runtime/studio-cases/melee-seed3/amber/journal")
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
    view.queue_free();await process_frame;await process_frame
    finish()
func finish()->void:
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Three actual initial/terminal prefix restores in one hidden native host, original light-table/source reuse, full world preparation, new epochs, no stale audio/native owners and audible-host rejection. Studio keeps the visible/spare publication boundary."}
    var path="res://generated/studio_spare_world_native_checks.json" if evidence.get("native",false) else "res://generated/studio_spare_world_checks.json"
    FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_SPARE_WORLD ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
