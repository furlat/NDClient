extends "res://tests/native_observed_damage_render_checks.gd"
## Original two-seat Orb recording, actual persistent owner and native source.
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for seat in ["amber","blue"]:
        var index:Dictionary=Fixtures.read("chromatic-orb",seat)
        check(index.ok,seat+" actual Orb journal compiles")
        if not index.ok:continue
        var at:float=float(index.presentation_end_ms)+4100.0
        var view:SubViewport=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
        view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
        var world=Play.new();world.external_playback=true;world.external_clock=true
        world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
        world.playback_end_ms=at+2000.0;world.component_renderer.audio.set_enabled(false)
        view.add_child(world);world.install_playback(Recording.restore(index,at))
        if not await settle(world):view.queue_free();await frame();continue
        var native=world.component_renderer.native_spells
        var handles:Array=native.handles.values().filter(func(handle):return handle.component.get("spatial_owner",false) and handle.component.get("spatial_content_id")=="spatial_effect.spell.acid_surface")
        check(handles.size()==1,seat+" one disclosed Acid UUID owns one actual native surface")
        if handles.size()!=1:view.queue_free();await frame();continue
        var component:Dictionary=handles[0].component
        world.camera_focus=Play.Placement.contact({"position":component.position,"base_height_steps":float(component.elevation_feet)/5.0})
        world.camera.size=7;world.initial_focus=true;world.position_camera();world.grid_visible=false
        # The final camera changes native support/output. Use the same actual
        # preparation boundary before observing its original source planes.
        if not await settle(world):view.queue_free();await frame();continue
        native=world.component_renderer.native_spells
        handles=native.handles.values().filter(func(handle):return handle.component.get("spatial_effect_uuid")==component.spatial_effect_uuid)
        check(handles.size()==1,seat+" final prepared camera retains the same one actual surface owner")
        if handles.size()!=1:view.queue_free();await frame();continue
        var handle:Dictionary=handles[0]
        component=handle.component
        var effect:Dictionary=world.timeline.state.senses.spatial_effects[component.spatial_effect_uuid]
        var programs:Array=handle.occurrence.input_receivers.get("set_surface_partition",[])
        var owner_programs:Array=handle.occurrence.input_receivers.get("set_owner_state",[])
        var anchor_programs:Array=handle.occurrence.input_receivers.get("set_live_endpoints",[])
        check(programs.size()==2 and programs.all(func(program):return program in owner_programs and program in anchor_programs),seat+" exact public owner, partition and anchor setters reach both original ground and film sources")
        var source_evidence:Array=[]
        for program in programs:
            var source:Dictionary={"part":str(program.name),"script":program.get_script().resource_path,
                "owner_uuid":program.owner_uuid,"owner_state":program.owner_state.duplicate(true),
                "partition":program.packet.duplicate(true),"anchor_valid":program.anchor_valid,
                "state_error":program.state_error,"plane_visible":program.plane!=null and program.plane.is_visible_in_tree()}
            source_evidence.append(source)
            check(program.owner_uuid==component.spatial_effect_uuid and program.owner_state.get("owner_uuid")==component.spatial_effect_uuid \
                and program.owner_state.get("present",false) and program.owner_state.get("observed",false) and not program.owner_state.get("suppressed",true),seat+" "+str(program.name)+" admits the actual current public owner")
            var drawn:Array=[]
            if not program.packet.is_empty():
                for cell_index in int(program.packet.count):
                    if program.packet.draw_flags[cell_index]!=1.0:continue
                    var point:Vector2=program.packet.points[cell_index]
                    drawn.append([component.position[0]+int(point.x),component.position[1]+int(point.y)])
            check(program.state_error.is_empty() and program.packet.get("owner_uuid")==component.spatial_effect_uuid \
                and drawn.size()==effect.positions.size() and drawn.all(func(position):return position in effect.positions),seat+" "+str(program.name)+" draws only all independently disclosed cells")
            check(float(program.owner_state.get("owner_age_seconds",0.0))>float(handle.clip.seconds),seat+" "+str(program.name)+" actual owner clock outlives the finite review phase without invented retirement")
            check(program.anchor_valid and program.plane!=null and program.plane.mesh!=null and program.plane.is_visible_in_tree(),seat+" "+str(program.name)+" real source geometry draws after actual setters, not neutral warm-up")
        var diagnostic:Dictionary=native.diagnostics.get(component.id,{}).duplicate(true)
        world.set_process(false)
        var present:Image=view.get_texture().get_image()
        var present_pass:Image=partition_pass_image(native,handle)
        var present_draw:Dictionary=partition_draw_state(native,handle)
        Effects.hide(handle);await frame();await frame()
        var hidden:Image=view.get_texture().get_image()
        var hidden_pass:Image=partition_pass_image(native,handle)
        var hidden_draw:Dictionary=partition_draw_state(native,handle)
        var pixels:int=changed(present,hidden)
        check(pixels>0,seat+" actual surface contributes native framebuffer pixels: "+str({"native":diagnostic,"source":source_evidence}))
        present.save_png("res://.runtime/native-spatial-"+seat+".png")
        var capture:Dictionary={"seat":seat,"spatial_effect_uuid":component.spatial_effect_uuid,"cells":effect.positions,"changed_pixels":pixels,
            "source":source_evidence,"native":diagnostic}
        if pixels==0:
            capture.zero_pixel_draw={"present":present_draw,"hidden":hidden_draw,
                "present_pass":partition_image_channels(present_pass),"hidden_pass":partition_image_channels(hidden_pass)}
            var path:String="res://.runtime/native-spatial-"+seat
            if present_pass!=null:present_pass.save_png(path+"-pass-present.png")
            if hidden_pass!=null:hidden_pass.save_png(path+"-pass-hidden.png")
        evidence.append(capture)
        var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
        world.set_process(true)
        world.install_playback(Recording.restore(index,0.0))
        if await settle(world):
            check(not world.timeline.state.senses.spatial_effects.has(component.spatial_effect_uuid),seat+" backward seek does not publish a future surface")
        world.install_playback(Recording.restore(index,at))
        if await settle(world):
            check(var_to_bytes(world.timeline.state)==canonical,seat+" repeated loop restores the identical canonical owner state")
            var active:Array=world.component_renderer.native_spells.handles.values().filter(func(item):return item.component.get("spatial_effect_uuid")==component.spatial_effect_uuid)
            check(active.size()==1,seat+" repeated seek owns one fresh prepared surface, without duplicate lifetime")
        check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+" owner replay has no resource/presentation errors")
        view.queue_free();await frame();await frame()
    finish()

func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Original independent Acid surface journals, sealed source setters/native output, exact lifetime, backward seek/replay and teardown. Other material variants/removal scenarios/art approval remain unqualified."}
    FileAccess.open("res://.runtime/native-spatial-owner-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPATIAL_OWNER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

# Additive failure diagnostics at the existing present/hidden capture points.
# Read actual source planes and the existing pass; never change its inputs.
func partition_draw_state(native:RefCounted,handle:Dictionary)->Dictionary:
    var group:Dictionary=native.groups.get(handle.get("group_key",""),{})
    var result:Dictionary={"root_visible":handle.root.visible,"root_visible_in_tree":handle.root.is_visible_in_tree(),"planes":[]}
    if not group.is_empty():
        result.pass_state={"layer":group.layer_mask,"viewport_size":group.viewport.size,
            "viewport_id":group.viewport.get_instance_id(),"viewport_rid":str(group.viewport.get_viewport_rid()),"process_frame":Engine.get_process_frames(),
            "clear_mode":group.viewport.render_target_clear_mode,
            # Pinned viewport.h: (RenderInfoType, RenderInfo), last completed render.
            "visible_draw_calls":group.viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
            "visible_objects":group.viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
            "update_mode":group.viewport.render_target_update_mode,"camera_transform":group.camera.global_transform,
            "camera_size":group.camera.size,"camera_layers":group.camera.cull_mask,
            "output_visible":group.output.visible,"output_visible_in_tree":group.output.is_visible_in_tree(),
            "output_modulate":group.output.modulate,"output_self_modulate":group.output.self_modulate,
            "output_material_matches":group.output.material==group.material,
            "native_texture_matches":group.material.get_shader_parameter("native_colour")==group.viewport.get_texture()}
        result.owners=partition_owner_inventory(native,handle,group)
    for program in handle.occurrence.input_receivers.get("set_surface_partition",[]):
        var plane:MeshInstance3D=program.plane
        var material:ShaderMaterial=plane.material_override
        var uniforms:Dictionary={}
        for name in ["payload_alpha","payload_footprint_origin","payload_cell_count","payload_draw_flags",
            "observed_cell_count","observed_draw_flags","orb_burst_envelope","factory_occurrence_alpha","factory_world_to_source"]:
            uniforms[name]=material.get_shader_parameter(name)
        result.planes.append({"part":str(program.name),"program_id":program.get_instance_id(),"program_path":str(program.get_path()),
            "plane":partition_node_identity(plane),"visible":plane.visible,"visible_in_tree":plane.is_visible_in_tree(),
            "top_level":plane.top_level,"transparency":plane.transparency,"layers":plane.layers,
            "transform":plane.global_transform,"aabb":plane.get_aabb(),
            "material_matches_source":material==program.material,"material_id":material.get_instance_id(),
            "shader_id":material.shader.get_instance_id(),"shader_path":material.shader.resource_path,
            "uniforms":uniforms})
    return result

func partition_pass_image(native:RefCounted,handle:Dictionary)->Image:
    var group:Dictionary=native.groups.get(handle.get("group_key",""),{})
    return null if group.is_empty() else group.viewport.get_texture().get_image()

func partition_image_channels(image:Image)->Dictionary:
    if image==null:return {"available":false}
    var rgb:int=0;var alpha:int=0;var maximum:Color=Color(0,0,0,0)
    for y in image.get_height():
        for x in image.get_width():
            var value:Color=image.get_pixel(x,y)
            if value.r!=0.0 or value.g!=0.0 or value.b!=0.0:rgb+=1
            if value.a!=0.0:alpha+=1
            maximum=Color(maxf(maximum.r,value.r),maxf(maximum.g,value.g),maxf(maximum.b,value.b),maxf(maximum.a,value.a))
    return {"available":true,"size":image.get_size(),"format":image.get_format(),"nonzero_rgb_pixels":rgb,
        "nonzero_alpha_pixels":alpha,"maximum_rgba":maximum}

# Bounded snapshots only, at the existing present/hidden capture fences.
func partition_node_identity(node:Node)->Dictionary:
    if not is_instance_valid(node):return {"valid":false}
    var parents:Array=[];var parent:Node=node.get_parent()
    while parent!=null and parents.size()<8:
        parents.append({"id":parent.get_instance_id(),"path":str(parent.get_path()),"class":parent.get_class(),
            "script":parent.get_script().resource_path if parent.get_script()!=null else ""})
        parent=parent.get_parent()
    return {"valid":true,"id":node.get_instance_id(),"path":str(node.get_path()),"class":node.get_class(),
        "script":node.get_script().resource_path if node.get_script()!=null else "","parents":parents,"parents_truncated":parent!=null}

func partition_geometry_identity(node:GeometryInstance3D)->Dictionary:
    var row:Dictionary=partition_node_identity(node)
    row.merge({"render_instance_rid":str(node.get_instance()),"visible":node.visible,"visible_in_tree":node.is_visible_in_tree(),"top_level":node.top_level,
        "layers":node.layers,"transform":node.global_transform,"world_id":node.get_world_3d().get_instance_id(),
        "material_override_id":node.material_override.get_instance_id() if node.material_override!=null else 0},true)
    return row

func partition_handle_identity(handle:Dictionary,mask:int)->Dictionary:
    var pieces:Array=[];var matching:int=0
    for index in handle.get("geometry",[]).size():
        var geometry:GeometryInstance3D=handle.geometry[index].node
        if not is_instance_valid(geometry) or (geometry.layers&mask)==0:continue
        matching+=1
        if pieces.size()==32:continue
        var piece:Dictionary=partition_geometry_identity(geometry);piece.geometry_index=index;pieces.append(piece)
    var occurrence:Node=handle.get("occurrence")
    var row:Dictionary={"root":partition_node_identity(handle.get("root")),"occurrence":partition_node_identity(occurrence),
        "clip_id":handle.get("clip",{}).get("id",""),"source_phase":handle.get("effect_source_phase",""),
        "layer_mask":handle.get("layer_mask",0),"group_key":handle.get("group_key",""),
        "started":handle.get("started",false),"warming":handle.get("warming",false),"age":handle.get("age",-1.0),
        "sample_time":handle.get("sample_time",-1.0),"matching_geometry_count":matching,"matching_geometry":pieces,
        "geometry_truncated":matching>pieces.size()}
    if is_instance_valid(handle.get("root")):
        row.root.visible=handle.root.visible;row.root.visible_in_tree=handle.root.is_visible_in_tree()
        row.root.world_id=handle.root.get_world_3d().get_instance_id()
    return row

func partition_owner_inventory(native:RefCounted,handle:Dictionary,group:Dictionary)->Dictionary:
    var mask:int=int(group.camera.cull_mask)
    var target_world:World3D=group.camera.get_world_3d()
    var result:Dictionary={"camera_mask":mask,"source_layer":group.layer_mask,"world_id":target_world.get_instance_id(),
        "native_owner":partition_node_identity(native._owner),"handles":[],"prepared_passes":[],"spare_passes":[],
        "visible_geometry":[],"visible_geometry_count":0,"walked_nodes":0}
    for id in native.handles:
        var candidate:Dictionary=native.handles[id]
        var same_group:bool=candidate.get("group_key","")==handle.get("group_key","")
        var on_layer:bool=candidate.get("geometry",[]).any(func(piece):return is_instance_valid(piece.node) and (piece.node.layers&int(group.layer_mask))!=0)
        if not same_group and not on_layer:continue
        var item:Dictionary=partition_handle_identity(candidate,mask)
        item.id=id;item.selected=is_same(candidate,handle);item.same_group=same_group
        item.component_id=candidate.get("component",{}).get("id","")
        item.spatial_effect_uuid=candidate.get("component",{}).get("spatial_effect_uuid")
        result.handles.append(item)
    for key in native.prepared_layers:
        var layer:Dictionary=native.prepared_layers[key]
        result.prepared_passes.append({"key":key,"layer":layer.layer_mask,"viewport":partition_node_identity(layer.viewport),
            "update_mode":layer.viewport.render_target_update_mode,"clear_mode":layer.viewport.render_target_clear_mode,"warm":layer.get("warm",-1)})
    for index in native.spare_layers.size():
        var layer:Dictionary=native.spare_layers[index]
        result.spare_passes.append({"index":index,"layer":layer.layer_mask,"viewport":partition_node_identity(layer.viewport),
            "update_mode":layer.viewport.render_target_update_mode,"clear_mode":layer.viewport.render_target_clear_mode,"warm":layer.get("warm",-1)})
    var pending:Array=[handle.root.get_tree().root]
    while not pending.is_empty() and result.walked_nodes<8192:
        var node:Node=pending.pop_back();result.walked_nodes+=1
        pending.append_array(node.get_children())
        if not node is GeometryInstance3D or not node.is_visible_in_tree() or (node.layers&mask)==0 or node.get_world_3d()!=target_world:continue
        result.visible_geometry_count+=1
        if result.visible_geometry.size()==128:continue
        var geometry:Dictionary=partition_geometry_identity(node)
        geometry.on_source_layer=(node.layers&int(group.layer_mask))!=0
        result.visible_geometry.append(geometry)
    result.walk_truncated=not pending.is_empty()
    result.geometry_truncated=result.visible_geometry_count>result.visible_geometry.size()
    var startup:Dictionary=Play.NativeStartup._state
    result.startup={"owner":partition_node_identity(startup.get("owner")),"active_key":startup.get("active",{}).get("key","")}
    if is_instance_valid(startup.get("owner")):
        result.startup.world_id=startup.owner.get_world_3d().get_instance_id()
        result.startup.same_world=startup.owner.get_world_3d()==target_world
    if not startup.get("active",{}).get("handle",{}).is_empty():
        result.startup.handle=partition_handle_identity(startup.active.handle,mask)
    return result
