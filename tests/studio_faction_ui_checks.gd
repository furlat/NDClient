extends SceneTree
const Studio=preload("res://studio/studio.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
var invisibility_case=false
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_FACTION_UI_FAIL ",label)
func ready(studio:Control)->bool:
    var until=Time.get_ticks_msec()+150000
    while (studio.index.is_empty() or studio.loader!=null or studio.seeker!=null or studio.installing or studio.requested_seek>=0) and Time.get_ticks_msec()<until:await process_frame
    var ok=not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0
    check(ok,"Atomic faction scene becomes ready: "+studio.status.text)
    return ok
func capture(studio:Control,label:String)->void:
    var cache=studio.tracks.thumbnails
    var until=Time.get_ticks_msec()+30000
    await process_frame
    while (cache.worker!=null or not cache.pending.is_empty() or not cache.active.is_empty()) and Time.get_ticks_msec()<until:await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.captures/studio/browser/"+label+".png")
    evidence.append({"capture":label,"perspective":studio.active_perspective,"time_ms":studio.world.timeline.display_ms,"window":root.size,"preview":studio.preview.size,"timeline":studio.tracks.size,"shown_rows":studio.tracks.rows.size(),"all_rows":studio.index.rows.size(),"source_errors":cache.errors.duplicate()})
    check(cache.errors.is_empty(),"Visible source thumbnails have no hidden source error: "+label)
func run()->void:
    var explicit_recording=false
    for arg in OS.get_cmdline_user_args():explicit_recording=explicit_recording or arg.begins_with("--recording=")
    if not explicit_recording:print("Usage: --recording=<actual Hide amber journal>");quit(2);return
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/browser")
    DisplayServer.window_set_size(Vector2i(1280,720))
    var studio=Studio.new();root.add_child(studio)
    if not await ready(studio):await finish(studio);return
    invisibility_case=studio.active_case.get("id","").begins_with("invisibility")
    if invisibility_case:
        await invisibility(studio);await finish(studio);return
    check(studio.case_bundle.views.size()==2,"Actual case opens both independent recorded factions")
    check(studio.active_perspective=="amber" and studio.perspective_picker.item_count==2 and not studio.perspective_picker.disabled,"Faction selector identifies the displayed amber scene")
    check(studio.capability_picker.get_item_text(studio.capability_picker.selected)=="Basic actions" and studio.interaction_picker.get_item_text(studio.interaction_picker.selected)=="Hide","Browser opens at capability / interaction / case")
    check(studio.index.rows.any(func(row):return row.kind=="perspective"),"Different faction perceptions have explicit subtracks under their same occurrence")
    check(studio.tracks.rows.all(func(item):return item.row.kind!="event" or item.row.event.kind!="undisclosed"),"Default timeline has no undisclosed event placeholders")
    check(studio.tracks.rows.all(func(item):return item.row.kind!="other_view" or (item.row.end_ms>item.row.start_ms and item.row.get("timing_status")!="other_perspective")),"Default timeline has no zero-length or unmapped other-faction placeholders")
    var original_labels={}
    for indexed in studio.index.rows:
        original_labels[indexed.id]=indexed.label
        var title=Studio.TimelineView._label(indexed)
        check(not "_" in title,"Display label has no raw underscore identifier: "+indexed.label)
        if indexed.kind!="event" and indexed.get("status")=="missing":
            check(not title.begins_with("Missing"),"Missing status is not duplicated in the requirement label")
    check(studio.index.rows.all(func(indexed):return indexed.label==original_labels[indexed.id]),"Human labels never rewrite indexed authored names")
    await capture(studio,"1280-amber")
    var hidden=studio.index.rows.filter(func(row):return row.kind=="condition" and row.label=="Hidden")
    check(not hidden.is_empty(),"Actual recorded hidden condition is inspectable in its owner's faction")
    if hidden.is_empty():await finish(studio);return
    var row:Dictionary=hidden[0]
    studio.selected_row=row;studio.tracks.reveal(row.id)
    studio._seek(row.start_ms+minf(30,maxf(0,row.end_ms-row.start_ms)/2))
    await pending_speed(studio)
    if not await ready(studio):await finish(studio);return
    check(studio.world.playback_speed==2.0 and studio.rate_picker.selected==3,"Loading candidate publishes the current selected playback rate")
    check(studio.world.timeline.paused,"Candidate speed change leaves paused source time unchanged")
    studio.selected_row=row
    var expected=Studio.Recording.view_index(studio.case_bundle,"blue")
    var anchor=Studio.Recording.navigation_anchor(studio.index,studio.world.timeline.display_ms,row)
    var aligned=Studio.Recording.anchor_time(expected,anchor)
    var old_world=studio.world;var old_index=studio.index;var old_clock=old_world.timeline.display_ms
    studio.world.camera.size=8.0;studio.world.position_camera()
    studio.select_perspective("blue")
    check(studio.world==old_world and is_same(studio.index,old_index) and studio.active_perspective=="amber" and studio.world.timeline.display_ms==old_clock,"Faction request retains displayed owner/index/clock/label until complete")
    if not await ready(studio):await finish(studio);return
    check(studio.active_perspective=="blue" and studio.world!=old_world and is_equal_approx(studio.world.timeline.display_ms,aligned),"Independent blue state and event-aligned clock publish together")
    check(studio.world.timeline.paused and studio.world.camera.size==8.0,"Faction switching retains paused mode and user camera")
    var restored=Studio.Recording.restore(studio.case_bundle.views.blue,aligned)
    check(studio.world.timeline.state==restored.state,"Displayed blue canonical state equals only the blue journal restore")
    var foreign=studio.index.rows.filter(func(item):return item.kind=="other_view" and item.get("source_kind")=="condition" and item.label.begins_with("Hidden"))
    check(not foreign.is_empty(),"Undisclosed Hidden lifetime remains an explicit other-faction inspection row")
    if not foreign.is_empty():
        studio.tracks.reveal(foreign[0].id);studio.selected_row=foreign[0]
        check(not studio.tracks.rows.any(func(item):return item.row.id==foreign[0].id),"Blue timeline shows nothing for an unseen foreign Hidden presentation")
        check(studio.tracks.rows.all(func(item):return item.row.kind!="perspective" or item.row.get("disclosed",false)),"No undisclosed faction heading occupies the timeline")
        await capture(studio,"1280-blue-hidden")
        var key=studio.tracks.thumbnails.request(foreign[0],studio.world.timeline.display_ms,0)
        check(key.is_empty(),"Foreign component does not render invented local faction imagery")
        var return_time=old_clock
        studio.select_perspective("amber")
        if await ready(studio):
            check(studio.active_perspective=="amber" and is_equal_approx(studio.world.timeline.display_ms,return_time),"Unseen zero-duration faction phase returns to the exact original owner clock")
            check(studio.selected_row.get("id")==foreign[0].source_row_id,"View action selects original source row, retaining causal owner")
    DisplayServer.window_set_size(Vector2i(1920,1080));await process_frame;await process_frame
    studio.tracks.fit();await capture(studio,"1920-amber-selected")
    check(is_equal_approx(studio.tracks._x(studio.index.presentation_end_ms),studio.tracks.size.x-24),"Short recording uses final 1920 timeline width")
    DisplayServer.window_set_size(Vector2i(960,640));await process_frame;await process_frame
    check(studio.size.x<=960 and studio.preview.size.x<=960 and studio.tracks.size.x<=960 and studio.perspective_picker.get_global_rect().end.x<=960 and studio.clock_label.get_global_rect().end.x<=960,"Compact browser and transport stay inside 960-pixel viewport")
    await capture(studio,"960-amber-selected")
    studio._show_source_inventory()
    var audit_until=Time.get_ticks_msec()+60000
    while not studio.source_inventory.is_prepared() and Time.get_ticks_msec()<audit_until:await process_frame
    check(studio.source_inventory.is_prepared(),"Authored requirements finish asynchronous preparation")
    check(studio.source_inventory.report.get("condition_recipes")==160,"On-demand browser includes every authored condition recipe, not only recorded cases")
    studio.source_inventory.bucket.select(0);studio.source_inventory.bucket.item_selected.emit(0)
    studio.source_inventory.filter.text="application_asset_id";studio.source_inventory.filter.text_changed.emit("application_asset_id")
    while not studio.source_inventory.is_prepared() and Time.get_ticks_msec()<audit_until:await process_frame
    check(studio.source_inventory.tree.get_root().get_child_count()>0,"Exact authored lifecycle source pointers remain searchable")
    studio.source_inventory.hide()
    check(studio.world.presentation_errors.is_empty(),"Displayed production source has no presentation errors")
    await finish(studio)
func pending_speed(studio:Control)->void:
    var until=Time.get_ticks_msec()+30000
    while studio.candidate_world==null and (studio.seeker!=null or studio.requested_seek>=0) and Time.get_ticks_msec()<until:await process_frame
    check(studio.candidate_world!=null,"Real prepared scene is still pending when playback speed changes")
    if studio.candidate_world==null:return
    check(studio.candidate_world.playback_speed==studio.world.playback_speed,"Candidate initially copies current playback rate")
    studio.rate_picker.select(3);studio.rate_picker.item_selected.emit(3)
    check(studio.world.playback_speed==2.0 and studio.candidate_world.playback_speed!=2.0,"Actual speed selector changes the displayed host while candidate retains its prior value")

func invisibility(studio:Control)->void:
    check(studio.case_bundle.views.size()==2,"Actual Invisibility case has both recorded factions")
    check(studio.capability_picker.get_item_text(studio.capability_picker.selected)=="Conditions" and studio.interaction_picker.get_item_text(studio.interaction_picker.selected)=="Perception","Invisibility is organized as Conditions / Perception")
    var invisible=studio.index.rows.filter(func(row):return row.kind=="condition" and row.owner.condition.behavior_id=="condition.spell.invisibility")
    check(not invisible.is_empty(),"Real recording contains an applied and removed Invisible lifetime")
    if invisible.is_empty():return
    var actor_id:String=invisible[0].owner.actor_uuid
    var movement=studio.index.rows.filter(func(row):return row.kind=="body" and row.track.actor_uuid==actor_id and row.track.get("activity")=="move")
    check(movement.size()==2,"Actual capture has unseen movement and detected movement before concentration ends")
    if movement.size()!=2:return
    for n in movement.size():
        if studio.active_perspective!="amber":
            studio.select_perspective("amber")
            if not await ready(studio):return
        var source_row:Dictionary=movement[n]
        var at=(source_row.start_ms+source_row.end_ms)*.5
        studio.selected_row=source_row;studio.tracks.reveal(source_row.id);studio._seek(at)
        if n==0:await pending_speed(studio)
        if not await ready(studio):return
        check(studio.world.playback_speed==2.0,"Changed loading-candidate rate remains selected after publication")
        check(studio.world.timeline.paused and is_equal_approx(studio.world.timeline.display_ms,at),"Rate change never advances a paused seek clock")
        check(studio.world.visual_actors.has(actor_id),"Actor's own faction renders its Invisible movement")
        studio.selected_row=source_row
        var original_time=studio.world.timeline.display_ms
        studio.select_perspective("blue")
        if not await ready(studio):return
        var canonical=Studio.Recording.restore(studio.case_bundle.views.blue,studio.world.timeline.display_ms)
        check(studio.world.timeline.state==canonical.state,"Blue display follows only its own immutable SDK prefix")
        if n==0:
            check(not studio.world.visual_actors.has(actor_id),"Unseen Invisible movement has no Blue actor render owner")
            var foreign=studio.index.rows.filter(func(row):return row.kind=="other_view" and row.get("source_row_id")==source_row.id)
            check(not foreign.is_empty(),"Unseen movement remains inspectable in the original faction branch")
            if not foreign.is_empty():studio.selected_row=foreign[0];studio.tracks.reveal(foreign[0].id)
        else:
            check(studio.world.timeline.state.actors.values().any(func(actor):return actor.get("conditions",[]).any(func(condition):return condition.behavior_id=="condition.spell.see_invisibility")),"Detected movement occurs while Blue's actual See Invisibility is active")
            check(studio.world.timeline.state.actors.get(actor_id,{}).get("conditions",[]).any(func(condition):return condition.behavior_id=="condition.spell.invisibility"),"Detected target remains Invisible; visibility is not concentration expiry")
            check(studio.world.visual_actors.has(actor_id) and studio.world.visual_actors[actor_id].entries.any(func(entry):return entry.node.visible),"See Invisibility admits actual visible native actor entries")
        await capture(studio,"invisibility-blue-"+("unseen" if n==0 else "detected"))
        studio.select_perspective("amber")
        if not await ready(studio):return
        check(is_equal_approx(studio.world.timeline.display_ms,original_time),"Perception switch preserves the same movement source phase in both directions")
    check(studio.world.presentation_errors.is_empty(),"Invisibility case native presentation reports no unexpected runtime errors")

func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Native compact browser, independent faction state/event-phase publication, foreign-owner selection and original source thumbnails. No combined omniscient state."}
    FileAccess.open("res://generated/studio_"+("invisibility_ui" if invisibility_case else "faction_ui")+"_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_FACTION_UI ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
