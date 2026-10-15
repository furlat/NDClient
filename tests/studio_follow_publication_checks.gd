extends SceneTree
## Real Gallery rows: pending source images cannot hold drawn or clickable rows.
const Recording=preload("res://studio/recording.gd")
const Timeline=preload("res://studio/timeline_view.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("FOLLOW_PUBLICATION_FAIL ",label)
func run()->void:
    var index=Recording.read("res://.runtime/gallery-sorcerer-20261015-seed3-door/amber/journal")
    check(index.ok,"Actual Gallery recording admits")
    if not index.ok:finish();return
    var view=Timeline.new();view.size=Vector2(1280,350);view.thumbnails.suspended=true
    root.add_child(view);view.set_process(false);view.set_index(index)
    # Hold the existing source queue cold: source readiness must remain false
    # while layout publication and actual input still follow the real rows.
    var clicks:Array=[]
    view.selected.connect(func(row):clicks.append(row.id))
    var times:Array=[]
    for row in index.rows:
        if row.kind=="native_effect" and row.end_ms>row.start_ms:times.append(row.start_ms+.01)
    times.sort()
    var selected_ids={};var changed_y=false;var previous_y=-1.0
    for at in times:
        var selected:String=view.follow_at(at)
        if selected.is_empty() or selected_ids.has(selected):continue
        selected_ids[selected]=true
        var prepared:Dictionary=view.prepare_visible()
        check(prepared.pending>0,"Actual followed source cells remain cold")
        check(view.published_layout.scroll_y==view.scroll_y,"Follow publishes current vertical position before previews complete")
        var matches:Array=view.published_layout.visible_rows.filter(func(item):return item.row.id==selected)
        check(matches.size()==1,"Followed row is in actual published visible geometry")
        if not matches.is_empty():
            var item:Dictionary=matches[0]
            check(item.y>=view.RULER and item.y+item.height<=view.size.y,"Followed row is fully inside the timeline")
            var point=Vector2(70,clampf(item.y+item.height*.5,view.RULER+.1,view.size.y-.1))
            check(view._get_tooltip(point).begins_with(view._label(item.row)),"Input resolves the same published followed row")
            var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
            click.position=Vector2(view.gutter+90,point.y);view._gui_input(click)
            check(not clicks.is_empty() and clicks.back()==selected,"Pointer click selects the newly published followed row")
            click.pressed=false;view._gui_input(click)
            evidence.append({"at_ms":at,"row":selected,"scroll_y":view.scroll_y,"row_y":item.y,"pending":prepared.pending})
        if previous_y>=0 and not is_equal_approx(view.scroll_y,previous_y):changed_y=true
        previous_y=view.scroll_y
        if evidence.size()>=12:break
    check(changed_y,"Real sequence drives vertical following across distinct rows")
    check(view.thumbnails.textures.is_empty(),"No fabricated ready source images were used")
    var selected:String=view.followed_row
    var scans:int=view.follow_scans
    var last_time:float=evidence.back().at_ms
    view.scroll_y=0;view.follow_at(last_time);view.prepare_visible()
    var active:Array=view.published_layout.visible_rows.filter(func(item):return item.row.id==selected)
    check(active.size()==1 and active[0].y>=view.RULER and active[0].y+active[0].height<=view.size.y,"Cached active lane returns onscreen after manual scroll")
    check(view.follow_scans==scans,"Visibility correction does not rescan source intervals")
    view.size.y=140;view.follow_at(last_time);view.prepare_visible()
    active=view.published_layout.visible_rows.filter(func(item):return item.row.id==selected)
    check(active.size()==1 and active[0].y>=view.RULER and active[0].y+active[0].height<=view.size.y,"Cached active lane fits after divider shrinks the timeline")
    check(view.follow_scans==scans,"Resize visibility correction preserves interval cache")
    # Rotating uses only its actual foreground quarter. Other views are optional.
    for quarter in [1,3,0]:
        view.quarter=quarter
        var prepared:Dictionary=view.prepare_visible()
        check(prepared.pending>0 and view.published_layout.quarter==quarter,"Cold rotation publishes current orientation with pending cells")
        check(view.preview_keys.keys().all(func(key):return str(key).ends_with(":"+str(quarter))),"Foreground keys contain only selected camera quarter")
    view.thumbnails.prewarm_suspended=true
    var before=view.prewarm_signature.duplicate()
    view._prepare_other_rows()
    check(view.thumbnails.warm_pending.is_empty() and view.prewarm_signature==before,"Playback suspension does not build or admit optional source samples")
    view.thumbnails.prewarm_suspended=false;view._prepare_other_rows()
    check(not view.thumbnails.warm_pending.is_empty(),"Paused mode resumes the existing optional preparation queue")
    view.queue_free();await process_frame;finish()
func finish()->void:
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Real Gallery source rows with a deliberately cold thumbnail cache; no native rendering or performance claims."}
    FileAccess.open("res://.runtime/studio-follow-publication.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_FOLLOW_PUBLICATION ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
