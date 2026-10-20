extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
## Real Gallery rows plus small display-only boundary fixtures. No GPU claims.
const Recording=preload("res://studio/recording.gd")
const Timeline=preload("res://studio/timeline_view.gd")
var checks=0
var failures:Array=[]
var evidence:Dictionary={}

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("TIMELINE_LAYOUT_FAIL ",label)

func run()->void:
    var index=Fixtures.read("gallery")
    check(index.ok,"Actual Gallery recording admits")
    if not index.ok:finish();return
    var original=JSON.stringify(index.rows)
    var view=Timeline.new();view.size=Vector2(1280,350);view.thumbnails.suspended=true
    root.add_child(view);view.set_process(false);view.set_index(index)
    var lights:Array=index.rows.filter(func(row):return row.kind=="light")
    var original_lights=JSON.stringify(lights)
    evidence={"indexed_rows":index.rows.size(),"light_rows":lights.size(),"native_light_rows":index.rows.filter(func(row):return row.kind=="native_light").size(),"environment_sources":view.environment_lights.size(),"default_display_rows":view.rows.size()}
    check(view.environment_lights.size()>10,"Gallery has many actual environment emitters")
    var headers:Array=view.rows.filter(func(item):return item.row.kind=="light_group")
    check(headers.is_empty(),"Default Gallery hides environment history headers")
    check(view.rows.all(func(item):return not view.lighting_rows.has(item.row.id)),"Default Gallery hides all detailed lighting tracks")
    check(view.rows.all(func(item):return item.row.kind!="event" or item.row.event.kind not in ["sensory","spatial","turn","undisclosed"]),"Default Gallery has no state-only exploration or turn bookkeeping rows")
    check(view.compact_projection.display.values().any(func(row):return row.kind=="missing_group" and not row.members.is_empty()),"Useful missing presentation work remains visible")
    var first_phase:Dictionary=index.rows.filter(func(row):return row.kind=="native_effect")[0]
    view.follow_at(first_phase.start_ms+.1)
    check(not view.show_lighting_tracks,"Ordinary event Follow cannot enable detailed lighting tracks")
    check(view.rows.any(func(item):return item.row.kind=="native_effect"),"Actual VFX stays visible while its light details are hidden")
    view.show_lighting_tracks=true;view.rebuild_rows()
    headers=view.rows.filter(func(item):return item.row.kind=="light_group")
    check(not headers.is_empty(),"Optional environment inspection presents source groups")
    check(headers.all(func(item):return view.collapsed.get(item.row.id,false)),"Environment groups initially collapse")
    check(view.rows.all(func(item):return not view.environment_lights.has(item.row.id)),"Default grouping hides histories, not event-owned lanes")
    check(lights.any(func(row):return not view.environment_lights.has(row.id)),"Actual carried lights remain classified separately")
    for id in view.environment_lights:
        view.reveal(id)
        check(view.rows.any(func(item):return item.row.id==id),"Explicit source reveal opens "+id)
        check(not view.collapsed[view.light_groups[id]],"Source reveal opens its own display group")
    view.filter="light";view.rebuild_rows()
    check(view.rows.all(func(item):return item.row.kind!="light_group"),"Filtering bypasses display groups")
    for row in lights:check(view.rows.any(func(item):return item.row.id==row.id),"Filtered exact source accessible "+row.id)
    check(JSON.stringify(lights)==original_lights,"All recorded light keys, ownership and fields remain exact")
    # Publication must use the same visible intersection for paint and input.
    # Ordinary optical tracks need no GPU thumbnail jobs in this headless check.
    view.filter="Torch light";view.rebuild_rows()
    check(view.rows.size()>10,"Actual torch histories exceed the visible viewport")
    for offset in [0.0,137.0,view._content_height()/2.0,maxf(0,view._content_height()-view.size.y)]:
        view.scroll_y=offset
        view.prepare_visible(false)
        var expected:Array=[];var y=view.RULER-offset
        for item in view.rows:
            var height=view._height(item.row)
            if y+height>=view.RULER and y<view.size.y:expected.append(item.row.id)
            y+=height
        var actual:Array=view.published_layout.visible_rows.map(func(item):return item.row.id)
        check(actual==expected,"Published visible rows match geometric intersection at "+str(offset))
        check(actual.size()<view.rows.size(),"Draw/hit-test footprint excludes offscreen histories")
        for item in view.published_layout.visible_rows:
            var point=Vector2(60,clampf(item.y+item.height/2.0,view.RULER+.1,view.size.y-.1))
            check(view._get_tooltip(point).begins_with(view._label(item.row)),"Hit-testing uses published visible row "+item.row.id)
    # An independent scan of recorded intervals is the follow oracle. It also
    # checks exact end boundaries, reverse seek and changed filters.
    var times:Array=[]
    for row in index.rows:
        if row.kind=="native_effect" and row.get("visible_here",true):
            times.append_array([row.start_ms,row.start_ms+.1,row.end_ms-.001,row.end_ms])
    times.sort()
    var backwards=times.duplicate();backwards.reverse();times.append_array(backwards)
    for query in ["Body","light","nothing matches this lane"]:
        view.filter=query;view.rebuild_rows()
        var retained:String=view.followed_row
        for at in times:
            retained=expected_follow(index.rows,view.lighting_rows,query,at,retained)
            check(view.follow_at(at)==retained,"Follow matches recorded intervals %s @ %.3f"%[query,at])
    view.filter="Body";view.rebuild_rows()
    var body:Dictionary=index.rows.filter(func(row):return row.kind=="body" and row.end_ms-row.start_ms>2)[0]
    view.follow_at(body.start_ms+.01)
    var scans:int=view.follow_scans
    for frame in 1000:view.follow_at(body.start_ms+.01)
    check(view.follow_scans==scans,"Paused playhead does not rescan the index")
    evidence.follow_scans_for_1000_paused_calls=view.follow_scans-scans
    var step=minf(100.0,view.follow_until-body.start_ms-.01)/1001.0
    for frame in 1000:view.follow_at(body.start_ms+.01+step*frame)
    check(view.follow_scans==scans,"Continuous play inside an unchanged interval reuses the selected lane")
    check(JSON.stringify(index.rows)==original,"Display changes never mutate indexed facts or components")
    boundary_fixture(view)
    view.queue_free();await process_frame
    finish()

func expected_follow(source:Array,environment:Dictionary,query:String,at:float,retained:String)->String:
    var chosen:Dictionary={};var retained_matches=false
    for row in source:
        var matching=query.is_empty() or query.to_lower() in (row.label+" "+row.kind+" "+row.get("actor_name","")+" "+row.get("status","")+" "+row.get("reason","")+" "+row.get("source","")).to_lower()
        if row.id==retained:retained_matches=matching and not (query.is_empty() and environment.has(row.id))
        if not matching or not row.get("visible_here",true) or row.kind=="part":continue
        if query.is_empty() and environment.has(row.id):continue
        if row.kind not in Timeline.PREVIEW_KINDS and row.kind not in ["native_light","light"]:continue
        if at<row.start_ms or at>=row.end_ms:continue
        if chosen.is_empty() or row.start_ms>chosen.start_ms or (row.start_ms==chosen.start_ms and row.id==retained):chosen=row
    return str(chosen.id) if not chosen.is_empty() else (retained if retained_matches else "")

func boundary_fixture(view:Control)->void:
    var sources:Array=[]
    for faction in ["amber","blue"]:
        var row={"id":faction+":source","parent":"","kind":"light","label":"Optical light","source_perspective":faction,"start_ms":0.0,"end_ms":1000.0,"status":"available","actor_uuid":"","light_keys":[{"source":{"actor_uuid":""}}]}
        sources.append(row)
    var missing:Dictionary=sources[0].duplicate(true);missing.id="missing-light";missing.status="missing";sources.append(missing)
    var later_carried:Dictionary=sources[0].duplicate(true);later_carried.id="later-carried"
    later_carried.light_keys.append({"source":{"actor_uuid":"real-actor"}});sources.append(later_carried)
    view.filter="";view.set_index({"rows":sources,"presentation_end_ms":1000.0})
    check(view.light_groups["amber:source"]!=view.light_groups["blue:source"],"Root environment groups retain faction separation")
    check(view.rows.any(func(item):return item.row.id=="missing-light"),"Missing light remains exposed outside collapsed groups")
    check(not view.environment_lights.has("later-carried"),"Later actor ownership prevents environment grouping")
    check(sources[0].parent=="" and sources[1].parent=="","Display groups never rewrite original causal parents")

func finish()->void:
    var result={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual Gallery timeline grouping, interval-follow equivalence, published visible row geometry and source access. Headless CPU correctness; no interactive FPS or native lighting claim."}
    FileAccess.open("res://.runtime/studio-timeline-layout-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("TIMELINE_LAYOUT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
