extends SceneTree
## Real invisible TimelineView preparation, quarter retention and bounded demand.
const Recording=preload("res://studio/recording.gd")
const TimelineView=preload("res://studio/timeline_view.gd")
var checks=0
var failures:Array=[]
var evidence:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("TIMELINE_PREPARATION_FAIL ",label)
func run()->void:
    var index=Recording.read("res://.runtime/studio-cases/melee-seed3/amber/journal")
    check(index.ok,"Actual melee recording indexes")
    if not index.ok:finish();return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,720)
    var view=TimelineView.new();view.size=Vector2(1280,400);view.visible=false
    root.add_child(view);view.set_index(index)
    var body:Dictionary=index.rows.filter(func(row):return row.kind=="body" and row.track.clip=="TakeDamage")[0]
    view.reveal(body.id)
    var prepared=view.prepare_visible(true)
    check(not prepared.ready and prepared.pending>0 and prepared.samples>0,"Invisible timeline explicitly queues the visible source cells without drawing")
    var quarters={}
    for job in view.thumbnails.pending:quarters[job.quarter]=true
    check(quarters.size()==4,"The initial visible source demand includes all four camera quarters")
    check(view.preview_demand==view.thumbnails.pinned,"Visible four-view source keys are retained by the bounded cache")
    if DisplayServer.get_name()!="headless":
        var started=Time.get_ticks_msec();var deadline=started+30000
        while not prepared.settled and Time.get_ticks_msec()<deadline:
            await process_frame;prepared=view.prepare_visible(true)
        check(prepared.ready and prepared.errors.is_empty(),"Hidden native staging finishes every actual visible source sample")
        check(not view.visible,"Source preparation does not require showing a candidate timeline")
        var handles=view.thumbnails.textures.duplicate();var reads=view.thumbnails.source_reads
        var ready_times=[]
        for quarter in 4:
            view.quarter=quarter
            var before_jobs=view.thumbnails.pending.map(func(job):return job.key)
            var at=Time.get_ticks_usec();var status=view.prepare_visible(true);ready_times.append((Time.get_ticks_usec()-at)/1000.0)
            check(status.ready,"Prepared visible samples are immediately ready in quarter "+str(quarter))
            check(view.thumbnails.pending.map(func(job):return job.key)==before_jobs,"Rotating the prepared timeline enqueues no source reload "+str(quarter))
        var unchanged=true
        for key in handles:
            if view.thumbnails.textures.get(key)!=handles[key]:unchanged=false
        check(unchanged,"All four quarters retain their exact composed texture handles")
        check(view.thumbnails.texture_bytes<=view.thumbnails.texture_limit and view.thumbnails.image_bytes<=view.thumbnails.image_limit,"Actual staged source and swatch caches stay within their byte budgets")
        evidence={"native":true,"prepare_ms":Time.get_ticks_msec()-started,"visible_samples":prepared.samples,"swatches":view.thumbnails.textures.size(),"source_reads":reads,"quarter_ready_ms":ready_times,"texture_bytes":view.thumbnails.texture_bytes}
        await check_layout_publication(view)
    view.queue_free();await process_frame
    finish()

func check_layout_publication(view:Control)->void:
    view.show()
    var displayed:Dictionary=view.published_layout
    var wheel=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.ctrl_pressed=true;wheel.pressed=true;wheel.position=Vector2(800,100)
    view._gui_input(wheel)
    var changed=view.prepare_visible(true)
    check(view.pixels_per_second!=displayed.pixels_per_second,"Native zoom input requests a different timeline scale")
    if not changed.settled:
        check(not is_same(view.published_layout,displayed) and view.published_layout.pixels_per_second==view.pixels_per_second,"Cold zoom publishes current row geometry while swatches prepare")
        check(view.published_layout.preview_keys==view.preview_keys,"Published cells own the new source sample keys")
    var drawn:Dictionary=view.published_layout
    var at=Vector2(drawn.gutter+200,10)
    var expected:float=view._time(at.x,drawn)
    var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=at
    view._gui_input(press)
    check(is_equal_approx(view.playhead_ms,expected),"Scrubbing during preparation uses the ruler the user can actually see")
    press.pressed=false;view._gui_input(press)
    var deadline=Time.get_ticks_msec()+30000
    while not changed.settled and Time.get_ticks_msec()<deadline:
        await process_frame;changed=view.prepare_visible(true)
    check(changed.ready and view.published_layout.pixels_per_second==view.pixels_per_second,"New zoom publishes with all exact visible samples ready")
    var scroll=InputEventMouseButton.new();scroll.button_index=MOUSE_BUTTON_WHEEL_DOWN;scroll.pressed=true;scroll.position=Vector2(700,150)
    view._gui_input(scroll)
    changed=view.prepare_visible(true)
    deadline=Time.get_ticks_msec()+30000
    var complete=true
    while not changed.settled and Time.get_ticks_msec()<deadline:
        complete=complete and view.published_layout.scroll_y==view.scroll_y
        await process_frame;changed=view.prepare_visible(true)
    check(complete and changed.ready and view.published_layout.scroll_y==view.scroll_y,"Scrolling publishes current row positions independently of pending source cells")

func finish()->void:
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Real recorded hidden timeline preparation, visible-cell readiness, all four camera views and retained bounded native swatches. No new source/model behavior."}
    var name="studio_timeline_preparation_native_checks.json" if evidence.get("native",false) else "studio_timeline_preparation_checks.json"
    FileAccess.open("res://generated/"+name,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_TIMELINE_PREPARATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
