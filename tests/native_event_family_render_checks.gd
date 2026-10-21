extends "res://tests/native_finite_observed_render_checks.gd"
## The whole new finite family batch through the ordinary Play renderer.
const EventChecks=preload("res://tests/event_family_consumers_checks.gd")
const EVENT_ROOT="res://tests/fixtures/schema16/event-families"
const RELEASE_CLIPS=EventChecks.RELEASE_CLIPS
var source_counts:Dictionary={}
var case_inputs:Array=[]
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var cases:PackedStringArray=DirAccess.get_directories_at(EVENT_ROOT);cases.sort()
    for case_id in cases:
        for seat in ["amber","blue"]:await family_seat(case_id,seat)
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "source_counts":source_counts,"case_inputs":case_inputs,
        "factory_version":JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/index.json")).version,
        "scope":"13 family case selections in both seats; portable and delayed Vitriolic positives use their completed same-ID current originals, while headless retains archived unavailable public operands. Exact admitted source counts and journal inputs are reported separately. Four camera views, supplied setters, isolated framebuffer pixels, held ice beyond review expiry, seek/loop and teardown; timing/performance and human visual/audio acceptance remain separate."}
    FileAccess.open("res://.runtime/native-event-family-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_EVENT_FAMILY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func family_clip(case_id:String)->String:
    return EventChecks.wanted(case_id)
func family_seat(case_id:String,seat:String)->void:
    var label:String=case_id+"/"+seat
    var directory:String=EVENT_ROOT.path_join(case_id).path_join(seat)
    var scenario_path:String=EVENT_ROOT.path_join(case_id).path_join("scenario.json")
    var producer:Dictionary={}
    if EventChecks.CURRENT_EVENT_FIXTURES.has(case_id):
        var current:Dictionary=EventChecks.current_family_original(case_id)
        check(not current.is_empty() and current.get("status")=="recorded" and not current.get("engine",{}).is_empty(),label+" current family source uses its completed same-ID original and actual producer identity")
        if current.is_empty() or current.get("status")!="recorded":return
        directory=str(current.get("journals",{}).get(seat,""));scenario_path=str(current.get("scenario",""))
        producer=current.get("engine",{});label+="/current"
        check(not directory.is_empty() and not scenario_path.is_empty(),label+" current journal and scenario paths are explicit")
        if directory.is_empty() or scenario_path.is_empty():return
    var scenario:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(scenario_path))
    var index:Dictionary=Recording.read(directory)
    check(index.ok,label+" ordinary Studio compilation opens unchanged journal")
    if not index.ok:return
    var rows:Array=EventChecks.family_rows(index,case_id)
    var expected:int=9 if case_id=="spell.vitriolic_sphere__delayed_end_results" \
        else 7 if case_id=="spell.freezing_sphere__launch_detonation" \
        else 6 if case_id in ["spell.freezing_sphere__portable_detonation","spell.delayed_blast_fireball__concentration_end_detonation"] \
        else 5 if family_clip(case_id)==EventChecks.PAYLOAD_COLD else 1
    check(rows.size()==expected and rows.all(func(row):return row.component.status=="available"),label+" exact finite family count has factual inputs")
    if rows.size()!=expected:return
    case_inputs.append({"case":scenario.id,"seat":seat,"journal":directory,"producer":producer,
        "provenance":"current_original" if not producer.is_empty() else "preserved_archived_original","source_rows":rows.size()})
    for row in rows:
        var component:Dictionary=row.component
        var category:String="accepted_release" if component.native_clip.id==RELEASE_CLIPS.get(case_id,"") \
            else "ice_owner" if component.native_clip.id==EventChecks.ICE \
            else "portable_blast" if component.native_cue.get("constructor_input",{}).get("projection")=="portable_payload_blast" \
            else "immediate_blast" if component.native_clip.id==EventChecks.BLAST \
            else "retired_blast" if component.native_clip.id==EventChecks.RETIRED_BLAST else "finite_contact_or_outcome"
        source_counts[category]=int(source_counts.get(category,0))+1
    var media:Dictionary=RecordingMedia.plan(index)
    check(media.errors.is_empty(),label+" original source media closure resolves")
    if not media.errors.is_empty():return
    Play.Catalog.adopt_snapshot(index.cache,media.source_files)
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.media_warmup.budget_bytes=0;world.media_warmup.encounter_override=media
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows)
    world.native_startup_requested_ms=maxf(0.0,float(rows[0].start_ms)-2.0)
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    for row in rows:
        var component:Dictionary=row.component
        var during:float=float(row.start_ms)+minf(110.0 if family_clip(case_id)!=EventChecks.DIVINE else 350.0,float(component.duration_ms)*.35)
        var release:bool=component.native_clip.id==RELEASE_CLIPS.get(case_id,"")
        var ice:bool=component.native_clip.id==EventChecks.ICE
        if release:during=float(row.start_ms)+(float(component.native_cue.launch)+.4*(float(component.native_cue.contact)-float(component.native_cue.launch)))*1000.0
        if ice:
            during=maxf(float(index.presentation_end_ms),float(row.start_ms))+4100.0
            world.playback_end_ms=during+2000.0
        world.install_playback(Recording.restore(index,during))
        if not await settle(world,component.id):break
        var native=world.component_renderer.native_spells
        check(native.handles.has(component.id),label+" actual finite source is prepared at its own result clock")
        if not native.handles.has(component.id):continue
        var handle:Dictionary=native.handles[component.id]
        var blast:bool=component.native_clip.id in [EventChecks.BLAST,EventChecks.RETIRED_BLAST]
        var portable:bool=component.native_cue.get("constructor_input",{}).get("projection")=="portable_payload_blast"
        var channel:String="accepted_release" if release else "owner_state" if ice else "observed_explosion" if portable else "blast_event" if blast else "observation" if family_clip(case_id)==EventChecks.DIVINE else "native_state" if family_clip(case_id)==EventChecks.TICK else "damage_event"
        var programs:Array=handle.occurrence.input_receivers.get("set_"+channel,[])
        check(programs.size()==1,label+" one actual sealed program receives the factual "+channel)
        var bindings:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
        check(not bindings.is_empty() and bindings.unavailable.is_empty(),label+" every selected phase input is supplied")
        if programs.size()!=1:continue
        var program:Node3D=programs[0]
        var supplied:Dictionary=handle.accepted_release_input if release else handle.spatial_owner_state_input if ice else component.native_inputs[channel]
        if release:
            check(program.authoritative_release and program.release_snapshot.is_equal_approx(supplied.point) \
                and program.specification.acting_holder_uuid==component.actor_uuid,label+" native release retains actual accepted holder and exact authored release hand")
        elif ice:
            check(program.owner_state==supplied and program.packet==component.spatial_surface_partition \
                and program.packet.owner_uuid==component.spatial_effect_uuid and program.packet.draw_count==49,
                label+" actual current49-cell owner and full-topology draw partition reach the selected source")
        elif portable:
            check(program.observed.explosion_occurrence==str(component.source_event_uuid) \
                and program.observed.source_caster_uuid==supplied.explosion.fact.source_entity_uuid \
                and not program.observed.ancestry_occurrences.is_empty(),label+" delivered portable source retains actual explosion, caster and accepted throw ancestry")
        else:
            var observed:Dictionary=program.observation if channel=="observation" else program.state if channel=="native_state" else program.event
            check(observed==supplied,label+" delivered program retains the exact native result/outcome packet")
        world.camera_focus=Play.Placement.contact({"position":component.from_position if blast else component.to_position,"base_height_steps":float(component.get("to_elevation_feet",0.0))/5.0})
        world.camera.size=4;world.initial_focus=true;world.grid_visible=false
        for quarter in 4:
            world.set_process(true);world.request_view(quarter)
            var deadline:int=Time.get_ticks_msec()+15000
            while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
            check(not world.rotation_pending() and world.world_quarter==quarter,label+" actual camera quarter publishes "+str(quarter))
            if not await settle(world,component.id):break
            if not native.handles.has(component.id):check(false,label+" view publication retains the finite source");break
            handle=native.handles[component.id]
            if release:
                var receivers:Array=handle.occurrence.input_receivers.get("set_accepted_release",[])
                check(receivers.size()==1,label+" view retains one accepted release program")
                if receivers.size()==1:
                    var source:Node3D=receivers[0]
                    var progress:float=clampf((float(source.previous_seconds)-float(source.launch_seconds))/float(source.travel_seconds),0.0,1.0)
                    var destination:Vector3=source.endpoints[1].point
                    var exact:Vector3=source.release_snapshot.lerp(destination,progress)
                    var geometry_follows:bool=source.draws[0].global_position.distance_to(exact)<.2 if source.specification.kind=="acid" else source.draws[0].global_position.is_equal_approx(exact)
                    var trajectory_ready:bool=source.point.is_equal_approx(exact) and geometry_follows
                    check(trajectory_ready,label+" internal world-point delivery follows exact hand/destination without a second root transform"+("" if trajectory_ready else ": "+JSON.stringify({
                        "quarter":quarter,"expected_world":exact,"source_point":source.point,
                        "draw_world":source.draws[0].global_position,"source_age":source.previous_seconds,
                        "source_transform":source.global_transform,"root_transform":handle.root.global_transform,
                        "release":source.release_snapshot,"destination":destination,"progress":progress})))
            # Final camera placement changes the measured recipient surface key.
            # Settle that actual optical demand before freezing the same clock;
            # a ready handle from the prior camera cannot certify this picture.
            world.position_camera()
            if not await settle(world,component.id):break
            handle=native.handles[component.id]
            var capture_bindings:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
            check(not capture_bindings.is_empty() and capture_bindings.unavailable.is_empty(),label+" final capture camera has every actual phase input ready")
            var payload_ready:Dictionary=payload_geometry_diagnostic(native,handle) if component.native_clip.id in [EventChecks.PAYLOAD_COLD,EventChecks.PAYLOAD_FIRE] else {}
            await frame();await frame();world.set_process(false)
            var payload_present:Dictionary=payload_geometry_diagnostic(native,handle) if not payload_ready.is_empty() else {}
            var original:PackedByteArray=var_to_bytes(world.timeline.state)
            var present:Image=view.get_texture().get_image()
            var present_pass:Image=partition_pass_image(native,handle) if ice else null
            var present_draw:Dictionary=partition_draw_state(native,handle) if ice else {}
            handle.root.hide();await frame();await frame()
            var hidden:Image=view.get_texture().get_image();var pixels:int=changed(present,hidden)
            var hidden_pass:Image=partition_pass_image(native,handle) if ice else null
            var hidden_draw:Dictionary=partition_draw_state(native,handle) if ice else {}
            check(pixels>0,label+" isolated native source changes framebuffer in camera "+str(quarter))
            check(var_to_bytes(world.timeline.state)==original,label+" framebuffer control does not alter canonical state")
            handle.root.show();await frame()
            var capture:Dictionary={"case":scenario.id,"fixture_folder":case_id,"seat":seat,"clip":component.native_clip.id,"occurrence":component.source_event_uuid,
                "quarter":quarter,"changed_pixels":pixels,"input":supplied}
            if pixels==0 and ice:
                var ice_receivers:Array=handle.occurrence.input_receivers.get("set_surface_partition",[])
                var ice_details:Dictionary={"stage":"restored_after_hide_control","receiver_count":ice_receivers.size(),
                    "sample_time":handle.sample_time,"requested_time":handle.requested_time,"drawn_time":handle.drawn_time,
                    "native_diagnostic":native.diagnostics.get(component.id,{}).duplicate(true),
                    "root_transform":handle.root.global_transform,"root_visible":handle.root.is_visible_in_tree(),
                    "camera_transform":world.camera.global_transform,"camera_size":world.camera.size,"camera_layers":world.camera.cull_mask,
                    "resolved_cells":component.resolved_area_positions,"source_anchor":component.from_position,
                    "source_elevation_feet":component.from_elevation_feet}
                if ice_receivers.size()==1:
                    var ice_source:Node3D=ice_receivers[0]
                    var ice_plane:MeshInstance3D=ice_source.plane
                    var ice_bounds:AABB=ice_plane.get_aabb()
                    var center:Vector3=ice_plane.global_transform*ice_bounds.get_center()
                    ice_details.merge({"owner_state":ice_source.owner_state,"anchor_valid":ice_source.anchor_valid,
                        "state_error":ice_source.state_error,"packet":ice_source.packet,"plane_visible":ice_plane.visible,
                        "plane_visible_in_tree":ice_plane.is_visible_in_tree(),"plane_layers":ice_plane.layers,
                        "plane_transform":ice_plane.global_transform,"plane_aabb":ice_bounds,"world_center":center,
                        "viewport_center":world.camera.unproject_position(center),"behind_camera":world.camera.is_position_behind(center),
                        "payload_alpha":ice_source.material.get_shader_parameter("payload_alpha"),
                        "payload_footprint_origin":ice_source.material.get_shader_parameter("payload_footprint_origin"),
                        "material_path":ice_source.material.shader.resource_path})
                DirAccess.make_dir_recursive_absolute("res://.runtime/event-family-captures")
                var ice_capture:String="res://.runtime/event-family-captures/"+case_id+"-"+seat+"-ice-q"+str(quarter)
                check(present.save_png(ice_capture+"-present.png")==OK and hidden.save_png(ice_capture+"-hidden.png")==OK,label+" failed ice source retains exact present/hidden framebuffer evidence")
                ice_details.capture=ice_capture
                ice_details.draw_control={"present":present_draw,"hidden":hidden_draw,
                    "present_pass":partition_image_channels(present_pass),"hidden_pass":partition_image_channels(hidden_pass)}
                if present_pass!=null:present_pass.save_png(ice_capture+"-pass-present.png")
                if hidden_pass!=null:hidden_pass.save_png(ice_capture+"-pass-hidden.png")
                capture.zero_pixel_diagnostic=ice_details
            if pixels==0 and component.native_clip.id in [EventChecks.PAYLOAD_COLD,EventChecks.PAYLOAD_FIRE]:
                var receivers:Array=handle.occurrence.input_receivers.get("set_damage_event",[])
                var details:Dictionary={"stage":"restored_after_hide_control","receiver_count":receivers.size(),"sample_time":handle.sample_time,
                    "ready_picture":payload_ready,"present_picture":payload_present,"restored_picture":payload_geometry_diagnostic(native,handle),
                    "requested_time":handle.requested_time,"drawn_time":handle.drawn_time,"rendered_once":handle.rendered_once,
                    "native_diagnostic":native.diagnostics.get(component.id,{}).duplicate(true),
                    "camera_transform":world.camera.global_transform,"camera_size":world.camera.size,
                    "root_transform":handle.root.global_transform,"root_visible":handle.root.is_visible_in_tree()}
                if receivers.size()==1:
                    var source:Node3D=receivers[0]
                    details.source_observation=source.capture_observation()
                    details.endpoints=source.endpoints.map(func(endpoint):return {"actor_uuid":endpoint.get("actor_uuid",""),"socket":endpoint.get("socket",""),"point":endpoint.point})
                    details.draws=[]
                    for i in source.draws.size():
                        var draw:MeshInstance3D=source.draws[i];var material:ShaderMaterial=source.materials[i]
                        details.draws.append({"visible":draw.visible,"inherited_visible":draw.is_visible_in_tree(),
                            "layers":draw.layers,"transform":draw.global_transform,"aabb":draw.get_aabb(),
                            "viewport_point":world.camera.unproject_position(draw.global_position),
                            "behind_camera":world.camera.is_position_behind(draw.global_position),
                            "payload_seconds":material.get_shader_parameter("payload_seconds"),
                            "payload_alpha":material.get_shader_parameter("payload_alpha")})
                capture.zero_pixel_diagnostic=details
            evidence.append(capture)
        world.set_process(true)
    for at in [maxf(0.0,float(rows[0].start_ms)-2.0),index.presentation_end_ms,(float(rows[0].start_ms)+float(rows[0].end_ms))*.5]:
        world.install_playback(Recording.restore(index,at))
        var first:Dictionary=rows[0].component
        var blast:bool=first.native_clip.id in [EventChecks.BLAST,EventChecks.RETIRED_BLAST]
        world.camera_focus=Play.Placement.contact({"position":first.from_position if blast else first.to_position,
            "base_height_steps":float(first.get("to_elevation_feet",0.0))/5.0})
        world.initial_focus=true;world.position_camera()
        var active:bool=at>rows[0].start_ms and at<rows[0].end_ms
        if not await settle(world,first.id if active else ""):break
        # A native witness is published by the sample after frame_post_draw
        # marks the new private occurrence rendered. Read that actual sample,
        # rather than the first ready frame's pre-draw witness population.
        await frame();await frame()
        var samples:Array=world.displayed_components.filter(func(sample):return sample.id==first.id)
        var witnessed:bool=world.component_renderer.native_spells.witnesses.any(func(witness):return witness.id==first.id)
        check((samples.size()==1)==active,label+" actual seek/loop samples the exact finite interval at "+str(at))
        if active and samples.size()==1:check(is_equal_approx(float(samples[0].age_ms),at-float(rows[0].start_ms)),label+" restored finite source retains its exact original age")
        check(witnessed==active,label+" actual seek/loop preserves visible finite interval ownership at "+str(at))
        evidence.append({"kind":"native_seek_interval","case":scenario.id,"fixture_folder":case_id,"seat":seat,
            "component_id":first.id,"target_ms":at,"display_ms":world.timeline.display_ms,"active":active,
            "sample_age_ms":samples[0].age_ms if samples.size()==1 else null,"witnessed":witnessed,
            "quarter":world.world_quarter,"camera_focus":world.camera_focus,
            "native_diagnostic":world.component_renderer.native_spells.diagnostics.get(first.id,{})})
    evidence.append({"kind":"native_preparation_profile","case":scenario.id,"fixture_folder":case_id,"seat":seat,
        "preparation_profile":preparation_profile(world)})
    var native=world.component_renderer.native_spells;native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty(),label+" teardown releases private source ownership")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+" original replay remains free of presentation/resource errors")
    view.queue_free();await frame();await frame()

# Read exact optical keys already supplied to the common payload recipient
# source. Never request/poll a measurement or change cache interest here.
func payload_geometry_diagnostic(native:RefCounted,handle:Dictionary)->Dictionary:
    var receivers:Array=handle.occurrence.input_receivers.get("set_damage_event",[])
    if receivers.size()!=1:return {}
    var source:Node3D=receivers[0]
    var geometry:Dictionary=source.geometry
    var surface:RefCounted=native.inputs.surfaces
    var keys:Array=[]
    for key in geometry.get("pose_key",[]):
        var job:Dictionary=surface.jobs.get(key,{})
        keys.append({"key":key.duplicate(true),"resident":surface.sources.has(key),
            "cache_order":surface.source_order.find(key),"pending":surface.pending.has(key),
            "pending_order":surface.pending_order.find(key),"worker":not job.is_empty(),
            "worker_complete":WorkerThreadPool.is_task_completed(job.task) if not job.is_empty() else false})
    return {"frame":Engine.get_process_frames(),"native_diagnostic":native.diagnostics.get(handle.component.id,{}).duplicate(true),
        "point_count":geometry.get("points",[]).size(),"geometry_ready":geometry.get("ready",false),
        "geometry_reason":geometry.get("reason",""),"geometry_actor":geometry.get("actor_uuid",geometry.get("actor","")),
        "source_keys":keys,"cache_entries":surface.sources.size(),"cache_capacity":surface.SOURCE_LIMIT,
        "source_builds":surface.source_builds,"worker_jobs":surface.jobs.size(),"pending_sources":surface.pending.size(),
        "source_observation":source.capture_observation()}

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
