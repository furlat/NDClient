extends SceneTree
## Exact native receiver depth/output parity against the pre-optimization pass.
const Support=preload("res://presentation/native_scene_support.gd")
const Original=preload("res://tests/native_scene_support_reference.gd")
const Source=preload("res://presentation/canvas_capped_modular.gdshader")
const Output=preload("res://presentation/canvas_received.gdshader")
class Host extends Node3D:
    var camera:Camera3D
var checks:int=0
var failures:Array=[]
var timings:Dictionary={}
var images:Dictionary={}
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
        var output=ShaderMaterial.new();output.shader=Output;output.set_shader_parameter("received",images.white);output.set_shader_parameter("atlas_region",Vector4(0,0,1,1));output.set_shader_parameter("source_quad_size",Vector2.ONE);node.material_override=output
        var placement={"position":[float(i%6)-2.5,float(i/6)-2.5],"base_height_steps":0}
        state.floors.append({"id":"floor"+str(i),"role":"terrain","source_version":0,"node":node,"placement":placement,"received_material":output})
    for i in 6:
        var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(.8,1.4);host.add_child(node)
        var material=ShaderMaterial.new();material.shader=Source
        var output=ShaderMaterial.new();output.shader=Output;node.material_override=output
        var source_fields:Dictionary={"sheet":images.white,"frame_uv":Vector4(0,0,1,1),"component_depth":images.depth,"component_support":images.white,"component_depth_range":Vector2(0,1),"component_units":.06,"component_reconstruction_origin":Vector2(8,16),"component_elevation":PI/4,"condition_alpha":1.0,"has_component_geometry":true}
        for parameter in source_fields:material.set_shader_parameter(parameter,source_fields[parameter])
        output.set_shader_parameter("received",images.white);output.set_shader_parameter("source_crop",Vector4(0,0,1,1));output.set_shader_parameter("atlas_region",Vector4(0,0,1,1));output.set_shader_parameter("source_quad_size",node.mesh.size)
        state.actors.body.entries.append({"id":"body"+str(i),"role":"body","source_version":0,"actor_layer":{"effect":{},"slot":"body"},"node":node,"material":material,"received_material":output,"texture_path":"body","cell":Vector2(16,16),"pivot":Vector2(8,16),"geometry_ground_pixels":0.0})
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
func sync(state:Dictionary)->void:state.support.sync(state.floors,state.actors,state.host.camera)
func draw()->void:
    await process_frame;await RenderingServer.frame_post_draw
    await process_frame;await RenderingServer.frame_post_draw
func compare(a:Dictionary,b:Dictionary,label:String)->void:
    check(a.support.viewport.get_texture().get_image().get_data()==b.support.viewport.get_texture().get_image().get_data(),label+": exact native packed receiver pixels")
    check(a.view.get_texture().get_image().get_data()==b.view.get_texture().get_image().get_data(),label+": exact painted output pixels")
    check(a.support.floors.keys()==b.support.floors.keys() and a.support.actors.keys()==b.support.actors.keys(),label+": exact receiver membership/order")
    for id in a.support.actors:
        var actual:MeshInstance3D=a.support.actors[id];var expected:MeshInstance3D=b.support.actors[id]
        check(actual.global_transform==expected.global_transform and actual.sorting_offset==expected.sorting_offset and actual.material_override.render_priority==expected.material_override.render_priority,label+": exact proxy transform/order "+id)
        for field in actual.material_override.shader.get_shader_uniform_list():
            check(actual.material_override.get_shader_parameter(field.name)==expected.material_override.get_shader_parameter(field.name),label+": exact proxy uniform "+id+"/"+str(field.name))
    for i in a.floors.size():
        for field in ["native_scene_enabled","native_scene_plane"]:
            check(a.floors[i].received_material.get_shader_parameter(field)==b.floors[i].received_material.get_shader_parameter(field),label+": exact floor output "+field)
    for i in a.actors.body.entries.size():
        for field in ["native_scene_enabled","native_scene_plane","native_scene_pivot","native_scene_ground_height"]:
            check(a.actors.body.entries[i].received_material.get_shader_parameter(field)==b.actors.body.entries[i].received_material.get_shader_parameter(field),label+": exact actor output "+field)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(320,240);Engine.max_fps=60
    create_timer(60).timeout.connect(func():printerr("Support check deadline");quit(2))
    images={"white":texture(Color.WHITE),"depth":texture(Color(.5,0,0,1)),"changed":texture(Color(.75,0,0,1)),"empty":texture(Color(0,0,0,1))}
    var a=make_world(Support);var b=make_world(Original)
    for quarter in 4:
        for zoom in [4.0,6.0]:
            for state in [a,b]:camera_view(state,quarter,zoom);sync(state)
            await draw();compare(a,b,"view%d zoom%.0f"%[quarter,zoom])
    var states=[a,b]
    for label in ["unchanged","clock","geometry","atlas","opacity","restore","hidden","reveal","output_replace","output_recopy","stamped_recopy","same_count_replace","mask","removed","sleep","wake"]:
        for state in states:
            var entry:Dictionary=state.actors.body.entries[0]
            match label:
                "clock":entry.material.set_shader_parameter("frame_uv",Vector4(.25,0,.5,1));entry.source_version+=1
                "geometry":entry.erase("source_version");entry.material.set_shader_parameter("component_depth",images.changed);entry.material.set_shader_parameter("component_units",.075)
                "atlas":entry.received_material.set_shader_parameter("atlas_region",Vector4(.1,.1,.8,.8));entry.received_material.set_shader_parameter("source_crop",Vector4(.1,.1,.8,.8))
                "opacity":entry.material.set_shader_parameter("condition_alpha",.55)
                "restore":entry.material.set_shader_parameter("condition_alpha",1.0)
                "hidden":entry.node.hide();state.floors[0].node.hide()
                "reveal":entry.node.show();state.floors[0].node.show()
                "output_replace":entry.received_material=entry.received_material.duplicate();entry.node.material_override=entry.received_material
                "output_recopy":entry.source_version=20;entry.received_material.set_shader_parameter("native_scene_enabled",false);entry.received_material.set_shader_parameter("native_scene_pivot",Vector2.ZERO)
                "stamped_recopy":entry.received_material.set_shader_parameter("native_scene_enabled",false);entry.received_material.set_shader_parameter("native_scene_pivot",Vector2.ZERO)
                "same_count_replace":entry.id="replacement";state.floors[0].id="floor-replacement"
                "mask":state.support.solid_masks.body=images.empty
                "removed":state.actors.body.entries[1].node.hide()
                "sleep":state.support.set_enabled(false)
                "wake":state.support.set_enabled(true);state.support.solid_masks.body=images.white
            if label!="sleep":sync(state)
        await draw();compare(a,b,label)
        if label=="sleep":check(a.support.actors.values().all(func(node):return node.material_override.get_shader_parameter("sheet")==null),"Inactive support releases texture references")
    for state in states:
        for entry in state.actors.body.entries:entry.source_version=10
        sync(state)
    for name in ["original","revised"]:
        var state:Dictionary=b if name=="original" else a
        var samples:Array=[]
        for i in 200:
            var started=Time.get_ticks_usec();sync(state);samples.append((Time.get_ticks_usec()-started)/1000.0)
        samples.sort();timings[name]={"median_ms":samples[100],"p95_ms":samples[190],"max_ms":samples[-1]}
    # Same-count floor replacements must invalidate the optional completed token.
    a.support.set_enabled(false)
    for i in 64:a.support.prepare_hidden(a.floors,a.actors)
    var old:Node=a.support.floors["floor-replacement"]
    a.floors[0].id="floor-new"
    for i in 64:a.support.prepare_hidden(a.floors,a.actors)
    check(not a.support.floors.has("floor-replacement") and a.support.floors.has("floor-new") and not is_instance_valid(old),"Changed publication replaces same-count hidden floor identity")
    for state in states:state.support.close();state.view.queue_free()
    await draw()
    var report={"checks":checks,"failures":failures,"timings":timings,"scope":"Original versus revised receiver depth and painted-output byte parity across fourviews/twozooms, live unstamped material/atlas/opacity/mask changes, membership, inactive media release. Synthetic finite receiver fixture; full real replay timing separate."}
    FileAccess.open("res://.runtime/native-scene-support-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("NATIVE_SCENE_SUPPORT_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
