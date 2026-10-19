extends RefCounted
## A camera-aligned render pass, sharing the player's actual World3D.
## Factory finishing colours all phases together; no sprite export or pixel grid.
const LAYER := 1 << 19
const Sources = preload("res://presentation/native_effects.gd")
const Support = preload("res://presentation/native_scene_support.gd")
const ClearSupport = preload("res://presentation/native_clear_support_colour.gd")
const SpellColour = preload("res://presentation/native_spell_colour.gdshader")

static func make(host: Node3D, layer_mask:int=LAYER) -> Dictionary:
    var viewport=SubViewport.new()
    viewport.world_3d=host.get_world_3d()
    viewport.transparent_bg=true
    # Selective receiver clearing must address the same colour/depth images used
    # by the subsequent native transparent pass (no unresolved MSAA attachment).
    viewport.msaa_3d=Viewport.MSAA_DISABLED
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    host.add_child(viewport)
    RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
    var camera=Camera3D.new();viewport.add_child(camera)
    # Additive native effects legitimately carry RGB at zero alpha. Their
    # transparent clear must therefore be black, not the world's sky colour.
    # Duplicate only this pass's environment; receiver lighting is unchanged.
    var environment:Environment=host.get_world_3d().environment
    camera.environment=environment.duplicate() if environment!=null else Environment.new()
    camera.environment.background_mode=Environment.BG_COLOR
    camera.environment.background_color=Color.BLACK
    camera.cull_mask=layer_mask|Support.DEPTH_LAYER
    var canvas=CanvasLayer.new();canvas.layer=0;host.add_child(canvas)
    var output=TextureRect.new();canvas.add_child(output)
    output.mouse_filter=Control.MOUSE_FILTER_IGNORE
    output.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    output.texture=viewport.get_texture()
    output.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    host.camera.cull_mask &= ~layer_mask
    var result={"viewport":viewport,"camera":camera,"output":output,"material":null,"canvas":canvas,"layer_mask":layer_mask}
    sync(result,host)
    return result

static func integrate(layer:Dictionary,support:RefCounted)->void:
    if support.clear_effect==null:
        support.clear_effect=ClearSupport.new()
        support.clear_effect.receiver_depth=support.viewport.get_texture()
    var clear:CompositorEffect=support.clear_effect
    var compositor=Compositor.new();compositor.compositor_effects=[clear]
    layer.camera.compositor=compositor
    layer.clear_support=clear

## A pass's first render allocates its targets and compiles its programs (the
## receiver depth copy, the receiver clear, the colour finish). It happens once,
## before any spell needs the pass: one render with the output hidden, then one
## frame drawing the finish over a transparent texel, which leaves every pixel
## unchanged (premultiplied zero). Returns true once the pass is warm.
static func warm(layer:Dictionary)->bool:
    var step:int=layer.get("warm",0)
    if step>=3:return true
    if layer.get("warm_pending",false):return false
    match step:
        0:layer.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
        1:
            layer.output.material.set_shader_parameter("native_colour",_clear_texel())
            layer.output.visible=true
        2:
            layer.output.material.set_shader_parameter("native_colour",layer.viewport.get_texture())
            layer.output.visible=false
            layer.warm=3
            return true
    layer.warm=step+1;layer.warm_pending=true
    var completed:Callable=func():
        layer.erase("warm_callback")
        layer.warm_pending=false
    layer.warm_callback=completed
    RenderingServer.frame_post_draw.connect(completed,CONNECT_ONE_SHOT)
    return false

static var _clear:ImageTexture
static func _clear_texel()->ImageTexture:
    if _clear==null:_clear=ImageTexture.create_from_image(Image.create(1,1,false,Image.FORMAT_RGBA8))
    return _clear

static func set_enabled(layer:Dictionary,value:bool)->void:
    if value and layer.get("warm",3)<3:
        # A spell claims the pass mid-warm: it is the first real render.
        layer.output.material.set_shader_parameter("native_colour",layer.viewport.get_texture())
        layer.warm=3
    layer.output.visible=value
    layer.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED

static func detach(layer:Dictionary)->void:
    if layer.is_empty():return
    layer.camera.compositor=null
    layer.erase("clear_support")

static func sync(layer: Dictionary,host: Node3D) -> void:
    layer.viewport.size=Vector2i(host.get_viewport().get_visible_rect().size)
    layer.camera.global_transform=host.camera.global_transform
    for property in ["projection","keep_aspect","size","near","far"]:
        layer.camera.set(property,host.camera.get(property))

static func colours(layer: Dictionary,profile: Dictionary,enabled: bool) -> void:
    var material=ShaderMaterial.new();material.shader=SpellColour
    material.set_shader_parameter("native_colour",layer.viewport.get_texture())
    var ramp:Array=profile.get("ramp",[]) if enabled else []
    if not ramp.is_empty():material.set_shader_parameter("ramp_texture",Sources._palette_texture(ramp))
    material.set_shader_parameter("ramp_count",ramp.size())
    for name in ["ramp_floor","ramp_ceiling","ramp_uses_luma"]:
        if profile.get("parameters",{}).has(name):material.set_shader_parameter(name,profile.parameters[name])
    layer.material=material
    layer.output.material=material

static func close(layer:Dictionary)->void:
    if layer.is_empty():return
    var completed:Callable=layer.get("warm_callback",Callable())
    if completed.is_valid() and RenderingServer.frame_post_draw.is_connected(completed):
        RenderingServer.frame_post_draw.disconnect(completed)
    layer.erase("warm_callback")
    detach(layer)
    if is_instance_valid(layer.get("canvas")):layer.canvas.free()
    if is_instance_valid(layer.get("viewport")):layer.viewport.free()
    layer.clear()
