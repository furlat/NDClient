extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
## Actual Gallery causal actions, exact component selection and compact Follow.
const Recording=preload("res://studio/recording.gd")
const Timeline=preload("res://studio/timeline_view.gd")
const Tracks=preload("res://presentation/tracks.gd")
var checks=0
var failures:Array=[]
var evidence={}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_FOLLOW_FAIL ",label)
func visible(view:Control,id:String)->bool:
    var display:String=view._display_id(id)
    if not view.row_tops.has(display):return false
    var row:Dictionary=view._display_row(display)
    var height:float=view._height(row)
    var top:float=view.row_tops[display]-view.scroll_y+view.RULER
    if row.kind=="compact_lane":
        height=view._band_height(row);top+=row.bands.get(id,0)*height
    return top>=view.RULER and top+height<=view.size.y
func run()->void:
    var index=Fixtures.read("gallery")
    check(index.ok,"Actual Gallery recording admits")
    if not index.ok:finish();return
    var original=JSON.stringify(index.rows)
    var view=Timeline.new();view.size=Vector2(1280,350);view.thumbnails.suspended=true
    root.add_child(view);view.set_process(false);view.set_index(index)
    evidence={"indexed_rows":index.rows.size(),"default_rows":view.rows.size(),"headers":{},"membership":{},"expanded_delivery_count":0,"default_phase_bands":1}
    check(not view.fit_enabled and view.pixels_per_second==240.0,"Recording opens at a readable fixed seconds-to-pixels scale")
    check(is_equal_approx(view._x(1000.0)-view._x(0.0),240.0),"A real second occupies240px without changing its duration")
    view.fit()
    check(view.fit_enabled and is_equal_approx(view._x(index.presentation_end_ms),view.size.x-24),"Explicit Fit still shows the entire recording")
    view.fit_enabled=false;view.pixels_per_second=240.0
    var projection:Dictionary=view.compact_projection
    evidence.shield_sources=[]
    for lane in projection.display.values():
        if lane.kind!="compact_lane" or lane.clips[0].kind!="native_effect":continue
        var source:Dictionary=lane.clips[0].component
        check(lane.clips.all(func(row):return row.component.get("spell_id")==source.get("spell_id") and row.component.get("source_id")==source.get("source_id") and row.component.get("native_clip",{}).get("id")==source.get("native_clip",{}).get("id")),"A native phase strip retains one spell and actual source mechanism")
        if source.get("spell_id")=="shield":
            evidence.shield_sources.append({"label":lane.label,"source":source.native_clip.id,"count":lane.clips.size()})
            check("Shield" in lane.label and "clips" in lane.label and "deliveries" not in lane.label,"Shield attached sources are named and counted as clips")
    check(evidence.shield_sources.size()>1,"Actual Shield hit and lifecycle sources remain separate under the causal cast")
    for spell in ["magic_missile","scorching_ray","fireball"]:
        var headers:Array=projection.roots.filter(func(row):return row.get("event",{}).get("behavior_id")=="spell."+spell)
        evidence.headers[spell]=headers.size()
        check(headers.size()==(2 if spell=="magic_missile" else 1),"Real cast owners stay distinct and applications do not become casts: "+spell)
        for header in headers:
            var phases:Array=index.rows.filter(func(row):return row.kind=="native_effect" and view.action_for.get(row.id)==header.id)
            var members:Array=[]
            for lane in projection.children[header.id]:
                if lane.kind=="compact_lane":members.append_array(lane.clips.filter(func(row):return row.kind=="native_effect"))
                elif lane.kind=="native_effect":members.append(lane)
            check(members.map(func(row):return row.id).size()==phases.size() and phases.all(func(row):return members.any(func(member):return is_same(row,member))),"Every actual native phase has exactly one unchanged displayed source under "+header.id)
            evidence.membership[header.id]=members.map(func(row):return row.id)
            if spell=="fireball":
                check(header.recipient_ids.size()==6,"Fireball header retains all six actual application recipients")
                var missing:Array=projection.children[header.id].filter(func(row):return row.kind=="missing_group")
                check(missing.size()==1 and view.collapsed[missing[0].id],"Repeated Fireball requirements have one visibly marked, initially collapsed summary")
                if not missing.is_empty():
                    check(missing[0].members.all(func(row):return is_same(row,view.rows_by_id[row.id])),"Missing summary retains exact original requirements and ownership")
                    var raw:Dictionary=missing[0].members[0]
                    view.reveal(raw.id)
                    check(view.rows.any(func(item):return item.row.id==raw.id),"Explicit missing-row reveal opens its exact requirement")
                    view.collapsed[missing[0].id]=true;view.rebuild_rows()
    var movement:Array=projection.display.values().filter(func(row):return row.kind=="compact_lane" and row.clips[0].kind=="body" and row.clips[0].track.get("motion",false))
    check(movement.any(func(lane):return lane.clips.size()>1 and not lane.cues.is_empty()),"Real movement segments and their step-owned Footsteps share one lane")
    for lane in movement:
        check(lane.band_count==1,"One actor's motion has exactly one default strip: "+lane.id)
        for window in lane.windows:
            var raw:Dictionary=window.row
            var group:Dictionary=index.groups.filter(func(item):return item.group.id==raw.group_id)[0]
            var time:float=(window.start_ms+window.end_ms)*.5
            var actual:Dictionary=Tracks.samples(group.group.actor_tracks,time-group.start_ms).get(raw.track.actor_uuid,{})
            check(actual.get("trace_track_id")==raw.id,"Motion strip uses the actual renderer winner at "+str(time))
        for n in range(1,lane.windows.size()):
            check(lane.windows[n-1].end_ms<=lane.windows[n].start_ms,"Motion strips do not stack overlapping source intervals")
    var opportunities:Array=projection.roots.filter(func(row):return str(row.get("event",{}).get("behavior_id","")).begins_with("reaction.opportunity"))
    check(not opportunities.is_empty(),"Actual opportunity reactions remain separate action headers")
    if not opportunities.is_empty():
        var ancestor:String=opportunities[0].parent
        while view.rows_by_id.has(ancestor) and view.rows_by_id[ancestor].get("event",{}).get("kind")!="movement":ancestor=view.rows_by_id[ancestor].parent
        check(view.rows_by_id.has(ancestor),"Actual opportunity attack retains its movement ancestry")
        if view.rows_by_id.has(ancestor):
            var details="display:details:"+ancestor
            view.collapsed[ancestor]=false;view.collapsed[details]=false;view.compact_projection={}
            view._open_occurrence(ancestor);view.rebuild_rows()
            var ids={}
            for item in view.rows:ids[item.row.id]=true
            check(ids.size()==view.rows.size(),"Expanded movement Details displays each raw reaction ID once")
            check(view.rows.any(func(item):return item.row.id==opportunities[0].id),"The original opportunity event remains visible inside movement Details")
            view.collapsed[details]=true;view.compact_projection={};view.rebuild_rows()
    var selections:Array=[]
    view.selected.connect(func(row):selections.append(row))
    for lane in projection.display.values():
        if not lane.get("phase_strip",false):continue
        evidence.expanded_delivery_count=lane.clips.size()
        check(lane.band_count==1 and view.collapsed[lane.id],"Real multishot phase uses one collapsed strip by default")
        view._open_action(lane.action_id,false);view.rebuild_rows()
        view.scroll_y=view.row_tops[lane.id];view.origin_ms=lane.start_ms-10;view.prepare_visible()
        var item:Dictionary=view.published_layout.visible_rows.filter(func(item):return item.row.id==lane.id)[0]
        check(not item.segments.is_empty(),"Collapsed phase has actual source samples")
        var maximum_art_height=0.0
        for segment in item.segments:
            var cell:Dictionary=segment.cells[0]
            var point=Vector2(cell.x+cell.spacing*.5,item.y+20)
            check(view._hit_row(item,point,view.published_layout).get("id")==segment.row.id,"Phase preview selects its exact raw delivery")
            var rect:Rect2=view.preview_rect(Vector2(128,128),cell,item.y,item.height)
            maximum_art_height=maxf(maximum_art_height,rect.size.y)
            check(is_equal_approx(rect.get_center().y,item.y+item.height*.5),"Artwork is vertically centered within its actual phase lane")
            check(rect.position.x>=cell.x and rect.end.x<=cell.x+cell.spacing,"Each delivery preview stays inside its own horizontal slot")
        evidence.maximum_phase_preview_height=maximum_art_height
        check(maximum_art_height>=60.0,"Three real simultaneous deliveries have readable row-height artwork at the default scale")
        var expand=InputEventMouseButton.new();expand.button_index=MOUSE_BUTTON_LEFT;expand.pressed=true
        expand.position=Vector2(12+item.depth*14,item.y+15);view._gui_input(expand)
        check(not view.collapsed[lane.id],"Phase disclosure expands its actual deliveries")
        for clip in lane.clips:
            check(view.rows.filter(func(item):return item.row.id==clip.id).size()==1 and view._display_id(clip.id)==clip.id,"Expanded delivery preserves one exact raw selectable source: "+clip.id)
        view.collapsed[lane.id]=true;view.compact_projection={};view.rebuild_rows();view.origin_ms=0
        break
    check(evidence.expanded_delivery_count>1,"Real multishot sources exercise collapsed and expanded delivery inspection")
    # Resolve checkpoints from this recording's actual selected finite sources.
    # Fixed milliseconds from an older authored schedule can now land in a later
    # movement; that does not test whether Follow retains an active spell.
    evidence.context={}
    var context_times:Array=[]
    for spell in ["magic_missile","fireball"]:
        var sources:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("status")!="missing" and row.get("visible_here",true) and row.end_ms>row.start_ms and row.component.get("spell_id")==spell and row.component.get("native_cue",{}).get("role") in ["flight","area","impact"])
        check(not sources.is_empty(),"Original recording contains an actual finite native source checkpoint: "+spell)
        if sources.is_empty():continue
        var source:Dictionary=sources[0]
        var at:float=(source.start_ms+source.end_ms)*.5
        var residue_id:String=""
        for phase in sources:
            for residue in index.rows:
                if residue.kind!="residue_deposit" or residue.start_ms<phase.start_ms or view.action_for.get(residue.id)!=view.action_for.get(phase.id):continue
                var begin:float=maxf(phase.start_ms,residue.start_ms)
                var end:float=minf(phase.end_ms,residue.end_ms)
                if end<=begin:continue
                source=phase;at=begin+minf(.1,(end-begin)*.5);residue_id=residue.id;break
            if not residue_id.is_empty():break
        var sample:Dictionary={"time":at,"spell":spell}
        context_times.append(at)
        view.follow_from=INF
        var followed:String=view.follow_at(sample.time)
        var current:Dictionary=view.rows_by_id.get(followed,{})
        var owner:Dictionary=view._display_row(view.followed_action)
        check(owner.get("event",{}).get("behavior_id")=="spell."+sample.spell,"Checkpoint Follow retains its current causal cast: "+sample.spell)
        check(current.get("kind")=="native_effect","Actual active spell source remains selected"+(" over newer recorded residue" if not residue_id.is_empty() else "")+": "+sample.spell)
        view.prepare_visible()
        check(view.followed_visible(),"Continuous export sees the published followed strip: "+sample.spell)
        check(view._x(sample.time)>=view.gutter and view._x(sample.time)<=view.size.x-20,"Playback follows the current time horizontally: "+sample.spell)
        var context:Array=view.context_labels(view.published_layout)
        check(context.size()==2 and context[0]==view._label(owner) and context[1]==view._label(view._display_row(view._display_id(followed))),"Sticky ruler identifies the actual visible cast and lane: "+sample.spell)
        evidence.context[sample.spell]={"raw_id":followed,"labels":context,"time_ms":sample.time,"source_interval":[source.start_ms,source.end_ms],"competing_residue":residue_id}
    if not context_times.is_empty():
        view.follow_at(context_times[0]);view.prepare_visible()
        check(view._x(context_times[0])>=view.gutter and view._x(context_times[0])<=view.size.x-20,"Backward seek restores the current horizontal time window")
    view.follow_at(0.0);view.prepare_visible()
    check(view.origin_ms==0.0,"Loop return restores the start of the time window")
    var stable_flight=false
    for lane in projection.display.values():
        if lane.kind!="compact_lane" or lane.clips.size()<2 or lane.clips[0].get("component",{}).get("native_cue",{}).get("role")!="flight":continue
        var begin:float=lane.clips.map(func(row):return row.start_ms).max()
        var end:float=lane.clips.map(func(row):return row.end_ms).min()
        for row in index.rows:
            if view.action_for.get(row.id)==lane.action_id and row.get("component",{}).get("native_cue",{}).get("role") in ["impact","area"]:end=minf(end,row.start_ms)
        if end<=begin:continue
        view.followed_row=lane.clips[0].id;view.follow_from=INF
        var held_id:String=view.follow_at((begin+end)*.5)
        check(held_id==lane.clips[0].id,"An active multishot sibling stays selected instead of jumping to a later sibling")
        stable_flight=true;break
    check(stable_flight,"Actual Gallery contains overlapping flights before their contact phase")
    var samples:Array=[]
    for lane in projection.display.values():
        if lane.kind=="compact_lane" and not lane.clips.is_empty():samples.append(lane.clips[0])
    samples.sort_custom(func(a,b):return a.start_ms<b.start_ms)
    for row in samples:
        var at:float=(row.start_ms+row.end_ms)*.5
        var followed:String=view.follow_at(at)
        check(not followed.is_empty() and visible(view,followed),"Follow exposes the current raw clip's compact band at "+str(at))
        check(view.rows_by_id.get(followed,{}).get("status")!="missing","Follow never targets a missing placeholder")
    var repeated:Dictionary=projection.display.values().filter(func(row):return row.kind=="compact_lane" and row.clips.size()>1)[0]
    var source:Dictionary=repeated.clips[0]
    view.reveal(source.id)
    var detail_id="display:details:"+repeated.action_id
    view.scroll_y=maxf(0,view.row_tops[detail_id]-30);view.prepare_visible()
    var detail_item:Dictionary=view.published_layout.visible_rows.filter(func(item):return item.row.id==detail_id)[0]
    var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
    click.position=Vector2(12+detail_item.depth*14,detail_item.y+15)
    view._gui_input(click)
    check(not view.collapsed[detail_id],"The actual Details disclosure arrow opens the original hierarchy")
    view.reveal(source.id)
    check(view.rows.any(func(item):return item.row.id==source.id),"Details retains the full original source hierarchy")
    view.collapsed[detail_id]=true;view.compact_projection={};view.rebuild_rows()
    view.filter=source.label;view.rebuild_rows()
    check(view.rows.any(func(item):return item.row.id==source.id),"Search bypasses display grouping and retains exact raw source")
    view.filter="";view.rebuild_rows()
    var at:float=(source.start_ms+source.end_ms)*.5
    view.follow_at(at)
    var scans:int=view.follow_scans
    var held:Dictionary=view.compact_projection
    for frame in 100:view.follow_at(at)
    check(view.follow_scans==scans and is_same(held,view.compact_projection),"Paused Follow neither scans nor reconstructs the immutable display projection")
    var owner:String=view.followed_action
    view.manual_collapse[owner]=true;view.collapsed[owner]=true;view.rebuild_rows();view.follow_at(at+.001)
    check(view.collapsed[owner],"Automatic Follow preserves an explicit manual action collapse")
    var part:Dictionary=index.rows.filter(func(row):return row.kind=="part")[0]
    view.reveal(part.id)
    check(view.rows.any(func(item):return item.row.id==part.id),"Explicit omitted gear-part reveal opens its exact original ancestry")
    var all_follow_rows:Array=view.follow_rows
    for kind in ["body","audio"]:
        var raw:Dictionary=all_follow_rows.filter(func(row):return row.kind==kind and row.end_ms>row.start_ms)[0]
        view.follow_rows=[raw];view.follow_from=INF
        check(view.follow_at((raw.start_ms+raw.end_ms)*.5)==raw.id,"An action with only its real "+kind+" source remains followable")
    view.follow_rows=all_follow_rows
    # The displayed lane must advance even when real source work consumed the
    # shared frame budget. Its thumbnail request remains deferred, not ready.
    view.manual_collapse.clear();view.follow_from=INF
    view.follow_at((samples.front().start_ms+samples.front().end_ms)*.5);view.prepare_visible()
    var earlier_follow:String=view.followed_row
    var earlier_requests:Array=view.thumbnails.pending.duplicate()
    var earlier_preview_signature:Array=view.preview_signature.duplicate(true)
    view.preparation_admission={"frame":Engine.get_process_frames(),"limit_usec":2000,"used_usec":2000,"phase_usec":{}}
    view.follow_at((samples.back().start_ms+samples.back().end_ms)*.5)
    var deferred:Dictionary=view.prepare_visible()
    check(view.followed_row!=earlier_follow and view.followed_visible(),"A different actual Gallery source is visibly followed while resource preparation is budget-exhausted")
    check(not deferred.ready and view.preview_signature==earlier_preview_signature and view.thumbnails.pending==earlier_requests,
        "Publishing current row geometry does not submit or qualify deferred source preparation")
    view.preparation_admission={};view.prepare_visible()
    check(view.followed_visible() and view.published_layout.preview_keys==view.preview_keys,
        "Ordinary source admission attaches the exact cell keys to the already current layout")
    check(JSON.stringify(index.rows)==original,"Grouping, Details, search and Follow preserve every indexed event/component byte")
    view.queue_free();await process_frame
    finish()
func finish()->void:
    var result={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual Gallery causal grouping, readable fixed scale and centered single motion/phase strips, exact source previews and expanded deliveries, raw selection/requirements, Details/search, published Follow visibility and index immutability. Native rendering is a separate checkpoint."}
    FileAccess.open("res://.runtime/studio-follow-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("STUDIO_FOLLOW ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
