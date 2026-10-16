extends "res://tests/native_atlas_lifecycle_checks.gd"
## Extend the native lifecycle suite with actual modular UV-frame pixels.
const Construction=preload("res://presentation/actor_construction.gd")
class FrameHost extends Node3D:
    var camera:Camera3D
    var textures:Dictionary={}
    var source_images:Dictionary={}
    var resources:Dictionary={}
    var catalog_cache:Dictionary={}
    var source_depth:bool=false
    var source_normals:bool=false
    var character_light_profile:String="original"
    func texture(path:String)->Texture2D:return textures.get(path)

func bind_frame(host:FrameHost,actor:Dictionary,frame:int,alpha:float=.9)->void:
    var state:Dictionary=Construction.Conditions.material("actor",[]);state.alpha=alpha
    Construction.bind_source(host,actor,{"cell_width":64,"cell_height":64,"facing_rows":{"SW":0}},
        "/fixture/frame-range.png",frame,"SW",Construction.Conditions.parameters(state,host.textures,host.resources))

func producer_range_pixels(atlas:RefCounted,world:World,actor:Dictionary)->void:
    var host=FrameHost.new();world.add_child(host);host.camera=world.camera
    host.textures["/fixture/frame-range.png"]=SourceMaterial.value(actor,"sheet")
    host.catalog_cache[Construction.CharacterGeometry.TABLE]={"records":{}}
    actor.actor_layer={"slot":"body","paths":{"Idle":"/fixture/frame-range.png"}}
    actor.scale=1.0;actor.placement.scale_x=1.0
    atlas.set_light_cap(1.0)
    var quad_size:Vector2=actor.node.mesh.size
    for quarter in 4:
        world.camera.position=Vector3(0,0,10).rotated(Vector3.UP,quarter*PI*.5)
        world.camera.look_at(Vector3.ZERO,Vector3.UP)
        actor.node.basis=world.camera.global_basis
        for mode in ["range","opacity_return","palette_return","geometry_return","quad_changed","highlight","output_replaced"]:
            actor.node.mesh.size=quad_size
            bind_frame(host,actor,0)
            sync_scene(atlas,world)
            var prepared:Dictionary=atlas.prepare_source_binding(actor,{},host,true)
            check(not prepared.is_empty(),"Quarter"+str(quarter)+" prepares current private actor copies")
            match mode:
                "opacity_return":bind_frame(host,actor,1,.4);bind_frame(host,actor,0,.9)
                "palette_return":
                    actor.actor_layer.effect={"palette":{"colors":[0xffffff,0x4488aa]}};bind_frame(host,actor,1)
                    actor.actor_layer.effect={};bind_frame(host,actor,0)
                "geometry_return":
                    host.source_depth=true;bind_frame(host,actor,1)
                    host.source_depth=false;bind_frame(host,actor,0)
                "quad_changed":actor.node.mesh.size=quad_size*1.2
                "highlight":SourceMaterial.set_parameter(actor,"highlighted",true)
                "output_replaced":prepared.output.received_material=prepared.output.received_material.duplicate()
            bind_frame(host,actor,1);bind_frame(host,actor,0);bind_frame(host,actor,1)
            var accepted:bool=atlas.prepared_dynamic_materials_match(prepared,actor)
            check(accepted==(mode in ["range","highlight","opacity_return"]),"Quarter"+str(quarter)+" exact producer range/full-owner proof "+mode)
            atlas.adopt_source_binding(prepared)
            sync_scene(atlas,world,true,false,sparse([actor]))
            await native_frame_oracle(atlas,world,actor,"producer-range-q"+str(quarter)+"-"+mode,null)
            SourceMaterial.set_parameter(actor,"highlighted",false)
    actor.node.mesh.size=quad_size
    world.camera.position=Vector3(0,0,10);world.camera.look_at(Vector3.ZERO,Vector3.UP)
    actor.node.basis=world.camera.global_basis
    host.queue_free()

func tracked_material_checks(atlas:RefCounted,world:World,entry:Dictionary,source:Image)->void:
    await super.tracked_material_checks(atlas,world,entry,source)
    var sheet=Image.create(128,64,false,Image.FORMAT_RGBA8)
    sheet.blit_rect(source,Rect2i(0,0,64,64),Vector2i.ZERO)
    for y in 64:
        for x in 64:
            var c=source.get_pixel(x,y)
            sheet.set_pixel(x+64,y,Color(c.b,c.r,c.g,c.a))
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(2,2)
    node.position=Vector3(0,2.1,0);world.add_child(node)
    var material=ShaderMaterial.new();material.shader=ActorSource
    node.material_override=material
    var actor={"node":node,"material":material,"cell":Vector2(64,64),"placement":{"id":"modular-frame-fixture","kind":"actor"},"role":"body","source_version":1}
    SourceMaterial.set_parameter(actor,"sheet",ImageTexture.create_from_image(sheet))
    SourceMaterial.set_parameter(actor,"frame_uv",Vector4(0,0,.5,1))
    SourceMaterial.set_parameter(actor,"material_cell_size",Vector2(64,64))
    SourceMaterial.set_parameter(actor,"condition_alpha",.65)
    SourceMaterial.set_parameter(actor,"tint",Vector3(.8,1,.7))
    world.entries.append(actor);world.actor_entries=[actor]
    sync_scene(atlas,world,true,false,sparse([actor]))
    for cap in [0.0,1.0]:
        atlas.set_light_cap(cap);sync_scene(atlas,world)
        var before=await capture(world.get_viewport())
        SourceMaterial.set_parameter(actor,"frame_uv",Vector4(.5 if cap==0 else 0,0,.5,1))
        sync_scene(atlas,world)
        check(atlas.last_reconcile_phases.get("material_frame_copies",0)==(1 if cap==0 else 2),"Actual modular frame uses only UV copies with cap="+str(cap))
        await native_frame_oracle(atlas,world,actor,"modular-frame-cap-"+str(cap),before)
    # Drop one sampled version while condition data also changes: only a full
    # copy can restore all state when this receiver next becomes current.
    SourceMaterial.set_parameter(actor,"condition_alpha",.8);SourceMaterial.acknowledge(actor)
    SourceMaterial.set_parameter(actor,"frame_uv",Vector4(.5,0,.5,1));SourceMaterial.set_parameter(actor,"condition_alpha",.9)
    sync_scene(atlas,world)
    check(atlas.last_reconcile_phases.get("material_frame_copies",0)==0,"Skipped native frame version never accepts a partial copy")
    await native_frame_oracle(atlas,world,actor,"modular-missed-version",null)
    await producer_range_pixels(atlas,world,actor)
    atlas.set_light_cap(0);var id=node.get_instance_id();world.entries.pop_back();world.actor_entries=[];node.queue_free()
    sync_scene(atlas,world,true,false,sparse([],[id]))

func native_frame_oracle(atlas:RefCounted,world:World,actor:Dictionary,label:String,before:Image)->void:
    var first=await capture(world.get_viewport())
    var receiver:Dictionary=row_receiver(atlas,actor)
    var crop=Rect2i(receiver.position,receiver.crop.pixels.size)
    var first_cell=atlas.viewport.get_texture().get_image().get_region(crop).get_data()
    var operands:Dictionary={}
    for name in receiver.group.material.shader.get_shader_uniform_list():operands[name.name]=receiver.group.material.get_shader_parameter(name.name)
    var id:int=actor.node.get_instance_id()
    for group in atlas.source_groups[id].values():group.version=-1
    actor.erase("received_source_key");atlas.material_dirty[id]=true
    sync_scene(atlas,world)
    var complete=await capture(world.get_viewport())
    if first_cell!=atlas.viewport.get_texture().get_image().get_region(crop).get_data():
        var changed:Dictionary={}
        for name in operands:
            var current:Variant=receiver.group.material.get_shader_parameter(name)
            if operands[name]!=current:changed[name]=[str(operands[name]),str(current)]
        print("FRAME_MATERIAL_DIFFERENCE ",JSON.stringify({"case":label,"changes":changed,"source_version":actor.source_version,"binding_revision":actor.source_binding_revision}))
    check(first.get_data()==complete.get_data(),label+": first fast-path final framebuffer equals forced complete copy exactly")
    check(first_cell==atlas.viewport.get_texture().get_image().get_region(crop).get_data(),label+": first fast-path receiving pixels equal forced complete copy exactly")
    if before!=null:check(before.get_data()!=first.get_data(),label+": actual frame changes visible pixels")
    first.save_png("res://.captures/atlas-lifecycle/"+label+".png")
