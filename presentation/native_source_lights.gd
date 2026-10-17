extends "res://presentation/lighting_2d.gd"
## Factory lights use the same native receiving atlas as ordinary world lights.
## These optical samples never enter the SDK state or gameplay light categories.
var effect_sources: Array = []
var _effect_roots: Dictionary = {}
var _effect_issues: Array = []
const RETAINED_EFFECT_COOKIES=8
var _effect_cookies: Dictionary = {}
var _effect_cookie_use:int=0
var _prepared_effect_ids:Dictionary={}
var _pending_attenuations:Dictionary={}
var native_preparation_ready:bool=true
var preparation_counts={"roots":0,"cookies":0,"nodes":0,"sample_constructors":0}

func prepare_native_handles(handles:Dictionary,budget:Dictionary={})->bool:
    var started:int=Time.get_ticks_usec()
    var wanted:Dictionary={}
    var retained:Dictionary={}
    var ready:bool=true
    for handle_id in handles:
        var root:Node3D=handles[handle_id].get("root")
        if not is_instance_valid(root):continue
        var instance:int=root.get_instance_id();retained[instance]=true
        if not _effect_roots.has(instance):
            if not budget.is_empty() and budget.used_usec+Time.get_ticks_usec()-started>=budget.limit_usec:ready=false;continue
            var lights:Array=[]
            for node in root.find_children("*","Light3D",true,false):lights.append({"node":node,"path":str(root.get_path_to(node))})
            _effect_roots[instance]=lights;preparation_counts.roots+=1
        for entry in _effect_roots[instance]:
            if not is_instance_valid(entry.node):continue
            var id:String="native-effect/"+str(handle_id)+"/"+str(entry.path)
            wanted[id]=true
            var attenuation:float=entry.node.omni_attenuation if entry.node is OmniLight3D else 0.0
            _pending_attenuations[attenuation]=true
            for page in _pages:
                if not is_instance_valid(page.parent):continue
                if not page.has("effect_nodes"):page.effect_nodes={}
                if page.effect_nodes.has(id):continue
                if not budget.is_empty() and budget.used_usec+Time.get_ticks_usec()-started>=budget.limit_usec:ready=false;continue
                var light=PointLight2D.new();light.name=("EffectLight2D_"+id).validate_node_name()
                light.enabled=false;light.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;light.shadow_enabled=false
                page.parent.add_child(light);page.effect_nodes[id]=light;preparation_counts.nodes+=1
    for attenuation in _pending_attenuations.keys():
        if _effect_cookies.has(attenuation):_pending_attenuations.erase(attenuation);continue
        if not budget.is_empty() and budget.used_usec+Time.get_ticks_usec()-started>=budget.limit_usec:ready=false;continue
        _effect_cookie("",attenuation);preparation_counts.cookies+=1;_pending_attenuations.erase(attenuation)
    for instance in _effect_roots.keys():
        if not retained.has(instance):_effect_roots.erase(instance)
    for page in _pages:
        for id in page.get("effect_nodes",{}).keys():
            if wanted.has(id):continue
            _release_effect_node(page.effect_nodes[id]);page.effect_nodes.erase(id)
    _prepared_effect_ids=wanted;native_preparation_ready=ready
    if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
    return ready

func effect_was_submitted(id:String)->bool:
    for page in _pages:
        var node:PointLight2D=page.get("effect_nodes",{}).get(id)
        if is_instance_valid(node) and node.enabled and node.is_visible_in_tree():return true
    return false

func sample_handles(handles: Dictionary, support_y: float = 0.0, optical: Dictionary = {}) -> void:
    effect_sources.clear()
    _effect_issues.clear()
    var retained := {}
    for handle_id in handles:
        var handle: Dictionary = handles[handle_id]
        var root: Node3D = handle.get("root")
        var occurrence_optical:Dictionary=handle.get("optical",optical)
        var occurrence_support:float=handle.get("support_y",support_y)
        if not is_instance_valid(root):
            _effect_issues.append("Native effect light root is unavailable: " + str(handle_id))
            continue
        var instance := root.get_instance_id()
        retained[instance] = true
        # The sandbox root converts Factory source units into game units.
        # Light3D disables transform scaling, so its range needs this same
        # explicit conversion once, just like native particle distances.
        var unit_scale := absf(root.global_basis.get_scale().x)
        if not _effect_roots.has(instance):
            native_preparation_ready=false;_effect_issues.append("Native effect lights awaiting preparation: "+str(handle_id));continue
        for entry in _effect_roots[instance]:
            var id := "native-effect/" + str(handle_id) + "/" + str(entry.path)
            if not is_instance_valid(entry.node):
                _effect_issues.append("Native effect light was removed after construction: " + id)
                continue
            var light: Light3D = entry.node
            if not light is OmniLight3D:
                _effect_issues.append("Native 2D source bridge does not support " + light.get_class() + ": " + id)
                continue
            if light.light_negative:
                _effect_issues.append("Native 2D source bridge does not support subtractive effect lights: " + id)
                continue
            var position := light.global_position
            # Factory playback converts the native renderer property after
            # sampling its animation. Read the retained source units so the
            # 2D receiver neither skips nor repeats that conversion.
            var units:Dictionary=handle.get("light_units",{}).get(light.get_instance_id(),{})
            var source_range: float = units.get("range",light.omni_range)
            var radius: float = source_range * unit_scale
            # A Factory finishing profile can change the visible spell hue.
            # Its explicit optical identity must also reach painted receivers;
            # preserve the donor node for its source animation and inspection.
            var colour: Color = occurrence_optical.get("color", light.light_color)
            var energy:float=light.light_energy*float(occurrence_optical.get("energy_multiplier",1.0))
            if not position.is_finite() or not is_finite(occurrence_support) or not is_finite(radius) or not is_finite(energy) or not _finite_colour(colour):
                _effect_issues.append("Native effect light has nonfinite authored optical data: " + id)
                continue
            # The source-unit owner restores raw values before native animation;
            # colour and energy stay authored, including optical hue overrides.
            effect_sources.append({"id":id, "world_position":position,
                "support_y":occurrence_support, "radius":radius, "energy":energy,
                "source_range":source_range, "world_range":radius, "unit_scale":unit_scale,
                "color":colour, "native_color":light.light_color, "visible":light.is_visible_in_tree(),
                "native_attenuation":light.omni_attenuation})
    effect_sources.sort_custom(func(a, b): return a.id < b.id)
    _update_issues()

func _effect_cookie(_id: String, attenuation: float) -> GradientTexture2D:
    # The grayscale image depends only on exact source attenuation. Position,
    # colour, radius and energy remain per-light values below. Never mutate an
    # admitted texture: shadow registration observes its immutable RID/image.
    if not _effect_cookies.has(attenuation):
        var texture := GradientTexture2D.new()
        texture.width = 256; texture.height = 256
        texture.fill = GradientTexture2D.FILL_RADIAL
        texture.fill_from = Vector2(.5, .5); texture.fill_to = Vector2(1.0, .5)
        texture.gradient = Gradient.new()
        var offsets := PackedFloat32Array()
        var colours := PackedColorArray()
        for index in 65:
            var radius := float(index) / 64.0
            # A smooth range envelope, shaped by the donor attenuation. This is
            # a Canvas optical approximation, not OmniLight3D inverse-distance
            # attenuation or the game's bright/dim category cookie.
            var envelope := 1.0 - smoothstep(0.0, 1.0, radius)
            var value := pow(envelope, 1.0 + maxf(0.0, attenuation))
            offsets.append(radius); colours.append(Color(value, value, value, 1.0))
        texture.gradient.offsets = offsets
        texture.gradient.colors = colours
        _effect_cookies[attenuation]={"texture":texture,"used":0}
    var cookie:Dictionary=_effect_cookies[attenuation]
    _effect_cookie_use+=1;cookie.used=_effect_cookie_use
    return cookie.texture

func _trim_effect_cookies()->void:
    var active:Dictionary={}
    for source in effect_sources:active[source.native_attenuation]=true
    var inactive:int=0
    for attenuation in _effect_cookies:
        if not active.has(attenuation):inactive+=1
    while inactive>RETAINED_EFFECT_COOKIES:
        var oldest:Variant=null;var use:int=9223372036854775807
        for attenuation in _effect_cookies:
            if not active.has(attenuation) and _effect_cookies[attenuation].used<use:
                oldest=attenuation;use=_effect_cookies[attenuation].used
        _effect_cookies.erase(oldest);inactive-=1

func clear_pages()->void:
    super.clear_pages()
    _effect_cookies.clear();_effect_cookie_use=0;_prepared_effect_ids.clear();_pending_attenuations.clear();native_preparation_ready=true

func project(camera: Camera3D, source_scale: float = 2.0) -> void:
    super.project(camera, source_scale)
    if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
        _disable_effect_pages()
        return
    var centre := camera.global_position - camera.global_basis.z * 10.0
    var pixels_per_unit := camera.unproject_position(centre + camera.global_basis.x).distance_to(camera.unproject_position(centre))
    var vertical := camera.global_basis.z.y
    if vertical <= 0.000001:
        _projection_issues.append("Native effect support-plane lights require the existing downward isometric camera")
        _disable_effect_pages()
        _update_issues()
        return
    var wanted := {}
    for source in effect_sources: wanted[source.id] = true
    for page in _pages:
        if not is_instance_valid(page.parent): continue
        if not page.has("effect_nodes"): page.effect_nodes = {}
        for id in page.effect_nodes:
            if not wanted.has(id):page.effect_nodes[id].enabled=false
    for source in effect_sources:
        var position: Vector3 = source.world_position
        var screen := camera.unproject_position(position)
        var cookie:Dictionary=_effect_cookies.get(source.native_attenuation,{})
        var texture:GradientTexture2D=cookie.get("texture")
        if texture==null:
            _pending_attenuations[source.native_attenuation]=true;native_preparation_ready=false
            _effect_issues.append("Native light attenuation awaiting preparation: "+source.id)
            continue
        var radius: float = source.radius
        var energy: float = source.energy * light_strength
        # PointLight2D height is depth towards the camera in canvas pixels.
        # Project the actual vertical optical separation, rather than borrowing
        # the fixed torch's56-source-pixel normal-height calibration.
        var height: float = maxf(0.0, position.y - source.support_y) * vertical * pixels_per_unit
        var active: bool = source.visible and radius > 0.0 and energy > 0.0 and texture != null and position.y >= source.support_y
        var texture_scale: float = 2.0 * radius * pixels_per_unit / texture.get_width() if texture != null else 0.0
        var span := Vector2(texture.get_size()) * texture_scale if texture != null else Vector2.ZERO
        _canvas_sources.append({"id":source.id, "screen_position":screen,
            "cookie_position":screen, "span":span, "height":height,
            "texture_scale":texture_scale, "cookie_scale":Vector2.ONE, "offset":Vector2.ZERO,
            "energy":energy, "color":source.color, "texture":texture,
            "enabled":active, "shadow_rank_position":screen,
            "shadow_rank_energy":energy, "world_position":position,
            "base_height_steps":source.support_y / Placement.HEIGHT_UNIT,
            "actor_uuid":"", "outer":radius})
        for page in _pages:
            if not is_instance_valid(page.parent): continue
            if not page.effect_nodes.has(source.id):
                native_preparation_ready=false;_effect_issues.append("Native light page awaiting preparation: "+source.id);continue
            var light: PointLight2D = page.effect_nodes[source.id]
            light.texture = texture
            light.position = screen
            light.scale = Vector2.ONE
            light.offset = Vector2.ZERO
            light.texture_scale = texture_scale
            light.height = height
            light.energy = energy
            light.color = source.color
            light.enabled = active
    _update_issues()

func _update_issues() -> void:
    super._update_issues()
    issues.append_array(_effect_issues)

func _free_page(page: Dictionary) -> void:
    for node in page.get("effect_nodes", {}).values(): _release_effect_node(node)
    if page.has("effect_nodes"): page.effect_nodes.clear()
    super._free_page(page)

func _disable_effect_pages() -> void:
    for page in _pages:
        for node in page.get("effect_nodes", {}).values():
            if is_instance_valid(node): node.enabled = false

static func _release_effect_node(node: PointLight2D) -> void:
    if not is_instance_valid(node): return
    node.enabled = false
    node.queue_free()

static func _finite_colour(value: Color) -> bool:
    return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
