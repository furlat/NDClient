extends RefCounted
## Native material evaluation only. The caller supplies the occurrence clock.

## spare: closed surfaces of this owner, reused before a new viewport is built.
static func make(parent:Node,source:Material,immutable_source:bool=false,spare:Array=[])->Dictionary:
    while not spare.is_empty():
        var parked:Dictionary=spare.pop_back()
        if not is_instance_valid(parked.get("viewport")) or parked.viewport.get_parent()!=parent:continue
        # The quad keeps its mesh; only the private material and clock change.
        parked.quad.material_override=source.duplicate(not immutable_source)
        return {"viewport":parked.viewport,"quad":parked.quad,"material":parked.quad.material_override,"ready":false,
            "pending":false,"requested_age":-1.0,"drawn_age":-1.0,"closed":false}
    var viewport=SubViewport.new()
    viewport.size=Vector2i(256,256)
    viewport.own_world_3d=true;viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
    parent.add_child(viewport)
    var environment=WorldEnvironment.new();environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_COLOR
    environment.environment.background_color=Color.BLACK
    environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color=Color.WHITE
    viewport.add_child(environment)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=2.0;camera.position.z=1.0;viewport.add_child(camera)
    var quad=MeshInstance3D.new();quad.mesh=QuadMesh.new();quad.mesh.size=Vector2(2,2)
    quad.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # Production templates have no remaining animation owner. Share their
    # immutable shader/textures, but keep uniforms and the clock private. The
    # authoring sandbox can still request a fully isolated resource graph.
    quad.material_override=source.duplicate(not immutable_source)
    viewport.add_child(quad)
    return {"viewport":viewport,"quad":quad,"material":quad.material_override,"ready":false,
        "pending":false,"requested_age":-1.0,"drawn_age":-1.0,"closed":false}

static func sample(surface:Dictionary,seconds:float,clock_parameter:String)->void:
    if surface.closed:return
    if surface.ready and (clock_parameter.is_empty() or is_equal_approx(surface.requested_age,seconds)):return
    if not clock_parameter.is_empty():surface.material.set_shader_parameter(clock_parameter,seconds)
    surface.requested_age=seconds
    surface.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
    if surface.pending:return
    surface.pending=true
    RenderingServer.frame_post_draw.connect(func():
        if surface.closed or not is_instance_valid(surface.viewport):return
        surface.ready=true;surface.pending=false;surface.drawn_age=surface.requested_age,
        CONNECT_ONE_SHOT)

## A closed surface parks in spare (when given) for the owner's next hit.
static func close(surface:Dictionary,spare:Variant=null)->void:
    if surface.is_empty() or surface.closed:return
    surface.closed=true
    if is_instance_valid(surface.viewport):
        surface.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
        if spare is Array:spare.append({"viewport":surface.viewport,"quad":surface.quad})
        else:surface.viewport.queue_free()
