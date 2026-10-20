extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
## One displayed faction, independently recorded timing, normal seek/loop publication.
const Studio=preload("res://studio/studio.gd")
const Recording=preload("res://studio/recording.gd")
const Library=preload("res://studio/case_library.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
var record:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_SINGLE_FAIL ",label)
func frame()->void:
    await process_frame
    if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func settle(studio:Control)->bool:
    var deadline=Time.get_ticks_msec()+90000
    while Time.get_ticks_msec()<deadline:
        if not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and studio.pending_directory.is_empty() and studio.world.playback_prepared():
            studio.world.timeline.paused=true;await frame()
            check(studio.world.presentation_errors.is_empty(),"Selected world has no presentation errors")
            return true
        await process_frame
    check(false,"Single preview publishes within bounded readiness interval: "+studio.status.text)
    return false
func verify(studio:Control,label:String)->void:
    var expected=Recording.restore(studio.case_bundle.views[studio.active_perspective],studio.world.timeline.display_ms)
    check(studio.world.timeline.state==expected.state,label+": exact independent recorded prefix")
    check(studio.world.timeline.completed_group_count==expected.completed_group_count and studio.world.timeline.commit_index==expected.commit_index,label+": all due ordered commits")
    check(studio.world.session==null,label+": no live network Session")
    check(studio.replay_diagnostics().panes.size()==1 and not studio.replay_diagnostics().comparison,label+": one recorded renderer")
    check(not studio.world.external_clock and studio.world.component_renderer.audio.enabled,label+": ordinary single-view advancement and audio")
    check(studio.world.media_warmup.budget_bytes==studio.replay_budget_bytes,label+": complete media budget")
    for child in studio.get_children():
        if not child is SubViewport or child==studio.viewport or child.is_queued_for_deletion():continue
        check(child.render_target_update_mode==SubViewport.UPDATE_DISABLED,label+": retained primary spare frozen")
        for nested in child.find_children("*","SubViewport",true,false):check(nested.render_target_update_mode==SubViewport.UPDATE_DISABLED,label+": spare helper frozen")
    check(studio.perspective_picker.get_item_metadata(studio.perspective_picker.selected)==studio.active_perspective,label+": faction selector matches displayed audience")
func headless_contract()->void:
    var cases:Array=[record,Fixtures.public_case("gallery")]
    for item in cases:
        # A selectable but unopened journal must not be read or planned before
        # the requested audience is usable. The real second journal is loaded
        # explicitly below, exactly as a later picker selection does.
        var descriptor:Dictionary=item.duplicate(true)
        descriptor.perspectives[1].journal="res://.runtime/not-opened-for-initial-selection/journal"
        var amber=Studio._read_selection(descriptor.perspectives[0].journal,descriptor,"amber",{})
        check(amber.get("ok",false),item.id+": selected audience loads despite an unavailable unopened audience")
        if not amber.get("ok",false):continue
        check(amber.bundle.views.keys()==["amber"] and amber.bundle.perspectives.size()==2,item.id+": only selected raw audience is loaded and original picker entries remain")
        check(amber.index.loading_ms.audiences_read==1 and amber.index.loading_ms.comparison_ms==0.0 and amber.index.loading_ms.final_media_ms.keys()==["amber"],item.id+": one admission and one exact media plan, no shared retiming")
        var blue=Studio._read_selection(item.perspectives[1].journal,item,"blue",{})
        check(blue.get("ok",false),item.id+": second original audience loads on explicit request")
        if not blue.get("ok",false):continue
        var selected=Studio._retain_recorded_views(blue,amber.bundle)
        check(selected.ok and selected.bundle.views.size()==2,item.id+": loaded audience records retained separately")
        if not selected.ok:continue
        var bundle:Dictionary=selected.bundle
        for side in ["amber","blue"]:
            var shown=Studio._inspection_index(bundle,side)
            var original:Dictionary=bundle.views[side]
            check(not shown.get("comparison",false) and is_same(shown.groups,original.groups),item.id+": exact original own group clocks "+side)
            check(shown.rows.size()==original.rows.size() and shown.rows.all(func(row):return row.get("visible_here",true) and row.get("source_perspective",side)==side),item.id+": complete own tracks without peer rows "+side)
            check(original.media_preload.group_plans.size()==original.groups.size() and original.media_preload.errors.is_empty(),item.id+": exact media closure covers all own groups "+side)
            for fraction in [0,.55,1.0]:
                var at=float(original.presentation_end_ms)*fraction
                var restored=Studio._restore_selection(shown,at,{})
                var expected=Recording.restore(original,at)
                check(restored.keys()==["primary"] and restored.primary.state==expected.state,item.id+": seek retains exact selected reducer "+side+"/"+str(fraction))
                check(is_equal_approx(restored.primary.display_ms,at),item.id+": own display time preserved "+side+"/"+str(fraction))
        var origin:Dictionary=Studio._inspection_index(bundle,"amber")
        var target:Dictionary=Studio._inspection_index(bundle,"blue")
        var mappings=0
        for row in origin.rows:
            if row.kind!="event" or row.end_ms<=row.start_ms:continue
            var at=lerpf(row.start_ms,row.end_ms,.35)
            var anchor=Recording.navigation_anchor(origin,at,row)
            var target_id=Studio._anchored_row(target,anchor)
            if target_id.is_empty():continue
            var destination:Dictionary=target.rows.filter(func(other):return other.id==target_id)[0]
            if destination.end_ms<=destination.start_ms:continue
            var mapped=Recording.anchor_time(target,anchor)
            check(is_equal_approx(mapped,lerpf(destination.start_ms,destination.end_ms,.35)),item.id+": faction navigation preserves actual event phase")
            anchor.mapped_time_ms=mapped
            var back=Recording.navigation_anchor(target,mapped,destination,anchor)
            check(is_equal_approx(Recording.anchor_time(origin,back),at),item.id+": round trip returns to original recorded event phase")
            mappings+=1
            if mappings==4:break
        check(mappings>0,item.id+": actual shared causes exercise independent-clock navigation")
        var absent_rows=0
        for row in origin.rows:
            if row.end_ms<=row.start_ms:continue
            var at=lerpf(row.start_ms,row.end_ms,.4)
            var anchor=Studio._navigation_anchor(origin,at,row,{})
            if not Studio._anchored_row(target,anchor).is_empty():continue
            var mapped=Recording.anchor_time(target,anchor);anchor.mapped_time_ms=mapped
            var back=Studio._navigation_anchor(target,mapped,{},anchor)
            check(is_equal_approx(Recording.anchor_time(origin,back),at),item.id+": undisclosed counterpart retains the original held event/phase on return")
            var changed=target.rows.filter(func(other):return other.start_ms<=mapped and other.end_ms>mapped and Recording._row_key(other)!=anchor.row_key)
            if not changed.is_empty():
                var deliberate=Studio._navigation_anchor(target,mapped,changed[0],anchor)
                check(deliberate.row_key==Recording._row_key(changed[0]),item.id+": explicit new row selection replaces the retained undisclosed anchor")
            absent_rows+=1
            if absent_rows==3:break
        if item.id.begins_with("hide-"):check(absent_rows>0,"Real Hide disclosure differences exercise missing-counterpart return")
        var wrong=blue.duplicate();wrong.bundle=blue.bundle.duplicate();wrong.bundle.views={"blue":{"identity":blue.bundle.views.blue.identity.duplicate()}}
        wrong.bundle.views.blue.identity.game_epoch="different-recorded-epoch"
        check(not Studio._retain_recorded_views(wrong,amber.bundle).ok,item.id+": other encounter epochs are rejected before replacement")
        evidence.append({"case":item.id,"amber":amber.index.loading_ms,"blue":blue.index.loading_ms,"durations_ms":{"amber":origin.presentation_end_ms,"blue":target.presentation_end_ms}})
func native_controls()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1440,850);root.gui_embed_subwindows=true
    var studio=Studio.new();studio.loop_enabled=false;root.add_child(studio)
    if not await settle(studio):await close(studio);return
    check(studio.active_case.id==record.id,"Uses original registered Hide/light recording")
    verify(studio,"Initial")
    var at=float(studio.index.presentation_end_ms)*.55
    studio._seek(at)
    if not await settle(studio):await close(studio);return
    verify(studio,"Seek")
    studio.tracks.show_lighting_tracks=true;studio.tracks.rebuild_rows()
    for side in ["blue","amber"]:
        var anchor=Studio._navigation_anchor(studio.index,studio.world.timeline.display_ms,studio.selected_row,studio.retained_view_anchor)
        studio.select_perspective(side)
        if not await settle(studio):await close(studio);return
        verify(studio,"Faction "+side)
        check(is_equal_approx(studio.world.timeline.display_ms,Recording.anchor_time(studio.index,anchor)),"Faction switch retains the selected recorded event and phase")
        check(studio.tracks.show_lighting_tracks,"Lighting filter survives faction publication")
    for time in [0,at]:
        studio._seek(time)
        if not await settle(studio):await close(studio);return
        verify(studio,"Reverse/reseek")
    studio.loop_start=0;studio.loop_end=minf(650,studio.index.presentation_end_ms);studio.loop_enabled=true
    studio._seek(0,true)
    if not await settle(studio):await close(studio);return
    studio.world.timeline.paused=false
    var previous=studio.world.timeline.display_ms;var wrapped=false;var deadline=Time.get_ticks_msec()+30000
    while Time.get_ticks_msec()<deadline and not wrapped:
        await frame()
        var now=studio.world.timeline.display_ms
        if not studio.installing:check(is_equal_approx(studio.tracks.playhead_ms,now),"Drawn timeline follows the displayed frame")
        check(now<=studio.loop_end+.001,"Loop never passes Out")
        wrapped=now<previous-.1;previous=now
    studio.world.timeline.paused=true;studio.loop_enabled=false;studio._cancel_loop_preparation()
    check(wrapped,"Single preview loops through ordinary prepared restore")
    if await settle(studio):verify(studio,"Loop")
    check(studio.fps_label.text.contains(" FPS · ") and studio.fps_label.text.ends_with(" ms") and studio.fps_label.text.to_int()>0,"Preview overlay reports FPS and frame milliseconds")
    evidence.append(studio.replay_diagnostics())
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/single-view")
    await frame();root.get_texture().get_image().save_png("res://.captures/studio/single-view/selected.png")
    await close(studio)
func close(studio:Control)->void:
    studio.queue_free();await frame();await frame()
func run()->void:
    var cases=[Fixtures.public_case("hide-light")]
    check(cases.size()==1,"Exact real Hide/light Library case exists")
    if not cases.is_empty():
        record=cases[0]
        if "--native" in OS.get_cmdline_user_args():await native_controls()
        else:headless_contract()
    var report={"checks":checks,"failures":failures,"evidence":evidence,"native":"--native" in OS.get_cmdline_user_args()}
    FileAccess.open("res://.runtime/studio-single-view"+("-native" if report.native else "")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_SINGLE_VIEW ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
