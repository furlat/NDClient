extends "res://tests/native_atlas_growth_checks.gd"
## Private receiving resources and future ground packets versus the unchanged
## complete planner. No gameplay events or modified artwork are used here.
const Preparation=preload("res://presentation/world_preparation.gd")
const FullCapture=preload("res://tests/native_light_capture_reference.gd")
const Construction=preload("res://presentation/actor_construction.gd")
class ActorMaterialHost extends Node3D:
    var camera:Camera3D
    var textures:Dictionary={}
    var resources:Dictionary={}
    var catalog_cache:Dictionary={}
    var source_depth:bool=false
    var source_normals:bool=false
    var character_light_profile:String="original"
    func texture(path:String)->Texture2D:return textures.get(path)

func prepared_dynamic_actor(side:Dictionary,prepare_copy:bool)->Dictionary:
    var host=ActorMaterialHost.new();side.world.add_child(host);host.camera=side.world.camera
    var path="/fixture/staged-actor.png";host.textures[path]=side.texture
    host.catalog_cache[Construction.CharacterGeometry.TABLE]={"records":{}}
    var entry:Dictionary=single(side.world,side.texture,19,Vector2(256,512),true)
    entry.material=ShaderMaterial.new();entry.material.shader=Construction.MODULAR_SHADER
    entry.node.material_override=entry.material;entry.node.hide()
    entry.actor_layer={"slot":"body","paths":{"Idle":path}};entry.scale=1.0;entry.placement.scale_x=1.0
    var state:Dictionary=Construction.Conditions.material("actor",[])
    var key:Array=Construction.material_key(state,host.textures,host.resources)
    var rig={"cell_width":256,"cell_height":512,"facing_rows":{"SW":0}}
    Construction.bind_source(host,entry,rig,path,0,"SW",state,key,[])
    if prepare_copy:
        var material:Dictionary=side.atlas.prepare_source_binding(entry,{},host,true)
        side.dynamic_output=weakref(material.output.received_material)
        check(side.atlas.adopt_source_binding(material),"Actual producer private actor materials enter the existing atlas preparation owner")
    Construction.bind_source(host,entry,rig,path,1,"SW",state,key,[])
    return entry

class EmptyPreparationHost extends Node3D:
    var native_light_atlas
    var camera:Camera3D

func empty_static_case(source:Image)->void:
    var a=make_side(source,true,false);var b=make_side(source,true,false)
    for side in [a,b]:
        var actor:Dictionary=single(side.world,side.texture,19,Vector2(512,512),true)
        side.world.entries.append(actor);side.world.actor_entries=[actor]
        publish(side,true,side.world.entries)
    await first_draw(a,b,"empty-static-initial")
    for step in 2:
        var host=EmptyPreparationHost.new();host.native_light_atlas=a.atlas;a.world.add_child(host)
        var candidate=Preparation.new();host.add_child(candidate);candidate.host=host
        candidate.membership={"upserts":[],"removed":{},"ground_updates":[]}
        var before:Dictionary=positions(a.atlas)
        candidate._begin_atlas_preparation()
        check(candidate.prepared and candidate.phase=="ready" and candidate.atlas_prefix.is_empty()
            and candidate.atlas_jobs.is_empty() and candidate.task==-1,
            "Empty static receipt finishes without a receiver/support capture or worker")
        candidate.publish_atlas_receivers()
        check(positions(a.atlas)==before and a.atlas.prepared_delta.is_empty(),
            "Empty static preparation does not publish or replace lighting geometry")
        if step==0:
            var removal=Preparation.new();host.add_child(removal);removal.host=host
            removal.membership={"upserts":[],"removed":{a.floor.node.get_instance_id():true},"ground_updates":[]}
            removal._begin_atlas_preparation()
            check(not removal.prepared and removal.phase=="atlas_receivers",
                "A real static removal still enters exact atlas preparation")
        for side in [a,b]:
            if step==0:
                var actor:Dictionary=side.world.actor_entries[0]
                actor.node.position+=Vector3(.4,.3,0)
                actor.material.set_shader_parameter("source_tint",Color(.6,1,.8,1));actor.source_version+=1
                side.world.entries[1].scenery_value=0.0
                side.world.camera.position.x+=.5;side.world.camera.size+=.25
            else:
                var actor:Dictionary=single(side.world,side.texture,20,Vector2(512,512),true)
                side.world.entries.append(actor);side.world.actor_entries.append(actor)
                side.world.camera.rotate_y(.15)
        publish(a,false,[]);publish(b,true,b.world.entries)
        check(a.atlas.dynamic_receivers.size()==step+1,
            "Ordinary synchronization retains or admits the actual dynamic actor after an empty static receipt")
        await first_draw(a,b,"empty-static-current-samples-"+str(step))
        host.queue_free();await process_frame
    a.atlas.close();b.atlas.close();a.view.queue_free();b.view.queue_free();await process_frame

func staged_case(source:Image,label:String,cap:bool,normals:bool,stale:bool=false,view_change:String="",changed_visibility:bool=false,extra_mode:String="")->void:
    var a=make_side(source,cap,normals);var b=make_side(source,cap,normals)
    if extra_mode=="dynamic_replace":
        for side in [a,b]:
            var actor:Dictionary=single(side.world,side.texture,19,Vector2(512,512),true)
            side.world.entries.append(actor);side.world.actor_entries=[actor]
    publish(a,true,a.world.entries);publish(b,true,b.world.entries)
    await first_draw(a,b,label+"-initial")
    var before:Image=a.view.get_texture().get_image()
    var old_positions:Dictionary=positions(a.atlas)
    var initial_atlas_size:Vector2i=a.atlas.viewport.size
    var old_buffer:PackedFloat32Array=a.floor.ground_buffer.duplicate()
    var old_output:ShaderMaterial=a.floor.received_material
    var candidate=Node3D.new();candidate.visible=false;a.world.add_child(candidate)
    var add_a:Array=[];var add_b:Array=[]
    for index in range(14,16):
        var entry:Dictionary=single(a.world,a.texture,index)
        entry.node.reparent(candidate,false);add_a.append(entry)
        add_b.append(single(b.world,b.texture,index));add_b.back().node.hide()
    if extra_mode=="water":
        for entry in [add_a[1],add_b[1]]:
            var material=ShaderMaterial.new();material.shader=WaterSource
            var parameters={"mask_texture":a.texture,"ripple_texture":a.texture,"cell":Vector2(512,512),"image_scale":1.0,
                "shallow_color":Color(.2,.4,.6,1),"deep_color":Color(.1,.2,.4,1),"tint":Color.WHITE,
                "uv_scale":1.0,"ripple_pan":Vector2(.5,0),"ripple_tiling":1.0,"ripple_amount":.3,
                "overall_alpha":1.0,"alpha_cutoff":.001,"sheen_sharpness":2.0}
            for name in parameters:material.set_shader_parameter(name,parameters[name])
            entry.material=material;entry.node.material_override=material;entry.role="terrain"
            entry.placement={"id":"water-new","kind":"terrain","material":"water","position":[0,2],"base_height_steps":0}
    var rows_a:Array=a.floor.batch_rows.duplicate(true)
    var rows_b:Array=b.floor.batch_rows.duplicate(true)
    if extra_mode not in ["plain_append","group_replaced"]:
        rows_a[0].base_height_steps=1;rows_b[0].base_height_steps=1
    for rows in [rows_a,rows_b]:
        var template:Dictionary=rows[0].duplicate(true)
        if extra_mode=="removed_floor":rows.remove_at(1)
        if extra_mode=="replace_floor":rows.clear()
        for index in 2:
            var row:Dictionary=template.duplicate(true)
            row.id="new-"+str(index);row.position=[2+index*2,2];row.base_height_steps=0
            rows.append(row)
    var packet_a:Dictionary=prepared_floor_packet(a.floor,[],a.atlas.floor_address_token(a.floor),rows_a)
    var packet_b:Dictionary=prepared_floor_packet(b.floor,[],b.atlas.floor_address_token(b.floor),rows_b)
    var snapshot:Dictionary=a.floor.duplicate()
    snapshot.ground_version=a.floor.ground_version+1;snapshot.batch_rows=packet_a.rows
    snapshot.ground_indices=packet_a.indices;snapshot.ground_packets=packet_a.packets
    snapshot.ground_buffer=packet_a.buffer;snapshot.scenery_values=packet_a.values;snapshot.placement=packet_a.rows[0]
    var supports:Dictionary=Atlas.GroundReceiving.heights([snapshot]+add_a)
    var prepared:Array=[]
    for entry in add_a+[a.floor]:
        var sampled:Dictionary=snapshot if entry==a.floor else entry.duplicate()
        var value:Dictionary=a.atlas.prepare_source_binding(entry,sampled,a.world)
        value.receiver_parent=a.atlas.projection_root
        var selected:Array=sampled.batch_rows if sampled.has("batch_rows") else [sampled.placement]
        for row in selected:
            var visibility:float=sampled.scenery_values[sampled.ground_indices[str(row.id)]] if sampled.has("batch_rows") else sampled.get("scenery_value",1.0)
            a.atlas.prepare_source_row(value,row,value.receiver_parent,supports,visibility)
        prepared.append(value)
    if extra_mode=="missing_shell":
        var unused_id:String=prepared[0].receivers.keys()[0]
        prepared[0].receivers[unused_id].node.queue_free()
        prepared[0].receivers.erase(unused_id)
    var bindings:Dictionary={};var jobs:Array=[]
    for value in prepared:
        var entry:Dictionary=value.entry;var is_floor:bool=entry==a.floor
        bindings[entry.node.get_instance_id()]=value
        jobs.append({"entry":entry,"prepared":value,"packet":packet_a if is_floor else {},
            "rows":packet_a.geometry_changes.changed if is_floor else [entry.placement]})
    var full_prefix:Dictionary=FullCapture.begin_candidate(a.atlas,jobs,{},a.world)
    while not FullCapture.capture_candidate(a.atlas,full_prefix,a.world):pass
    FullCapture.compute_candidate(full_prefix)
    var prefix:Dictionary=Atlas.Delta.begin_candidate(a.atlas,jobs,{},a.world)
    while not Atlas.Delta.capture_candidate(a.atlas,prefix,a.world):pass
    var task:int=WorkerThreadPool.add_task(Atlas.Delta.compute_candidate.bind(prefix),false,"Qualify private atlas plan")
    while not WorkerThreadPool.is_task_completed(task):await process_frame
    WorkerThreadPool.wait_for_task_completion(task)
    check(prefix.get("error","")==full_prefix.get("error",""),label+" sparse capture has the original full-prefix outcome")
    if prefix.get("complete",false) and full_prefix.get("complete",false):
        var plan:Dictionary=prefix.plan.duplicate();var expected:Dictionary=full_prefix.plan.duplicate()
        for field in ["specs_ms","reservations_ms"]:plan.erase(field);expected.erase(field)
        check(plan==expected and prefix.bind_ids==full_prefix.bind_ids,label+" sparse plan/reservation/bind order equals independently frozen full capture")
        for id in prefix.floor_ids:
            check(prefix.source_patches[id].prepared_addresses==full_prefix.source_patches[id].prepared_addresses,label+" complete future floor buffer/addresses equal frozen full capture")
    while not Atlas.Delta.prepare_candidate_binding(a.atlas,prefix,bindings):pass
    check(not prefix.has("error"),label+" passive private prefix reserves the complete exact input")
    await process_frame;await RenderingServer.frame_post_draw
    check(before.get_data()==a.view.get_texture().get_image().get_data(),label+" future materials and receiver records expose no pixels")
    check(positions(a.atlas)==old_positions and a.floor.ground_buffer==old_buffer and a.floor.received_material==old_output,label+" future floor snapshot changes no live addresses, buffers or material")
    check(a.atlas.prepared_source_bindings.is_empty(),label+" preparation remains exclusively candidate-owned")
    if extra_mode=="group_replaced":
        # Replacing a receiver material need not move atlas cells or advance
        # the world receipt. The prebound native references must still reject.
        for side in [a,b]:
            var group:Dictionary=row_receiver(side.atlas,side.floor,str(side.floor.batch_rows[0].id)).group
            group.material=group.material.duplicate(true)
            for receiver in side.atlas.receivers:
                if is_same(receiver.group,group):receiver.node.material=group.material
    if extra_mode=="dynamic_replace":
        for side in [a,b]:
            var actor:Dictionary=side.world.actor_entries[0].duplicate();actor.source_version+=1
            side.world.entries[side.world.entries.size()-1]=actor;side.world.actor_entries=[actor]
    if extra_mode=="prepared_dynamic_append":
        for side in [a,b]:
            side.late_actor=prepared_dynamic_actor(side,side==a)
            side.world.actor_entries.append(side.late_actor)
    if extra_mode in ["append","changed_base"]:
        for side in [a,b]:
            var actor:Dictionary=single(side.world,side.texture,19,Vector2(512,512),true)
            side.world.actor_entries.append(actor)
            if extra_mode=="changed_base":
                side.world.entries.append(actor);publish(side,false,[actor])
            else:side.late_actor=actor
    if extra_mode=="hover_after_prepare":
        for entry in [add_a[0],add_b[0],a.floor,b.floor]:entry.material.set_shader_parameter("highlighted",true)
    if extra_mode=="retained_output_changed":
        for side in [a,b]:
            var retained:Dictionary=side.world.entries[1]
            retained.material.set_shader_parameter("source_tint",Color(.4,.8,.6,1));retained.source_version=retained.get("source_version",0)+1
            retained.material.set_shader_parameter("highlighted",true)

    if extra_mode=="water":
        for entry in [add_a[1],add_b[1]]:entry.material.set_shader_parameter("displayed_time_seconds",2.5)
    if stale:
        for entry in [add_a[0],add_b[0]]:
            entry.material.set_shader_parameter("wall_opacity",.41);entry.source_version+=1
    if not view_change.is_empty():
        for side in [a,b]:
            if view_change=="basis":side.world.camera.rotate_y(.25)
            else:side.world.camera.position.x+=.75;side.world.camera.size+=.5
            # Consume the changed camera before the prepared source arrives;
            # ordinary sync basis_changed is then false at source admission.
            publish(side,false,[])
    a.atlas.prepared_delta=prefix
    for value in prepared:a.atlas.adopt_source_binding(value)
    for entry in add_a:entry.node.reparent(a.world,false)
    for entry in add_b:entry.node.show()
    a.world.entries.append_array(add_a);b.world.entries.append_array(add_b)
    if extra_mode in ["append","prepared_dynamic_append"]:
        a.world.entries.append(a.late_actor);b.world.entries.append(b.late_actor)
        a.late_actor.node.show();b.late_actor.node.show()
    publish_floor(a.floor,packet_a);publish_floor(b.floor,packet_b)
    if changed_visibility:
        for side in [a,b]:
            var values:Array=side.floor.scenery_values.duplicate()
            values[side.floor.ground_indices["new-1"]]=1.0
            set_visibility(side.floor,values)
    publish(a,false,add_a+[a.floor]);publish(b,true,b.world.entries)
    check(a.atlas.last_reconcile_phases.get("prepared_receiver_bindings",0)==(0 if view_change=="basis" else 3 if stale or extra_mode=="missing_shell" else 4),label+" only current prepared receiver records are adopted")
    check(a.atlas.last_reconcile_phases.get("prepared_output_materials",0)==(0 if view_change=="basis" else 2 if stale else 4 if extra_mode=="prepared_dynamic_append" else 3),label+" only exact source versions adopt pre-copied outputs")
    check((a.atlas.last_reconcile_phases.get("prepared_receiver_materials",0)>0)==(view_change!="basis"),label+" actual receiver groups reuse only current private pre-copied materials")
    check(a.atlas.prepared_source_bindings.is_empty(),label+" publication releases temporary preparation ownership")
    if extra_mode=="prepared_dynamic_append":
        check(a.dynamic_output.get_ref()!=null and a.late_actor.received_material==a.dynamic_output.get_ref(),label+" actual dynamic extra keeps its accepted private output through static-prefix publication and cleanup")
        check(a.atlas.last_reconcile_phases.get("output_created",0)==0,label+" accepted dynamic copy allocates no replacement output material")
        check(not a.atlas.entry_specs[a.late_actor.node.get_instance_id()].has("prepared_output"),label+" dynamic extra detaches private preparation payload after exact output adoption")

    if extra_mode=="hover_after_prepare":
        for entry in [add_a[0],a.floor]:check(entry.received_material.get_shader_parameter("highlighted")==true,label+" current hover replaces the privately prepared output style without a source version change")
    check((a.atlas.last_reconcile_phases.get("prepared_prefix_specs",0)>0)==(not stale and view_change.is_empty() and not changed_visibility and extra_mode!="changed_base"),label+" exact private prefix accepted or unchanged transaction used after stale input")
    if extra_mode=="missing_shell":check(a.atlas.last_reconcile_phases.get("prepared_bulk_registered",0)==3,label+" an ordinary unprepared row preserves bulk list offsets for the remaining ready receivers")
    if extra_mode in ["removed_floor","replace_floor"]:check(a.atlas.last_reconcile_phases.get("prepared_bulk_registered",0)==4,label+" exact planned removals preserve bulk registration and final group/list ownership")
    if extra_mode=="plain_append":check(a.atlas.last_reconcile_phases.get("prepared_bulk_registered",0)==4,label+" exact static append publishes already-bound native receiver arrays")
    if extra_mode in ["plain_append","retained_output_changed"]:
        check(a.atlas.last_reconcile_phases.get("prepared_output_regions",0)==3,label+" exact future output regions publish without repeating shader writes")
        check(a.atlas.last_reconcile_phases.get("resize_output_regions",0)==a.world.entries.size()-3,label+" retained growth uses the original bounded normalized-region writes")
        check(a.atlas.last_reconcile_phases.get("prepared_style_receivers",0)==4,label+" exact prepared rows keep their already-bound visibility on first publication")

    if extra_mode=="group_replaced":check(a.atlas.last_reconcile_phases.get("prepared_bulk_registered",0)==0,label+" replaced actual group material uses the unchanged binding transaction")
    check(a.atlas.viewport.size==Vector2i(8192,initial_atlas_size.y*2) and a.atlas.viewport.size==b.atlas.viewport.size,label+" prepared append grows using the unchanged bounded planner")
    check(positions(a.atlas)==positions(b.atlas),label+" every reserved pixel address equals complete planning")
    var first_group:Dictionary=row_receiver(a.atlas,a.floor,"new-0").group
    var second_group:Dictionary=row_receiver(a.atlas,a.floor,"new-1").group
    check(is_same(first_group,second_group)!=changed_visibility,label+" shared floor material splits only for the actual changed visibility")
    for index in a.atlas.receivers.size():
        var receiver:Dictionary=a.atlas.receivers[index]
        check(receiver.list_index==index,label+" admitted receiver owns its exact live list offset")
    for index in a.atlas.static_receivers.size():check(a.atlas.static_receivers[index].partition_index==index,label+" admitted static receiver owns its exact partition offset")
    for group in a.atlas.groups.values():
        check(group.users==a.atlas.receivers.filter(func(receiver):return is_same(receiver.group,group)).size(),label+" each material group owns exactly its actual receiver count")
    if extra_mode=="water":
        for side in [a,b]:
            var receiver:Dictionary=row_receiver(side.atlas,side.world.entries.filter(func(entry):return entry.placement.id=="water-new")[0])
            check(receiver.group.material.get_shader_parameter("receiver_world_origin")==receiver.entry.node.global_position,label+" prepared water retains the actual optical support origin")
    transport(a,label);transport(b,label+" reference")
    await first_draw(a,b,label+"-accepted")
    var cancelled=Node3D.new();cancelled.visible=false;a.world.add_child(cancelled)
    var unused:Dictionary=single(a.world,a.texture,18);unused.node.reparent(cancelled,false)
    var discarded:Dictionary=a.atlas.prepare_source_binding(unused,unused.duplicate(),a.world)
    a.atlas.prepare_source_row(discarded,unused.placement,cancelled,supports,1.0)
    var node_ref:WeakRef=weakref(discarded.receivers.values()[0].node)
    var count:int=a.atlas.receivers.size()
    cancelled.queue_free();discarded={};await process_frame;await process_frame
    check(node_ref.get_ref()==null and a.atlas.receivers.size()==count,label+" cancellation releases private nodes without publishing membership")
    candidate.queue_free();a.atlas.close();b.atlas.close();a.view.queue_free();b.view.queue_free();await process_frame

func flame_shell_case(source:Image,label:String,cap:bool,normals:bool)->void:
    var a=make_side(source,cap,normals);var b=make_side(source,cap,normals)
    publish(a,true,a.world.entries);publish(b,true,b.world.entries)
    await first_draw(a,b,label+"-initial")
    var images:Array[Image]=[]
    for index in 2:
        var image=Image.create(64,64,false,Image.FORMAT_RGBA8)
        image.fill_rect(Rect2i(10+index*9,6,26,52),Color(1,.25+index*.35,.08,.75))
        images.append(image)
    var frames=Texture2DArray.new();check(frames.create_from_images(images)==OK,label+" original fixture frames load")
    var added:Array=[]
    for side in [a,b]:
        var entry:Dictionary=single(side.world,side.texture,16,Vector2(64,64))
        var material=ShaderMaterial.new();material.shader=Sources.FIXTURE_FLAME_SHADER
        material.set_shader_parameter("frames",frames);material.set_shader_parameter("frame_index",0)
        entry.material=material;entry.node.material_override=material;entry.role="body"
        entry.node.position=Vector3(0,1.5,0);entry.record={"path":"fixture","rect":[0,0,64,64]}
        added.append(entry)
    var host=EmptyPreparationHost.new();host.native_light_atlas=a.atlas;host.camera=a.world.camera;a.world.add_child(host)
    var candidate=Preparation.new();host.add_child(candidate);candidate.host=host;candidate.visible=false
    candidate.result={"visibility":{added[0].placement.id:true},"supports":{}}
    candidate.atlas_jobs=[{"entry":added[0],"rows":[added[0].placement],"packet":{}}]
    added[0].node.reparent(candidate,false);added[1].node.hide()
    candidate._prepare_atlas_receiver()
    var shell:Sprite2D=candidate.atlas_fixture_shells.values()[0].nodes[0]
    var shell_id:int=shell.get_instance_id()
    var materials:Dictionary=candidate.atlas_fixture_shells.values()[0].materials
    var material_id:int=materials.groups.values()[0].material.get_instance_id()
    var output_id:int=materials.output.received_material.get_instance_id()
    check(not shell.visible and shell.material==null and candidate.atlas_shells.is_empty(),
        label+" private dynamic flame preparation assigns no receiver material or visible pixels")
    check(materials.receivers.is_empty() and materials.specs.is_empty(),label+" private material copies have no projection/address")
    var prefix:Dictionary=Atlas.Delta.begin_candidate(a.atlas,candidate.atlas_jobs,{},a.world)
    while not Atlas.Delta.capture_candidate(a.atlas,prefix,a.world):pass
    Atlas.Delta.compute_candidate(prefix)
    while not Atlas.Delta.prepare_candidate_binding(a.atlas,prefix,{}):pass
    check(not prefix.has("error"),label+" ordinary static-prefix capture includes future fixture identity")
    candidate.atlas_prefix=prefix
    await first_draw(a,b,label+"-private")
    # The shared fixture clock advances while world preparation is private.
    # Adoption must display this actual frame, not the earlier source frame.
    for index in 2:
        var side:Dictionary=a if index==0 else b
        var entry:Dictionary=added[index]
        entry.material.set_shader_parameter("frame_index",1);entry.source_version+=1
        if entry.node.get_parent()!=side.world:entry.node.reparent(side.world,false)
        entry.node.show();side.world.entries.append(entry);side.world.fixture_entries.append(entry)
    candidate.publish_atlas_receivers()
    publish(a,false,[added[0]]);publish(b,true,b.world.entries)
    check(a.atlas.last_reconcile_phases.get("prepared_receiver_nodes",0)==1
        and row_receiver(a.atlas,added[0]).node.get_instance_id()==shell_id,
        label+" first actual sample consumes the already prepared flame node")
    check(a.atlas.last_reconcile_phases.get("prepared_prefix_specs",0)>0,label+" prepared material admission also validates the accepted static-prefix path")
    check(row_receiver(a.atlas,added[0]).group.material.get_instance_id()==material_id and added[0].received_material.get_instance_id()==output_id,
        label+" actual first draw uses privately prepared receiving/output material owners")
    if not normals:
        check(row_receiver(a.atlas,added[0]).group.material.get_shader_parameter("frame_index")==1,
            label+" receiving material uses the current fixture frame")
    await first_draw(a,b,label+"-current-frame")
    for entry in added:entry.material.set_shader_parameter("frame_index",0);entry.source_version+=1
    publish(a,false,[]);publish(b,true,b.world.entries)
    await first_draw(a,b,label+"-next-frame")
    host.queue_free();a.atlas.close();b.atlas.close();a.view.queue_free();b.view.queue_free();await process_frame

func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures/atlas-growth"))
    var source:Image=pair_source()
    await empty_static_case(source)
    await flame_shell_case(source,"flame-shell-ldr",false,false)
    await flame_shell_case(source,"flame-shell-capped",true,false)
    await flame_shell_case(source,"flame-shell-normals",true,true)
    await staged_case(source,"staged-ldr",false,false)
    await staged_case(source,"staged-capped",true,false)
    await staged_case(source,"staged-normals",true,true)
    await staged_case(source,"staged-version-rejection",true,false,true)
    await staged_case(source,"staged-view-rejection",true,false,false,"basis")
    await staged_case(source,"staged-pan-reuse",true,false,false,"pan")
    await staged_case(source,"staged-row-visibility",true,false,false,"",true)
    await staged_case(source,"staged-dynamic-append",true,false,false,"",false,"append")
    await staged_case(source,"staged-base-rejection",true,false,false,"",false,"changed_base")
    await staged_case(source,"staged-ground-removal",true,false,false,"",false,"removed_floor")
    await staged_case(source,"staged-whole-floor-replacement",true,false,false,"",false,"replace_floor")
    await staged_case(source,"staged-water-origin",true,false,false,"",false,"water")
    await staged_case(source,"staged-dynamic-replacement",true,false,false,"",false,"dynamic_replace")
    await staged_case(source,"staged-bulk-append",true,false,false,"",false,"plain_append")
    await staged_case(source,"staged-bulk-group-replaced",true,false,false,"",false,"group_replaced")
    await staged_case(source,"staged-bulk-missing-shell",true,false,false,"",false,"missing_shell")
    await staged_case(source,"staged-current-hover",true,false,false,"",false,"hover_after_prepare")
    await staged_case(source,"staged-prepared-actor-extra",true,false,false,"",false,"prepared_dynamic_append")
    await staged_case(source,"staged-retained-output-changed",true,false,false,"",false,"retained_output_changed")
    var report={"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"cases":cases,
        "scope":"Private future source/spec/material/receiver preparation; exact source-version admission; changed ground packets; growth, cancellation and first-draw byte parity against complete original planning. No gameplay latency claim."}
    FileAccess.open("res://generated/native_atlas_staged_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ATLAS_STAGED ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
