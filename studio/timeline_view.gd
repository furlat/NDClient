extends Control
signal seek_requested(time_ms: float)
signal scrub_requested(time_ms: float, finished: bool)
signal selected(row: Dictionary)
signal clip_requested(row: Dictionary)
signal perspective_requested(row:Dictionary)
const Thumbnails = preload("res://studio/thumbnail_cache.gd")
const Compact = preload("res://studio/timeline_compact.gd")
const LightTracks = preload("res://studio/light_tracks.gd")
const AudioCues=preload("res://presentation/audio_cues.gd")
var thumbnails = Thumbnails.new()
var light_settings:Dictionary={}
var fixture_curves:Dictionary={}
var light_plots:Dictionary={}
var fixture_count=0
var index: Dictionary = {}
var rows: Array = []
var collapsed: Dictionary = {}
var missing_counts: Dictionary = {}
var filter = ""
var show_metadata=false
var show_lighting_tracks=false
var fit_enabled=false
var playhead_ms = 0.0
var pixels_per_second = 240.0
var origin_ms = 0.0
var scroll_y = 0.0
var gutter = 250.0
var quarter = 0
var drag_gutter = false
var drag_playhead = false
var selection = ""
var followed_row=""
var followed_action=""
var display_row_for:Dictionary={}
var display_rows:Dictionary={}
var action_for:Dictionary={}
var manual_collapse:Dictionary={}
var auto_opened_action=""
var compact_projection:Dictionary={}
var font: Font
var rows_revision=0
var preview_signature:Array=[]
var preview_keys:Dictionary={}
var preview_demand:Dictionary={}
var preview_request_errors:Array=[]
var published_layout:Dictionary={}
var prewarm_signature:Array=[]
var rows_by_id:Dictionary={}
var event_descendants:Dictionary={}
var environment_lights:Dictionary={}
var lighting_rows:Dictionary={}
var light_groups:Dictionary={}
var row_tops:Dictionary={}
var content_height=0.0
var follow_rows:Array=[]
var follow_filter=""
var follow_from=INF
var follow_until=-INF
var follow_scans=0
var preview_visible_rows:Array=[]
var frame_cpu_ms:Dictionary={}
const RULER = 27.0
const PREVIEW_KINDS = ["body","part","condition_material","condition_pose","condition_restore","registered_media","native_effect","sprite_layer","material_flash","feedback_text","damage_number","audio","residue_deposit","geometry_projectile"]

func _ready() -> void:
    thumbnails.host=self
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    focus_mode = Control.FOCUS_ALL
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    font = ThemeDB.fallback_font
    resized.connect(func():if fit_enabled:fit())

func set_index(value: Dictionary) -> void:
    index = value
    compact_projection={}
    followed_row="";followed_action="";auto_opened_action="";manual_collapse.clear()
    published_layout={}
    light_plots.clear()
    collapsed.clear(); thumbnails.reset(); scroll_y = 0; origin_ms = 0
    thumbnails.cache=Thumbnails.Catalog.source_snapshot(value.get("cache",{}))
    rows_by_id.clear();event_descendants.clear();environment_lights.clear();lighting_rows.clear();follow_rows.clear()
    follow_from=INF;follow_until=-INF;follow_scans=0
    var by_id=rows_by_id
    var first_body={}
    for row in index.get("rows",[]):
        by_id[row.id]=row
        if _environment_light(row):environment_lights[row.id]=true
        if row.kind in ["light","native_light"] and row.get("status")!="missing":lighting_rows[row.id]=true
        if row.get("visible_here",true) and row.get("status")!="missing" and row.kind!="part" and (row.kind in PREVIEW_KINDS or row.kind in ["native_light","light"]):follow_rows.append(row)
        if row.kind in ["event","parts","condition","condition_exit"] or row.get("source_kind") in ["parts","condition","condition_exit"]:collapsed[row.id]=true
        if first_body.is_empty() and row.kind=="body":first_body=row
    for row in index.get("rows",[]):
        if row.kind!="event":continue
        var ancestor:String=row.id
        while by_id.has(ancestor):
            if by_id[ancestor].kind=="event":
                if not event_descendants.has(ancestor):event_descendants[ancestor]=[]
                event_descendants[ancestor].append(row.id)
            ancestor=by_id[ancestor].parent
    missing_counts.clear()
    # Missing authored work is visible even when it produced no drawable track.
    for row in index.get("rows",[]):
        if row.get("status")!="missing" or row.kind=="event" or not row.get("visible_here",true):continue
        var ancestor:String=row.parent
        while by_id.has(ancestor):
            missing_counts[ancestor]=missing_counts.get(ancestor,0)+1
            ancestor=by_id[ancestor].parent
    if not first_body.is_empty():
        var owner=Compact.action_id(first_body,by_id)
        collapsed[owner]=false;auto_opened_action=owner
    rebuild_rows()
    fit_enabled=false;pixels_per_second=240.0
    queue_redraw()

func _open_occurrence(id:String,by_id:Dictionary={}) -> void:
    if by_id.is_empty():by_id=rows_by_id
    var occurrence=id
    while by_id.has(occurrence) and by_id[occurrence].kind!="event":occurrence=by_id[occurrence].parent
    if not by_id.has(occurrence):return
    # Retain component/gear collapse choices; only causal event wrappers open.
    for child in event_descendants.get(occurrence,[]):collapsed[child]=false

func _environment_light(row:Dictionary)->bool:
    if row.kind!="light" or not row.get("visible_here",true) or row.get("status")=="missing":return false
    if not str(row.get("actor_uuid","")).is_empty():return false
    # A source that becomes carried later still belongs to its actor's lane.
    for key in row.get("light_keys",[]):
        if not str(key.get("source",{}).get("actor_uuid","")).is_empty():return false
    return true

func rebuild_rows() -> void:
    rows_revision+=1
    rows.clear();row_tops.clear();light_groups.clear();content_height=0.0
    if filter.is_empty() and not show_metadata and not show_lighting_tracks and not compact_projection.is_empty():
        _append_compact();return
    var by_id=rows_by_id;var direct={};var seeds={};var branch_of={};var useful_views={}
    for row in index.get("rows",[]):
        if row.kind in ["event","perspective"]:continue
        if lighting_rows.has(row.id) and filter.is_empty() and not show_lighting_tracks:continue
        var parent:String=row.parent
        while by_id.has(parent) and by_id[parent].kind not in ["event","perspective"]:parent=by_id[parent].parent
        var branch:Dictionary=by_id.get(parent,{})
        if branch.get("kind")=="perspective":branch_of[row.id]=branch.id
        # Foreign zero-length/unmapped rows are inspection metadata, not tracks.
        # Unseen factions do not acquire placeholders in the visible timeline.
        if row.kind=="other_view" and (row.end_ms<=row.start_ms or row.get("timing_status")=="other_perspective" or not branch.get("disclosed",false)):continue
        if branch.get("kind")=="perspective" and not branch.get("disclosed",false):continue
        if row.kind in ["parts","condition","condition_exit","condition_state"] and row.get("status")!="missing":continue
        seeds[row.id]=true;direct[row.parent]=true
        if branch.get("kind")=="perspective" and row.end_ms>row.start_ms and row.get("status")!="missing":
            if not useful_views.has(branch.parent):useful_views[branch.parent]={}
            useful_views[branch.parent][branch.id]=true
    var relevant={}
    for id in seeds:
        var parent:String=id
        while by_id.has(parent) and not relevant.has(parent):relevant[parent]=true;parent=by_id[parent].parent
    var visible={}
    for row in index.get("rows",[]):
        if lighting_rows.has(row.id) and filter.is_empty() and not show_lighting_tracks:continue
        var keep=show_metadata or relevant.has(row.id)
        if not show_metadata:
            if row.kind=="perspective":keep=relevant.has(row.id) and useful_views.get(row.parent,{}).size()>1
            elif row.kind=="other_view":keep=seeds.has(row.id) and useful_views.get(by_id.get(branch_of.get(row.id,""),{}).get("parent",""),{}).size()>1
            elif row.kind=="event":
                if not row.get("visible_here",true) or row.event.kind=="undisclosed":keep=false
                elif row.event.kind in ["sensory","spatial","turn","damage"] and not direct.has(row.id):keep=false
        if keep:visible[row.id]=row
    display_row_for={};display_rows={};action_for={}
    if filter.is_empty() and not show_metadata and not show_lighting_tracks:
        compact_projection=Compact.project(index.get("rows",[]),visible,by_id,PREVIEW_KINDS,collapsed)
        _append_compact();return
    var children={};var roots:Array=[];var groups={}
    for row in index.get("rows",[]):
        if not visible.has(row.id):continue
        # Display-only compression retains the true parent on the indexed row.
        var parent:String=row.parent
        while by_id.has(parent) and not visible.has(parent):parent=by_id[parent].parent
        if filter.is_empty() and environment_lights.has(row.id):
            # Display grouping never combines faction identities or changes the
            # recorded row's true parent, keys, timing, or source ownership.
            var group_id="display:environment-lights:"+JSON.stringify([parent,row.get("source_perspective","")])
            if not groups.has(group_id):
                var group={"id":group_id,"parent":parent,"kind":"light_group","label":"Environment lights","start_ms":0.0,"end_ms":0.0,"source_perspective":row.get("source_perspective",""),"count":0}
                groups[group_id]=group
                if not collapsed.has(group_id):collapsed[group_id]=true
                if not visible.has(parent):roots.append(group)
                else:
                    if not children.has(parent):children[parent]=[]
                    children[parent].append(group)
            groups[group_id].count+=1
            groups[group_id].label="Environment lights · %d"%groups[group_id].count
            light_groups[row.id]=group_id
            if not children.has(group_id):children[group_id]=[]
            children[group_id].append(row)
            continue
        if not visible.has(parent):roots.append(row)
        else:
            if not children.has(parent):children[parent]=[]
            children[parent].append(row)
    for parent in children:
        children[parent]=children[parent].filter(func(row):return row.kind!="event")+children[parent].filter(func(row):return row.kind=="event")
    for row in roots:_append_tree(row,children,0)
    queue_redraw()

func _append_compact()->void:
    display_row_for=compact_projection.raw_to_display;display_rows=compact_projection.display;action_for=compact_projection.owner_of
    for row in compact_projection.roots:
        if not collapsed.has(row.id):collapsed[row.id]=true
    for row in display_rows.values():
        if (row.kind in ["missing_group","action_details"] or row.get("phase_strip",false)) and not collapsed.has(row.id):collapsed[row.id]=true
    for row in compact_projection.roots:_append_tree(row,compact_projection.children,0)
    queue_redraw()

func _matches_filter(row:Dictionary)->bool:
    return filter.is_empty() or filter.to_lower() in (row.label+" "+row.kind+" "+row.get("actor_name","")+" "+row.get("status","")+" "+row.get("reason","")+" "+row.get("source","")).to_lower()

func _append_tree(row: Dictionary, children: Dictionary, depth: int) -> void:
    if _matches_filter(row):
        var height=_height(row)
        row_tops[row.id]=content_height
        rows.append({"row":row,"depth":depth,"children":children.has(row.id),"top":content_height,"height":height})
        content_height+=height
    if not collapsed.get(row.id,false) or not filter.is_empty():
        for child in children.get(row.id,[]): _append_tree(child,children,depth+1)

func _display_id(id:String)->String:
    return display_row_for.get(id,id)

func _display_row(id:String)->Dictionary:
    return display_rows.get(id,rows_by_id.get(id,{}))

func _open_action(owner:String,automatic:bool)->void:
    if automatic and auto_opened_action!=owner and not auto_opened_action.is_empty() and not manual_collapse.has(auto_opened_action):
        collapsed[auto_opened_action]=true
    if not automatic or not manual_collapse.has(owner):
        collapsed[owner]=false
        if automatic:auto_opened_action=owner

func reveal(id:String)->void:
    var by_id=rows_by_id
    if lighting_rows.has(id) and filter.is_empty() and not show_lighting_tracks:
        show_lighting_tracks=true;rebuild_rows()
    if action_for.has(id):
        _open_action(action_for[id],false)
        if not display_row_for.has(id) and id!=action_for[id]:
            collapsed["display:details:"+action_for[id]]=false
            compact_projection={}
        var display_id=_display_id(id)
        if _display_row(display_id).get("phase_strip",false):
            collapsed[display_id]=false;compact_projection={}
        if _display_row(display_id).get("kind")=="missing_group":collapsed[display_id]=false
        if not collapsed.get("display:details:"+action_for[id],true):
            var parent:String=by_id.get(id,{}).get("parent","")
            while by_id.has(parent):collapsed[parent]=false;parent=by_id[parent].parent
    else:
        var parent:String=by_id.get(id,{}).get("parent","")
        while by_id.has(parent):collapsed[parent]=false;parent=by_id[parent].parent
        if light_groups.has(id):collapsed[light_groups[id]]=false
        _open_occurrence(id,by_id)
    selection=id;rebuild_rows()
    var shown=id if row_tops.has(id) else _display_id(id)
    if row_tops.has(shown):scroll_y=maxf(0,row_tops[shown]-minf(116,size.y*.35))
    queue_redraw()

func _follow_priority(row:Dictionary)->int:
    # Sound is an eligible fallback; numbers and notices are not Follow targets.
    if row.kind=="native_effect":
        var component:Dictionary=row.get("component",{})
        if component.get("native_spell",false):
            return {"cast":3,"flight":4,"area":5,"impact":5,"spray":5,"attached":4}.get(component.get("native_cue",{}).get("role",""),3)
        return 2
    if row.kind in ["body","condition_pose","condition_restore"]:return 2
    if row.kind in ["registered_media","sprite_layer","geometry_projectile","residue_deposit"]:return 1
    if row.kind=="audio":return 0
    return -1

func _follow_action_start(row:Dictionary)->float:
    return float(_display_row(action_for.get(row.id,"")).get("start_ms",row.start_ms))

func _prefer_follow(row:Dictionary,chosen:Dictionary)->bool:
    if chosen.is_empty():return true
    # First choose the current causal action. A lingering source from an older
    # cast must not pin Follow while the actor starts a new action.
    var action_start=_follow_action_start(row)
    var chosen_start=_follow_action_start(chosen)
    if action_start!=chosen_start:return action_start>chosen_start
    var priority=_follow_priority(row);var chosen_priority=_follow_priority(chosen)
    if priority!=chosen_priority:return priority>chosen_priority
    # Keep an active sibling within the same phase rather than bouncing through
    # three simultaneous projectiles. A later phase can still take precedence.
    if chosen.id==followed_row:return false
    return row.id==followed_row or row.start_ms>chosen.start_ms

func follow_at(time_ms:float)->String:
    if drag_playhead or drag_gutter:return followed_row
    if filter!=follow_filter or time_ms<follow_from or time_ms>=follow_until:
        follow_scans+=1;follow_filter=filter;follow_from=time_ms;follow_until=INF
        var chosen:Dictionary={}
        for row in follow_rows:
            if not _matches_filter(row):continue
            if filter.is_empty() and (lighting_rows.has(row.id) or _follow_priority(row)<0):continue
            if row.start_ms>time_ms:follow_until=minf(follow_until,row.start_ms)
            if row.end_ms>time_ms:follow_until=minf(follow_until,row.end_ms)
            if time_ms<row.start_ms or time_ms>=row.end_ms:continue
            var lane:Dictionary=_display_row(_display_id(row.id))
            if lane.has("windows") and not lane.windows.any(func(window):return window.row.id==row.id and time_ms>=window.start_ms and time_ms<window.end_ms):continue
            if _prefer_follow(row,chosen):chosen=row
        if not chosen.is_empty():
            var changed=chosen.id!=followed_row
            followed_row=chosen.id
            followed_action=action_for.get(followed_row,"")
            if not followed_action.is_empty():
                _open_action(followed_action,true)
                if changed:rebuild_rows()
            elif changed:reveal(followed_row)
        elif not rows_by_id.has(followed_row) or not _matches_filter(rows_by_id.get(followed_row,{})) or (filter.is_empty() and lighting_rows.has(followed_row)):
            followed_row="";followed_action=""
    var shown=_display_id(followed_row)
    if not row_tops.has(shown) and row_tops.has(followed_action):shown=followed_action
    if row_tops.has(shown):
        var row=_display_row(shown)
        var top:float=row_tops[shown]
        var height:float=_height(row)
        if row.kind=="compact_lane":
            height=_band_height(row)
            top+=row.bands.get(followed_row,0)*height
        if top<scroll_y or top+height>scroll_y+maxf(0,size.y-RULER):
            var next_scroll=maxf(0,top-minf(68,maxf(0,size.y-RULER-height)*.25))
            if not is_equal_approx(next_scroll,scroll_y):scroll_y=next_scroll;queue_redraw()
    var x:float=_x(time_ms)
    if x<gutter+12 or x>size.x-20:
        origin_ms=maxf(0,time_ms-maxf(1,size.x-gutter)*250.0/pixels_per_second)
        queue_redraw()
    return followed_row

func followed_visible()->bool:
    if followed_row.is_empty():return true
    var shown:String=_display_id(followed_row)
    for item in published_layout.get("visible_rows",[]):
        if item.row.id!=shown:continue
        var top:float=item.y;var height:float=item.height
        if item.row.kind=="compact_lane":
            height=_band_height(item.row)
            top+=item.row.bands.get(followed_row,0)*height
        return top>=RULER and top+height<=published_layout.get("extent",size).y
    return false

func fit() -> void:
    fit_enabled=true
    pixels_per_second = maxf(1,(size.x-gutter-24)/maxf(.001,index.get("presentation_end_ms",index.get("duration_ms",1000.0))/1000.0))
    origin_ms = 0; queue_redraw()

func _process(_delta: float) -> void:
    var started=Time.get_ticks_usec()
    prepare_visible()
    var prepared=Time.get_ticks_usec()
    _prepare_other_rows()
    var optional=Time.get_ticks_usec()
    if thumbnails.poll(): queue_redraw()
    var finished=Time.get_ticks_usec()
    frame_cpu_ms={"visible":(prepared-started)/1000.0,"optional":(optional-prepared)/1000.0,
        "poll":(finished-optional)/1000.0,"total":(finished-started)/1000.0,"frame":Engine.get_process_frames()}

func _prepare_other_rows()->void:
    if thumbnails.prewarm_suspended or index.is_empty():return
    var signature=[thumbnails.generation,origin_ms,pixels_per_second,gutter,size.x]
    if signature==prewarm_signature:return
    prewarm_signature=signature
    var samples:Array=[]
    # Work through mechanism lanes before optional individual equipment parts.
    # Source decoding remains bounded background work in the thumbnail cache.
    var candidates:Array=index.rows.filter(func(row):return row.kind!="part")+index.rows.filter(func(row):return row.kind=="part")
    for row in candidates:
        if row.kind not in PREVIEW_KINDS or row.get("status")=="missing" or not row.get("visible_here",true):continue
        for cell in _sample_cells(row):
            for view in 4:
                samples.append({"row":row,"sample_ms":cell.sample_ms,"quarter":view})
                if samples.size()>=thumbnails.limit:break
            if samples.size()>=thumbnails.limit:break
        if samples.size()>=thumbnails.limit:break
    thumbnails.queue_prewarm(samples)

func _sample_cells(row:Dictionary,layout:Dictionary={},span:Dictionary={})->Array:
    var size:Vector2=layout.get("extent",self.size)
    var gutter:float=layout.get("gutter",self.gutter)
    var first:float=span.get("start_ms",row.start_ms);var last:float=span.get("end_ms",row.end_ms)
    if row.kind=="condition_restore" and row.end_ms==row.start_ms:
        var point=_x(row.start_ms,layout)
        if point<gutter or point>size.x:return []
        return [{"x":clampf(point-37,gutter+2,maxf(gutter+2,size.x-74)),"spacing":74.0,"sample_ms":float(row.start_ms)}]
    var right=minf(size.x,_x(last,layout))
    if right<=maxf(gutter+2,_x(first,layout)):return []
    var width=maxf(1.0,_x(last,layout)-_x(first,layout))
    var spacing=width/maxi(1,floori(width/float(span.get("cell_width",74.0))))
    var x=_x(first,layout)+maxf(0,ceilf((gutter-_x(first,layout))/spacing))*spacing
    var cells:Array=[]
    while x<right-10:
        cells.append({"x":x,"spacing":spacing,"sample_ms":clampf(_time(x+spacing/2,layout),first,last)})
        x+=spacing
    return cells

func _cell_key(row:Dictionary,sample_ms:float,view:int)->String:
    return "%s:%s:%d"%[row.id,sample_ms,view]

func _visible_rows()->Array:
    var result:Array=[]
    # Rows already have cumulative offsets from the last structural rebuild.
    # Locate the first intersection without walking every off-screen lane.
    var low=0;var high=rows.size()
    while low<high:
        var middle=(low+high)/2
        var item:Dictionary=rows[middle]
        if item.top+item.height<scroll_y:low=middle+1
        else:high=middle
    for i in range(low,rows.size()):
        var item:Dictionary=rows[i]
        var y:float=RULER+item.top-scroll_y
        if y>=size.y:break
        var displayed:Dictionary=item.duplicate()
        displayed.y=y
        displayed.cells=_sample_cells(item.row) if item.row.kind in PREVIEW_KINDS else []
        displayed.segments=[]
        if item.row.kind=="compact_lane":
            if item.row.get("phase_strip",false):
                if collapsed.get(item.row.id,true):
                    for window in item.row.phase_windows:
                        for cell in _sample_cells(item.row,{},window):
                            for n in window.clips.size():
                                var part:Dictionary=cell.duplicate()
                                part.x+=n*cell.spacing/window.clips.size();part.spacing/=window.clips.size()
                                displayed.segments.append({"row":window.clips[n],"cells":[part],"y":y,"height":item.height})
            else:
                var windows:Array=item.row.get("windows",[])
                if not item.row.has("windows"):
                    for clip in item.row.clips:windows.append({"row":clip,"start_ms":clip.start_ms,"end_ms":clip.end_ms})
                for window in windows:
                    var clip:Dictionary=window.row
                    var clip_y:float=y+item.row.bands[clip.id]*_band_height(item.row)
                    var clip_height:float=_band_height(item.row)
                    if clip_y+clip_height<RULER or clip_y>=size.y:continue
                    displayed.segments.append({"row":clip,"cells":_sample_cells(clip,{},window),"y":clip_y,"height":clip_height,"span":window})
        result.append(displayed)
    return result

func prepare_visible(all_quarters:bool=false)->Dictionary:
    # Staging works while this Control is invisible. Both demand and drawing
    # use _sample_cells, so readiness never depends on a hidden _draw callback.
    var signature=[thumbnails.generation,thumbnails.suspended,rows_revision,size,scroll_y,origin_ms,pixels_per_second,gutter,quarter,all_quarters]
    if signature!=preview_signature:
        preview_signature=signature;preview_keys={};preview_demand={};preview_request_errors=[]
        var samples:Array=[]
        preview_visible_rows=_visible_rows()
        for item in preview_visible_rows:
            var row:Dictionary=item.row
            if row.kind=="compact_lane":
                for segment in item.segments:
                    for cell in segment.cells:samples.append({"row":segment.row,"sample_ms":cell.sample_ms})
            elif row.kind in PREVIEW_KINDS and row.get("status")!="missing" and row.get("visible_here",true):
                for cell in item.cells:samples.append({"row":row,"sample_ms":cell.sample_ms})
        var views:Array=[quarter]
        if all_quarters:
            for view in 4:
                if view!=quarter:views.append(view)
        for view in views:
            for sample in samples:
                var key=thumbnails.request(sample.row,sample.sample_ms,view,false)
                preview_keys[_cell_key(sample.row,sample.sample_ms,view)]=key
                if key.is_empty():preview_request_errors.append("No source preview: "+str(sample.row.label))
                else:preview_demand[key]=true
        # Keep the displayed samples resident until their replacement is ready.
        var retained:Dictionary=preview_demand.duplicate()
        for key in published_layout.get("preview_keys",{}).values():
            if not key.is_empty():retained[key]=true
        thumbnails.set_demand(retained)
    var issues:Array=preview_request_errors.duplicate()
    var remaining=0
    for key in preview_demand:
        if thumbnails.errors.has(key):
            var issue:String=thumbnails.errors[key]
            if issue not in issues:issues.append(issue)
        elif not thumbnails.textures.has(key) and not thumbnails.inactive.has(key):remaining+=1
    # Row geometry and hit-testing follow immediately. Cold swatches fill their
    # own cells when ready; they must not hold the visible timeline on an old row.
    if not drag_playhead and published_layout.get("signature",[])!=preview_signature:
        published_layout={"signature":preview_signature.duplicate(),"rows":rows.duplicate(),"visible_rows":preview_visible_rows,"collapsed":collapsed.duplicate(),"scroll_y":scroll_y,"origin_ms":origin_ms,"pixels_per_second":pixels_per_second,"gutter":gutter,"quarter":quarter,"preview_keys":preview_keys.duplicate(),"extent":size}
        thumbnails.set_demand(preview_demand)
        queue_redraw()
    return {"ready":remaining==0 and issues.is_empty(),"settled":remaining==0,"pending":remaining,"errors":issues,"samples":preview_demand.size()}

func _band_height(row:Dictionary)->float:
    return 56.0 if row.get("band_count",1)>1 else 78.0

func _height(row: Dictionary) -> float:
    if row.get("phase_strip",false) and not collapsed.get(row.id,true):return 29.0
    if row.kind=="compact_lane":return _band_height(row)*row.band_count+(16 if not row.cues.is_empty() else 0)
    if row.kind=="light":return 72.0
    if row.has("movement_allowance"):return 48.0
    if row.kind=="other_view":return 29.0
    if row.get("status")=="missing" and row.kind!="event":return 29.0
    if row.kind=="audio":return 52.0
    return 78.0 if row.kind in PREVIEW_KINDS else 29.0

func _draw_audio_waveform(row:Dictionary,texture:Texture2D,left:float,right:float,y:float,height:float,layout:Dictionary)->void:
    var cue:Dictionary=row.component
    var length=maxf(.000001,float(cue.get("clip_duration_s",0)))
    var cursor=maxf(row.start_ms,_time(left,layout))
    var stop=minf(row.end_ms,_time(right,layout))
    var end_seconds=float(cue.get("loop_end_s",length)) if cue.get("loop",false) else length
    while cursor<stop:
        var source=AudioCues.source_seconds(cue,cursor-row.start_ms)
        var next=minf(stop,cursor+maxf(.000001,end_seconds-source)*1000.0)
        var x=maxf(left,_x(cursor,layout));var end_x=minf(right,_x(next,layout))
        # At extreme zoom-out, one pixel is the sampling bound. Do not submit
        # thousands of subpixel loop draws for one source-preview pixel.
        if end_x-x<1.0:
            end_x=minf(right,x+1.0);next=minf(stop,_time(end_x,layout))
            var source_x=clampf(source/length,0,1)*maxf(0,texture.get_width()-1)
            draw_texture_rect_region(texture,Rect2(x,y+5,end_x-x,height-10),Rect2(source_x,0,1,texture.get_height()))
        else:
            var width=(next-cursor)/1000.0/length*texture.get_width()
            draw_texture_rect_region(texture,Rect2(x,y+5,end_x-x,height-10),Rect2(source/length*texture.get_width(),0,width,texture.get_height()))
        if next<=cursor:break
        cursor=next

func _x(time: float,layout:Dictionary={}) -> float:
    return layout.get("gutter",gutter)+(time-layout.get("origin_ms",origin_ms))*layout.get("pixels_per_second",pixels_per_second)/1000.0

func _time(x: float,layout:Dictionary={}) -> float:
    return clampf(layout.get("origin_ms",origin_ms)+(x-layout.get("gutter",gutter))*1000/layout.get("pixels_per_second",pixels_per_second),0,index.get("presentation_end_ms",index.get("duration_ms",0.0)))

func _draw() -> void:
    if font==null: return
    draw_rect(Rect2(Vector2.ZERO,size),Color("141b25"))
    if published_layout.is_empty():return
    _draw_layout(published_layout)

func _draw_layout(layout:Dictionary)->void:
    var size:Vector2=layout.extent
    var collapsed:Dictionary=layout.collapsed
    var origin_ms:float=layout.origin_ms
    var pixels_per_second:float=layout.pixels_per_second
    var gutter:float=layout.gutter
    var quarter:int=layout.quarter
    var preview_keys:Dictionary=layout.preview_keys
    var interval = 1000.0
    if pixels_per_second<45: interval=5000.0
    elif pixels_per_second>240: interval=250.0
    var tick = floorf(origin_ms/interval)*interval
    while _x(tick,layout)<size.x:
        if _x(tick,layout)>=gutter:
            draw_line(Vector2(_x(tick,layout),RULER),Vector2(_x(tick,layout),size.y),Color("283140"))
            draw_string(font,Vector2(_x(tick,layout)+4,18),"%.2fs" % (tick/1000),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8d9eb1"))
        tick += interval
    for item in layout.visible_rows:
        var row: Dictionary = item.row
        var height:float=item.height
        var y:float=item.y
        if y+height>=RULER and y<size.y:
            var fill = Color("253449") if row.id==selection or row.id==_display_id(selection) else Color("19222f")
            draw_rect(Rect2(0,maxf(y,RULER),gutter,minf(height,y+height-RULER)),fill)
            var label = ("▸ " if collapsed.get(row.id,false) else "▾ ") if item.children else "  "
            var title:String=_label(row)+(" · %d gaps"%missing_counts[row.id] if missing_counts.has(row.id) else "")
            # A tall multi-clip lane can enter above the viewport. Keep its
            # existing gutter label visible without adding a new header row.
            var label_top=maxf(y,RULER)
            if label_top+22<y+height:
                draw_string(font,Vector2(8+item.depth*14,label_top+20),label+title,HORIZONTAL_ALIGNMENT_LEFT,gutter-22-item.depth*14,13,Color("d9e3ee"))
            var participants=_participants(row)
            if label_top+42<y+height and not participants.is_empty():
                draw_string(font,Vector2(22+item.depth*14,label_top+39),participants,HORIZONTAL_ALIGNMENT_LEFT,gutter-30-item.depth*14,11,Color("a0b1c6"))
            var detail=_movement_label(row)
            if not detail.is_empty():
                draw_string(font,Vector2(22+item.depth*14,y+(58 if row.kind=="body" else 39)),detail,HORIZONTAL_ALIGNMENT_LEFT,gutter-30-item.depth*14,11,Color("a0b1c6"))
            if row.kind=="compact_lane":
                if row.get("phase_strip",false):
                    if collapsed.get(row.id,true):
                        for clip in row.clips:
                            var left=maxf(gutter+2,_x(clip.start_ms,layout));var right=minf(size.x,_x(clip.end_ms,layout))
                            if right>left:draw_rect(Rect2(left,y+4,right-left,height-8),Color("465a72"))
                        for segment in item.segments:
                            _draw_preview_cells(segment.row,segment.cells,y,height,layout)
                else:
                    for segment in item.segments:
                        _draw_interval(segment.row,segment.cells,segment.y,segment.height,layout,segment.get("span",{}))
                for cue in row.cues:
                    var cue_x=_x(cue.start_ms,layout)
                    if cue_x>=gutter and cue_x<size.x:
                        draw_circle(Vector2(cue_x,y+height-8),3,Color("89c7e0"))
            else:_draw_interval(row,item.cells,y,height,layout)
            draw_line(Vector2(0,y+height),Vector2(size.x,y+height),Color("303a49"))
    draw_rect(Rect2(0,0,gutter,RULER),Color("222d3c"))
    var context=context_labels(layout)
    if context.is_empty():
        draw_string(font,Vector2(10,18),"OCCURRENCE / COMPONENT",HORIZONTAL_ALIGNMENT_LEFT,gutter-14,11,Color("a0b1c6"))
    else:
        draw_string(font,Vector2(10,12),context[0],HORIZONTAL_ALIGNMENT_LEFT,gutter-14,11,Color("e0e9f3"))
        draw_string(font,Vector2(10,24),context[1],HORIZONTAL_ALIGNMENT_LEFT,gutter-14,10,Color("a0b1c6"))
    draw_line(Vector2(gutter,0),Vector2(gutter,size.y),Color("556980"),2)
    var play_x = _x(playhead_ms,layout)
    if play_x>=gutter:
        draw_line(Vector2(play_x,0),Vector2(play_x,size.y),Color("f3be66"),2)

func context_labels(layout:Dictionary)->Array:
    var selected:Dictionary={}
    for item in layout.get("visible_rows",[]):
        var row:Dictionary=item.row
        var owner:String=row.get("action_id",action_for.get(row.id,""))
        if owner.is_empty():continue
        if selected.is_empty():selected={"row":row,"owner":owner}
        if row.id==_display_id(followed_row):selected={"row":row,"owner":owner};break
    if selected.is_empty():return []
    var action:Dictionary=_display_row(selected.owner)
    if action.is_empty():return []
    return [_label(action),_label(selected.row) if selected.row.id!=action.id else "Recorded action"]

func _draw_interval(row:Dictionary,cells:Array,y:float,height:float,layout:Dictionary,span:Dictionary={})->void:
    var size:Vector2=layout.extent
    var gutter:float=layout.gutter
    var quarter:int=layout.quarter
    var preview_keys:Dictionary=layout.preview_keys
    var left = maxf(gutter+2,_x(span.get("start_ms",row.start_ms),layout))
    var right = minf(size.x,_x(span.get("end_ms",row.end_ms),layout))
    if row.kind=="condition_restore" and row.end_ms==row.start_ms:
        var point_cells:Array=cells
        if not point_cells.is_empty():left=point_cells[0].x;right=minf(size.x,left+point_cells[0].spacing)
    if row.kind=="perspective":
        var current:bool=row.get("visible_here",false)
        draw_rect(Rect2(gutter,y+2,maxf(0,size.x-gutter),height-4),Color("263b50") if current else Color("1d2c3c"))
        if not current:
            draw_rect(Rect2(size.x-82,y+2,74,25),Color("294b71"))
            draw_string(font,Vector2(size.x-66,y+20),"View →",HORIZONTAL_ALIGNMENT_LEFT,66,12,Color("e0ecfa"))
    elif row.kind=="other_view":
        draw_rect(Rect2(size.x-82,y+2,74,25),Color("294b71"))
        draw_string(font,Vector2(size.x-66,y+20),"View →",HORIZONTAL_ALIGNMENT_LEFT,66,12,Color("e0ecfa"))
    elif row.kind=="missing_group":
        draw_string(font,Vector2(gutter+8,y+19),row.get("summary","Expand for exact requirements"),HORIZONTAL_ALIGNMENT_LEFT,size.x-gutter-16,12,Color("f4b1a7"))
    elif row.kind=="action_details":
        pass
    elif row.get("status")=="missing" and row.kind!="event":
        if row.get("timing_status")!="unresolved" and right>left:draw_rect(Rect2(left,y+4,maxf(3,right-left),height-8),Color("573839"))
        var category:String=row.get("missing_category","source")
        var notice={"inspection":"Track needed","unassessed":"Not assessed","renderer":"Renderer needed","implementation":"Renderer needed","source":"Source missing","authoring":"Assignment needed","authoring_assignment":"Assignment needed","authoring_review":"Review needed"}.get(category,"Source needed")
        draw_string(font,Vector2(gutter+8,y+19),notice,HORIZONTAL_ALIGNMENT_LEFT,size.x-gutter-16,12,Color("f4b1a7"))
    elif row.kind=="light" and right>left:
        _draw_light(row,left,right,y,height,layout)
    elif right>left:
        var colour = Color("573839") if row.get("status")=="missing" else (Color("3e776b") if row.kind=="body" else Color("465a72"))
        draw_rect(Rect2(left,y+4,maxf(3,right-left),height-8),colour)
        if row.kind=="audio":
            if not cells.is_empty():
                var key:String=preview_keys.get(_cell_key(row,cells[0].sample_ms,quarter),"")
                if thumbnails.textures.has(key):
                    _draw_audio_waveform(row,thumbnails.textures[key],left,right,y,height,layout)
                elif thumbnails.errors.has(key):
                    draw_string(font,Vector2(left+5,y+height/2),"Source error",HORIZONTAL_ALIGNMENT_LEFT,right-left-8,11,Color("f4b1a7"))
                else:draw_arc(Vector2((left+right)*.5,y+height*.5),3.5,0,TAU,12,Color("94a6b6"),1)
        elif row.kind in PREVIEW_KINDS and row.get("status")!="missing":
            _draw_preview_cells(row,cells,y,height,layout)
        else:
            draw_string(font,Vector2(left+6,y+19),"missing component" if row.get("status")=="missing" else _label(row),HORIZONTAL_ALIGNMENT_LEFT,right-left-8,12,Color("d9e3ee"))
    for marker in row.get("markers",[]):
        var marker_x=_x(marker.at_ms,layout)
        if marker_x<left or marker_x>=right:continue
        var ink=Color("e9ac65") if marker.kind=="commit" else Color("89c7e0")
        draw_line(Vector2(marker_x,maxf(RULER,y+3)),Vector2(marker_x,y+height-3),ink,1)
        draw_circle(Vector2(marker_x,maxf(RULER+3,y+6)),3,ink)
        if row.id==selection:draw_string(font,Vector2(marker_x+5,maxf(RULER+14,y+14)),marker.kind,HORIZONTAL_ALIGNMENT_LEFT,90,10,ink)

func _draw_preview_cells(row:Dictionary,cells:Array,y:float,height:float,layout:Dictionary)->void:
    var error_shown=false
    for cell in cells:
        var x:float=cell.x;var spacing:float=cell.spacing
        var key:String=layout.preview_keys.get(_cell_key(row,cell.sample_ms,layout.quarter),"")
        if thumbnails.textures.has(key):
            var texture:Texture2D=thumbnails.textures[key]
            draw_texture_rect(texture,preview_rect(texture.get_size(),cell,y,height),false)
        elif thumbnails.errors.has(key) and not error_shown:
            draw_string(font,Vector2(x+3,y+height/2),"Source error",HORIZONTAL_ALIGNMENT_LEFT,spacing-4,10,Color("f4b1a7"));error_shown=true
        elif thumbnails.inactive.has(key):draw_line(Vector2(x+spacing*.5-3,y+height*.5),Vector2(x+spacing*.5+3,y+height*.5),Color("94a6b6"),1)
        elif key.is_empty() and not error_shown:
            draw_string(font,Vector2(x+3,y+height/2),"Source unavailable",HORIZONTAL_ALIGNMENT_LEFT,spacing-4,10,Color("f4b1a7"));error_shown=true
        else:draw_arc(Vector2(x+spacing*.5,y+height*.5),3.5,0,TAU,12,Color("94a6b6"),1)

static func preview_rect(texture_size:Vector2,cell:Dictionary,y:float,height:float)->Rect2:
    var limit=minf(68.0,height-10)
    var scale=minf(minf(limit,maxf(1,cell.spacing-4))/texture_size.x,limit/texture_size.y)
    var dim=texture_size*scale
    return Rect2(Vector2(cell.x+(cell.spacing-dim.x)*.5,y+(height-dim.y)*.5),dim)

func set_light_context(settings:Dictionary,curves:Dictionary)->void:
    if settings!=light_settings or not is_same(curves,fixture_curves) or curves.size()!=fixture_count:
        light_settings=settings;fixture_curves=curves;fixture_count=curves.size();light_plots.clear()

func _draw_light(row:Dictionary,left:float,right:float,y:float,height:float,layout:Dictionary)->void:
    # Curves sample the production light path; cached samples only describe the
    # visible interval. Keys remain exact, including instant on/off transitions.
    var signature=[layout.origin_ms,layout.pixels_per_second,layout.gutter,layout.extent.x]
    var held:Dictionary=light_plots.get(row.id,{})
    if held.get("signature",[])!=signature:
        var times:Array=[]
        var count=clampi(ceili((right-left)/12.0),2,96)
        for i in count+1:times.append(_time(lerpf(left,right,float(i)/count),layout))
        for key in row.light_keys:
            if _x(key.at_ms,layout)>=left and _x(key.at_ms,layout)<=right:
                times.append(maxf(row.start_ms,key.at_ms-.001));times.append(key.at_ms)
        times.sort()
        var samples:Array=[];var maximum=0.0
        for time in times:
            var sample=LightTracks.sample(row,time,light_settings,fixture_curves)
            samples.append({"time":time,"energy":sample.energy})
            if sample.energy!=null:maximum=maxf(maximum,float(sample.energy))
        held={"signature":signature,"samples":samples,"maximum":maximum};light_plots[row.id]=held
    draw_rect(Rect2(left,y+3,right-left,height-6),Color("292e31"))
    var base=y+height-9;var amplitude=height-35
    draw_line(Vector2(left,base),Vector2(right,base),Color("526066"))
    var previous=Vector2.ZERO;var joined=false
    for sample in held.samples:
        if sample.energy==null:joined=false;continue
        var point=Vector2(_x(sample.time,layout),base-float(sample.energy)/maxf(.001,held.maximum)*amplitude)
        if joined:draw_line(previous,point,Color("e6c47a"),1.5)
        previous=point;joined=true
    for key in row.light_keys:
        var x=_x(key.at_ms,layout)
        if x<left or x>right:continue
        draw_circle(Vector2(x,base),3,Color("e6c47a") if key.enabled else Color("7e8993"))
    var current=LightTracks.sample(row,playhead_ms,light_settings,fixture_curves)
    var caption="Off at playhead"
    if current.enabled:
        var energy="%.2f"%float(current.energy) if current.energy!=null else "unprepared"
        var height_text="%.2f"%current.position.y if current.position!=null else "unprepared"
        caption="Energy %s · bright %.0f ft / dim %.0f ft · height %s cells"%[energy,current.bright_radius_feet,current.dim_radius_feet,height_text]
    draw_string(font,Vector2(left+5,y+18),caption,HORIZONTAL_ALIGNMENT_LEFT,right-left-10,11,Color("e1d9be"))

static func _label(row:Dictionary)->String:
    if row.kind=="perspective":return str(row.get("source_perspective",row.label)).capitalize()
    if row.kind=="body":return str(row.track.clip).to_snake_case().capitalize()
    if row.get("component",{}).get("native_spell",false):return Compact.source_label(row)
    var label:String=row.label
    if row.get("status")=="missing" and row.kind!="event":label=label.trim_prefix("Missing · ")
    # The index keeps exact authored identifiers; only display wording changes.
    return label.capitalize()

static func _participants(row:Dictionary)->String:
    if row.kind=="compact_lane":
        var names:Array=[]
        for clip in row.clips:
            var name=_participants(clip)
            if not name.is_empty() and name not in names:names.append(name)
        return "; ".join(names)
    var actor:String=row.get("actor_name","")
    var target:String=row.get("target_name","")
    if not target.is_empty() and target!=actor:return actor+" → "+target if not actor.is_empty() else target
    return actor

static func _movement_label(row:Dictionary)->String:
    if row.has("movement_allowance"):
        var allowance:Dictionary=row.movement_allowance
        return "Movement %s → %s ft"%[String.num(allowance.before_feet,1),String.num(allowance.after_feet,1)]
    var metrics:Dictionary=row.get("track",{}).get("movement_metrics",{})
    if not metrics.is_empty():return "%s tiles/s · ×%s"%[String.num(metrics.tiles_per_second,2),String.num(metrics.speed_multiplier,2)]
    return ""

func _hit_row(item:Dictionary,at:Vector2,layout:Dictionary)->Dictionary:
    var row:Dictionary=item.row
    if row.kind!="compact_lane":return row
    var time=_time(at.x,layout) if at.x>layout.get("gutter",gutter) else playhead_ms
    if at.y>=item.y+item.height-16 and not row.cues.is_empty():
        for cue in row.cues:
            if absf(at.x-_x(cue.start_ms,layout))<=6:return cue
    if row.get("phase_strip",false):
        for segment in item.get("segments",[]):
            for cell in segment.cells:
                if at.x>=cell.x and at.x<cell.x+cell.spacing:return segment.row
        for clip in row.clips:
            if time>=clip.start_ms and time<clip.end_ms:return clip
        return row.clips[0] if at.x<=layout.get("gutter",gutter) else {}
    if row.has("windows"):
        for window in row.windows:
            if time>=window.start_ms and time<window.end_ms:return window.row
        return row.clips[0] if at.x<=layout.get("gutter",gutter) else {}
    var band=clampi(floori((at.y-item.y)/_band_height(row)),0,row.band_count-1)
    var fallback:Dictionary={}
    for clip in row.clips:
        if row.bands[clip.id]!=band:continue
        if fallback.is_empty():fallback=clip
        if time>=clip.start_ms and time<clip.end_ms:return clip
    return fallback if at.x<=layout.get("gutter",gutter) else {}

func _get_tooltip(at:Vector2)->String:
    for item in published_layout.get("visible_rows",[]):
        if at.y>=maxf(item.y,RULER) and at.y<item.y+item.height:
            var row:Dictionary=_hit_row(item,at,published_layout)
            if row.is_empty():return "No clip at this time"
            if row.kind=="missing_group":return row.label+"\n"+row.summary+"\nExpand to inspect every original requirement."
            var movement=_movement_label(row)
            if row.has("movement_allowance"):movement+=" (operation boundary)"
            return _label(row)+(" · "+row.actor_name if not row.get("actor_name","").is_empty() else "")+"\n"+movement+"\n"+str(row.get("reason",row.get("component",{}).get("reason",""))).replace("_"," ")+"\n"+str(row.get("source",""))
    return ""

func _scrub(x:float,finished:bool)->void:
    playhead_ms=_time(x,published_layout)
    scrub_requested.emit(playhead_ms,finished)
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        grab_focus()
        if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
            var direction = -1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1
            if event.ctrl_pressed:
                fit_enabled=false
                var at = _time(event.position.x)
                pixels_per_second = clampf(pixels_per_second*pow(1.2,-direction),8,1600)
                origin_ms = maxf(0,at-(event.position.x-gutter)*1000/pixels_per_second)
            elif event.shift_pressed: fit_enabled=false;origin_ms = maxf(0,origin_ms+direction*30000/pixels_per_second)
            else: scroll_y = clampf(scroll_y+direction*70,0,maxf(0,_content_height()-size.y+RULER))
            queue_redraw(); accept_event()
        elif event.button_index==MOUSE_BUTTON_LEFT:
            if not event.pressed:
                var was_scrubbing=drag_playhead
                drag_gutter=false;drag_playhead=false
                if was_scrubbing:_scrub(event.position.x,true)
                accept_event();return
            var drawn_gutter:float=published_layout.get("gutter",gutter)
            drag_gutter = absf(event.position.x-drawn_gutter)<7
            drag_playhead = not drag_gutter and event.position.x>drawn_gutter+7 and (event.position.y<RULER or absf(event.position.x-_x(playhead_ms,published_layout))<=7)
            if drag_playhead:_scrub(event.position.x,false)
            elif event.pressed and not drag_gutter:
                for item in published_layout.get("visible_rows",[]):
                    if event.position.y>=maxf(item.y,RULER) and event.position.y<item.y+item.height:
                        var row:Dictionary=_hit_row(item,event.position,published_layout)
                        var toggle=(event.position.x<30+item.depth*14 or item.row.kind in ["light_group","missing_group","action_details"]) and item.children
                        if toggle:
                            collapsed[item.row.id] = not collapsed.get(item.row.id,false)
                            manual_collapse[item.row.id]=collapsed[item.row.id]
                            if item.row.kind=="action_details":
                                if not collapsed[item.row.id]:
                                    for id in event_descendants.get(item.row.action_id,[]):collapsed[id]=false
                                    for id in action_for:
                                        if action_for[id]==item.row.action_id and rows_by_id[id].kind=="event":collapsed[id]=false
                                compact_projection={}
                            elif item.row.get("phase_strip",false):compact_projection={}
                            if not collapsed[item.row.id] and action_for.is_empty():_open_occurrence(item.row.id)
                            rebuild_rows()
                        if item.row.kind in ["light_group","action_details"]:queue_redraw();break
                        if row.is_empty():
                            if event.position.x>drawn_gutter:seek_requested.emit(_time(event.position.x,published_layout))
                            queue_redraw();break
                        selection = row.id
                        selected.emit(row)
                        if row.kind in ["other_view","perspective"]:
                            if event.position.x>=published_layout.get("extent",size).x-82 and not row.get("visible_here",true):perspective_requested.emit(row)
                        elif event.position.x>drawn_gutter: seek_requested.emit(_time(event.position.x,published_layout))
                        elif not toggle and row.kind!="missing_group":clip_requested.emit(row)
                        queue_redraw(); break
            accept_event()
    elif event is InputEventMouseMotion:
        if drag_gutter:
            gutter=clampf(event.position.x,160,size.x*.5)
            if fit_enabled:fit()
            queue_redraw();accept_event()
        elif drag_playhead:_scrub(event.position.x,false);accept_event()

func _content_height() -> float:
    return content_height

func _exit_tree() -> void:
    thumbnails.close()
