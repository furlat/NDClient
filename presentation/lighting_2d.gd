extends RefCounted
## Native 2D receiving lights for an offscreen atlas; visible scene stays 3D.
## Page canvases use identity transforms and physical screen pixel coordinates.
const ExistingLighting = preload("res://presentation/lighting.gd")
const Placement = preload("res://placement.gd")
const OPTICAL_ENERGY = ExistingLighting.OPTICAL_ENERGY
const NORMAL_HEIGHT_SOURCE_PIXELS := 56.0
const Catalog = preload("res://source_catalog.gd")
const RangeProfile = preload("res://presentation/resources/light_range_profile.gd")
const LightCookies = preload("res://presentation/light_cookies.gd")
## The torch appearance's colour and the items that show it, and the cookie
## used without a range profile (environment source lighting entries).
static var TORCH_COLOUR: Color = ExistingLighting.OPTICAL_SETTINGS.value.torch_colour
static var TORCH_ITEM_IDS: Array = ExistingLighting.OPTICAL_SETTINGS.value.torch_item_ids
static var DEFAULT_COOKIE: String = ExistingLighting.OPTICAL_SETTINGS.value.fallback_cookie
var range_profile: RangeProfile = Catalog.light_ranges()
var cookie_path: String = DEFAULT_COOKIE
var sources: Array = []
var issues: Array = []
var nodes: Dictionary = {} # First page, keyed by original item UUID.
var directional_nodes: Dictionary = {}
var sampled: Dictionary = {}
var fire_light_flicker := false
var light_strength := 1.0
var cookie: Texture2D
var carried_optical_lift_steps: float = ExistingLighting.CARRIED_OPTICAL_LIFT_STEPS
var _resolver = ExistingLighting.new() # Never attach: world position calculation only.
var _pages: Array = []
var _source_colours: Dictionary = {}
var _directionals: Array = []
var _resource_issues: Array = []
var _directional_issues: Array = []
var _projection_issues: Array = []
var _canvas_sources: Array = []
var _canvas_directionals: Array = []
var _cookie_attempted := false
var _range_cookies: Dictionary = {}

func apply(material: ShaderMaterial) -> void:
    # The original spatial material remains a source-parameter store only.
    material.set_shader_parameter("authored_base_light",0.0)

static func resolve(state: Dictionary) -> Dictionary:
    # Optical emitters are canonical top-level state, including an observed empty set.
    var optical:Dictionary=state.get("light_sources",{})
    var output: Array = []
    for id in optical:
        var observed: Dictionary = optical[id]
        var actor = str(observed.anchor_entity_uuid) if observed.anchor_entity_uuid != null else ""
        var item = str(observed.anchor_item_uuid) if observed.anchor_item_uuid != null else ""
        var lift = ExistingLighting.CARRIED_OPTICAL_LIFT_STEPS if observed.actor_anchored else ExistingLighting.UNREGISTERED_OPTICAL_LIFT_STEPS
        var position: Array = observed.position
        output.append({"item_uuid":id,"anchor_item_uuid":item,"item_id":"equipment.portable_torch" if observed.appearance=="torch" else "",
            "actor_uuid":actor,"position":Vector3(position[0],(observed.base_height_steps+lift)*Placement.HEIGHT_UNIT,position[1]),
            "base_height_steps":observed.base_height_steps,"very_bright_radius_feet":observed.very_bright_radius_feet,
            "bright_radius_feet":observed.bright_radius_feet,"dim_radius_feet":observed.dim_radius_feet,
            "very":float(observed.very_bright_radius_feet)/5.0,
            "bright":maxf(floor(float(observed.bright_radius_feet)/5.0),1.0),
            "outer":maxf(floor(float(observed.bright_radius_feet+observed.dim_radius_feet)/5.0),1.0)})
    output.sort_custom(func(a,b):return a.item_uuid<b.item_uuid)
    return {"sources":output,"issues":[]}

func _update_issues() -> void:
    issues = _resolver.issues + _resource_issues + _directional_issues + _projection_issues

func _load_cookie() -> void:
    if range_profile != null: return
    if _cookie_attempted: return
    _cookie_attempted = true
    if not FileAccess.file_exists(cookie_path):
        _resource_issues.append("Native 2D light cookie is missing: "+cookie_path)
        _update_issues()
        return
    var image := Image.load_from_file(cookie_path)
    if image == null or image.is_empty():
        _resource_issues.append("Native 2D light cookie cannot be decoded: "+cookie_path)
    else:
        cookie = ImageTexture.create_from_image(image)
        # Like generated cookies, it carries its RGBA8 image for CPU consumers.
        var pixels := image.duplicate()
        if pixels.is_compressed(): pixels.decompress()
        pixels.convert(Image.FORMAT_RGBA8)
        cookie.set_meta(&"cookie_image", pixels)
    _update_issues()

func _source_cookie(source: Dictionary) -> Texture2D:
    if range_profile == null: return cookie
    var outer: float = source.outer
    var very = clampf(float(source.very_bright_radius_feet) / (5.0 * outer), 0.0, 1.0)
    var bright = clampf(maxf(floor(float(source.bright_radius_feet) / 5.0), 1.0) / outer, very, 1.0)
    var key = Vector4(very, bright, range_profile.very_bright_edge, range_profile.bright_edge)
    # One immutable cookie per ratio/profile, shared across emitters. It shapes
    # the receiving plane; it is not an objective light map. Generated off the
    # main thread: null until ready, which preparation waits for.
    if not _range_cookies.has(key): _range_cookies[key] = LightCookies.start(_range_gradient(very, bright))
    return LightCookies.texture(_range_cookies[key])

## True while the cookie this source needs is still being generated.
func cookie_pending(source: Dictionary) -> bool:
    return range_profile != null and _source_cookie(source) == null

func _range_gradient(very: float, bright: float) -> Gradient:
    var gradient = Gradient.new()
    gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
    gradient.offsets = PackedFloat32Array([0.0, 1.0])
    var centre = 1.0 if very > 0 else range_profile.very_bright_edge
    gradient.colors = PackedColorArray([Color(centre, centre, centre), Color.BLACK])
    if very > 0 and very < 1:
        var value = range_profile.very_bright_edge
        gradient.add_point(very, Color(value, value, value))
    if bright > very and bright < 1:
        var value = range_profile.bright_edge
        gradient.add_point(bright, Color(value, value, value))
    return gradient

func prepare_cookie(source: Dictionary) -> Texture2D:
    # Only immutable artwork is admitted here. The current source list, native
    # light nodes and camera projection remain owned by sync()/project().
    _load_cookie()
    return _source_cookie(source)

func attach(parent: Node) -> void:
    clear_pages()
    attach_page(parent)

func attach_page(parent: Node) -> void:
    for page in _pages:
        if page.parent == parent: return
    _load_cookie()
    var page = {"parent":parent,"nodes":{},"directionals":{}}
    _pages.append(page)
    _sync_page(page)
    if _pages.size()==1:
        nodes=page.nodes
        directional_nodes=page.directionals

func detach_page(parent: Node) -> void:
    for index in range(_pages.size()-1,-1,-1):
        var page: Dictionary = _pages[index]
        if page.parent != parent: continue
        _free_page(page)
        _pages.remove_at(index)
    nodes = _pages[0].nodes if not _pages.is_empty() else {}
    directional_nodes = _pages[0].directionals if not _pages.is_empty() else {}

func clear_pages() -> void:
    for page in _pages: _free_page(page)
    _pages.clear()
    nodes={}
    directional_nodes={}
    _canvas_sources.clear()
    _canvas_directionals.clear()

## Terminal teardown only: ordinary page replacement retains range cookies.
func close() -> void:
    clear_pages()
    for cookie in _range_cookies.values():LightCookies.release(cookie)
    _range_cookies.clear()

func _free_page(page: Dictionary) -> void:
    for collection in [page.nodes,page.directionals]:
        for node in collection.values():
            if is_instance_valid(node):
                node.enabled=false
                node.queue_free()
        collection.clear()

func begin_preparation(resolved: Dictionary) -> Dictionary:
    # Candidate nodes are parented to their eventual canvas but stay disabled
    # and outside page membership until the displayed cut adopts them.
    # A retained resolution already owns its cookies and nodes on these pages.
    # Sampling still updates live positions/energy; no emitter was changed here.
    return {"resolved":resolved,"pages":_pages.duplicate(),"nodes":[],"updates":[],"removals":[],
        "colours":{},"wanted":{},"phase":"colours","removal_ids":[],"removal":0,"page":0,"source":0,
        "complete":is_same(resolved.sources,sources),"retained":is_same(resolved.sources,sources)}

func prepare_step(work: Dictionary) -> void:
    if work.complete:return
    var selected:Array=work.resolved.sources
    if work.phase=="colours":
        if work.source<selected.size():
            var source:Dictionary=selected[work.source];work.source+=1
            work.colours[source.item_uuid]=TORCH_COLOUR if source.item_id in TORCH_ITEM_IDS else Color.WHITE
            work.wanted[source.item_uuid]=true
            return
        work.colours.make_read_only()
        work.phase="nodes";work.source=0
    if work.page>=work.pages.size():work.complete=true;return
    var page:Dictionary=work.pages[work.page]
    if work.phase=="removals":
        if work.removal<work.removal_ids.size():
            var id:String=work.removal_ids[work.removal];work.removal+=1
            if not work.wanted.has(id):work.removals.append({"page":page,"id":id,"node":page.nodes[id]})
            return
        work.page+=1;work.source=0;work.phase="nodes"
        work.removal_ids=[];work.removal=0
        return
    if work.source>=selected.size():
        work.phase="removals";work.removal_ids=page.nodes.keys()
        return
    var source:Dictionary=selected[work.source];work.source+=1
    var colour:Color=work.colours[source.item_uuid]
    if page.nodes.has(source.item_uuid):
        var node:PointLight2D=page.nodes[source.item_uuid]
        var texture:Texture2D=_source_cookie(source)
        var colour_changed:bool=node.color!=colour
        var texture_changed:bool=node.texture!=texture
        if colour_changed or texture_changed:
            work.updates.append({"node":node,"colour":colour,"texture":texture,
                "colour_changed":colour_changed,"texture_changed":texture_changed})
        return
    var node:PointLight2D=_make_point(page.parent,source)
    node.color=colour
    work.nodes.append({"page":page,"id":source.item_uuid,"node":node})

func preparation_valid(work: Dictionary) -> bool:
    if not work.get("complete",false) or work.pages.size()!=_pages.size():return false
    for i in _pages.size():
        if not is_same(work.pages[i],_pages[i]) or not is_instance_valid(_pages[i].parent):return false
    for record in work.nodes:
        if not is_instance_valid(record.node) or record.page.nodes.has(record.id):return false
    return true

func publish_prepared(work: Dictionary) -> void:
    if work.get("retained",false):return
    for record in work.nodes:record.page.nodes[record.id]=record.node
    for record in work.updates:
        if record.colour_changed:record.node.color=record.colour
        if record.texture_changed:record.node.texture=record.texture
    for record in work.removals:
        record.node.enabled=false;record.node.queue_free()
        record.page.nodes.erase(record.id)
    work.nodes=[]
    work.updates=[];work.removals=[];work.retained=true
    _canvas_sources.clear()
    sources=work.resolved.sources
    _resolver.sources=sources;_resolver.issues=work.resolved.issues
    _source_colours=work.colours
    # Play samples the actual displayed actor/fixture anchors before project().
    # Publication only adopts the prepared optical membership and native deltas.
    _update_issues()

func _make_point(parent:Node,source:Dictionary) -> PointLight2D:
    var node=PointLight2D.new()
    node.name=("Emitter2D_"+str(source.item_uuid)).validate_node_name()
    node.texture=_source_cookie(source)
    node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
    node.shadow_enabled=false
    node.enabled=false
    parent.add_child(node)
    return node

func _sync_page(page: Dictionary) -> void:
    if not is_instance_valid(page.parent): return
    var wanted = {}
    for source in sources: wanted[source.item_uuid]=true
    for id in page.nodes.keys():
        if wanted.has(id): continue
        page.nodes[id].enabled=false
        page.nodes[id].queue_free()
        page.nodes.erase(id)
    for source in sources:
        var id: String=source.item_uuid
        if not page.nodes.has(id):
            page.nodes[id]=_make_point(page.parent,source)
        page.nodes[id].color=_source_colours.get(id,Color.WHITE)
        page.nodes[id].texture=_source_cookie(source)
    wanted.clear()
    for source in _directionals: wanted[source.id]=true
    for id in page.directionals.keys():
        if wanted.has(id): continue
        page.directionals[id].enabled=false
        page.directionals[id].queue_free()
        page.directionals.erase(id)
    for source in _directionals:
        if not page.directionals.has(source.id):
            var node=DirectionalLight2D.new()
            node.name=("Directional2D_"+source.id).validate_node_name()
            node.shadow_enabled=false
            node.enabled=false
            page.parent.add_child(node)
            page.directionals[source.id]=node
        var node: DirectionalLight2D=page.directionals[source.id]
        node.color=source.colour
        node.energy=source.energy*light_strength

func _sync_pages() -> void:
    for page in _pages: _sync_page(page)

func sync(state: Dictionary) -> void:
    _sync_resolved(resolve(state))

func _sync_resolved(resolved: Dictionary) -> void:
    _canvas_sources.clear()
    _canvas_directionals.clear()
    sources=resolved.sources
    _resolver.sources=sources
    _resolver.issues=resolved.issues
    _source_colours={}
    for source in sources:
        _source_colours[source.item_uuid]=TORCH_COLOUR if source.item_id in TORCH_ITEM_IDS else Color.WHITE
    _sync_pages()
    sample({})
    _update_issues()

func sample(actor_rows: Dictionary, source_energy: Dictionary = {}, fixture_heights: Dictionary = {}, fixture_shadow_heights: Dictionary = {}) -> void:
    # Optical source IDs are independent of private item IDs. Authored fixture
    # registration is usable only when the server also disclosed that item.
    var energies = {}; var heights = {}; var shadow_heights = {}
    for source in sources:
        var anchor: String = source.get("anchor_item_uuid",source.item_uuid)
        if source_energy.has(anchor): energies[source.item_uuid] = source_energy[anchor]
        if fixture_heights.has(anchor): heights[source.item_uuid] = fixture_heights[anchor]
        if fixture_shadow_heights.has(anchor): shadow_heights[source.item_uuid] = fixture_shadow_heights[anchor]
    _resolver.carried_optical_lift_steps=carried_optical_lift_steps
    _resolver.sampled.clear()
    _resolver.sample(actor_rows,energies if fire_light_flicker else {},heights if fire_light_flicker else shadow_heights)
    sampled=_resolver.sampled
    # The casting-source choice uses the complete authored cycle's mean, not
    # whichever flame frame is brightest today. The optional flicker setting only
    # affects fixture energy/optical height; actor contacts remain live.
    for source in sources:
        var value: Dictionary=sampled[source.item_uuid]
        value.support_height_steps = actor_rows.get(source.actor_uuid,{}).get("base_height_steps",source.base_height_steps)
        var position: Vector3=value.position
        var energy: float=value.energy
        if source.actor_uuid.is_empty() and shadow_heights.has(source.item_uuid):
            position.y=(source.base_height_steps+shadow_heights[source.item_uuid])*Placement.HEIGHT_UNIT
            energy=OPTICAL_ENERGY # Fixture cycle luminance is normalized to mean1.
        value.energy*=light_strength
        value.shadow_rank_position=position
        value.shadow_rank_energy=energy*light_strength
    # No view transform is inferred here: project() runs with the published camera.

func set_directionals(policy: Dictionary) -> void:
    _directionals.clear()
    _directional_issues.clear()
    for source in policy.get("directionalSources",[]):
        var values: Array=source.get("directionToSource",[])
        var colour: Array=source.get("colorLinear",[])
        var energy=float(source.get("intensity",-1))
        if values.size()!=3 or colour.size()!=3 or energy<0 or not is_finite(energy):
            _directional_issues.append("Invalid authored directional light: "+str(source.get("id","")))
            continue
        var direction=Vector3(values[0],values[1],values[2])
        if not direction.is_finite() or direction.is_zero_approx() or colour.any(func(value):return not is_finite(float(value)) or float(value)<0):
            _directional_issues.append("Invalid authored directional light: "+str(source.get("id","")))
            continue
        _directionals.append({"id":str(source.id),"direction":direction.normalized(),
            "colour":Color(colour[0],colour[1],colour[2]).linear_to_srgb(),"energy":energy})
    _sync_pages()
    _update_issues()

func project(camera: Camera3D, source_scale: float = 2.0) -> void:
    _projection_issues.clear()
    _canvas_sources.clear()
    _canvas_directionals.clear()
    if camera.projection!=Camera3D.PROJECTION_ORTHOGONAL:
        _projection_issues.append("The native 2D receiving atlas requires the existing orthographic camera")
        _disable_pages()
        _update_issues()
        return
    var centre=camera.global_position-camera.global_basis.z*10.0
    var pixels_per_unit=camera.unproject_position(centre+camera.global_basis.x).distance_to(camera.unproject_position(centre))
    var height=NORMAL_HEIGHT_SOURCE_PIXELS*source_scale/Placement.PIXELS_PER_UNIT*pixels_per_unit
    for source in sources:
        var value: Dictionary=sampled[source.item_uuid]
        var source_cookie = _source_cookie(source)
        var position: Vector2=camera.unproject_position(value.position)
        var radius: float=source.outer*pixels_per_unit
        var texture_scale: float=radius*2.0/source_cookie.get_width() if source_cookie!=null else 1.0
        var colour: Color=_source_colours.get(source.item_uuid,Color.WHITE)
        var active: bool=source_cookie!=null and value.energy>0
        var cookie_scale := Vector2.ONE
        var cookie_position := position
        if range_profile != null:
            # The no-roll orthographic camera projects a support-plane circle
            # into this ellipse. Only the native cookie matrix changes: optical
            # origin and normal height remain the original PointLight2D values.
            cookie_scale.y = absf(camera.global_basis.z.y)
            var support := Vector3(value.position.x, value.get("support_height_steps", source.base_height_steps) * Placement.HEIGHT_UNIT, value.position.z)
            cookie_position = camera.unproject_position(support)
        var span: Vector2=Vector2(source_cookie.get_size())*texture_scale*cookie_scale if source_cookie!=null else Vector2.ZERO
        _canvas_sources.append({"id":source.item_uuid,"screen_position":position,"span":span,
            "texture_scale":texture_scale,"cookie_scale":cookie_scale,"offset":(cookie_position-position)/cookie_scale,
            "height":height,"energy":value.energy,"color":colour,"texture":source_cookie,"enabled":active,
            "shadow_rank_position":camera.unproject_position(value.get("shadow_rank_position",value.position)),
            "shadow_rank_energy":value.get("shadow_rank_energy",value.energy),
            "world_position":value.position,"base_height_steps":source.base_height_steps,"actor_uuid":source.actor_uuid,
            "outer":source.outer,"very_bright_radius_feet":source.very_bright_radius_feet,
            "bright_radius_feet":source.bright_radius_feet,"dim_radius_feet":source.dim_radius_feet})
        if range_profile != null: _canvas_sources[-1]["cookie_position"] = cookie_position
        for page in _pages:
            if not is_instance_valid(page.parent): continue
            var node: PointLight2D=page.nodes[source.item_uuid]
            node.position=position
            node.scale=cookie_scale
            node.offset=_canvas_sources[-1].offset
            node.texture_scale=texture_scale
            node.height=height
            node.energy=value.energy
            node.color=colour
            node.enabled=active
    for source in _directionals:
        var direction: Vector3=source.direction
        var towards=Vector3(camera.global_basis.x.dot(direction),-camera.global_basis.y.dot(direction),camera.global_basis.z.dot(direction))
        var planar=Vector2(towards.x,towards.y)
        var active: bool=towards.z>=-0.000001
        if not active:
            _projection_issues.append("Authored directional light is behind the native 2D receiving plane: "+source.id)
        var native_height: float=maxf(towards.z,0.0)/(planar.length()+maxf(towards.z,0.0)) if active else 0.0
        var rotation:float=atan2(planar.x,-planar.y) if not planar.is_zero_approx() else 0.0
        # The renderer reads -normalized(node.transform.y), not a finite point
        # source. Keep it separate from point-cookie/shadow selection inputs.
        _canvas_directionals.append({"id":source.id,"direction":-Transform2D(rotation,Vector2.ZERO).y.normalized(),
            "height":native_height,"color":source.colour,"energy":source.energy*light_strength,
            "enabled":active and light_strength>0})
        for page in _pages:
            if not is_instance_valid(page.parent): continue
            var node: DirectionalLight2D=page.directionals[source.id]
            node.rotation=rotation
            node.height=native_height
            node.energy=source.energy*light_strength
            node.enabled=active and light_strength>0
    _update_issues()

func _disable_pages() -> void:
    for page in _pages:
        for collection in [page.nodes,page.directionals]:
            for node in collection.values():
                if is_instance_valid(node):node.enabled=false

func canvas_sources() -> Array:
    return _canvas_sources

func canvas_directionals() -> Array:
    return _canvas_directionals
