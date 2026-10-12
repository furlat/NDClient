extends RefCounted
## Native 2D receiving lights for an offscreen atlas; visible scene stays 3D.
## Page canvases use identity transforms and physical screen pixel coordinates.
const ExistingLighting = preload("res://presentation/lighting.gd")
const Placement = preload("res://placement.gd")
const OPTICAL_ENERGY = ExistingLighting.OPTICAL_ENERGY
const NORMAL_HEIGHT_SOURCE_PIXELS := 20.0
const TORCH_COLOUR := Color(0.809372,0.429306,0.269121,1.0)
const TORCH_ITEM_IDS = ["equipment.portable_torch","environment.wall_torch"]
const DEFAULT_COOKIE = "C:/Users/tommaso/Documents/Dev/NDCharacterLight/.reference-template/scenes/vfx/textures/T_basic1_vfx.PNG"
var cookie_path: String = ProjectSettings.get_setting("source_data/light_cookie",DEFAULT_COOKIE)
var sources: Array = []
var issues: Array = []
var nodes: Dictionary = {} # First page, keyed by original item UUID.
var directional_nodes: Dictionary = {}
var sampled: Dictionary = {}
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
var _cookie_attempted := false

func apply(material: ShaderMaterial) -> void:
    # The original spatial material remains a source-parameter store only.
    material.set_shader_parameter("authored_base_light",0.0)

static func resolve(state: Dictionary) -> Dictionary:
    return ExistingLighting.resolve(state)

func _update_issues() -> void:
    issues = _resolver.issues + _resource_issues + _directional_issues + _projection_issues

func _load_cookie() -> void:
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
    _update_issues()

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

func _free_page(page: Dictionary) -> void:
    for collection in [page.nodes,page.directionals]:
        for node in collection.values():
            if is_instance_valid(node):
                node.enabled=false
                node.queue_free()
        collection.clear()

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
            var node=PointLight2D.new()
            node.name=("Emitter2D_"+id).validate_node_name()
            node.texture=cookie
            node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
            node.shadow_enabled=false
            node.enabled=false # project() publishes the matching camera position.
            page.parent.add_child(node)
            page.nodes[id]=node
        page.nodes[id].color=_source_colours.get(id,Color.WHITE)
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
        node.energy=source.energy

func _sync_pages() -> void:
    for page in _pages: _sync_page(page)

func sync(state: Dictionary) -> void:
    _canvas_sources.clear()
    var resolved=resolve(state)
    sources=resolved.sources
    _resolver.sources=sources
    _resolver.issues=resolved.issues
    _source_colours.clear()
    var disclosed_items = {}
    for object in state.get("objects",{}).values():
        disclosed_items[object.item.item_uuid]=object.item
    var controlled: Array=state.get("audience",{}).get("controlled",[])
    for id in state.get("actors",{}):
        var actor: Dictionary=state.actors[id]
        var items: Array=actor.get("controlled_items",[]) if id in controlled and actor.get("controlled_items")!=null else actor.get("visual_loadout",{}).get("layers",[])
        for item in items: disclosed_items[item.item_uuid]=item
    for source in sources:
        var item: Dictionary=disclosed_items.get(source.item_uuid,{})
        _source_colours[source.item_uuid]=TORCH_COLOUR if item.get("item_id","") in TORCH_ITEM_IDS else Color.WHITE
    _sync_pages()
    sample({})
    _update_issues()

func sample(actor_rows: Dictionary, source_energy: Dictionary = {}, fixture_heights: Dictionary = {}) -> void:
    _resolver.carried_optical_lift_steps=carried_optical_lift_steps
    _resolver.sampled.clear()
    _resolver.sample(actor_rows,source_energy,fixture_heights)
    sampled=_resolver.sampled
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
        var position: Vector2=camera.unproject_position(value.position)
        var radius: float=source.outer*pixels_per_unit
        var texture_scale: float=radius*2.0/cookie.get_width() if cookie!=null else 1.0
        var colour: Color=_source_colours.get(source.item_uuid,Color.WHITE)
        var active: bool=cookie!=null and value.energy>0
        var span: Vector2=Vector2(cookie.get_size())*texture_scale if cookie!=null else Vector2.ZERO
        _canvas_sources.append({"id":source.item_uuid,"screen_position":position,"span":span,
            "height":height,"energy":value.energy,"color":colour,"texture":cookie,"enabled":active,
            "world_position":value.position,"base_height_steps":source.base_height_steps,"actor_uuid":source.actor_uuid,
            "outer":source.outer,"very_bright_radius_feet":source.very_bright_radius_feet,
            "bright_radius_feet":source.bright_radius_feet,"dim_radius_feet":source.dim_radius_feet})
        for page in _pages:
            if not is_instance_valid(page.parent): continue
            var node: PointLight2D=page.nodes[source.item_uuid]
            node.position=position
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
        for page in _pages:
            if not is_instance_valid(page.parent): continue
            var node: DirectionalLight2D=page.directionals[source.id]
            node.rotation=atan2(planar.x,-planar.y) if not planar.is_zero_approx() else 0.0
            node.height=native_height
            node.enabled=active
    _update_issues()

func _disable_pages() -> void:
    for page in _pages:
        for collection in [page.nodes,page.directionals]:
            for node in collection.values():
                if is_instance_valid(node):node.enabled=false

func canvas_sources() -> Array:
    return _canvas_sources
