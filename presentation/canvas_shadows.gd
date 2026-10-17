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
const RETAINED_COOKIE_IMAGES=16
const RETAINED_COOKIE_BYTES=4*1024*1024

var enabled := true
var shadow_atlas_size := 2048
var issues: Array = []
var actors: Dictionary = {}
var _parent: Node3D
var _meshes: Dictionary = {}
var _sources: Array = []
var _source_key: Array = []
var _source_revision: int = 0
var _rank_key: Array = []
var _rank_revision: int = 0
var _cookie_key: Array = []
var _cookie_images: Dictionary = {}
var _retained_cookies:Dictionary={}
var _cookie_use:int=0
var _cookie_rects: Dictionary = {}
var _cookie_texture: Texture2D
var _source_texture: ImageTexture
var _updates := 0
var _last_cpu_ms := 0.0
var _last_phases: Dictionary = {}
var _last_counts: Dictionary = {}
var _caster_shapes: Dictionary = {}

func _timed(name: String, started: int) -> void:
    _last_phases[name]=float(_last_phases.get(name,0.0))+(Time.get_ticks_usec()-started)/1000.0

func attach(parent: Node3D) -> void:
    close()
    _parent=parent
    RenderingServer.frame_post_draw.connect(_after_draw)

## visual_actors are the existing displayed records: {row, entries, valid}.
## canvas_sources use displayed viewport pixels: id, screen_position, span,
## height, texture, energy, color, enabled. Their order is the deterministic tie
## order. They are NOT undisclosed backend objects or future prepared actors.
func sync(visual_actors: Array, camera: Camera3D, canvas_sources: Array) -> Array:
    var started := Time.get_ticks_usec()
    _last_phases={};_last_counts={"new_actors":0,"new_casters":0,"new_meshes":0,"cookie_reads":0,"cookie_cache_hits":0,"updated_actors":0,"removed_actors":0}
    issues.clear()
    var result: Array = []
    var retained := {}
    if not is_instance_valid(_parent): _last_cpu_ms=0.0;return result
    # Visibility and light selection do not end the actor's resource lifetime.
    # Keep prepared helpers disabled between casts instead of recreating them
    # when the camera or a light returns.
    for actor in visual_actors:
        if actor.get("valid",true):retained[str(actor.row.id)]=true
    for id in actors.keys():
        if not retained.has(id):_remove(id);_last_counts.removed_actors+=1
    var shown:Dictionary={}
    var phase_started:=Time.get_ticks_usec()
    if not enabled or not _prepare_sources(canvas_sources):
        _timed("sources",phase_started);phase_started=Time.get_ticks_usec()
        _hide_unshown(shown)
        _timed("retire",phase_started);_last_cpu_ms=float(Time.get_ticks_usec()-started)/1000.0
        return result
    _timed("sources",phase_started)
    var view_key:Array=[camera.global_transform,camera.size,camera.get_viewport().get_visible_rect().size,_rank_revision,_sources.size(),_source_texture,_cookie_texture]
    for actor in visual_actors:
        if not actor.get("valid",true): continue
        var row: Dictionary=actor.row
        phase_started=Time.get_ticks_usec()
        # Every snapshot, layout and binding input of an unchanged actor: its
        # layers' material versions, transforms and bind-time fields, its
        # contact, the camera/view and the light sources. Equal inputs give
        # the same key below, so the shown helper is kept as it is.
        var contact:Vector3=Placement.contact(row)
        # Ranking uses each flame cycle's mean; only the dominant source's live
        # position/height/cookie feed this actor's projection and footprint.
        var dominant:int=_dominant(camera.unproject_position(contact))
        var live_source:Array=[] if dominant<0 else [_sources[dominant].screen_position,_sources[dominant].height,_sources[dominant].cookie_position,_sources[dominant].span]
        var input_key:Array=[view_key,contact,dominant,live_source]
        for entry in actor.entries:
            input_key.append([entry.node.visible,entry.get("source_version",0),entry.node.global_position,entry.get("pivot"),
                entry.get("geometry_cell_size"),entry.get("geometry_ground_pixels"),entry.placement.get("scale_x",1.0)])
        var held: Dictionary=actors.get(str(row.id),{})
        if not held.is_empty() and held.get("input_key")==input_key:
            shown[str(row.id)]=true
            held.entry.node.visible=true
            result.append(held.entry)
            _last_counts.retained_actors=int(_last_counts.get("retained_actors",0))+1
            _timed("retained",phase_started)
            continue
        if not held.is_empty():held.erase("input_key")
        phase_started=Time.get_ticks_usec()
        var snapshots := _snapshots(actor.entries,camera)
        _timed("snapshots",phase_started)
        if snapshots.is_empty(): continue
        phase_started=Time.get_ticks_usec()
        var origin := Placement.contact(row)
        var pixels_per_world := camera.unproject_position(origin+camera.global_basis.x).distance_to(camera.unproject_position(origin))
        var units: float=snapshots[0].component_units
        var zoom: float=units*pixels_per_world
        if zoom<=0.00001: _timed("layout",phase_started);continue
        var ground: float=snapshots[0].ground_pixels*units
        for snapshot in snapshots:
            snapshot.caster_shape=_caster_shape(snapshot,ground)
        var selection := _dominant(camera.unproject_position(origin))
        if selection<0: _timed("layout",phase_started);continue
        var projection := _projection(camera,origin,ground,units,zoom,_sources[selection])
        var bounds := _bounds(snapshots,origin,ground,projection.position,camera)
        var source: Dictionary=_sources[selection]
        var visible_rect := Rect2(Vector2.ZERO,camera.get_viewport().get_visible_rect().size)
        var cookie_rect := Rect2(source.cookie_position-source.span*0.5,source.span)
        var rect: Rect2=(cookie_rect if bounds.unbounded else bounds.rect.grow(2.0*maxf(zoom,1.0))).intersection(cookie_rect).intersection(visible_rect)
        if not rect.has_area(): _timed("layout",phase_started);continue
        # At close range use one sample per source pixel. At distance never
        # allocate a target larger than its actual displayed footprint.
        var sample_scale := maxf(zoom,1.0)
        rect=_sampling_rect(rect,sample_scale)
        var size := Vector2i((rect.size/sample_scale).round())
        var id: String=row.id
        _timed("layout",phase_started)
        if not actors.has(id):
            phase_started=Time.get_ticks_usec();actors[id]=_create(id)
            _timed("create",phase_started);_last_counts.new_actors+=1
        phase_started=Time.get_ticks_usec()
        var state: Dictionary=actors[id]
        state.entry.placement=row
        state.source_id=_sources[selection].id
        state.entry.screen_rect=rect
        state.entry.material.set_shader_parameter("dominant_index",selection)
        state.entry.material.set_shader_parameter("source_count",_sources.size())
        state.entry.material.set_shader_parameter("source_data",_source_texture)
        state.entry.material.set_shader_parameter("cookie_atlas",_cookie_texture)
        var key: Array=[snapshots,origin,camera.global_basis,projection,rect,size]
        _timed("bind",phase_started)
        if state.key!=key:
            phase_started=Time.get_ticks_usec()
            _update(state,snapshots,camera,origin,ground,projection,rect,size,pixels_per_world)
            _timed("update",phase_started);_last_counts.updated_actors+=1
            state.key=key
            state.unbounded=bounds.unbounded
        state.entry.node.visible=true
        result.append(state.entry)
        shown[id]=true
        state.input_key=input_key
    phase_started=Time.get_ticks_usec()
    _hide_unshown(shown)
    var retained_shapes:Dictionary={}
    for state in actors.values():
        for id in state.casters:retained_shapes[id]=true
    for id in _caster_shapes.keys():
        if not retained_shapes.has(id):_caster_shapes.erase(id)
    _timed("retire",phase_started)
    _last_cpu_ms=float(Time.get_ticks_usec()-started)/1000.0
    return result

func _hide_unshown(shown: Dictionary) -> void:
    # Only helpers that are not drawn this frame are hidden; shown helpers keep
    # their visibility and update mode instead of toggling every frame.
    for id in actors:
        if shown.has(id): continue
        var state: Dictionary=actors[id]
        state.erase("input_key")
        if state.entry.node.visible: state.entry.node.hide()
        state.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED

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

func _prepare_sources(input: Array) -> bool:
    var sources: Array=[]
    var key: Array=[]
    for source in input:
        if not source.get("enabled",true) or float(source.get("energy",0.0))<=0.0: continue
        if not source.get("texture") is Texture2D or not source.get("span") is Vector2 or not source.get("screen_position") is Vector2 or not source.get("color") is Color:
            issues.append("Generated shadow requires the exact native 2D source projection/cookie: "+str(source.get("id","")))
            return false
        if source.span.x<=0 or source.span.y<=0: continue
        var colour: Color=source.color.srgb_to_linear()
        var strength: float=source.energy*(0.2126*colour.r+0.7152*colour.g+0.0722*colour.b)
        if strength<=0: continue
        var row: Dictionary=source.duplicate()
        row.strength=strength
        row.cookie_position=source.get("cookie_position",source.screen_position)
        row.shadow_cookie_position=source.get("cookie_position",source.get("shadow_rank_position",source.screen_position))
        row.shadow_rank_position=source.get("shadow_rank_position",source.screen_position)
        row.shadow_rank_strength=float(source.get("shadow_rank_energy",source.energy))*(0.2126*colour.r+0.7152*colour.g+0.0722*colour.b)
        sources.append(row)
        key.append([row.id,row.screen_position,row.cookie_position,row.span,row.height,row.texture.get_rid(),row.energy,row.color,row.shadow_rank_position,row.shadow_rank_strength])
    if key==_source_key: return true
    if not _prepare_cookies(sources): return false
    # This is a small numeric parameter upload (3 RGBA float texels/source),
    # not image readback, sprite rasterization or per-frame artwork decoding.
    var data := Image.create(3,maxi(sources.size(),1),false,Image.FORMAT_RGBAF)
    for i in sources.size():
        var source: Dictionary=sources[i]
        var rect: Rect2=_cookie_rects[source.texture.get_rid()]
        data.set_pixel(0,i,Color(source.cookie_position.x,source.cookie_position.y,source.span.x,source.span.y))
        data.set_pixel(1,i,Color(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
        data.set_pixel(2,i,Color(source.strength,0,0,0))
    if _source_texture==null or _source_texture.get_height()!=data.get_height(): _source_texture=ImageTexture.create_from_image(data)
    else: _source_texture.update(data)
    _source_key=key
    _source_revision+=1
    var rank_key:Array=[]
    for source in sources:rank_key.append([source.id,source.shadow_cookie_position,source.span,source.shadow_rank_strength,source.texture.get_rid()])
    if rank_key!=_rank_key:_rank_key=rank_key;_rank_revision+=1
    _sources=sources
    return true

func cookie_prepared(texture: Texture2D) -> bool:
    if texture==null:return false
    var retained:Dictionary=_retained_cookies.get(texture.get_rid(),{})
    return is_same(retained.get("texture"),texture) and retained.get("image")!=null

func _cookie_image(texture: Texture2D) -> Image:
    var id:RID=texture.get_rid()
    var retained:Dictionary=_retained_cookies.get(id,{})
    var image:Image=retained.get("image") if is_same(retained.get("texture"),texture) else null
    if image==null:
        _last_counts.cookie_reads=int(_last_counts.get("cookie_reads",0))+1
        image=texture.get_image()
        if image==null or image.is_empty():
            issues.append("Generated shadow cannot read original light cookie once at registration")
            return null
        image=image.duplicate()
        if image.is_compressed():image.decompress()
        image.convert(Image.FORMAT_RGBA8)
        # Retain the exact native texture, never just a recyclable RID.
        retained={"texture":texture,"image":image,"bytes":image.get_width()*image.get_height()*4,"used":0}
        _retained_cookies[id]=retained
    else:_last_counts.cookie_cache_hits=int(_last_counts.get("cookie_cache_hits",0))+1
    _cookie_use+=1;retained.used=_cookie_use
    return image

func prepare_cookie(texture: Texture2D) -> bool:
    # World preparation calls this only after the native texture's draw fence.
    # CPU image retention does not publish source selection or a shadow atlas.
    var image:Image=_cookie_image(texture)
    var active:Dictionary=_cookie_images.duplicate()
    active[texture.get_rid()]=true
    _trim_cookie_images(active)
    return image!=null

func _prepare_cookies(sources: Array) -> bool:
    var textures: Dictionary={}
    for source in sources: textures[source.texture.get_rid()]=source.texture
    var key: Array=textures.keys()
    if key==_cookie_key: return true
    var phase_started:=Time.get_ticks_usec()
    var images: Dictionary={}
    for id in textures:
        var image:Image=_cookie_image(textures[id])
        if image==null:
            _trim_cookie_images(textures)
            _timed("cookie_read_format",phase_started)
            return false
        images[id]=image
    _trim_cookie_images(textures)
    _timed("cookie_read_format",phase_started);phase_started=Time.get_ticks_usec()
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

func _trim_cookie_images(active:Dictionary)->void:
    var count:int=0;var bytes:int=0
    for id in _retained_cookies:
        if active.has(id):continue
        count+=1;bytes+=_retained_cookies[id].bytes
    # Active source images remain required. Only inactive reuse is bounded;
    # removal never changes a live light or silently skips its fresh readback.
    while count>RETAINED_COOKIE_IMAGES or bytes>RETAINED_COOKIE_BYTES:
        var oldest:RID;var use:int=9223372036854775807
        for id in _retained_cookies:
            if not active.has(id) and _retained_cookies[id].used<use:
                oldest=id;use=_retained_cookies[id].used
        bytes-=_retained_cookies[oldest].bytes;count-=1
        _retained_cookies.erase(oldest)

func _dominant(foot: Vector2) -> int:
    var selected := -1
    var strongest := 0.0
    for i in _sources.size():
        var source: Dictionary=_sources[i]
        var uv: Vector2=(foot-source.shadow_cookie_position)/source.span+Vector2.ONE*0.5
        var score: float=source.shadow_rank_strength*_cookie_at(_cookie_images[source.texture.get_rid()],uv)
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

static func _projection(camera: Camera3D,origin: Vector3,ground: float,units: float,zoom: float,source: Dictionary) -> Dictionary:
    var foot := _on_plane(camera,camera.unproject_position(origin),origin.y+ground)-origin
    var on_ground := _on_plane(camera,source.screen_position,origin.y+ground)-origin
    var height := maxf(64.0*units,(64.0+source.height/zoom)*units)
    var offset := Vector3(on_ground.x-foot.x,0,on_ground.z-foot.z)
    var slope := offset.length()/height
    if slope>0.72:
        var excess := slope-0.72
        offset*=(0.72+excess/(1.0+excess/0.08))/slope
    return {"position":foot+offset+Vector3.UP*height,"foot":foot}

static func _snapshots(entries: Array,camera: Camera3D) -> Array:
    var result: Array=[]
    for entry in entries:
        if entry.role=="shadow" or not entry.node.visible or not SourceMaterial.value(entry,"has_component_geometry"): continue
        var snapshot: Dictionary={"id":entry.id,"pivot":entry.pivot,"position":entry.node.global_position,
            "scale_x":entry.placement.get("scale_x",1.0),"basis":camera.global_basis,
            "component_cell_size":Vector2(entry.get("geometry_cell_size",Vector2(128,128))),
            "ground_pixels":float(entry.get("geometry_ground_pixels",19.0))}
        var complete := true
        for parameter in CASTER_PARAMETERS:
            snapshot[parameter]=SourceMaterial.value(entry,parameter)
            if snapshot[parameter]==null: complete=false
        if complete: result.append(snapshot)
    return result

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
            var caster:MeshInstance3D=_create_caster(private,target_id,Vector2(entry.get("geometry_cell_size",Vector2(128,128))))
            for parameter in CASTER_PARAMETERS:caster.material_override.set_shader_parameter(parameter,SourceMaterial.value(entry,parameter))
        prepared.shadow_cursor=index+1
        return false
    if not prepared.has("shadow_state"):
        prepared.shadow_state=_create(prepared.row.id,owner)
        prepared.shadow_state.entry.node.hide()
        return false
    var state:Dictionary=prepared.shadow_state
    var caster:MeshInstance3D=_create_caster(state,entry.id,Vector2(entry.get("geometry_cell_size",Vector2(128,128))))
    for parameter in CASTER_PARAMETERS:caster.material_override.set_shader_parameter(parameter,SourceMaterial.value(entry,parameter))
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
        state.casters=casters;state.caster_samples=samples;state.entry.placement=prepared.row;state.key=[];state.erase("input_key")
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
    prepared.erase("shadow_state")
    return retired

func _create_caster(state:Dictionary,id:String,cell:Vector2)->MeshInstance3D:
    var node:=MeshInstance3D.new()
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
    node.material_override=ShaderMaterial.new()
    node.material_override.shader=CASTER
    node.mesh=_caster_mesh(cell)
    state.root.add_child(node)
    state.casters[id]=node
    return node

func _create(id: String,owner:Node3D=null) -> Dictionary:
    if owner==null:owner=_parent
    var viewport := SubViewport.new()
    viewport.name=("ShadowMeasure_"+id).validate_node_name()
    viewport.size=Vector2i(2,2)
    viewport.world_3d=World3D.new()
    viewport.msaa_3d=Viewport.MSAA_DISABLED
    viewport.positional_shadow_atlas_size=shadow_atlas_size
    viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
    viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
    # RD Omni shadows need two adjacent atlas slots; a one-slot quadrant can
    # never allocate the pair and silently produces an entirely unshadowed map.
    for quadrant in range(4): viewport.set_positional_shadow_atlas_quadrant_subdiv(quadrant,Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4)
    owner.add_child(viewport)
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
    var material := ShaderMaterial.new()
    material.shader=COMPOSITE
    material.set_shader_parameter("visibility_map",viewport.get_texture())
    output.material_override=material
    owner.add_child(output)
    var entry: Dictionary={"id":id+":generatedShadow","placement":{},"role":"shadow","layer":-1,
        "source_role":-1,"node":output,"material":material,"mobile":true,"screen_rect":Rect2(),"generated_shadow":true}
    return {"viewport":viewport,"root":root,"camera":camera,"ground":ground,"light":light,"casters":{},"caster_samples":{},
        "entry":entry,"key":[],"pending":false,"unbounded":false}

func _update(state: Dictionary,snapshots: Array,camera: Camera3D,origin: Vector3,ground: float,projection: Dictionary,rect: Rect2,size: Vector2i,pixels_per_world: float) -> void:
    var update_started:int=Time.get_ticks_usec()
    var wanted := {}
    for snapshot in snapshots:
        wanted[snapshot.id]=true
        if not state.casters.has(snapshot.id):
            _last_counts.new_casters=int(_last_counts.get("new_casters",0))+1
            _create_caster(state,snapshot.id,snapshot.component_cell_size)
        var caster: MeshInstance3D=state.casters[snapshot.id]
        caster.visible=true
        var parameters:Array=[]
        for parameter in CASTER_PARAMETERS:parameters.append(snapshot[parameter])
        var sample_key:Array=[parameters,snapshot.component_cell_size,camera.global_basis,snapshot.pivot,
            snapshot.scale_x,ground,snapshot.position-origin,caster.material_override,caster.material_override.shader]
        var previous:Array=state.caster_samples.get(snapshot.id,[])
        if previous==sample_key:continue
        state.caster_samples[snapshot.id]=sample_key
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
            caster.material_override.set_shader_parameter("frame_uv",snapshot.frame_uv)
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
        var shape:Dictionary=snapshot.caster_shape if snapshot.has("caster_shape") else _caster_shape(snapshot,ground)
        caster.custom_aabb=shape.bounds
        RenderingServer.instance_set_custom_aabb(caster.get_instance(),caster.custom_aabb)
    for id in state.casters:
        if not wanted.has(id):state.casters[id].hide()
    _timed("update_casters",update_started);update_started=Time.get_ticks_usec()
    state.viewport.size=size
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
    _timed("update_camera_output",update_started)
    # Dependency rendering runs before the parent consumes the texture. Keep
    # ALWAYS for this actual frame; frame_post_draw disables unchanged helpers.
    state.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    state.pending=true
    _updates+=1

func _after_draw() -> void:
    for state in actors.values():
        if state.pending:
            state.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
            state.pending=false

func _remove(id: String) -> void:
    var state: Dictionary=actors[id]
    state.entry.node.visible=false
    state.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
    state.entry.node.free()
    state.viewport.free()
    actors.erase(id)

func _clear_actors() -> void:
    for id in actors.keys(): _remove(id)
    _caster_shapes.clear()

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
        selected[state.entry.placement.id]=state.source_id
    return {"actors":actors.size(),"casters":casters,"caster_triangles_before_native_shadow_passes":triangles,
        "target_pixels":pixels,"last_render_gpu_ms":last_gpu_ms,"last_render_cpu_ms":last_cpu_ms,"sources":_sources.size(),"updates":_updates,"wide_depth_bounds":wide_bounds,"sync_cpu_ms":_last_cpu_ms,"selected_sources":selected,
        "sync_phases_ms":_last_phases.duplicate(),"sync_counts":_last_counts.duplicate(),"cookie_cached_images":_retained_cookies.size(),"source_revision":_source_revision,"rank_revision":_rank_revision,
        "phase_accounting":"Cookie read/pack/upload are nested inside sources; other named phases are disjoint."}

func close() -> void:
    if RenderingServer.frame_post_draw.is_connected(_after_draw): RenderingServer.frame_post_draw.disconnect(_after_draw)
    _clear_actors()
    _parent=null
    _meshes.clear()
    _sources.clear()
    _source_key.clear()
    _cookie_key.clear()
    _cookie_images.clear()
    _retained_cookies.clear();_cookie_use=0
    _cookie_rects.clear()
    _cookie_texture=null
    _source_texture=null
