extends Node
## Source-only thumbnail. Uses the same Factory sampler and finishing shader;
## the actual replay continues to use NativeSpellRenderer in its player world.
const Factory=preload("res://presentation/native_factory_source.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const Layer=preload("res://presentation/native_effect_layer.gd")
var viewport:SubViewport
var output:SubViewport
var camera:Camera3D
var handle:Dictionary={}
var component:Dictionary={}
var prepared:Dictionary={}
var sampled:=-1.0
var drawn:=-1.0
var drawn_basis:=Basis.IDENTITY

func configure_component(value:Dictionary)->String:
    component=value
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
    var rect=TextureRect.new();rect.size=Vector2(output.size)
    rect.texture=viewport.get_texture();rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    output.add_child(rect)
    Layer.colours({"viewport":viewport,"output":rect},component.finish_profile,true)
    return ""

func sample(seconds:float,basis:Basis,_position:Vector3,_scale:float,_history:Array,_context:Dictionary)->Dictionary:
    var resources=Factory.prepare([component.native_clip],prepared)
    if not resources.ready:return {"ready":false,"error":"; ".join(resources.errors)}
    if handle.is_empty():
        var parent=Node3D.new();viewport.add_child(parent)
        var clip:Dictionary=component.native_clip.duplicate(true)
        if component.native_cue.has("opacity_uniform"):clip.opacity_uniform=component.native_cue.opacity_uniform
        handle=Factory.make(parent,clip)
        if not handle.error.is_empty():return {"ready":false,"error":handle.error}
        handle.root.scale=Vector3.ONE*float(component.native_cue.get("scale",.18))
        handle.root.show()
    camera.global_basis=basis;camera.global_position=basis.z*10.0
    var next:float=minf(seconds,maxf(0.0,sampled)+1.0/60.0)
    if component.get("persistent_owner",false) and sampled>=float(component.lifecycle.get("enter_end_seconds",0)):next=seconds
    Factory.view(handle,camera)
    Factory.sample(handle,Playback.source_time(component.native_cue,next),1.0/60.0,next-component.native_cue.launch)
    Playback.controls(handle,component.native_cue,next)
    var path:String=component.native_cue.get("origin_path","")
    if not path.is_empty():handle.root.position-=handle.root.get_node(path).global_position
    sampled=next
    var complete:bool=absf(sampled-seconds)<.00001 and absf(drawn-seconds)<.00001 and drawn_basis.is_equal_approx(basis)
    RenderingServer.frame_post_draw.connect(func():drawn=next;drawn_basis=basis,CONNECT_ONE_SHOT)
    return {"ready":complete,"error":""}

func texture()->Texture2D:return output.get_texture()

func close()->void:
    if not handle.is_empty():Factory.close(handle);handle={}
    if is_instance_valid(output):output.queue_free()
    prepared.clear()
