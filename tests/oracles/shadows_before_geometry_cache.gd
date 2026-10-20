# Frozen bd3c20f7:presentation/canvas_shadows.gd; before geometry cache and fixed viewport.
extends RefCounted
const SourceMaterial=preload("res://presentation/source_material.gd")
## Native depth casters are isolated measurement helpers. Painted receivers and
## all real lights remain owned by the production native Canvas light path.
const Placement = preload("res://placement.gd")
const CASTER = preload("shadow_caster.gdshader")
const VISIBILITY = preload("shadow_visibility.gdshader")
const COMPOSITE = preload("shadow_composite.gdshader")
const CASTER_PARAMETERS = ["sheet","frame_uv","component_depth","component_support",
    "component_depth_range","component_units","component_reconstruction_origin","component_elevation"]
## Every caster operand but the sampled frame, as snapshot keys and as the
## source's parameter names.
const OPERANDS = ["sheet","component_depth","component_support","component_depth_range","component_units","component_reconstruction_origin","component_elevation"]
const OPERAND_NAMES = [&"sheet",&"component_depth",&"component_support",&"component_depth_range",&"component_units",&"component_reconstruction_origin",&"component_elevation"]
## Packed light rows in canvas-source order (the deterministic tie order).
## Live: screen position, height, cookie centre, span, strength. Rank: cookie
## centre, span and the cycle-mean strength. Doubles: every value reaches the
## projection and the ranking exactly as the source carried it.
const LIVE := 8
const RANK := 5
const SOURCE_ROWS := 64 # The composite's light table keeps one texture while this suffices.
const COUNTS := {"new_actors":0,"new_casters":0,"new_meshes":0,"updated_actors":0,"removed_actors":0,"evaluated_actors":0,"retained_actors":0}
## Helpers built ahead with optional work, so a reveal's new actors take them
## instead of constructing worlds, viewports and casters in preparation.
const SPARE_HELPERS := 8
const SPARE_CASTERS := 80

var enabled := true
var shadow_atlas_size := 2048
var issues: Array = []
var actors: Dictionary = {}
var _parent: Node3D
var _meshes: Dictionary = {}
var _source_ids := PackedStringArray()
var _source_textures: Array = []
var _source_live := PackedFloat64Array()
var _source_rank := PackedFloat64Array()
var _source_moved := PackedByteArray() # Rows whose live projection changed at this frame's pack.
var _sources_ready := false
var _source_revision: int = 0
var _rank_revision: int = 0
var _light_revision := -2
var _cookie_key: Array = []
var _cookie_images: Dictionary = {}
var _cookie_rects: Dictionary = {}
var _cookie_texture: Texture2D
var _source_texture: ImageTexture
var _source_data := PackedFloat32Array()
var _view_transform := Transform3D()
var _view_scale := -1.0
var _view_size := Vector2(-1,-1)
var _active := false
var _frame := 0
var _seen: Dictionary = {} # Actor id -> [visual, sampled pose, frame, dominant row] of its last evaluation.
var _shown: Array = [] # Shown helper entries in actor order; a new array only when the set changes.
var _shown_dirty := false
var _dominant_row := -1
var _spare_helpers: Array = []
var _spare_casters: Array = []
var _updates := 0
var _writes := 0
var _last_cpu_ms := 0.0
var _last_phases: Dictionary = {}
var _last_counts: Dictionary = COUNTS.duplicate()
var _caster_shapes: Dictionary = {}

func _timed(name: String, started: int) -> void:
    _last_phases[name]=float(_last_phases.get(name,0.0))+(Time.get_ticks_usec()-started)/1000.0

func attach(parent: Node3D) -> void:
    close()
    _parent=parent

## visual_actors are the existing displayed records: {row, entries, valid}.
## canvas_sources use displayed viewport pixels: id, screen_position, span,
## height, texture, energy, color, enabled. Their order is the deterministic tie
## order. They are NOT undisclosed backend objects or future prepared actors.
## light_revision changes whenever the canvas sources may have changed; -1
## packs them on every call. An actor is evaluated again only when its record,
## its sampled pose, the view, the ranking or its casting light changed. The
## returned array is replaced only when the set of shown helpers changes.
func sync(visual_actors: Array, camera: Camera3D, canvas_sources: Array, light_revision: int = -1) -> Array:
    var started := Time.get_ticks_usec()
    _last_phases.clear();_last_counts=COUNTS.duplicate()
    if not is_instance_valid(_parent): _last_cpu_ms=0.0;return _show([])
    _frame+=1
    var phase_started:=Time.get_ticks_usec()
    var view_size:Vector2=camera.get_viewport().get_visible_rect().size
    var view_changed:bool=camera.global_transform!=_view_transform or camera.size!=_view_scale or view_size!=_view_size
    if view_changed:_view_transform=camera.global_transform;_view_scale=camera.size;_view_size=view_size
    var rank_revision:int=_rank_revision
    if view_changed or light_revision<0 or light_revision!=_light_revision:
        _light_revision=light_revision
        _sources_ready=_prepare_sources(canvas_sources)
    elif not _source_moved.is_empty():_source_moved=PackedByteArray()
    _timed("sources",phase_started)
    var active:bool=enabled and _sources_ready
    # Leaving and returning re-evaluates everyone; helpers are only hidden.
    var force:bool=view_changed or rank_revision!=_rank_revision or active!=_active
    _active=active
    var looked:=0
    for visual in visual_actors:
        if not visual.get("valid",true): continue
        looked+=1
        var id:String=visual.row.id
        var pose:Variant=visual.get("sampled_pose")
        var seen:Variant=_seen.get(id)
        var moved:bool=seen!=null and seen[3]>=0 and seen[3]<_source_moved.size() and _source_moved[seen[3]]==1
        # A null pose is a hidden actor or an unsampled record: always looked at.
        if not force and not moved and pose!=null and seen!=null and is_same(seen[0],visual) and is_same(seen[1],pose):
            seen[2]=_frame;_last_counts.retained_actors+=1
            continue
        _dominant_row=-1
        var shown:bool=active and _evaluate(visual,camera,force or moved)
        _seen[id]=[visual,pose,_frame,_dominant_row]
        var state:Variant=actors.get(id)
        if state!=null and state.shown!=shown:
            state.shown=shown;_shown_dirty=true
            if shown:state.entry.node.visible=true
            else:_hide(state)
    phase_started=Time.get_ticks_usec()
    # Records that left the displayed set retire their helpers.
    if _seen.size()!=looked or actors.size()>looked:
        for id in _seen.keys():
            if _seen[id][2]!=_frame:_seen.erase(id)
        for id in actors.keys():
            if not _seen.has(id):_remove(id);_last_counts.removed_actors+=1
        for id in _caster_shapes.keys():
            if not _caster_owned(id):_caster_shapes.erase(id)
    if _shown_dirty:
        _shown_dirty=false
        var result:Array=[]
        for visual in visual_actors:
            var state:Variant=actors.get(visual.row.id) if visual.get("valid",true) else null
            if state!=null and state.shown:result.append(state.entry)
        _show(result)
    _timed("retire",phase_started)
    _last_cpu_ms=float(Time.get_ticks_usec()-started)/1000.0
    return _shown

func _show(result: Array) -> Array:
    var same:bool=result.size()==_shown.size()
    for i in result.size():
        if not same:break
        same=is_same(result[i],_shown[i])
    if not same:_shown=result
    return _shown

func _caster_owned(id: String) -> bool:
    for state in actors.values():
        if state.casters.has(id):return true
    return false

func _hide(state: Dictionary) -> void:
    if state.entry.node.visible: state.entry.node.hide()
    state.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED

## One actor's helper from its displayed layers. Writes only operands that
## differ from what the helper holds and renders only when one was written.
## Without `relayout` (same view, ranking and casting light) and with the same
## contact and layer geometry, the footprint is kept and only casters update.
func _evaluate(visual: Dictionary, camera: Camera3D, relayout: bool) -> bool:
    var row: Dictionary=visual.row
    var id: String=row.id
    _last_counts.evaluated_actors+=1
    var phase_started:=Time.get_ticks_usec()
    var state: Dictionary=actors.get(id,{})
    var snapshots := _snapshots(visual.entries,camera,state.get("snapshots",[]))
    _timed("snapshots",phase_started)
    if snapshots.is_empty(): return _unlit(state)
    phase_started=Time.get_ticks_usec()
    var origin := Placement.contact(row)
    var units: float=snapshots[0].component_units
    var ground: float=snapshots[0].ground_pixels*units
    var geometry:Array=[origin,ground]
    for snapshot in snapshots:geometry.append(snapshot.geometry)
    if not relayout and not state.is_empty() and state.dominant>=0 and geometry==state.geometry:
        # Only sampled frames or sheets changed: the footprint stays.
        _dominant_row=state.dominant
        state.snapshots=snapshots
        _timed("layout",phase_started);phase_started=Time.get_ticks_usec()
        if _update_casters(state,snapshots,camera,origin,ground,true):_render(state)
        _timed("update",phase_started)
        return true
    var foot:=camera.unproject_position(origin)
    var pixels_per_world := camera.unproject_position(origin+camera.global_basis.x).distance_to(foot)
    var zoom: float=units*pixels_per_world
    if zoom<=0.00001: _timed("layout",phase_started);return _unlit(state)
    for snapshot in snapshots:
        snapshot.caster_shape=_caster_shape(snapshot,ground)
    var selection := _dominant(foot)
    if selection<0: _timed("layout",phase_started);return _unlit(state)
    _dominant_row=selection
    var k:int=selection*LIVE
    var projection := _projection(camera,origin,ground,units,zoom,Vector2(_source_live[k],_source_live[k+1]),_source_live[k+2])
    var bounds := _bounds(snapshots,origin,ground,projection.position,camera)
    var visible_rect := Rect2(Vector2.ZERO,_view_size)
    var span:=Vector2(_source_live[k+5],_source_live[k+6])
    var cookie_rect := Rect2(Vector2(_source_live[k+3],_source_live[k+4])-span*0.5,span)
    var rect: Rect2=(cookie_rect if bounds.unbounded else bounds.rect.grow(2.0*maxf(zoom,1.0))).intersection(cookie_rect).intersection(visible_rect)
    if not rect.has_area(): _timed("layout",phase_started);return _unlit(state)
    # At close range use one sample per source pixel. At distance never
    # allocate a target larger than its actual displayed footprint.
    var sample_scale := maxf(zoom,1.0)
    rect=_sampling_rect(rect,sample_scale)
    var size := Vector2i((rect.size/sample_scale).round())
    _timed("layout",phase_started)
    if state.is_empty():
        phase_started=Time.get_ticks_usec();state=_create(id);actors[id]=state
        _timed("create",phase_started);_last_counts.new_actors+=1
    phase_started=Time.get_ticks_usec()
    state.entry.placement=row
    state.source_id=_source_ids[selection]
    _bind(state,selection)
    var same_place:bool=state.geometry.size()>=2 and state.geometry[0]==origin and state.geometry[1]==ground and state.geometry_basis==camera.global_basis
    state.snapshots=snapshots;state.geometry=geometry;state.geometry_basis=camera.global_basis;state.dominant=selection
    _timed("bind",phase_started);phase_started=Time.get_ticks_usec()
    var written:bool=_update_casters(state,snapshots,camera,origin,ground,same_place)
    var layout:Array=[size,rect,projection.position,origin,ground,pixels_per_world,_view_transform,_view_scale,_view_size]
    if layout!=state.layout:
        state.layout=layout
        _update_layout(state,camera,origin,ground,projection,rect,size,pixels_per_world)
        written=true
    if written:_render(state)
    state.unbounded=bounds.unbounded
    _timed("update",phase_started)
    return true

# Nothing is cast here (no geometry, light or footprint): the helper keeps its
# resources, and its next evaluation lays it out again.
func _unlit(state: Dictionary) -> bool:
    if not state.is_empty():state.dominant=-1
    return false

func _bind(state: Dictionary, selection: int) -> void:
    var material: ShaderMaterial=state.entry.material
    if state.bound_dominant!=selection:
        state.bound_dominant=selection;material.set_shader_parameter("dominant_index",selection);_writes+=1
    if state.bound_count!=_source_ids.size():
        state.bound_count=_source_ids.size();material.set_shader_parameter("source_count",_source_ids.size());_writes+=1
    if not is_same(state.bound_data,_source_texture):
        state.bound_data=_source_texture;material.set_shader_parameter("source_data",_source_texture);_writes+=1
    if not is_same(state.bound_cookies,_cookie_texture):
        state.bound_cookies=_cookie_texture;material.set_shader_parameter("cookie_atlas",_cookie_texture);_writes+=1

func _render(state: Dictionary) -> void:
    # One render in this frame's draw, before the composite samples it; the
    # server disables the target again by itself.
    RenderingServer.viewport_set_update_mode(state.viewport.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ONCE)
    _updates+=1;_last_counts.updated_actors+=1

static func _sampling_rect(rect: Rect2, sample_scale: float) -> Rect2:
    var first := (rect.position/sample_scale).floor()*sample_scale
    var last := (rect.end/sample_scale).ceil()*sample_scale
    # Godot render targets require at least2 samples per axis. Expand the shared
    # screen footprint too, so helper camera and output quad use the same aspect.
    last=last.max(first+Vector2.ONE*2.0*sample_scale)
    # Forward+ rasterizes clustered-light coverage at quarter resolution. A
    # partial final raster sample can leave an unlit strip at a cluster edge
    # (observed at x256 in a257px helper). Pad all shared dimensions together.
    last=first+((last-first)/(sample_scale*4.0)).ceil()*(sample_scale*4.0)
    return Rect2(first,last-first)

## Packs the canvas sources. A changed row set or rank field re-ranks every
## actor; changed live values mark their rows moved; the composite's table is
## uploaded only when its values change.
func _prepare_sources(input: Array) -> bool:
    issues.clear()
    var ids := PackedStringArray()
    var textures: Array=[]
    var live := PackedFloat64Array()
    var rank := PackedFloat64Array()
    for source in input:
        if not source.get("enabled",true) or float(source.get("energy",0.0))<=0.0: continue
        if not source.get("texture") is Texture2D or not source.get("span") is Vector2 or not source.get("screen_position") is Vector2 or not source.get("color") is Color:
            issues.append("Generated shadow requires the exact native 2D source projection/cookie: "+str(source.get("id","")))
            return false
        var span: Vector2=source.span
        if span.x<=0 or span.y<=0: continue
        var colour: Color=source.color.srgb_to_linear()
        var strength: float=source.energy*(0.2126*colour.r+0.7152*colour.g+0.0722*colour.b)
        if strength<=0: continue
        var position: Vector2=source.screen_position
        var cookie: Vector2=source.get("cookie_position",position)
        var rank_cookie: Vector2=source.get("cookie_position",source.get("shadow_rank_position",position))
        ids.append(str(source.id));textures.append(source.texture)
        live.append_array([position.x,position.y,source.height,cookie.x,cookie.y,span.x,span.y,strength])
        rank.append_array([rank_cookie.x,rank_cookie.y,span.x,span.y,float(source.get("shadow_rank_energy",source.energy))*(0.2126*colour.r+0.7152*colour.g+0.0722*colour.b)])
    var same_rows:bool=ids==_source_ids and textures.size()==_source_textures.size()
    for i in textures.size():
        if not same_rows:break
        same_rows=is_same(textures[i],_source_textures[i])
    if same_rows and live==_source_live and rank==_source_rank:
        if not _source_moved.is_empty():_source_moved=PackedByteArray()
        return true
    if not _prepare_cookies(textures): return false
    # A small numeric table (3 RGBA float texels per source) in one texture.
    var data := PackedFloat32Array()
    for i in ids.size():
        var rect: Rect2=_cookie_rects[textures[i].get_rid()]
        var k:int=i*LIVE
        data.append_array(PackedFloat32Array([live[k+3],live[k+4],live[k+5],live[k+6],rect.position.x,rect.position.y,rect.size.x,rect.size.y,live[k+7],0,0,0]))
    data.resize(maxi(SOURCE_ROWS,nearest_po2(ids.size()))*12)
    if data!=_source_data:
        _source_data=data
        var image:=Image.create_from_data(3,data.size()/12,false,Image.FORMAT_RGBAF,data.to_byte_array())
        if _source_texture==null or _source_texture.get_height()!=image.get_height(): _source_texture=ImageTexture.create_from_image(image)
        else: _source_texture.update(image)
        _source_revision+=1
    var moved:=PackedByteArray();moved.resize(ids.size())
    if same_rows:
        for i in ids.size():
            for j in 7:
                if live[i*LIVE+j]!=_source_live[i*LIVE+j]:moved[i]=1;break
    if not same_rows or rank!=_source_rank:_rank_revision+=1
    _source_ids=ids;_source_textures=textures;_source_live=live;_source_rank=rank;_source_moved=moved
    return true

## One packed light row as a dictionary, for checks and diagnostics.
func _source_row(row: int) -> Dictionary:
    var k:int=row*LIVE;var r:int=row*RANK
    return {"id":_source_ids[row],"texture":_source_textures[row],"screen_position":Vector2(_source_live[k],_source_live[k+1]),"height":_source_live[k+2],
        "cookie_position":Vector2(_source_live[k+3],_source_live[k+4]),"span":Vector2(_source_live[k+5],_source_live[k+6]),"strength":_source_live[k+7],
        "shadow_cookie_position":Vector2(_source_rank[r],_source_rank[r+1]),"shadow_rank_strength":_source_rank[r+4]}

## The CPU image of a light cookie. Generated cookies carry it (meta
## cookie_image); nothing is ever read back from the GPU.
func cookie_image(texture: Texture2D) -> Image:
    if texture.has_meta(&"cookie_image"):return texture.get_meta(&"cookie_image")
    var message:="Generated shadow requires a light cookie that carries its image: "+str(texture)
    if not message in issues:issues.append(message)
    return null

func _prepare_cookies(textures: Array) -> bool:
    var unique: Dictionary={}
    for texture in textures: unique[texture.get_rid()]=texture
    var key: Array=unique.keys()
    if key==_cookie_key: return true
    var phase_started:=Time.get_ticks_usec()
    var images: Dictionary={}
    for id in unique:
        var image:Image=cookie_image(unique[id])
        if image==null:return false
        images[id]=image
    var width := 1
    var height := 1
    for image in images.values():
        width=maxi(width,image.get_width()+2)
        height+=image.get_height()+2
    var atlas := Image.create(width,height,false,Image.FORMAT_RGBA8)
    atlas.fill(Color.TRANSPARENT)
    var rects := {}
    var y := 1
    for id in images:
        var image: Image=images[id]
        var size := image.get_size()
        atlas.blit_rect(image,Rect2i(Vector2i.ZERO,size),Vector2i(1,y))
        # One duplicated border preserves each original cookie's clamp + linear
        # sampling, without allowing a neighbouring cookie to bleed into it.
        atlas.blit_rect(image,Rect2i(0,0,size.x,1),Vector2i(1,y-1))
        atlas.blit_rect(image,Rect2i(0,size.y-1,size.x,1),Vector2i(1,y+size.y))
        atlas.blit_rect(image,Rect2i(0,0,1,size.y),Vector2i(0,y))
        atlas.blit_rect(image,Rect2i(size.x-1,0,1,size.y),Vector2i(size.x+1,y))
        atlas.set_pixel(0,y-1,image.get_pixel(0,0))
        atlas.set_pixel(size.x+1,y-1,image.get_pixel(size.x-1,0))
        atlas.set_pixel(0,y+size.y,image.get_pixel(0,size.y-1))
        atlas.set_pixel(size.x+1,y+size.y,image.get_pixel(size.x-1,size.y-1))
        rects[id]=Rect2(Vector2(1,y)/Vector2(width,height),Vector2(size)/Vector2(width,height))
        y+=size.y+2
    _timed("cookie_pack",phase_started);phase_started=Time.get_ticks_usec()
    _cookie_texture=ImageTexture.create_from_image(atlas)
    _timed("cookie_upload",phase_started)
    _cookie_rects=rects
    _cookie_images=images
    _cookie_key=key
    return true

func _dominant(foot: Vector2) -> int:
    var selected := -1
    var strongest := 0.0
    for i in _source_ids.size():
        var k:int=i*RANK
        var uv: Vector2=(foot-Vector2(_source_rank[k],_source_rank[k+1]))/Vector2(_source_rank[k+2],_source_rank[k+3])+Vector2.ONE*0.5
        # Outside its cookie a light scores 0, which never beats the start.
        if uv.x<0 or uv.y<0 or uv.x>=1 or uv.y>=1: continue
        var score: float=_source_rank[k+4]*_cookie_at(_cookie_images[_source_textures[i].get_rid()],uv)
        # Strict comparison preserves exact input order for equal scores.
        if score>strongest: strongest=score; selected=i
    return selected

static func _cookie_at(image: Image,uv: Vector2) -> float:
    if uv.x<0 or uv.y<0 or uv.x>=1 or uv.y>=1: return 0.0
    var p := uv*Vector2(image.get_size())-Vector2.ONE*0.5
    var base := Vector2i(p.floor())
    var fraction := p-p.floor()
    var last := image.get_size()-Vector2i.ONE
    var a := image.get_pixelv(base.clamp(Vector2i.ZERO,last)).lerp(image.get_pixelv((base+Vector2i.RIGHT).clamp(Vector2i.ZERO,last)),fraction.x)
    var b := image.get_pixelv((base+Vector2i.DOWN).clamp(Vector2i.ZERO,last)).lerp(image.get_pixelv((base+Vector2i.ONE).clamp(Vector2i.ZERO,last)),fraction.x)
    var colour := a.lerp(b,fraction.y)
    return maxf(colour.r,maxf(colour.g,colour.b))*colour.a

static func _on_plane(camera: Camera3D,screen: Vector2,height: float) -> Vector3:
    var ray := camera.project_ray_normal(screen)
    var start := camera.project_ray_origin(screen)
    return start+ray*((height-start.y)/ray.y)

static func _projection(camera: Camera3D,origin: Vector3,ground: float,units: float,zoom: float,light: Vector2,light_height: float) -> Dictionary:
    var foot := _on_plane(camera,camera.unproject_position(origin),origin.y+ground)-origin
    var on_ground := _on_plane(camera,light,origin.y+ground)-origin
    var height := maxf(64.0*units,(64.0+light_height/zoom)*units)
    var offset := Vector3(on_ground.x-foot.x,0,on_ground.z-foot.z)
    var slope := offset.length()/height
    if slope>0.72:
        var excess := slope-0.72
        offset*=(0.72+excess/(1.0+excess/0.08))/slope
    return {"position":foot+offset+Vector3.UP*height,"foot":foot}

## Caster inputs of the displayed geometry layers. Given the last evaluated
## snapshots, a layer whose entry, source version, position and geometry
## fields are unchanged keeps its snapshot without reading its operands.
static func _snapshots(entries: Array,camera: Camera3D,previous: Array=[]) -> Array:
    var result: Array=[]
    var cursor:=0
    for entry in entries:
        if entry.role=="shadow" or not entry.node.visible: continue
        var position:Vector3=entry.node.global_position
        var version:int=entry.get("source_version",0)
        var cell:=Vector2(entry.get("geometry_cell_size",Vector2(128,128)))
        var ground_pixels:=float(entry.get("geometry_ground_pixels",19.0))
        if cursor<previous.size() and is_same(previous[cursor].entry,entry):
            var last:Dictionary=previous[cursor];cursor+=1
            if last.id==entry.id and last.position==position and last.basis==camera.global_basis \
                and last.pivot==entry.pivot and last.scale_x==entry.placement.get("scale_x",1.0) \
                and last.component_cell_size==cell and last.ground_pixels==ground_pixels \
                and (last.version==version or _frame_only(entry.source_parameters,last)):
                last.version=version;result.append(last);continue
        if not SourceMaterial.value(entry,"has_component_geometry"): continue
        var snapshot: Dictionary={"id":entry.id,"pivot":entry.pivot,"position":position,
            "scale_x":entry.placement.get("scale_x",1.0),"basis":camera.global_basis,
            "component_cell_size":cell,"ground_pixels":ground_pixels,"entry":entry,"version":version}
        var complete := true
        for parameter in CASTER_PARAMETERS:
            snapshot[parameter]=SourceMaterial.value(entry,parameter)
            if snapshot[parameter]==null: complete=false
        if not complete: continue
        # Everything the footprint depends on; sampled frames and sheets are not.
        snapshot.geometry=[entry.id,position,entry.pivot,snapshot.scale_x,snapshot.basis,cell,ground_pixels,
            snapshot.component_depth_range,snapshot.component_units,snapshot.component_reconstruction_origin,snapshot.component_elevation]
        result.append(snapshot)
    return result

# A new source version that changed at most the sampled frame keeps its
# snapshot; a changed frame is marked for a frame-only caster write.
static func _frame_only(parameters: Dictionary,last: Dictionary) -> bool:
    if not parameters.get(&"has_component_geometry",false): return false
    for i in OPERANDS.size():
        if parameters.get(OPERAND_NAMES[i])!=last[OPERANDS[i]]: return false
    var frame:Variant=parameters.get(&"frame_uv")
    if frame==null: return false
    if frame!=last.frame_uv: last.frame_uv=frame;last.frame_changed=true
    return true

static func _caster_point(snapshot: Dictionary,x: float,y: float,depth: float,ground: float) -> Vector3:
    var units: float=snapshot.component_units
    var elevation: float=snapshot.component_elevation
    var height: float=((snapshot.component_reconstruction_origin.y-y)*cos(elevation)+depth*sin(elevation))*units
    height=ground+(height-ground)*0.5
    var painted: Vector3=snapshot.basis*Vector3((x-snapshot.pivot.x)*snapshot.scale_x,snapshot.pivot.y-y,0)*units
    return painted+snapshot.basis.z*((height-painted.y)/snapshot.basis.z.y)

func _caster_shape(snapshot:Dictionary,ground:float)->Dictionary:
    # Local reconstructed bounds depend on source geometry and camera basis,
    # not animation UVs, a moving light, or the actor's world contact.
    var key:Array=[snapshot.basis,snapshot.component_cell_size,snapshot.component_depth_range,
        snapshot.component_units,snapshot.component_elevation,snapshot.component_reconstruction_origin,
        snapshot.pivot,snapshot.scale_x,ground]
    var previous:Dictionary=_caster_shapes.get(snapshot.id,{})
    if previous.get("key",[])==key:return previous
    var points:Array=[]
    for x in [0.0,snapshot.component_cell_size.x]:
        for y in [0.0,snapshot.component_cell_size.y]:
            for depth in [snapshot.component_depth_range.x,snapshot.component_depth_range.y]:
                points.append(_caster_point(snapshot,x,y,depth,ground))
    var bounds:=AABB(points[0],Vector3.ZERO)
    for point in points:bounds=bounds.expand(point)
    var shape:Dictionary={"key":key,"points":points,"bounds":bounds.grow(0.001)}
    _caster_shapes[snapshot.id]=shape
    return shape

static func _bounds(snapshots: Array,origin: Vector3,ground: float,light: Vector3,camera: Camera3D) -> Dictionary:
    var first := true
    var rect := Rect2()
    for snapshot in snapshots:
        var points:Array=[]
        if snapshot.has("caster_shape"):points=snapshot.caster_shape.points
        else:
            for x in [0.0,snapshot.component_cell_size.x]:
                for y in [0.0,snapshot.component_cell_size.y]:
                    for depth in [snapshot.component_depth_range.x,snapshot.component_depth_range.y]:
                        points.append(_caster_point(snapshot,x,y,depth,ground))
        for local in points:
            var point:Vector3=local+snapshot.position-origin
            if point.y>=light.y-0.0001:return {"unbounded":true,"rect":rect}
            var target:Vector3=light+(point-light)*((ground-light.y)/(point.y-light.y))
            var projected:=camera.unproject_position(origin+target)
            if first:rect=Rect2(projected,Vector2.ZERO);first=false
            else:rect=rect.expand(projected)
    return {"unbounded":false,"rect":rect}

func _caster_mesh(cell: Vector2) -> QuadMesh:
    # One vertex grid per delivered native cell. No sprite resizing or padding.
    var size := Vector2i(cell)
    if not _meshes.has(size):
        _last_counts.new_meshes=int(_last_counts.get("new_meshes",0))+1
        var mesh := QuadMesh.new()
        mesh.subdivide_width=size.x-1
        mesh.subdivide_depth=size.y-1
        _meshes[size]=mesh
    return _meshes[size]

func prepare_actor_step(owner:Node3D,prepared:Dictionary)->bool:
    # The accepted actor boundary owns these disabled native objects until
    # publication. Light selection and animation remain displayed sampling.
    var index:int=prepared.get("shadow_cursor",0)
    if index==0 and prepared.get("reuse_actor",false) and actors.has(prepared.row.id) and not prepared.has("shadow_base"):
        prepared.shadow_base=actors[prepared.row.id]
        prepared.shadow_rekeys=[];prepared.shadow_new={}
    if index>=prepared.entries.size():return true
    var entry:Dictionary=prepared.entries[index]
    if entry.role=="shadow" or not SourceMaterial.value(entry,"has_component_geometry"):
        prepared.shadow_cursor=index+1
        return false
    if prepared.has("shadow_base"):
        var target_id:String=prepared.row.id+":"+str(index)+":"+entry.role
        var before:Dictionary=prepared.shadow_base
        if is_same(prepared.get("retained_entries",{}).get(entry.actor_layer.slot),entry) and before.casters.has(entry.id):
            prepared.shadow_rekeys.append({"before":entry.id,"after":target_id})
        else:
            # Only added/replaced caster resources belong to the hidden owner.
            # The displayed viewport and its existing casters stay untouched.
            var private:Dictionary={"root":owner,"casters":prepared.shadow_new}
            _create_caster(private,target_id,Vector2(entry.get("geometry_cell_size",Vector2(128,128))))
        prepared.shadow_cursor=index+1
        return false
    if not prepared.has("shadow_state"):
        prepared.shadow_state=_create(prepared.row.id,owner)
        return false
    # Operands are bound at the first displayed sample, which writes them all.
    _create_caster(prepared.shadow_state,entry.id,Vector2(entry.get("geometry_cell_size",Vector2(128,128))))
    prepared.shadow_cursor=index+1
    return false

func adopt_actor(prepared:Dictionary)->Array:
    var retired:Array=[]
    if prepared.has("shadow_base"):
        var state:Dictionary=prepared.shadow_base
        var casters:Dictionary={};var samples:Dictionary={};var shapes:Dictionary={}
        for change in prepared.shadow_rekeys:
            casters[change.after]=state.casters[change.before]
            if state.caster_samples.has(change.before):samples[change.after]=state.caster_samples[change.before]
            if _caster_shapes.has(change.before):shapes[change.after]=_caster_shapes[change.before]
        for id in state.casters:
            _caster_shapes.erase(id)
            if state.casters[id] not in casters.values():
                state.casters[id].hide();retired.append(state.casters[id])
        for id in prepared.shadow_new:
            var caster:MeshInstance3D=prepared.shadow_new[id]
            caster.reparent(state.root,false);casters[id]=caster
        _caster_shapes.merge(shapes)
        state.casters=casters;state.caster_samples=samples;state.entry.placement=prepared.row;_forget(state)
        prepared.erase("shadow_base");prepared.erase("shadow_new");prepared.erase("shadow_rekeys")
        return retired
    if not prepared.has("shadow_state"):return retired
    var id:String=prepared.row.id
    if actors.has(id):
        var old:Dictionary=actors[id]
        old.entry.node.hide()
        old.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
        retired=[old.viewport,old.entry.node]
    var state:Dictionary=prepared.shadow_state
    state.viewport.reparent(_parent,false)
    state.entry.node.reparent(_parent,false)
    state.entry.placement=prepared.row
    actors[id]=state
    _forget(state)
    prepared.erase("shadow_state")
    return retired

# The helper's next evaluation lays it out again and the shown set is
# rebuilt: its record or its layers were replaced.
func _forget(state: Dictionary) -> void:
    state.snapshots=[];state.geometry=[];state.layout=[];state.applied={};state.dominant=-1
    _seen.erase(str(state.entry.placement.get("id","")))
    _shown_dirty=true

func _create_caster(state:Dictionary,id:String,cell:Vector2)->MeshInstance3D:
    var node:MeshInstance3D=_spare_casters.pop_back() if not _spare_casters.is_empty() else _new_caster()
    node.mesh=_caster_mesh(cell)
    state.root.add_child(node)
    state.casters[id]=node
    return node

func _new_caster()->MeshInstance3D:
    var node:=MeshInstance3D.new()
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
    node.material_override=ShaderMaterial.new()
    node.material_override.shader=CASTER
    return node

func _create(id: String,owner:Node3D=null) -> Dictionary:
    if owner==null:owner=_parent
    var state:Dictionary=_spare_helpers.pop_back() if not _spare_helpers.is_empty() else _new_helper()
    state.viewport.name=("ShadowMeasure_"+id).validate_node_name()
    owner.add_child(state.viewport)
    owner.add_child(state.entry.node)
    state.entry.id=id+":generatedShadow"
    return state

## A complete disabled helper outside the tree: its own world, camera, light,
## ground and hidden composite quad.
func _new_helper() -> Dictionary:
    var viewport := SubViewport.new()
    viewport.size=Vector2i(2,2)
    viewport.world_3d=World3D.new()
    viewport.msaa_3d=Viewport.MSAA_DISABLED
    viewport.positional_shadow_atlas_size=shadow_atlas_size
    viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
    viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
    # RD Omni shadows need two adjacent atlas slots; a one-slot quadrant can
    # never allocate the pair and silently produces an entirely unshadowed map.
    for quadrant in range(4): viewport.set_positional_shadow_atlas_quadrant_subdiv(quadrant,Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4)
    RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
    var root := Node3D.new()
    viewport.add_child(root)
    var environment := Environment.new()
    environment.background_mode=Environment.BG_COLOR
    environment.background_color=Color.WHITE
    environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_energy=0.0
    var camera := Camera3D.new()
    camera.environment=environment
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.keep_aspect=Camera3D.KEEP_HEIGHT
    root.add_child(camera)
    camera.current=true
    var ground := MeshInstance3D.new()
    # A unit plane sized by its transform: resizing a PlaneMesh rebuilds its
    # native surface (measured up to 9.9 ms when a move starts).
    ground.mesh=PlaneMesh.new()
    ground.mesh.size=Vector2.ONE
    ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ground.material_override=ShaderMaterial.new()
    ground.material_override.shader=VISIBILITY
    root.add_child(ground)
    var light := OmniLight3D.new()
    light.shadow_enabled=true
    light.shadow_bias=0.01
    light.shadow_normal_bias=0.0
    light.shadow_blur=1.5
    light.light_energy=1.0
    light.omni_attenuation=1.0
    root.add_child(light)
    var output := MeshInstance3D.new()
    output.mesh=QuadMesh.new()
    output.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    output.sorting_use_aabb_center=false
    output.visible=false
    var material := ShaderMaterial.new()
    material.shader=COMPOSITE
    material.set_shader_parameter("visibility_map",viewport.get_texture())
    output.material_override=material
    var entry: Dictionary={"id":"","placement":{},"role":"shadow","layer":-1,
        "source_role":-1,"node":output,"material":material,"mobile":true,"screen_rect":Rect2(),"generated_shadow":true}
    return {"viewport":viewport,"root":root,"camera":camera,"ground":ground,"light":light,"casters":{},"caster_samples":{},
        "entry":entry,"layout":[],"geometry":[],"geometry_basis":Basis(),"snapshots":[],"applied":{},"dominant":-1,"shown":false,"unbounded":false,
        "bound_dominant":-2,"bound_count":-1,"bound_data":null,"bound_cookies":null}

## Builds spare helpers, then spare casters, while `budget_usec` lasts.
## Optional work calls it, so reveals rarely construct native objects.
func prepare_spares(budget_usec: int) -> void:
    var deadline:int=Time.get_ticks_usec()+budget_usec
    while Time.get_ticks_usec()<deadline:
        if _spare_helpers.size()<SPARE_HELPERS:_spare_helpers.append(_new_helper())
        elif _spare_casters.size()<SPARE_CASTERS:_spare_casters.append(_new_caster())
        else:return

func spares_needed() -> bool:
    return _spare_helpers.size()<SPARE_HELPERS or _spare_casters.size()<SPARE_CASTERS

## Writes each caster's operands that differ from its last applied snapshot.
## `same_place`: the contact and ground of the applied snapshots still hold, so
## an applied snapshot is current but for a marked frame.
func _update_casters(state: Dictionary,snapshots: Array,camera: Camera3D,origin: Vector3,ground: float,same_place: bool) -> bool:
    var update_started:int=Time.get_ticks_usec()
    var written:=false
    var wanted := {}
    for snapshot in snapshots:
        wanted[snapshot.id]=true
        if not state.casters.has(snapshot.id):
            _last_counts.new_casters=int(_last_counts.get("new_casters",0))+1
            _create_caster(state,snapshot.id,snapshot.component_cell_size)
        var caster: MeshInstance3D=state.casters[snapshot.id]
        if not caster.visible:caster.visible=true;written=true
        var applied:Variant=state.applied.get(snapshot.id)
        if same_place and applied!=null and is_same(applied[0],snapshot) and is_same(applied[1],caster.material_override):
            if snapshot.has("frame_changed"):
                snapshot.erase("frame_changed")
                caster.material_override.set_shader_parameter("frame_uv",snapshot.frame_uv);_writes+=1;written=true
                state.caster_samples[snapshot.id][0][1]=snapshot.frame_uv
                _last_counts.caster_frame_copies=int(_last_counts.get("caster_frame_copies",0))+1
            continue
        state.applied[snapshot.id]=[snapshot,caster.material_override]
        snapshot.erase("frame_changed")
        var parameters:Array=[]
        for parameter in CASTER_PARAMETERS:parameters.append(snapshot[parameter])
        var sample_key:Array=[parameters,snapshot.component_cell_size,camera.global_basis,snapshot.pivot,
            snapshot.scale_x,ground,snapshot.position-origin,caster.material_override,caster.material_override.shader]
        var previous:Array=state.caster_samples.get(snapshot.id,[])
        if previous==sample_key:continue
        state.caster_samples[snapshot.id]=sample_key
        written=true
        # These operands already prove the full caster sample. An animation UV
        # changes no sheet, optical packet, transform, material owner or bounds.
        var frame_only:bool=previous.size()==sample_key.size()
        if frame_only:
            for index in range(1,sample_key.size()):
                if previous[index]!=sample_key[index]:frame_only=false;break
        if frame_only:
            for index in parameters.size():
                if index!=1 and previous[0][index]!=parameters[index]:frame_only=false;break
        if frame_only:
            caster.material_override.set_shader_parameter("frame_uv",snapshot.frame_uv);_writes+=1
            _last_counts.caster_frame_copies=int(_last_counts.get("caster_frame_copies",0))+1
            continue
        _last_counts.caster_full_copies=int(_last_counts.get("caster_full_copies",0))+1
        caster.mesh=_caster_mesh(snapshot.component_cell_size)
        caster.position=snapshot.position-origin
        for parameter in CASTER_PARAMETERS: caster.material_override.set_shader_parameter(parameter,snapshot[parameter])
        caster.material_override.set_shader_parameter("component_cell_size",snapshot.component_cell_size)
        caster.material_override.set_shader_parameter("display_basis",camera.global_basis)
        caster.material_override.set_shader_parameter("sprite_pivot",snapshot.pivot)
        caster.material_override.set_shader_parameter("horizontal_scale",snapshot.scale_x)
        caster.material_override.set_shader_parameter("ground_height",ground)
        _writes+=CASTER_PARAMETERS.size()+5
        var shape:Dictionary=snapshot.caster_shape if snapshot.has("caster_shape") else _caster_shape(snapshot,ground)
        caster.custom_aabb=shape.bounds
        RenderingServer.instance_set_custom_aabb(caster.get_instance(),caster.custom_aabb)
    for id in state.casters:
        if not wanted.has(id) and state.casters[id].visible:state.casters[id].hide();written=true
    _timed("update_casters",update_started)
    return written

func _update_layout(state: Dictionary,camera: Camera3D,origin: Vector3,ground: float,projection: Dictionary,rect: Rect2,size: Vector2i,pixels_per_world: float) -> void:
    var update_started:int=Time.get_ticks_usec()
    # The target follows the exact footprint: its sample grid is the picture.
    if state.viewport.size!=size:state.viewport.size=size
    _timed("update_target",update_started);update_started=Time.get_ticks_usec()
    var center := _on_plane(camera,rect.get_center(),origin.y+ground)-origin
    var plane_bounds := AABB(center,Vector3.ZERO)
    var helper_range := 2.0
    for point in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
        var corner := _on_plane(camera,point,origin.y+ground)-origin
        plane_bounds=plane_bounds.expand(corner)
        helper_range=maxf(helper_range,projection.position.distance_to(corner)+2.0)
    # The visibility shader reads MODEL_MATRIX*VERTEX; unit vertices +-0.5
    # scaled by the size give the same world positions as a sized plane.
    var ground_size:Vector2=Vector2(plane_bounds.size.x,plane_bounds.size.z)+Vector2.ONE*0.01
    state.ground.transform=Transform3D(Basis.from_scale(Vector3(ground_size.x,1.0,ground_size.y)),plane_bounds.get_center())
    state.ground.material_override.set_shader_parameter("helper_position",projection.position)
    state.ground.material_override.set_shader_parameter("helper_range",helper_range)
    _writes+=2
    state.light.position=projection.position
    state.light.omni_range=helper_range
    _timed("update_light_plane",update_started);update_started=Time.get_ticks_usec()
    var distance: float=maxf(20.0,helper_range*2.0)
    state.camera.transform=Transform3D(camera.global_basis,center+camera.global_basis.z*distance)
    state.camera.size=rect.size.y/pixels_per_world
    state.camera.far=distance*3.0
    state.entry.node.global_transform=Transform3D(camera.global_basis,center+origin)
    state.entry.node.mesh.size=rect.size/pixels_per_world
    state.entry.node.custom_aabb=state.entry.node.mesh.get_aabb()
    state.entry.screen_rect=rect
    _timed("update_camera_output",update_started)

func _remove(id: String) -> void:
    var state: Dictionary=actors[id]
    if state.shown:_shown_dirty=true
    state.entry.node.visible=false
    state.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
    state.entry.node.free()
    state.viewport.free()
    actors.erase(id)

func _clear_actors() -> void:
    for id in actors.keys(): _remove(id)
    _caster_shapes.clear()
    _seen.clear()

func diagnostics() -> Dictionary:
    var casters := 0
    var pixels := 0
    var triangles := 0
    var wide_bounds := 0
    var selected := {}
    var last_gpu_ms := 0.0
    var last_cpu_ms := 0.0
    for state in actors.values():
        last_gpu_ms+=RenderingServer.viewport_get_measured_render_time_gpu(state.viewport.get_viewport_rid())
        last_cpu_ms+=RenderingServer.viewport_get_measured_render_time_cpu(state.viewport.get_viewport_rid())
        casters+=state.casters.size()
        for caster in state.casters.values():
            triangles+=2*(caster.mesh.subdivide_width+1)*(caster.mesh.subdivide_depth+1)
        pixels+=state.viewport.size.x*state.viewport.size.y
        if state.unbounded: wide_bounds+=1
        selected[state.entry.placement.id]=state.get("source_id","")
    return {"actors":actors.size(),"casters":casters,"caster_triangles_before_native_shadow_passes":triangles,
        "target_pixels":pixels,"last_render_gpu_ms":last_gpu_ms,"last_render_cpu_ms":last_cpu_ms,"sources":_source_ids.size(),"updates":_updates,"writes":_writes,"wide_depth_bounds":wide_bounds,"sync_cpu_ms":_last_cpu_ms,"selected_sources":selected,
        "sync_phases_ms":_last_phases.duplicate(),"sync_counts":_last_counts.duplicate(),"cookie_images":_cookie_images.size(),"source_revision":_source_revision,"rank_revision":_rank_revision,
        "spare_helpers":_spare_helpers.size(),"spare_casters":_spare_casters.size(),
        "phase_accounting":"Cookie pack/upload are nested inside sources and update_* inside update; other named phases are disjoint."}

func close() -> void:
    _clear_actors()
    _parent=null
    _meshes.clear()
    _source_ids=PackedStringArray();_source_textures=[];_source_live=PackedFloat64Array();_source_rank=PackedFloat64Array()
    _source_moved=PackedByteArray();_source_data=PackedFloat32Array();_sources_ready=false;_light_revision=-2
    _view_scale=-1.0;_view_size=Vector2(-1,-1);_active=false
    _cookie_key.clear()
    _cookie_images.clear()
    _cookie_rects.clear()
    _cookie_texture=null
    _source_texture=null
    _shown=[];_shown_dirty=false
    for state in _spare_helpers:
        state.entry.node.free();state.viewport.free()
    for node in _spare_casters:node.free()
    _spare_helpers.clear();_spare_casters.clear()
