extends Node3D
## Shared native-source presenter. One simulation, original rear/front captures,
## independent source materials, and no clock other than the supplied source age.
const Sources=preload("res://presentation/native_effects.gd")
const Receiving=preload("res://presentation/native_effect_receiving.gd")
const Output=preload("res://presentation/native_effect_output.gdshader")
var viewport: SubViewport
var source_root: Node3D
var source_camera: Camera3D
var surface: MeshInstance3D
var views: Array=[]
var surfaces: Array=[]
var composite: SubViewport
var handle: Dictionary={}
var receiving: Dictionary={}
var receiving_halves:Array=[]
var _actor_partition_key:Array=[]
var record: Dictionary={}
var error: String=""
var sample_ready: bool=false
var sampled_age: float=-1.0
var requested_age: float=-1.0
var _draw_pending: bool=false
var _generation: int=0
var _requested_render_key:Array=[]
var _rendered_key:Array=[]
var _history_owner:Array=[]
var _history_basis:Basis=Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
var _capture_target:Vector3=Vector3.ZERO

func configure(source_id: String, cache: Dictionary = {}, seed: int = 0, palette_colors: Array = []) -> String:
    close()
    record=Sources.source_record(source_id,cache)
    if record.is_empty():
        error="Native source not selected: "+source_id
        return error
    if not palette_colors.is_empty():
        if record.get("palette",{}).get("operator")!="class_neutral" or palette_colors.size()!=3:
            error="Native source does not support the authored three-color palette: "+source_id
            return error
        # A recipe owns this occurrence's colors; never recolor the cached source
        # or another attack which happens to use the same native composition.
        record=record.duplicate()
        record.palette=record.palette.duplicate()
        record.palette.colors=palette_colors.map(func(value):return "#%06x"%int(value))
    # Class sources retain their authored half planes. Selected blood adds a
    # declared actor presentation-plane split when its receiving adapter binds.
    var halves=record.get("capture_halves",["back","front"]) if record.kind=="class_component" else (["back","front"] if record.get("actor_partition",false) else ["all"])
    var world=World3D.new()
    for half in halves:
        var view=SubViewport.new()
        view.size=Vector2i(record.canvas[0],record.canvas[1])
        view.world_3d=world
        view.transparent_bg=true
        view.msaa_3d=Viewport.MSAA_2X
        view.render_target_update_mode=SubViewport.UPDATE_DISABLED
        add_child(view)
        var camera=Camera3D.new();view.add_child(camera)
        camera.projection=Camera3D.PROJECTION_ORTHOGONAL
        camera.keep_aspect=Camera3D.KEEP_WIDTH
        camera.size=float(record.canvas[0])/float(record.pixels_per_unit)
        camera.cull_mask=((1<<18)-1) | ((1<<18) if half=="back" else (1<<19) if half=="front" else 0)
        camera.current=true
        var capture=view
        if not record.get("palette",{}).is_empty():
            capture=SubViewport.new();capture.size=view.size
            capture.disable_3d=true;capture.transparent_bg=true
            capture.render_target_update_mode=SubViewport.UPDATE_DISABLED
            add_child(capture)
            Sources.add_palette_pass(capture,record,view.get_texture())
        var output=_surface(capture)
        surfaces.append({"node":output,"half":half})
        views.append({"viewport":view,"output":capture,"camera":camera,"half":half})
    # The unbound actor-partition source is wholly in the front pass. Preserve
    # the single-source thumbnail/inspection API while draw_entries exposes both.
    var primary=1 if record.get("actor_partition",false) else 0
    viewport=views[primary].viewport;source_camera=views[primary].camera;surface=surfaces[primary].node
    source_root=Node3D.new();viewport.add_child(source_root)
    handle=Sources.make(source_root,record,seed)
    error=handle.get("error","")
    return error

func _surface(view: SubViewport) -> MeshInstance3D:
    var output=MeshInstance3D.new()
    output.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    output.sorting_use_aabb_center=false
    var mesh=QuadMesh.new()
    var size=Vector2(record.canvas[0],record.canvas[1]);var pivot=Vector2(record.pivot[0],record.pivot[1])
    mesh.size=size/float(record.pixels_per_unit)
    mesh.center_offset=Vector3(size.x*.5-pivot.x,pivot.y-size.y*.5,0)/float(record.pixels_per_unit)
    output.mesh=mesh
    var material=ShaderMaterial.new();material.shader=Output
    material.set_shader_parameter("effect_texture",view.get_texture())
    output.material_override=material;output.visible=false
    add_child(output)
    return output

func bind_receiving(lighting: RefCounted) -> String:
    if not receiving.is_empty():return ""
    if "native_surface_lighting" not in record.get("requirements",[]):return ""
    for index in views.size():
        var row:Dictionary=views[index]
        var partition_layer=(1<<18) if row.half=="back" else ((1<<19) if row.half=="front" else 0)
        var state=Receiving.make(self,record,viewport.world_3d,row.viewport,lighting,partition_layer)
        receiving_halves.append(state)
        if row.viewport==viewport:receiving=state
        row.camera.cull_mask=((1<<15)-1)|partition_layer
        var material:ShaderMaterial=surfaces[index].node.material_override
        material.set_shader_parameter("receiving_enabled",true)
        material.set_shader_parameter("receiving_texture",state.output.get_texture())
    var issue=Receiving.adapt(handle,receiving.depth.get_texture())
    if not issue.is_empty():
        for state in receiving_halves:Receiving.close(state)
        receiving_halves=[];receiving={};error=issue
    return issue

func bind_actor_partition(actor_foot:Vector3,camera_basis:Basis,anchor:Vector3,source_scale:float)->String:
    if not record.get("actor_partition",false):return ""
    if receiving.is_empty():return "Native actor partition requires its selected source receiving adapter"
    if source_scale<=0:return "Native actor partition needs positive source scale"
    var normal=Vector3(camera_basis.z.x,0,camera_basis.z.z).normalized()
    if normal.is_zero_approx():return "Native actor partition needs the current ground-view direction"
    var origin=(actor_foot-anchor)/source_scale
    var key=[origin,normal]
    if key==_actor_partition_key:return ""
    _actor_partition_key=key
    for node in handle.subject.find_children("*","GeometryInstance3D",true,false):
        var material:ShaderMaterial=node.material_override
        material.set_shader_parameter("native_actor_partition",true)
        material.set_shader_parameter("native_actor_plane_origin",origin)
        material.set_shader_parameter("native_actor_plane_normal",normal)
    return ""

func _frame_history(history:Array,camera_basis:Basis)->void:
    if _history_basis==camera_basis and (is_same(_history_owner,history) or (_history_owner.is_empty() and history.is_empty())):return
    _history_owner=history;_history_basis=camera_basis
    var left=0.0;var right=0.0;var up=0.0;var down=0.0
    var ppu=float(record.pixels_per_unit)
    for row in history:
        var point:Vector3=row.transform.origin
        var x=point.dot(camera_basis.x)*ppu;var y=point.dot(camera_basis.y)*ppu
        left=minf(left,x);right=maxf(right,x);down=minf(down,y);up=maxf(up,y)
    var padding=Vector4(ceil(-left),ceil(right),ceil(up),ceil(-down))
    var size=Vector2i(record.canvas[0]+padding.x+padding.y,record.canvas[1]+padding.z+padding.w)
    var pivot=Vector2(record.pivot[0]+padding.x,record.pivot[1]+padding.z)
    _capture_target=Vector3(record.camera_target[0],record.camera_target[1],record.camera_target[2])+camera_basis.x*(padding.y-padding.x)*.5/ppu+camera_basis.y*(padding.z-padding.w)*.5/ppu
    for row in views:
        row.viewport.size=size;row.output.size=size;row.camera.size=float(size.x)/ppu
        if row.output!=row.viewport:
            for layer in row.output.get_children():
                for child in layer.get_children():
                    if child is Control:child.size=Vector2(size)
    for row in surfaces:
        row.node.mesh.size=Vector2(size)/ppu
        row.node.mesh.center_offset=Vector3(size.x*.5-pivot.x,pivot.y-size.y*.5,0)/ppu

func sample(seconds: float, camera_basis: Basis, world_position: Vector3, source_scale: float = 1.0, history: Array = [], receiving_context: Dictionary = {}) -> Dictionary:
    if not error.is_empty(): return {"ready":false,"error":error}
    if handle.is_empty(): return {"ready":false,"error":"No native source configured"}
    # Immutable history rows are {age_seconds, transform} relative to one
    # stable occurrence anchor. The caller supplies that same world_position;
    # the painter entry may independently track the current projectile contact.
    position=world_position
    for row in surfaces:row.node.basis=camera_basis*Basis.from_scale(Vector3.ONE*source_scale)
    _frame_history(history,camera_basis)
    var target=_capture_target
    for row in views:
        row.camera.basis=camera_basis
        row.camera.position=target+camera_basis.z*12.0
    if seconds<sampled_age:
        for row in surfaces:row.node.visible=false
    requested_age=seconds
    if not receiving.is_empty():
        if "depth_receiver" in record.get("requirements",[]) and receiving_context.get("supports",[]).is_empty():
            return {"ready":false,"error":"Native deposit requires the published supporting surface"}
        var pixel_scale=float(receiving_context.get("pixel_scale",0.0))
        if pixel_scale<=0:return {"ready":false,"error":"Native receiving needs actual screen pixel scale"}
        var size=Vector2i(maxi(1,roundi(record.canvas[0]*pixel_scale)),maxi(1,roundi(record.canvas[1]*pixel_scale)))
        for row in views:row.viewport.size=size
        for state in receiving_halves:
            var issue=Receiving.sample(state,camera_basis,target,receiving_context)
            if not issue.is_empty():return {"ready":false,"error":issue}
        for row in surfaces:
            row.node.material_override.set_shader_parameter("light_cap",float(receiving_context.get("light_cap",0.0)))
    if history.is_empty():
        handle.root.basis=receiving_context.get("source_basis",Basis.IDENTITY)
        if record.get("camera_relative",false):
            var original_basis=Basis.looking_at(Vector3(-6,-sqrt(24.),-6))
            handle.root.basis=camera_basis*original_basis.inverse()
    var result=Sources.sample(handle,seconds,history,receiving_context)
    Sources.set_view(handle,camera_basis)
    var light_fields:Array=[]
    if not receiving.is_empty():
        for child in receiving.output.get_children():
            if child is Light2D:
                light_fields.append([child.get_instance_id(),child.transform,child.color,child.energy,child.enabled])
                if child is PointLight2D:light_fields.append([child.height,child.texture,child.texture_scale])
            elif child is CanvasModulate:light_fields.append(child.color)
    var render_context=receiving_context.duplicate(true)
    render_context.erase("native_frame_seconds");render_context.erase("native_continuous");render_context.erase("native_transform")
    _requested_render_key=[camera_basis,world_position,source_scale,render_context,light_fields,_actor_partition_key]
    sample_ready=result.ready and is_equal_approx(sampled_age,seconds) and _rendered_key==_requested_render_key
    for row in views:
        row.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
        row.output.render_target_update_mode=SubViewport.UPDATE_ONCE
    if is_instance_valid(composite):composite.render_target_update_mode=SubViewport.UPDATE_ONCE
    # Publish the exact submitted native sample after its draw, even while the
    # caller advances every frame. Waiting for repeated same-age calls would
    # leave newly activated particles invisible during continuous playback.
    if (result.ready or result.has("submitted_age")) and not _draw_pending:
        _draw_pending=true
        var drawn_age=float(result.get("submitted_age",result.get("age",seconds)))
        RenderingServer.frame_post_draw.connect(_texture_drawn.bind(_generation,drawn_age,_requested_render_key),CONNECT_ONE_SHOT)
    return {"ready":sample_ready,"source_ready":result.ready,"age":result.get("age",0.0),"error":result.get("error","")}

func _texture_drawn(generation: int, age: float, render_key:Array) -> void:
    if generation!=_generation or not is_instance_valid(surface):return
    sampled_age=age;_draw_pending=false;_rendered_key=render_key
    sample_ready=is_equal_approx(age,requested_age) and _rendered_key==_requested_render_key
    for row in surfaces:row.node.visible=true

func draw_entries(component_id: String, placement: Dictionary, back_layer: int, front_layer: int) -> Array:
    var result:Array=[]
    for row in surfaces:
        result.append({"id":component_id+":"+row.half,"node":row.node,"material":row.node.material_override,
            "placement":placement,"role":"native_effect","layer":back_layer if row.half=="back" else front_layer,"half":row.half})
    return result

func texture() -> Texture2D:
    if views.size()==1:return views[0].output.get_texture()
    if views.is_empty():return null
    if not is_instance_valid(composite):
        # A bounded thumbnail output, allocated only if requested. It samples the
        # same two captures; it never simulates or instances the source again.
        composite=SubViewport.new();composite.size=viewport.size
        composite.disable_3d=true;composite.transparent_bg=true
        composite.render_target_update_mode=SubViewport.UPDATE_ONCE
        add_child(composite)
        for row in views:
            var image=TextureRect.new();image.texture=row.output.get_texture()
            image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
            image.size=Vector2(composite.size);composite.add_child(image)
    return composite.get_texture()

func set_opacity(value: float) -> void:
    for row in surfaces:row.node.material_override.set_shader_parameter("opacity",value)

func close() -> void:
    _generation+=1;sampled_age=-1.0;requested_age=-1.0;_draw_pending=false
    _requested_render_key=[];_rendered_key=[];_history_owner=[];_history_basis=Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
    for row in surfaces:
        if is_instance_valid(row.node):row.node.material_override.set_shader_parameter("receiving_texture",null)
    # Adapted source materials also borrow the support-depth viewport. Drop
    # those consumers while all receiving texture providers are still alive.
    if not handle.is_empty():Sources.release(handle)
    for state in receiving_halves:Receiving.close(state)
    receiving_halves=[];receiving={};_actor_partition_key=[]
    for row in views:
        if row.output!=row.viewport and is_instance_valid(row.output):row.output.free()
        if is_instance_valid(row.viewport):row.viewport.free()
    for row in surfaces:
        if is_instance_valid(row.node):row.node.free()
    if is_instance_valid(composite):composite.free()
    views=[];surfaces=[];sample_ready=false;error="";record={}
