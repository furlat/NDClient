extends SceneTree
## Exact native receiver depth/output parity against the pre-optimization pass.
## Sources are lit sprites: each entry displays its own material (modular for
## actors, environment for floors) and the proxies address the cell texel.
const Support=preload("res://presentation/native_scene_support.gd")
const Original=preload("res://tests/native_scene_support_reference.gd")
const Source=preload("res://modular.gdshader")
const Floor=preload("res://environment.gdshader")
class Host extends Node3D:
    var camera:Camera3D
var checks:int=0
var failures:Array=[]
var timings:Dictionary={}
var images:Dictionary={}
var actor_count:int=6
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func texture(colour:Color)->ImageTexture:
    var image=Image.create(16,16,false,Image.FORMAT_RGBA8);image.fill(colour)
    return ImageTexture.create_from_image(image)
func make_world(script:Script)->Dictionary:
    var view=SubViewport.new();view.size=Vector2i(192,192);view.own_world_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var host=Host.new();view.add_child(host)
    host.camera=Camera3D.new();host.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;host.camera.size=5;host.camera.near=.01;host.camera.far=50;host.add_child(host.camera)
    var support=script.new();support.attach_shared(host)
    var state={"view":view,"host":host,"support":support,"floors":[],"actors":{"body":{"entries":[]}}}
    for i in 36:
        var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2.ONE;host.add_child(node)
        var output=ShaderMaterial.new();output.shader=Floor;output.set_shader_parameter("colour_texture",images.white);output.set_shader_parameter("colour_rect",Vector4(0,0,16,16))
        output.set_shader_parameter("colour_size",Vector2(16,16));output.set_shader_parameter("has_geometry",false);output.set_shader_parameter("source_quad_size",Vector2.ONE);node.material_override=output
        var placement={"position":[float(i%6)-2.5,float(i/6)-2.5],"base_height_steps":0}
        state.floors.append({"id":"floor"+str(i),"role":"terrain","source_version":0,"node":node,"placement":placement,"material":output})
    for i in actor_count:
        var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(.8,1.4);host.add_child(node)
        var material=ShaderMaterial.new();material.shader=Source;node.material_override=material
        var source_fields:Dictionary={"sheet":images.white,"frame_uv":Vector4(0,0,1,1),"component_depth":images.depth,"component_support":images.white,"component_depth_range":Vector2(0,1),"component_units":.06,"component_reconstruction_origin":Vector2(8,16),"component_elevation":PI/4,"condition_alpha":1.0,"has_component_geometry":true,"material_cell_size":Vector2(16,16)}
        for parameter in source_fields:material.set_shader_parameter(parameter,source_fields[parameter])
        material.set_shader_parameter("source_quad_size",node.mesh.size)
        state.actors.body.entries.append({"id":"body"+str(i),"role":"body","source_version":0,"source_parameters":source_fields.duplicate(),"actor_layer":{"effect":{},"slot":"body"},"node":node,"material":material,"texture_path":"body","cell":Vector2(16,16),"pivot":Vector2(8,16),"geometry_ground_pixels":0.0})
    support.solid_masks.body=images.white
    return state
func camera_view(state:Dictionary,quarter:int,zoom:float)->void:
    var camera:Camera3D=state.host.camera
    camera.basis=Basis(Vector3.UP,quarter*PI*.5)*Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4,0));camera.position=camera.basis.z*10;camera.size=zoom
    for entry in state.floors:
        entry.node.position=Vector3(entry.placement.position[0],0,entry.placement.position[1]);entry.node.basis=camera.basis
    for i in state.actors.body.entries.size():
        state.actors.body.entries[i].node.position=Vector3(float(i%3)-1,.7,float(i/3)-.5)
        state.actors.body.entries[i].node.basis=camera.basis
func sync(state:Dictionary)->void:
    if state.support is Support:check(state.support.prepare_membership(state.floors,state.actors).ready,"Exact receiver membership prepares before sync")
    state.support.sync(state.floors,state.actors,state.host.camera)
static func set_source(entry:Dictionary,name:StringName,value:Variant)->void:
    # The fixture produces the same explicit value and legacy-oracle uniform.
    entry.source_parameters[name]=value;entry.material.set_shader_parameter(name,value)
func floor_proxy(state:Dictionary,index:int)->MeshInstance3D:
    var entry:Dictionary=state.floors[index]
    var key:Variant=entry.node.get_instance_id()
    if not state.support.floors.has(key):key=entry.id
    return state.support.floors.get(key)
func floor_members(state:Dictionary)->Array:
    var result:Array=[]
    for i in state.floors.size():
        if floor_proxy(state,i)!=null:result.append(i)
    return result
func draw()->void:
    await process_frame;await RenderingServer.frame_post_draw
    await process_frame;await RenderingServer.frame_post_draw
func compare(a:Dictionary,b:Dictionary,label:String)->void:
    check(a.support.viewport.get_texture().get_image().get_data()==b.support.viewport.get_texture().get_image().get_data(),label+": exact native packed receiver pixels")
    check(a.view.get_texture().get_image().get_data()==b.view.get_texture().get_image().get_data(),label+": exact painted output pixels")
    check(floor_members(a)==floor_members(b) and a.support.floors.size()==b.support.floors.size() and a.support.actors.keys()==b.support.actors.keys(),label+": exact receiver source membership and actor order")
    for i in floor_members(a):
        check(floor_proxy(a,i).position==floor_proxy(b,i).position,label+": exact floor contact "+str(i))
    for id in a.support.actors:
        var actual:MeshInstance3D=a.support.actors[id];var expected:MeshInstance3D=b.support.actors[id]
        check(actual.global_transform==expected.global_transform and actual.sorting_offset==expected.sorting_offset and actual.material_override.render_priority==expected.material_override.render_priority,label+": exact proxy transform/order "+id)
        for field in actual.material_override.shader.get_shader_uniform_list():
            check(actual.material_override.get_shader_parameter(field.name)==expected.material_override.get_shader_parameter(field.name),label+": exact proxy uniform "+id+"/"+str(field.name))
    for i in a.floors.size():
        for field in ["native_scene_enabled","native_scene_plane"]:
            check(a.floors[i].material.get_shader_parameter(field)==b.floors[i].material.get_shader_parameter(field),label+": exact floor output "+field)
    for i in a.actors.body.entries.size():
        for field in ["native_scene_enabled","native_scene_plane","native_scene_pivot","native_scene_ground_height"]:
            check(a.actors.body.entries[i].material.get_shader_parameter(field)==b.actors.body.entries[i].material.get_shader_parameter(field),label+": exact actor output "+field)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(320,240);Engine.max_fps=60
    create_timer(60).timeout.connect(func():printerr("Support check deadline");quit(2))
    RenderingServer.global_shader_parameter_set(&"light_ambient",1.0);RenderingServer.global_shader_parameter_set(&"light_cap",0.0);RenderingServer.global_shader_parameter_set(&"light_normals",false)
    images={"white":texture(Color.WHITE),"depth":texture(Color(.5,0,0,1)),"changed":texture(Color(.75,0,0,1)),"empty":texture(Color(0,0,0,1))}
    var candidate:Script=Support;var before:Script=Support
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--candidate="):candidate=load(argument.trim_prefix("--candidate="))
        if argument.begins_with("--before="):before=load(argument.trim_prefix("--before="))
        if argument.begins_with("--actors="):actor_count=int(argument.trim_prefix("--actors="))
    var a=make_world(candidate);var b=make_world(Original);var c=make_world(before)
    for quarter in 4:
        for zoom in [4.0,6.0]:
            for state in [a,b,c]:camera_view(state,quarter,zoom);sync(state)
            await draw();compare(a,b,"view%d zoom%.0f"%[quarter,zoom])
            var retained:MeshInstance3D=floor_proxy(a,0)
            for state in [a,b,c]:
                state.floors[0].id="floor-representative-%d-%.0f"%[quarter,zoom]
                state.floors[0].placement=state.floors[0].placement.duplicate(true)
                state.floors[0].placement.base_height_steps=1 if zoom==4.0 else 0
                sync(state)
            check(floor_proxy(a,0)==retained,"Representative ID/contact change retains same source-owned floor proxy")
            check(a.support.last_sync_phases.floor_created==0 and a.support.last_sync_phases.floor_retired==0,"Representative replacement avoids receiver creation and retirement")
            await draw();compare(a,b,"representative_change_view%d_zoom%.0f"%[quarter,zoom])
            retained=floor_proxy(a,0)
            for state in [a,b,c]:
                var entry:Dictionary=state.floors[0]
                var old_source:Node=entry.node
                entry.node=old_source.duplicate()
                state.host.add_child(entry.node)
                old_source.free()
                var old_output:ShaderMaterial=entry.material
                entry.material=old_output.duplicate()
                entry.node.material_override=entry.material
                sync(state)
                check(old_output.get_shader_parameter("native_scene_enabled")==false,"Replaced floor output disabled")
            check(not is_instance_valid(retained),"Actual source-node replacement retires old floor proxy despite same row ID")
            check(a.support.last_sync_phases.floor_created==0 and a.support.last_sync_phases.floor_retired==0,"Actual source-node replacement is prepared before sampling without constructors")
            await draw();compare(a,b,"source_node_replacement_view%d_zoom%.0f"%[quarter,zoom])
    var states=[a,b,c]
    for label in ["unchanged","clock","geometry","opacity","restore","hidden","reveal","material_replace","output_recopy","stamped_recopy","same_count_replace","mask","pivot","ground","cell_size","solid_missing","solid_arrival","copy_stable","copy_overwrite","first_draw","removed","sleep","wake"]:
        for state in states:
            var entry:Dictionary=state.actors.body.entries[0]
            match label:
                "clock":set_source(entry,"frame_uv",Vector4(.25,0,.5,1));entry.source_version+=1
                "geometry":entry.erase("source_version");set_source(entry,"component_depth",images.changed);set_source(entry,"component_units",.075)
                "opacity":set_source(entry,"condition_alpha",.55)
                "restore":set_source(entry,"condition_alpha",1.0)
                "hidden":entry.node.hide();state.floors[0].node.hide()
                "reveal":entry.node.show();state.floors[0].node.show()
                "material_replace":entry.material=entry.material.duplicate();entry.node.material_override=entry.material
                "output_recopy":entry.source_version=20;entry.material.set_shader_parameter("native_scene_enabled",false);entry.material.set_shader_parameter("native_scene_pivot",Vector2.ZERO)
                "stamped_recopy":entry.material.set_shader_parameter("native_scene_enabled",false);entry.material.set_shader_parameter("native_scene_pivot",Vector2.ZERO)
                "same_count_replace":entry.id="replacement";state.floors[0].id="floor-replacement"
                "mask":state.support.solid_masks.body=images.empty
                "pivot":entry.pivot=Vector2(7,14)
                "ground":entry.geometry_ground_pixels=3.0
                "cell_size":entry.geometry_cell_size=Vector2(17,18)
                "solid_missing":state.support.solid_masks.erase("body")
                "solid_arrival":state.support.solid_masks.body=images.changed
                "copy_stable":pass
                "copy_overwrite":
                    entry.material.set_shader_parameter("native_scene_enabled",false)
                    entry.material.set_shader_parameter("native_scene_pivot",Vector2.ZERO)
                "first_draw":entry.pivot=Vector2(6,15);entry.geometry_ground_pixels=2.0
                "removed":state.actors.body.entries[1].node.hide()
                "sleep":state.support.set_enabled(false)
                "wake":state.support.set_enabled(true);state.support.solid_masks.body=images.white
            if label!="sleep":sync(state)
        if label=="first_draw":
            await process_frame;await RenderingServer.frame_post_draw
            compare(a,b,"first_draw_after_one_frame")
        await draw();compare(a,b,label)
        if label=="sleep":check(a.support.actors.values().all(func(node):return node.material_override.get_shader_parameter("sheet")==null),"Inactive support releases texture references")
    for state in states:
        for entry in state.actors.body.entries:entry.source_version=10
        sync(state)
    var measured={"original":[],"before":[],"revised":[]}
    # Alternate complete sync calls against the immediate pre-edit source,
    # rather than attributing its earlier source-binding improvement here.
    for round_index in 9:
        var order=["revised","before","original"] if round_index%2==0 else ["original","before","revised"]
        for name in order:
            var state:Dictionary=b if name=="original" else (c if name=="before" else a)
            for i in 40:
                var started=Time.get_ticks_usec();sync(state);measured[name].append((Time.get_ticks_usec()-started)/1000.0)
    for name in measured:
        var samples:Array=measured[name];samples.sort()
        timings[name]={"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*.95)],"max_ms":samples[-1]}
    # Hidden preparation also follows actual source identity, not row labels.
    a.support.set_enabled(false)
    for i in 64:a.support.prepare_hidden(a.floors,a.actors)
    var old:Node=floor_proxy(a,0)
    a.floors[0].id="floor-new"
    for i in 64:a.support.prepare_hidden(a.floors,a.actors)
    check(floor_proxy(a,0)==old and is_instance_valid(old),"Hidden representative change retains same source-owned receiver")
    var source:Node=a.floors[0].node
    a.floors[0].node=source.duplicate();a.host.add_child(a.floors[0].node);source.free()
    for i in 64:a.support.prepare_hidden(a.floors,a.actors)
    check(floor_proxy(a,0)!=null and not is_instance_valid(old),"Hidden actual source replacement retires obsolete receiver")
    for state in states:
        state.support.close()
        check(state.support.floors.is_empty() and state.support.actors.is_empty(),"Close releases every floor and actor receiver")
        state.view.queue_free()
    await draw()
    var report={"actor_proxies":actor_count,"checks":checks,"failures":failures,"timings":timings,"scope":"Original versus revised receiver depth and painted-output byte parity across fourviews/twozooms, live unstamped material/opacity/mask changes on lit sprite materials, membership, inactive media release. Synthetic finite receiver fixture; full real replay timing separate."}
    FileAccess.open("res://.runtime/native-scene-support-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("NATIVE_SCENE_SUPPORT_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
