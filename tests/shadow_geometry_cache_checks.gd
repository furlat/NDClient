extends "res://tests/creature_shadow_checks.gd"
## Same delivered bodies and exact pre-edit shadow calculation, with independent
## helper viewports. The optional oracle is a saved source file, never gameplay.
var reference:RefCounted
var largest_delta:=0
var differing_samples:=0
var compared_samples:=0
# The fixed helper target keeps the footprint in its top-left corner; the
# pre-edit helper was exactly the footprint. Accepted (user, 17 October): the
# moved helper camera's noise, measured as fewer than 0.5% of the footprint's
# samples differing (mostly by 1/255; a flipped soft-shadow tap gives more).
func visibility_matches(current:Dictionary,previous:Dictionary)->bool:
    var expected:Image=previous.viewport.get_texture().get_image()
    var actual:Image=current.viewport.get_texture().get_image().get_region(Rect2i(Vector2i.ZERO,expected.get_size()))
    var a:PackedByteArray=actual.get_data();var b:PackedByteArray=expected.get_data()
    var stride:=4 if expected.get_format()==Image.FORMAT_RGBA8 else 3
    var differing:=0
    for i in range(0,a.size(),stride):
        var delta:=maxi(absi(a[i]-b[i]),maxi(absi(a[i+1]-b[i+1]),absi(a[i+2]-b[i+2])))
        if delta>0:differing+=1;largest_delta=maxi(largest_delta,delta)
    differing_samples+=differing;compared_samples+=a.size()/stride
    return differing*200<=a.size()/stride
func modular()->Dictionary:
    # The original painted sheet is unchanged. Its current metadata owner is
    # the registered native source path and must be explicitly prepared before
    # Geometry.bind's passive descriptor read (as in the gameplay media lane).
    var entry:Dictionary=super.modular()
    var path:String="res://assets/art/media/smallscale/modular/Chest14/Idle.png"
    var admitted:Dictionary=Geometry.BodySources.prepare_descriptor(path,"chest",cache)
    check(not admitted.is_empty(),"Actual modular Chest14 native source metadata admits before geometry binding")
    Geometry.bind(entry,path,cache,texture,true,true,"reference")
    check(SourceMaterial.value(entry,"has_component_geometry") and SourceMaterial.value(entry,"component_depth")!=null and SourceMaterial.value(entry,"component_support")!=null,"Prepared modular source publishes its actual depth and support operands")
    return entry

func run()->void:
    if DisplayServer.get_name()=="headless":quit(2);return
    create_timer(90).timeout.connect(func():printerr("Shadow cache qualification deadline");quit(2))
    var oracle:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--oracle="):oracle=argument.trim_prefix("--oracle=")
    if oracle.is_empty():printerr("Provide the saved pre-edit shadow source with --oracle");quit(2);return
    reference=load(oracle).new()
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    viewport=SubViewport.new();viewport.size=Vector2i(512,512);viewport.world_3d=World3D.new()
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
    stage=Node3D.new();viewport.add_child(stage);camera=Camera3D.new();stage.add_child(camera)
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4
    manager.attach(stage);reference.attach(stage)
    var authored=read(FACTORY.path_join("delivery/catalog.json"))
    var selected:Array=[packet(authored,FACTORY.path_join("delivery"),"goblin-01/idle"),modular()]
    var cookie=light_cookie("C:/Users/tommaso/Documents/Dev/NDCharacterLight/.reference-template/scenes/vfx/textures/T_basic1_vfx.PNG")
    var timings:Dictionary={"original":[],"cached":[]}
    var frame_timings:Dictionary={"original":[],"cached":[]}
    var frame_copies:int=0
    for entry in selected:
        print("SHADOW_GEOMETRY_VISIBILITY ",JSON.stringify({"before":entry.id,"largest_delta":largest_delta,"differing_samples":differing_samples,"compared_samples":compared_samples}))
        var actor:Dictionary={"valid":true,"row":entry.placement,"entries":[entry]}
        var sources:Array=[]
        for quarter in 4:
            camera.basis=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4+quarter*PI/2,0))
            camera.position=camera.basis.z*12;entry.node.basis=camera.basis
            for step in 6:
                var origin:=Vector3(step*.05,0,0)
                actor.row.position=[origin.x,origin.z];entry.node.position=origin
                var uv:Vector4=SourceMaterial.value(entry,"frame_uv")
                uv.x=float(step%3)/entry.frames;uv.y=float(quarter*2)/8
                SourceMaterial.set_parameter(entry,"frame_uv",uv)
                var zoom:float=1.0/Placement.PIXELS_PER_UNIT*camera.unproject_position(camera.basis.x).distance_to(camera.unproject_position(Vector3.ZERO))
                sources=[{"id":"reference","screen_position":camera.unproject_position(origin)+Vector2(14+step*3,42)*zoom,
                    "span":Vector2(cookie.get_size())*19.36*zoom,"height":(20+step)*zoom,"texture":cookie,
                    "energy":2.0,"color":Color(.809372,.429306,.269121),"enabled":true}]
                var actual=manager.sync([actor],camera,sources)
                var expected=reference.sync([actor],camera,sources)
                check(actual.size()==expected.size() and actual.size()==1,"Both helpers admit actual body "+str([entry.id,quarter,step]))
                if actual.is_empty() or expected.is_empty():continue
                var current:Dictionary=manager.actors[entry.id];var previous:Dictionary=reference.actors[entry.id]
                await process_frame;await RenderingServer.frame_post_draw
                check(visibility_matches(current,previous),"Shadow visibility matches the pre-edit helper within the fixed-target noise "+str([entry.id,quarter,step]))
                check(current.footprint==previous.viewport.size and current.entry.node.global_transform==previous.entry.node.global_transform and current.entry.node.mesh.size==previous.entry.node.mesh.size,"Exact footprint and output quad")
                var a:MeshInstance3D=current.casters[entry.id];var b:MeshInstance3D=previous.casters[entry.id]
                check(a.position==b.position and a.custom_aabb==b.custom_aabb,"Exact local bounds and contact")
                for parameter in Shadows.CASTER_PARAMETERS+["component_cell_size","display_basis","sprite_pivot","horizontal_scale","ground_height"]:
                    check(a.material_override.get_shader_parameter(parameter)==b.material_override.get_shader_parameter(parameter),"Exact caster parameter "+parameter)
                var shape:Dictionary=manager._caster_shapes[entry.id]
                manager.sync([actor],camera,sources)
                check(is_same(shape,manager._caster_shapes[entry.id]),"Repeated sample reuses immutable geometry")
                # This second actual source frame keeps actor/light/geometry
                # fixed, exercising only the existing sample key's UV operand.
                var next_uv:Vector4=SourceMaterial.value(entry,"frame_uv")
                next_uv.x=float((step+1)%3)/entry.frames
                SourceMaterial.set_parameter(entry,"frame_uv",next_uv)
                manager.sync([actor],camera,sources);reference.sync([actor],camera,sources)
                frame_copies+=int(manager.diagnostics().sync_counts.get("caster_frame_copies",0))
                await process_frame;await RenderingServer.frame_post_draw
                check(visibility_matches(current,previous),"Actual-frame UV-only redraw within the fixed-target noise "+str([entry.id,quarter,step]))
                for parameter in Shadows.CASTER_PARAMETERS+["component_cell_size","display_basis","sprite_pivot","horizontal_scale","ground_height"]:
                    check(a.material_override.get_shader_parameter(parameter)==b.material_override.get_shader_parameter(parameter),"Exact UV-only caster parameter "+parameter)
                check(a.custom_aabb==b.custom_aabb and a.position==b.position,"UV-only redraw retains exact contact/bounds")
                # A light-only change must redraw shadows without recomputing
                # or rebinding the unchanged source body.
                sources[0].height+=zoom*.5
                for pair in [[reference,"original"],[manager,"cached"]]:
                    var began:int=Time.get_ticks_usec();pair[0].sync([actor],camera,sources)
                    timings[pair[1]].append((Time.get_ticks_usec()-began)/1000.)
                check(is_same(shape,manager._caster_shapes[entry.id]),"Light movement preserves cached local geometry")
                await process_frame;await RenderingServer.frame_post_draw
                check(visibility_matches(current,previous),"Light-only redraw within the fixed-target noise "+str([entry.id,quarter,step]))
        if not manager.actors.has(entry.id) or not reference.actors.has(entry.id):
            # Failed admission is already a failing gate; still finish/report
            # cleanly instead of indexing a helper that was never admitted.
            check(false,"Both actual helpers remain available for source-frame timing controls: "+entry.id)
            entry.node.hide();continue
        for cycle in 9:
            for step in 40:
                var uv:Vector4=SourceMaterial.value(entry,"frame_uv")
                uv.x=float(step%3)/entry.frames
                SourceMaterial.set_parameter(entry,"frame_uv",uv)
                var order=[[reference,"original"],[manager,"cached"]] if cycle%2==0 else [[manager,"cached"],[reference,"original"]]
                for pair in order:
                    var began=Time.get_ticks_usec();pair[0].sync([actor],camera,sources)
                    frame_timings[pair[1]].append((Time.get_ticks_usec()-began)/1000.)
        # Replacing the private caster material must use the complete update,
        # even when the delivered source changes only its next frame UV.
        var current:Dictionary=manager.actors[entry.id];var previous:Dictionary=reference.actors[entry.id]
        for state in [current,previous]:
            state.casters[entry.id].material_override=state.casters[entry.id].material_override.duplicate()
            state.casters[entry.id].material_override.set_shader_parameter("component_units",0.0)
        var replacement_uv:Vector4=SourceMaterial.value(entry,"frame_uv");replacement_uv.x=float(2)/entry.frames
        SourceMaterial.set_parameter(entry,"frame_uv",replacement_uv)
        manager.sync([actor],camera,sources);reference.sync([actor],camera,sources)
        check(manager.diagnostics().sync_counts.get("caster_frame_copies",0)==0,"Material replacement refuses UV-only update")
        for parameter in Shadows.CASTER_PARAMETERS:
            check(current.casters[entry.id].material_override.get_shader_parameter(parameter)==previous.casters[entry.id].material_override.get_shader_parameter(parameter),"Replacement preserves complete caster material: "+parameter)
        manager.sync([],camera,[]);reference.sync([],camera,[])
        check(manager._caster_shapes.is_empty(),"Retired body releases cached shape")
        entry.node.hide()
    check(frame_copies>0,"Delivered body animations exercise UV-only update across views")
    manager.close();reference.close();viewport.queue_free();await process_frame;await process_frame
    var profile=load("res://frame_profile.gd")
    var report:Dictionary={"checks":checks,"failures":failures,"timings":{"original":profile.distribution(timings.original),"cached":profile.distribution(timings.cached)},"frame_only_timings":{"original":profile.distribution(frame_timings.original),"cached":profile.distribution(frame_timings.cached)},"frame_copies":frame_copies,"largest_visibility_delta":largest_delta,"differing_visibility_samples":differing_samples,"compared_visibility_samples":compared_samples,"scope":"Delivered goblin and modular chest; four cameras, animated UVs, moving actor and light; pre-edit native visibility within the fixed-target noise (under 0.5% of samples) and all caster parameters. Isolated timings, not full-game acceptance."}
    FileAccess.open("res://.runtime/shadow-geometry-cache-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SHADOW_GEOMETRY_CACHE_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
