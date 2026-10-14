extends Control
signal seek_requested(time_ms: float)
signal scrub_requested(time_ms: float, finished: bool)
signal selected(row: Dictionary)
signal clip_requested(row: Dictionary)
signal perspective_requested(row:Dictionary)
const Thumbnails = preload("res://studio/thumbnail_cache.gd")
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
var fit_enabled=true
var playhead_ms = 0.0
var pixels_per_second = 100.0
var origin_ms = 0.0
var scroll_y = 0.0
var gutter = 250.0
var quarter = 0
var drag_gutter = false
var drag_playhead = false
var selection = ""
var font: Font
var rows_revision=0
var preview_signature:Array=[]
var preview_keys:Dictionary={}
var preview_demand:Dictionary={}
var preview_request_errors:Array=[]
var published_layout:Dictionary={}
var prewarm_signature:Array=[]
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
    published_layout={}
    light_plots.clear()
    collapsed.clear(); thumbnails.reset(); scroll_y = 0; origin_ms = 0
    thumbnails.cache=Thumbnails.Catalog.source_snapshot(value.get("cache",{}))
    var by_id={}
    var first_body={}
    for row in index.get("rows",[]):
        by_id[row.id]=row
        if row.kind in ["event","parts","condition","condition_exit"] or row.get("source_kind") in ["parts","condition","condition_exit"]:collapsed[row.id]=true
        if first_body.is_empty() and row.kind=="body":first_body=row
    missing_counts.clear()
    # Missing authored work is visible even when it produced no drawable track.
    for row in index.get("rows",[]):
        if row.get("status")!="missing" or row.kind=="event" or not row.get("visible_here",true):continue
        var ancestor:String=row.parent
        while by_id.has(ancestor):
            missing_counts[ancestor]=missing_counts.get(ancestor,0)+1
            collapsed[ancestor]=false;ancestor=by_id[ancestor].parent
    # Restoration belongs to its recorded removal occurrence, which may be a
    # different root action from application. Show that exit path initially.
    for row in index.get("rows",[]):
        if row.kind!="condition_restore" or not row.get("visible_here",true):continue
        var ancestor:String=row.parent
        while by_id.has(ancestor):collapsed[ancestor]=false;ancestor=by_id[ancestor].parent
    # A composition includes its target reactions. Opening only the attacker's
    # ancestry concealed TakeDamage behind nested damage wrappers.
    var parent: String=first_body.get("parent","")
    while by_id.has(parent):
        collapsed[parent]=false;parent=by_id[parent].parent
    _open_occurrence(first_body.get("parent",""),by_id)
    rebuild_rows()
    fit()

func _open_occurrence(id:String,by_id:Dictionary={}) -> void:
    if by_id.is_empty():
        for row in index.get("rows",[]):by_id[row.id]=row
    var occurrence=id
    while by_id.has(occurrence) and by_id[occurrence].kind!="event":occurrence=by_id[occurrence].parent
    if not by_id.has(occurrence):return
    # Retain component/gear collapse choices; only causal event wrappers open.
    for row in index.get("rows",[]):
        if row.kind!="event":continue
        var parent:String=row.id
        while by_id.has(parent):
            if parent==occurrence:collapsed[row.id]=false;break
            parent=by_id[parent].parent

func rebuild_rows() -> void:
    rows_revision+=1
    rows.clear()
    var by_id={};var direct={};var seeds={};var branch_of={};var useful_views={}
    for row in index.get("rows",[]):by_id[row.id]=row
    for row in index.get("rows",[]):
        if row.kind in ["event","perspective"]:continue
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
        var keep=show_metadata or relevant.has(row.id)
        if not show_metadata:
            if row.kind=="perspective":keep=relevant.has(row.id) and useful_views.get(row.parent,{}).size()>1
            elif row.kind=="other_view":keep=seeds.has(row.id) and useful_views.get(by_id.get(branch_of.get(row.id,""),{}).get("parent",""),{}).size()>1
            elif row.kind=="event":
                if not row.get("visible_here",true) or row.event.kind=="undisclosed":keep=false
                elif row.event.kind in ["sensory","spatial","turn","damage"] and not direct.has(row.id):keep=false
        if keep:visible[row.id]=row
    var children={};var roots:Array=[]
    for row in index.get("rows",[]):
        if not visible.has(row.id):continue
        # Display-only compression retains the true parent on the indexed row.
        var parent:String=row.parent
        while by_id.has(parent) and not visible.has(parent):parent=by_id[parent].parent
        if not visible.has(parent):roots.append(row)
        else:
            if not children.has(parent):children[parent]=[]
            children[parent].append(row)
    for parent in children:
        children[parent]=children[parent].filter(func(row):return row.kind!="event")+children[parent].filter(func(row):return row.kind=="event")
    for row in roots:_append_tree(row,children,0)
    queue_redraw()

func _append_tree(row: Dictionary, children: Dictionary, depth: int) -> void:
    var matching = filter.is_empty() or filter.to_lower() in (row.label+" "+row.kind+" "+row.get("actor_name","")+" "+row.get("status","")+" "+row.get("reason","")+" "+row.get("source","")).to_lower()
    if matching:
        rows.append({"row":row,"depth":depth,"children":children.has(row.id)})
    if not collapsed.get(row.id,false) or not filter.is_empty():
        for child in children.get(row.id,[]): _append_tree(child,children,depth+1)

func reveal(id:String)->void:
    var by_id={}
    for row in index.get("rows",[]):by_id[row.id]=row
    var parent:String=by_id.get(id,{}).get("parent","")
    while by_id.has(parent):collapsed[parent]=false;parent=by_id[parent].parent
    _open_occurrence(id,by_id)
    selection=id;rebuild_rows()
    var top=0.0
    for item in rows:
        if item.row.id==id:scroll_y=maxf(0,top-minf(116,size.y*.35));break
        top+=_height(item.row)
    queue_redraw()

func fit() -> void:
    fit_enabled=true
    pixels_per_second = maxf(1,(size.x-gutter-24)/maxf(.001,index.get("presentation_end_ms",index.get("duration_ms",1000.0))/1000.0))
    origin_ms = 0; queue_redraw()

func _process(_delta: float) -> void:
    prepare_visible(true)
    _prepare_other_rows()
    if thumbnails.poll(): queue_redraw()

func _prepare_other_rows()->void:
    if index.is_empty():return
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

func _sample_cells(row:Dictionary,layout:Dictionary={})->Array:
    var size:Vector2=layout.get("extent",self.size)
    var gutter:float=layout.get("gutter",self.gutter)
    if row.kind=="condition_restore" and row.end_ms==row.start_ms:
        var point=_x(row.start_ms,layout)
        if point<gutter or point>size.x:return []
        return [{"x":clampf(point-37,gutter+2,maxf(gutter+2,size.x-74)),"spacing":74.0,"sample_ms":float(row.start_ms)}]
    var right=minf(size.x,_x(row.end_ms,layout))
    if right<=maxf(gutter+2,_x(row.start_ms,layout)):return []
    var width=maxf(1.0,_x(row.end_ms,layout)-_x(row.start_ms,layout))
    var spacing=width/maxi(1,floori(width/74.0))
    var x=_x(row.start_ms,layout)+maxf(0,ceilf((gutter-_x(row.start_ms,layout))/spacing))*spacing
    var cells:Array=[]
    while x<right-10:
        cells.append({"x":x,"spacing":spacing,"sample_ms":clampf(_time(x+spacing/2,layout),row.start_ms,row.end_ms-0.001)})
        x+=spacing
    return cells

func _cell_key(row:Dictionary,sample_ms:float,view:int)->String:
    return "%s:%s:%d"%[row.id,sample_ms,view]

func prepare_visible(all_quarters:bool=true)->Dictionary:
    # Staging works while this Control is invisible. Both demand and drawing
    # use _sample_cells, so readiness never depends on a hidden _draw callback.
    var signature=[thumbnails.generation,thumbnails.suspended,rows_revision,size,scroll_y,origin_ms,pixels_per_second,gutter,quarter,all_quarters]
    if signature!=preview_signature:
        preview_signature=signature;preview_keys={};preview_demand={};preview_request_errors=[]
        var samples:Array=[]
        var y=RULER-scroll_y
        for item in rows:
            var row:Dictionary=item.row
            var height=_height(row)
            if y+height>=RULER and y<size.y and row.kind in PREVIEW_KINDS and row.get("status")!="missing" and row.get("visible_here",true):
                for cell in _sample_cells(row):samples.append({"row":row,"sample_ms":cell.sample_ms})
            y+=height
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
    if remaining==0 and not drag_playhead and published_layout.get("signature",[])!=preview_signature:
        published_layout={"signature":preview_signature.duplicate(),"rows":rows.duplicate(),"collapsed":collapsed.duplicate(),"scroll_y":scroll_y,"origin_ms":origin_ms,"pixels_per_second":pixels_per_second,"gutter":gutter,"quarter":quarter,"preview_keys":preview_keys.duplicate(),"extent":size}
        thumbnails.set_demand(preview_demand)
        queue_redraw()
    return {"ready":remaining==0 and issues.is_empty(),"settled":remaining==0,"pending":remaining,"errors":issues,"samples":preview_demand.size()}

func _height(row: Dictionary) -> float:
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
    var rows:Array=layout.rows
    var collapsed:Dictionary=layout.collapsed
    var scroll_y:float=layout.scroll_y
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
    var y = RULER-scroll_y
    for item in rows:
        var row: Dictionary = item.row
        var height = _height(row)
        if y+height>=RULER and y<size.y:
            var fill = Color("253449") if row.id==selection else Color("19222f")
            draw_rect(Rect2(0,maxf(y,RULER),gutter,minf(height,y+height-RULER)),fill)
            var label = ("▸ " if collapsed.get(row.id,false) else "▾ ") if item.children else "  "
            var title:String=_label(row)+(" · %d gaps"%missing_counts[row.id] if missing_counts.has(row.id) else "")
            draw_string(font,Vector2(8+item.depth*14,y+20),label+title,HORIZONTAL_ALIGNMENT_LEFT,gutter-22-item.depth*14,13,Color("d9e3ee"))
            var participants=_participants(row)
            if height>=52 and not participants.is_empty():
                draw_string(font,Vector2(22+item.depth*14,y+39),participants,HORIZONTAL_ALIGNMENT_LEFT,gutter-30-item.depth*14,11,Color("a0b1c6"))
            var detail=_movement_label(row)
            if not detail.is_empty():
                draw_string(font,Vector2(22+item.depth*14,y+(58 if row.kind=="body" else 39)),detail,HORIZONTAL_ALIGNMENT_LEFT,gutter-30-item.depth*14,11,Color("a0b1c6"))
            var left = maxf(gutter+2,_x(row.start_ms,layout))
            var right = minf(size.x,_x(row.end_ms,layout))
            if row.kind=="condition_restore" and row.end_ms==row.start_ms:
                var point_cells=_sample_cells(row,layout)
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
                    var cells=_sample_cells(row,layout)
                    if not cells.is_empty():
                        var key:String=preview_keys.get(_cell_key(row,cells[0].sample_ms,quarter),"")
                        if thumbnails.textures.has(key):
                            _draw_audio_waveform(row,thumbnails.textures[key],left,right,y,height,layout)
                        elif thumbnails.errors.has(key):
                            draw_string(font,Vector2(left+5,y+height/2),"Source error",HORIZONTAL_ALIGNMENT_LEFT,right-left-8,11,Color("f4b1a7"))
                elif row.kind in PREVIEW_KINDS and row.get("status")!="missing":
                    var error_shown=false
                    for cell in _sample_cells(row,layout):
                        var x:float=cell.x;var spacing:float=cell.spacing
                        var key:String=preview_keys.get(_cell_key(row,cell.sample_ms,quarter),"")
                        if thumbnails.textures.has(key):
                            var texture: Texture2D = thumbnails.textures[key]
                            var scale = minf(68.0/texture.get_width(),68.0/texture.get_height())
                            var dim = texture.get_size()*scale
                            draw_texture_rect(texture,Rect2(Vector2(x+(spacing-dim.x)/2,y+5),dim),false)
                        else:
                            if thumbnails.errors.has(key) and not error_shown:
                                draw_string(font,Vector2(x+5,y+height/2),"Source error",HORIZONTAL_ALIGNMENT_LEFT,right-x-8,11,Color("f4b1a7"));error_shown=true
                            elif thumbnails.inactive.has(key):draw_line(Vector2(x+spacing*.5-3,y+height*.5),Vector2(x+spacing*.5+3,y+height*.5),Color("94a6b6"),1)
                            elif key.is_empty() and not error_shown:
                                draw_string(font,Vector2(x+5,y+height/2),"Source unavailable",HORIZONTAL_ALIGNMENT_LEFT,right-x-8,11,Color("f4b1a7"));error_shown=true
                else:
                    draw_string(font,Vector2(left+6,y+19),"missing component" if row.get("status")=="missing" else _label(row),HORIZONTAL_ALIGNMENT_LEFT,right-left-8,12,Color("d9e3ee"))
            for marker in row.get("markers",[]):
                var marker_x=_x(marker.at_ms,layout)
                if marker_x<gutter or marker_x>=size.x:continue
                var ink=Color("e9ac65") if marker.kind=="commit" else Color("89c7e0")
                draw_line(Vector2(marker_x,maxf(RULER,y+3)),Vector2(marker_x,y+height-3),ink,1)
                draw_circle(Vector2(marker_x,maxf(RULER+3,y+6)),3,ink)
                if row.id==selection:draw_string(font,Vector2(marker_x+5,maxf(RULER+14,y+14)),marker.kind,HORIZONTAL_ALIGNMENT_LEFT,90,10,ink)
            draw_line(Vector2(0,y+height),Vector2(size.x,y+height),Color("303a49"))
        y += height
    draw_rect(Rect2(0,0,gutter,RULER),Color("222d3c"))
    draw_string(font,Vector2(10,18),"OCCURRENCE / COMPONENT",HORIZONTAL_ALIGNMENT_LEFT,gutter-14,11,Color("a0b1c6"))
    draw_line(Vector2(gutter,0),Vector2(gutter,size.y),Color("556980"),2)
    var play_x = _x(playhead_ms,layout)
    if play_x>=gutter:
        draw_line(Vector2(play_x,0),Vector2(play_x,size.y),Color("f3be66"),2)

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
    var label:String=row.label
    if row.get("status")=="missing" and row.kind!="event":label=label.trim_prefix("Missing · ")
    # The index keeps exact authored identifiers; only display wording changes.
    return label.capitalize()

static func _participants(row:Dictionary)->String:
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

func _get_tooltip(at:Vector2)->String:
    var y=RULER-published_layout.get("scroll_y",0.0)
    for item in published_layout.get("rows",[]):
        if at.y>=maxf(y,RULER) and at.y<y+_height(item.row):
            var row:Dictionary=item.row
            var movement=_movement_label(row)
            if row.has("movement_allowance"):movement+=" (operation boundary)"
            return _label(row)+(" · "+row.actor_name if not row.get("actor_name","").is_empty() else "")+"\n"+movement+"\n"+str(row.get("reason",row.get("component",{}).get("reason",""))).replace("_"," ")+"\n"+str(row.get("source",""))
        y+=_height(item.row)
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
                var y = RULER-published_layout.get("scroll_y",0.0)
                for item in published_layout.get("rows",[]):
                    if event.position.y>=maxf(y,RULER) and event.position.y<y+_height(item.row):
                        selection = item.row.id
                        var toggle=event.position.x<30+item.depth*14 and item.children
                        if toggle:
                            collapsed[item.row.id] = not collapsed.get(item.row.id,false)
                            if not collapsed[item.row.id]:_open_occurrence(item.row.id)
                            rebuild_rows()
                        selected.emit(item.row)
                        if item.row.kind in ["other_view","perspective"]:
                            if event.position.x>=published_layout.get("extent",size).x-82 and not item.row.get("visible_here",true):perspective_requested.emit(item.row)
                        elif event.position.x>drawn_gutter: seek_requested.emit(_time(event.position.x,published_layout))
                        elif not toggle:clip_requested.emit(item.row)
                        queue_redraw(); break
                    y += _height(item.row)
            accept_event()
    elif event is InputEventMouseMotion:
        if drag_gutter:
            gutter=clampf(event.position.x,160,size.x*.5)
            if fit_enabled:fit()
            queue_redraw();accept_event()
        elif drag_playhead:_scrub(event.position.x,false);accept_event()

func _content_height() -> float:
    var height=0.0
    for item in rows: height += _height(item.row)
    return height

func _exit_tree() -> void:
    thumbnails.close()
