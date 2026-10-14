extends SceneTree
## Actual journal rows and timeline input; transport restores are a separate owner.
const Recording=preload("res://studio/recording.gd")
const Timeline=preload("res://studio/timeline_view.gd")
var checks=0
var failures:Array=[]
var scrubs:Array=[]
var seeks:Array=[]
var clips:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("TIMELINE_SCRUB_FAIL ",label)
func button(view:Control,at:Vector2,pressed:bool)->void:
    var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at
    view._gui_input(event)
func motion(view:Control,at:Vector2)->void:
    var event=InputEventMouseMotion.new();event.position=at;event.button_mask=MOUSE_BUTTON_MASK_LEFT
    view._gui_input(event)
func run()->void:
    var index=Recording.read("res://.runtime/studio-cases/dash-seed3/amber/journal")
    check(index.ok,"Actual server recording indexes")
    if not index.ok:finish();return
    var view=Timeline.new();view.size=Vector2(1280,540);view.thumbnails.suspended=true;root.add_child(view);view.set_index(index)
    view.scrub_requested.connect(func(at,finished):scrubs.append({"at":at,"finished":finished}))
    view.seek_requested.connect(func(at):seeks.append(at))
    view.clip_requested.connect(func(row):clips.append(row.id))
    var end:float=index.presentation_end_ms
    view.playhead_ms=end*.5
    # Grab the actual vertical bar well below the ruler, then drag both ways.
    button(view,Vector2(view._x(view.playhead_ms)+4,140),true)
    check(view.drag_playhead and scrubs.size()==1 and not scrubs[0].finished,"Playhead can be grabbed inside a track, beyond its thin painted line")
    motion(view,Vector2(view._x(end*.75),160))
    check(is_equal_approx(view.playhead_ms,end*.75),"Forward dragging updates the playhead immediately")
    motion(view,Vector2(view._x(end*.2),120))
    check(is_equal_approx(view.playhead_ms,end*.2),"Backward dragging updates the playhead immediately")
    button(view,Vector2(view._x(end*.2),120),false)
    check(not view.drag_playhead and scrubs.back().finished and is_equal_approx(scrubs.back().at,end*.2),"Release emits the final intended time exactly once")
    check(scrubs.filter(func(row):return row.finished).size()==1 and seeks.is_empty() and clips.is_empty(),"A drag emits scrub intents without per-motion seeks or accidental clip selection")
    var count=scrubs.size();motion(view,Vector2(view._x(end*.8),120))
    check(scrubs.size()==count,"Pointer movement after release cannot continue a stale drag")
    button(view,Vector2(view._x(end*.4),10),true)
    motion(view,Vector2(view.gutter-100,10))
    check(view.playhead_ms==0,"Ruler drag clamps before the beginning")
    motion(view,Vector2(view._x(end)+200,10))
    button(view,Vector2(view._x(end)+200,10),false)
    check(view.playhead_ms==end and scrubs.back().finished,"Ruler drag and release clamp after the final authored tail")
    count=scrubs.size()
    button(view,Vector2(view.gutter+2,150),true)
    motion(view,Vector2(view.gutter+30,150))
    button(view,Vector2(view.gutter,150),false)
    check(scrubs.size()==count and not view.drag_playhead and not view.drag_gutter,"Divider dragging does not enter scrubbing")
    var body:Dictionary=index.rows.filter(func(row):return row.kind=="body" and row.end_ms>row.start_ms)[0]
    view.reveal(body.id)
    var y=view.RULER-view.scroll_y
    for item in view.rows:
        if item.row.id==body.id:break
        y+=view._height(item.row)
    button(view,Vector2(view.gutter-20,y+20),true);button(view,Vector2(view.gutter-20,y+20),false)
    check(clips==[body.id] and scrubs.size()==count,"Clicking an actual animation label still selects and plays that clip")
    view.playhead_ms=end
    button(view,Vector2(view._x(end*.3),y+20),true);button(view,Vector2(view._x(end*.3),y+20),false)
    check(seeks.size()==1 and is_equal_approx(seeks[0],end*.3),"Clicking an ordinary sample away from the bar retains precise seek behavior")
    view.queue_free();await process_frame
    finish()
func finish()->void:
    var report={"checks":checks,"failures":failures,"scrub_intents":scrubs,"scope":"Actual recorded timeline input: bar and ruler dragging, immediate pointer feedback, final-intent signal, clamping, divider separation and unchanged label/sample clicks. Transport publication is tested separately."}
    FileAccess.open("res://generated/studio_timeline_scrub_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_TIMELINE_SCRUB ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
