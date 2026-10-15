extends SceneTree
## Studio's publication/transport boundary. Native first-frame readiness is an
## explicit input here; the integrated checkpoint proves actual renderer output.
const Studio=preload("res://studio/studio.gd")
const Recording=preload("res://studio/recording.gd")
const TimelineView=preload("res://studio/timeline_view.gd")
const Media=preload("res://presentation/media_warmup.gd")

class FrameOwner extends Node3D:
    var prepared=false
    var rotating=false
    var timeline={"display_ms":0.0,"paused":true}
    var media_warmup=Media.create()
    var media_plan={"required":{"current":"current"}}
    var media_environment_required={}
    var native_startup={"elapsed_ms":6500.0,"completed":72,"total":72}
    func rotation_pending()->bool:return rotating
    func playback_prepared()->bool:return prepared

var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_STARTUP_BOUNDARY_FAIL ",label)

func run()->void:
    var host=Studio.new()
    var owner=FrameOwner.new();host.world=owner;host.candidate_world=owner
    owner.media_warmup.wanted={"current":"current","upcoming":"upcoming"}
    owner.media_warmup.preload_selected={"current":"current","upcoming":"upcoming","later":"later"}
    owner.media_warmup.ready_paths={"current":true}
    host.candidate_preview_pending=9
    host.candidate_preview_errors=["Explicit unavailable source preview"]
    check(not host._candidate_frame_ready(false),"Optional readiness never substitutes for missing displayed-frame readiness")
    owner.prepared=true
    check(host._candidate_frame_ready(false),"Ready displayed frame publishes with later recording assets and thumbnails still pending")
    check(not Media.ready(owner.media_warmup,owner.media_warmup.preload_selected),"Recording-wide optional media remains actually unready")
    check(host.candidate_preview_errors==["Explicit unavailable source preview"],"Publication eligibility does not discard preview errors")
    check(not host._candidate_frame_ready(true),"Changed camera remains blocked until its exact frame is prepared")
    owner.rotating=true
    check(not host._candidate_frame_ready(false),"Pending rotation remains a first-frame gate")
    owner.rotating=false
    host._report_publication(true)
    check(host.startup_receipt.required_sources==1 and host.startup_receipt.required_ready==1,"Receipt counts current mandatory source readiness")
    check(host.startup_receipt.upcoming_sources==1 and host.startup_receipt.upcoming_ready==0,"Receipt distinguishes finite upcoming demand from current requirements")
    check(host.startup_receipt.optional_sources==1 and host.startup_receipt.optional_ready==0 and host.startup_receipt.thumbnail_pending==9,"Receipt honestly retains optional and thumbnail pending counts")
    var transport=HBoxContainer.new();root.add_child(transport)
    var menu=PopupMenu.new();transport.add_child(menu);menu.add_check_item("Follow active track",13);host.diagnostic_menu=menu
    host._add_follow_control(transport)
    check(host.follow_tracks and host.follow_button.button_pressed and menu.is_item_checked(0),"Visible Follow and Inspect start enabled together")
    host.follow_button.button_pressed=false
    check(not host.follow_tracks and not menu.is_item_checked(0),"Visible Follow disables the actual transport setting and Inspect")
    host._set_follow_tracks(true)
    check(host.follow_button.button_pressed and menu.is_item_checked(0),"Inspect setting synchronizes the visible Follow control")
    var index:Dictionary=Recording.read("res://.runtime/studio-spells-20261015/magic_missile-seed3/amber/journal")
    check(index.ok,"Original Magic Missile recording admits for transport proof")
    if index.ok:
        var view=TimelineView.new();view.size=Vector2(1280,340);view.thumbnails.suspended=true
        root.add_child(view);view.set_process(false);view.set_index(index);host.tracks=view;host.index=index
        var phases:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.component.get("native_spell",false))
        check(not phases.is_empty(),"Actual recording has native spell work")
        if not phases.is_empty():
            owner.timeline.display_ms=phases[0].start_ms+1.0
            var before=JSON.stringify(index.rows)
            host.installing=true;host.preparing_loop=true;owner.timeline.paused=false
            host._follow_displayed_track()
            check(not view.followed_row.is_empty(),"Displayed recorded work keeps following while hidden next-loop frame prepares")
            var followed=view.followed_row;var scans=view.follow_scans
            host.scrub_target=owner.timeline.display_ms+30;owner.timeline.display_ms+=20
            host._follow_displayed_track()
            check(view.followed_row==followed and view.follow_scans==scans,"Explicit scrub retains priority over automatic follow")
            host.scrub_target=-1;view.drag_playhead=true;host._follow_displayed_track()
            check(view.follow_scans==scans,"Pointer playhead drag retains follow priority")
            view.drag_playhead=false;host.preparing_loop=false;owner.timeline.paused=true;host._follow_displayed_track()
            check(view.follow_scans==scans,"Explicit paused seek retains its selected rows until publication")
            host.installing=false;view.filter="Body";view.rebuild_rows()
            var pending:Dictionary=view.prepare_visible()
            check(pending.pending>0,"Newly filtered source previews are deliberately cold")
            host._seek(owner.timeline.display_ms,true)
            check(not owner.timeline.paused and not host.installing and host.requested_seek<0,"Same-clock resume starts immediately without waiting for source swatches or rebuilding the renderer")
            check(JSON.stringify(index.rows)==before,"Transport controls preserve authoritative recording rows")
        view.queue_free()
    host.candidate_world=null;host.world=null;host.free();owner.free();transport.queue_free()
    await process_frame
    var report={"checks":checks,"failures":failures,"scope":"Headless Studio admission and controls with real Magic Missile rows. Native readiness is supplied explicitly; this does not claim native cold-start timing or pixels."}
    FileAccess.open("res://.runtime/studio-startup-boundary.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_STARTUP_BOUNDARY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
