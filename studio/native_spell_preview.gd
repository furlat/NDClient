extends Node
## Source-only thumbnail. Uses the same package effect and finishing shader;
## the actual replay continues to use NativeSpellRenderer in its player world.
const Effects=preload("res://presentation/effect_package.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const Layer=preload("res://presentation/native_effect_layer.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
var viewport:SubViewport
var output:SubViewport
var camera:Camera3D
var handle:Dictionary={}
var component:Dictionary={}
var prepared:Dictionary={}
var sampled:=-1.0
var drawn:=-1.0
var drawn_basis:=Basis.IDENTITY
var rect:TextureRect
var source_parent:Node3D
static var _live_built_frame:int=-1

## A parked swatch keeps its viewports; the next component replaces only its
## source and colour finish.
func configure_component(value:Dictionary)->String:
    component=value
    if is_instance_valid(output):
        sampled=-1.0;drawn=-1.0;drawn_basis=Basis.IDENTITY
        output.render_target_update_mode=SubViewport.UPDATE_ALWAYS
        viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
        Layer.colours({"viewport":viewport,"output":rect},component.finish_profile,true)
        return ""
    output=SubViewport.new();output.size=Vector2i(256,256)
    output.disable_3d=true;output.transparent_bg=true
    output.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    add_child(output)
    viewport=SubViewport.new();viewport.size=output.size
    viewport.own_world_3d=true;viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    output.add_child(viewport)
    camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=3.0;camera.near=.01;camera.far=100;camera.cull_mask=Layer.LAYER
    camera.environment=Environment.new()
    camera.environment.background_mode=Environment.BG_COLOR;camera.environment.background_color=Color.BLACK
    camera.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    camera.environment.ambient_light_color=Color.WHITE
    viewport.add_child(camera)
    rect=TextureRect.new();rect.size=Vector2(output.size)
    rect.texture=viewport.get_texture();rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    output.add_child(rect)
    Layer.colours({"viewport":viewport,"output":rect},component.finish_profile,true)
    return ""

func sample(seconds:float,basis:Basis,_position:Vector3,_scale:float,_history:Array,_context:Dictionary)->Dictionary:
    var resources=Effects.prepare([component.native_clip],prepared)
    if not resources.ready:return {"ready":false,"error":"; ".join(resources.errors)}
    # A live approach (a condition lifecycle's constructor costs tens to
    # hundreds of ms) is built by one swatch per frame, never several at once.
    var live:bool=builds_live()
    if live and _live_built_frame==Engine.get_process_frames():return {"ready":false,"error":""}
    if handle.is_empty():
        if live:_live_built_frame=Engine.get_process_frames()
        source_parent=Node3D.new();viewport.add_child(source_parent)
        var clip:Dictionary=component.native_clip.duplicate(false)
        if component.native_cue.has("opacity_uniform"):clip.opacity_uniform=component.native_cue.opacity_uniform
        handle=Effects.make(source_parent,clip,Layer.LAYER)
        if handle.error.is_empty():Effects.resolve_paths(handle,component.native_cue,str(component.get("spell_id","")))
        if not handle.error.is_empty():return {"ready":false,"error":handle.error}
        handle.root.scale=Vector3.ONE*float(component.native_cue.get("scale",.18))
        handle.root.show()
    camera.global_basis=basis;camera.global_position=basis.z*10.0
    var next:float=minf(seconds,maxf(0.0,sampled)+1.0/60.0)
    var lifecycle:bool=component.has("lifecycle_phases")
    var opened:float=Persistent.application_end(component) if lifecycle else float(component.lifecycle.get("enter_end_seconds",0)) if component.get("persistent_owner",false) else INF
    if sampled>=opened:next=seconds
    if lifecycle:
        var state:Dictionary=Persistent.lifecycle_state(component,next)
        Effects.set_input(handle,"owner_state",state);Effects.sample(handle,state.owner_age_seconds)
    else:Effects.sample(handle,Playback.source_time(component.native_cue,next))
    Playback.controls(handle,component.native_cue,next)
    var path:String=component.native_cue.get("origin_path","")
    var anchor:Node3D=Effects.node(handle,path) if not path.is_empty() else null
    if anchor!=null:handle.root.position-=anchor.global_position
    sampled=next
    var complete:bool=absf(sampled-seconds)<.00001 and absf(drawn-seconds)<.00001 and drawn_basis.is_equal_approx(basis)
    RenderingServer.frame_post_draw.connect(func():drawn=next;drawn_basis=basis,CONNECT_ONE_SHOT)
    return {"ready":complete,"error":""}

## Whether the next sample constructs a live (not recorded) occurrence.
func builds_live()->bool:
    return handle.is_empty() and not component.get("native_clip",{}).is_empty() and Effects.choice(component.native_clip).kind!="recorded"

func texture()->Texture2D:return output.get_texture()

## Park: release the source, stop drawing, keep the viewports for reuse.
func release()->void:
    if not handle.is_empty():Effects.close(handle);handle={}
    if is_instance_valid(source_parent):source_parent.free()
    component={}
    if is_instance_valid(output):
        output.render_target_update_mode=SubViewport.UPDATE_DISABLED
        viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED

func close()->void:
    if not handle.is_empty():Effects.close(handle);handle={}
    if is_instance_valid(output):output.queue_free()
    prepared.clear()
