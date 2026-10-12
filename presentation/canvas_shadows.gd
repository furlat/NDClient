extends RefCounted
## Native depth casters are isolated measurement helpers. Painted receivers and
## all real lights remain owned by the production native Canvas light path.
const Placement = preload("res://placement.gd")
const CASTER = preload("shadow_caster.gdshader")
const VISIBILITY = preload("shadow_visibility.gdshader")
const COMPOSITE = preload("shadow_composite.gdshader")
const CASTER_PARAMETERS = ["sheet","frame_uv","component_depth","component_support",
    "component_depth_range","component_units","component_reconstruction_origin","component_elevation"]

var enabled := true
var shadow_atlas_size := 2048
var issues: Array = []
var actors: Dictionary = {}
var _parent: Node3D
var _meshes: Dictionary = {}
var _sources: Array = []
var _source_key: Array = []
var _cookie_key: Array = []
var _cookie_images: Dictionary = {}
var _cookie_rects: Dictionary = {}
var _cookie_texture: Texture2D
var _source_texture: ImageTexture
var _updates := 0
var _last_cpu_ms := 0.0

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
    issues.clear()
    var result: Array = []
    var retained := {}
    if not is_instance_valid(_parent): return result
    if not enabled or not _prepare_sources(canvas_sources):
        _clear_actors()
        return result
    for actor in visual_actors:
        if not actor.get("valid",true): continue
        var row: Dictionary=actor.row
        var snapshots := _snapshots(actor.entries,camera)
        if snapshots.is_empty(): continue
        var origin := Placement.contact(row)
        var pixels_per_world := camera.unproject_position(origin+camera.global_basis.x).distance_to(camera.unproject_position(origin))
        var units: float=snapshots[0].component_units
        var zoom: float=units*pixels_per_world
        if zoom<=0.00001: continue
        var ground: float=snapshots[0].ground_pixels*units
        var selection := _dominant(camera.unproject_position(origin))
        if selection<0: continue
        var projection := _projection(camera,origin,ground,units,zoom,_sources[selection])
        var bounds := _bounds(snapshots,origin,ground,projection.position,camera)
        var source: Dictionary=_sources[selection]
        var visible_rect := Rect2(Vector2.ZERO,camera.get_viewport().get_visible_rect().size)
        var cookie_rect := Rect2(source.screen_position-source.span*0.5,source.span)
        var rect: Rect2=(cookie_rect if bounds.unbounded else bounds.rect.grow(2.0*maxf(zoom,1.0))).intersection(cookie_rect).intersection(visible_rect)
        if not rect.has_area(): continue
        # At close range use one sample per source pixel. At distance never
        # allocate a target larger than its actual displayed footprint.
        var sample_scale := maxf(zoom,1.0)
        var first := (rect.position/sample_scale).floor()*sample_scale
        var last := (rect.end/sample_scale).ceil()*sample_scale
        rect=Rect2(first,last-first)
        var size := Vector2i((rect.size/sample_scale).ceil()).max(Vector2i(2,2))
        var id: String=row.id
        retained[id]=true
        if not actors.has(id): actors[id]=_create(id)
        var state: Dictionary=actors[id]
        state.entry.placement=row
        state.source_id=_sources[selection].id
        state.entry.screen_rect=rect
        state.entry.material.set_shader_parameter("dominant_index",selection)
        state.entry.material.set_shader_parameter("source_count",_sources.size())
        state.entry.material.set_shader_parameter("source_data",_source_texture)
        state.entry.material.set_shader_parameter("cookie_atlas",_cookie_texture)
        var key: Array=[snapshots,origin,camera.global_basis,projection,rect,size]
        if state.key!=key:
            _update(state,snapshots,camera,origin,ground,projection,rect,size,pixels_per_world)
            state.key=key
            state.unbounded=bounds.unbounded
        state.entry.node.visible=true
        result.append(state.entry)
    for id in actors.keys():
        if not retained.has(id): _remove(id)
    _last_cpu_ms=float(Time.get_ticks_usec()-started)/1000.0
    return result

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
        sources.append(row)
        key.append([row.id,row.screen_position,row.span,row.height,row.texture.get_rid(),row.energy,row.color])
    if key==_source_key: return true
    if not _prepare_cookies(sources): return false
    # This is a small numeric parameter upload (3 RGBA float texels/source),
    # not image readback, sprite rasterization or per-frame artwork decoding.
    var data := Image.create(3,maxi(sources.size(),1),false,Image.FORMAT_RGBAF)
    for i in sources.size():
        var source: Dictionary=sources[i]
        var rect: Rect2=_cookie_rects[source.texture.get_rid()]
        data.set_pixel(0,i,Color(source.screen_position.x,source.screen_position.y,source.span.x,source.span.y))
        data.set_pixel(1,i,Color(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
        data.set_pixel(2,i,Color(source.strength,0,0,0))
    if _source_texture==null or _source_texture.get_height()!=data.get_height(): _source_texture=ImageTexture.create_from_image(data)
    else: _source_texture.update(data)
    _source_key=key
    _sources=sources
    return true

func _prepare_cookies(sources: Array) -> bool:
    var textures: Dictionary={}
    for source in sources: textures[source.texture.get_rid()]=source.texture
    var key: Array=textures.keys()
    if key==_cookie_key: return true
    var images: Dictionary={}
    for id in textures:
        var image: Image=_cookie_images.get(id)
        if image==null:
            image=textures[id].get_image()
            if image==null or image.is_empty():
                issues.append("Generated shadow cannot read original light cookie once at registration")
                return false
            image=image.duplicate()
            if image.is_compressed(): image.decompress()
            image.convert(Image.FORMAT_RGBA8)
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
    _cookie_texture=ImageTexture.create_from_image(atlas)
    _cookie_rects=rects
    _cookie_images=images
    _cookie_key=key
    return true

func _dominant(foot: Vector2) -> int:
    var selected := -1
    var strongest := 0.0
    for i in _sources.size():
        var source: Dictionary=_sources[i]
        var uv: Vector2=(foot-source.screen_position)/source.span+Vector2.ONE*0.5
        var score: float=source.strength*_cookie_at(_cookie_images[source.texture.get_rid()],uv)
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
        if entry.role=="shadow" or not entry.node.visible or not entry.material.get_shader_parameter("has_component_geometry"): continue
        var snapshot: Dictionary={"id":entry.id,"pivot":entry.pivot,"position":entry.node.global_position,
            "scale_x":entry.placement.get("scale_x",1.0),"basis":camera.global_basis,
            "component_cell_size":Vector2(entry.get("geometry_cell_size",Vector2(128,128))),
            "ground_pixels":float(entry.get("geometry_ground_pixels",19.0))}
        var complete := true
        for parameter in CASTER_PARAMETERS:
            snapshot[parameter]=entry.material.get_shader_parameter(parameter)
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

static func _bounds(snapshots: Array,origin: Vector3,ground: float,light: Vector3,camera: Camera3D) -> Dictionary:
    var first := true
    var rect := Rect2()
    for snapshot in snapshots:
        for x in [0.0,snapshot.component_cell_size.x]:
            for y in [0.0,snapshot.component_cell_size.y]:
                for depth in [snapshot.component_depth_range.x,snapshot.component_depth_range.y]:
                    var point: Vector3=_caster_point(snapshot,x,y,depth,ground)+snapshot.position-origin
                    if point.y>=light.y-0.0001: return {"unbounded":true,"rect":rect}
                    var target: Vector3=light+(point-light)*((ground-light.y)/(point.y-light.y))
                    var projected := camera.unproject_position(origin+target)
                    if first: rect=Rect2(projected,Vector2.ZERO); first=false
                    else: rect=rect.expand(projected)
    return {"unbounded":false,"rect":rect}

func _caster_mesh(cell: Vector2) -> QuadMesh:
    # One vertex grid per delivered native cell. No sprite resizing or padding.
    var size := Vector2i(cell)
    if not _meshes.has(size):
        var mesh := QuadMesh.new()
        mesh.subdivide_width=size.x-1
        mesh.subdivide_depth=size.y-1
        _meshes[size]=mesh
    return _meshes[size]

func _create(id: String) -> Dictionary:
    var viewport := SubViewport.new()
    viewport.name=("ShadowMeasure_"+id).validate_node_name()
    viewport.size=Vector2i(2,2)
    viewport.world_3d=World3D.new()
    viewport.msaa_3d=Viewport.MSAA_DISABLED
    viewport.positional_shadow_atlas_size=shadow_atlas_size
    viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
    viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
    for quadrant in range(4): viewport.set_positional_shadow_atlas_quadrant_subdiv(quadrant,Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1)
    _parent.add_child(viewport)
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
    ground.mesh=PlaneMesh.new()
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
    _parent.add_child(output)
    var entry: Dictionary={"id":id+":generatedShadow","placement":{},"role":"shadow","layer":-1,
        "source_role":-1,"node":output,"material":material,"mobile":true,"screen_rect":Rect2(),"generated_shadow":true}
    return {"viewport":viewport,"root":root,"camera":camera,"ground":ground,"light":light,"casters":{},
        "entry":entry,"key":[],"pending":false,"unbounded":false}

func _update(state: Dictionary,snapshots: Array,camera: Camera3D,origin: Vector3,ground: float,projection: Dictionary,rect: Rect2,size: Vector2i,pixels_per_world: float) -> void:
    var wanted := {}
    for snapshot in snapshots:
        wanted[snapshot.id]=true
        if not state.casters.has(snapshot.id):
            var node := MeshInstance3D.new()
            node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
            node.material_override=ShaderMaterial.new()
            node.material_override.shader=CASTER
            state.root.add_child(node)
            state.casters[snapshot.id]=node
        var caster: MeshInstance3D=state.casters[snapshot.id]
        caster.mesh=_caster_mesh(snapshot.component_cell_size)
        caster.position=snapshot.position-origin
        for parameter in CASTER_PARAMETERS: caster.material_override.set_shader_parameter(parameter,snapshot[parameter])
        caster.material_override.set_shader_parameter("component_cell_size",snapshot.component_cell_size)
        caster.material_override.set_shader_parameter("display_basis",camera.global_basis)
        caster.material_override.set_shader_parameter("sprite_pivot",snapshot.pivot)
        caster.material_override.set_shader_parameter("horizontal_scale",snapshot.scale_x)
        caster.material_override.set_shader_parameter("ground_height",ground)
        var aabb := AABB(_caster_point(snapshot,0,0,snapshot.component_depth_range.x,ground),Vector3.ZERO)
        for x in [0.0,snapshot.component_cell_size.x]:
            for y in [0.0,snapshot.component_cell_size.y]:
                for d in [snapshot.component_depth_range.x,snapshot.component_depth_range.y]: aabb=aabb.expand(_caster_point(snapshot,x,y,d,ground))
        caster.custom_aabb=aabb.grow(0.001)
        RenderingServer.instance_set_custom_aabb(caster.get_instance(),caster.custom_aabb)
    for id in state.casters.keys():
        if not wanted.has(id): state.casters[id].free(); state.casters.erase(id)
    state.viewport.size=size
    var center := _on_plane(camera,rect.get_center(),origin.y+ground)-origin
    var plane_bounds := AABB(center,Vector3.ZERO)
    var helper_range := 2.0
    for point in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
        var corner := _on_plane(camera,point,origin.y+ground)-origin
        plane_bounds=plane_bounds.expand(corner)
        helper_range=maxf(helper_range,projection.position.distance_to(corner)+2.0)
    state.ground.position=plane_bounds.get_center()
    state.ground.mesh.size=Vector2(plane_bounds.size.x,plane_bounds.size.z)+Vector2.ONE*0.01
    state.ground.material_override.set_shader_parameter("helper_position",projection.position)
    state.ground.material_override.set_shader_parameter("helper_range",helper_range)
    state.light.position=projection.position
    state.light.omni_range=helper_range
    var distance: float=maxf(20.0,helper_range*2.0)
    state.camera.transform=Transform3D(camera.global_basis,center+camera.global_basis.z*distance)
    state.camera.size=rect.size.y/pixels_per_world
    state.camera.far=distance*3.0
    state.entry.node.global_transform=Transform3D(camera.global_basis,center+origin)
    state.entry.node.mesh.size=rect.size/pixels_per_world
    state.entry.node.custom_aabb=state.entry.node.mesh.get_aabb()
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
        "target_pixels":pixels,"last_render_gpu_ms":last_gpu_ms,"last_render_cpu_ms":last_cpu_ms,"sources":_sources.size(),"updates":_updates,"wide_depth_bounds":wide_bounds,"sync_cpu_ms":_last_cpu_ms,"selected_sources":selected}

func close() -> void:
    if RenderingServer.frame_post_draw.is_connected(_after_draw): RenderingServer.frame_post_draw.disconnect(_after_draw)
    _clear_actors()
    _parent=null
    _meshes.clear()
    _sources.clear()
    _source_key.clear()
    _cookie_key.clear()
    _cookie_images.clear()
    _cookie_rects.clear()
    _cookie_texture=null
    _source_texture=null
