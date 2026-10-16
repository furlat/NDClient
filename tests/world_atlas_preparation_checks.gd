extends "res://tests/native_atlas_growth_checks.gd"
# Native-data ownership checks use the actual WorldPreparation inputs. Native
# runs also compare the first draw with independent complete source publication.
const Preparation=preload("res://presentation/world_preparation.gd")
class PreparationHost extends Node3D:
    var profile:Dictionary={"recording":false}
    var native_light_atlas
    var native_light_change_serial:int=0
    var camera:Camera3D
    var source_images:Dictionary={}
    var scenery_consumers:Dictionary={}
    var scenery_batches:Array=[]
    var visual_actors:Dictionary={}
    var world_row_cache:Dictionary={"visual_slots":{}}

func make_host(side:Dictionary)->PreparationHost:
    var host=PreparationHost.new();side.world.add_child(host)
    host.native_light_atlas=side.atlas;host.native_light_change_serial=side.serial
    host.camera=side.world.camera;host.source_images=side.world.source_images
    host.scenery_batches=[side.floor]
    for entry in side.world.entries:
        if not entry.has("batch_rows"):host.scenery_consumers[entry.placement.id]=[{"entry":entry}]
    return host

func finish_atlas(job:Node,side:Dictionary)->Dictionary:
    var upserts:Array=job.membership.upserts
    job.result.merge({"wanted":{},"ground":{},"packets":{},"actors":{},"actor_members":{},
        "removed_wanted":[],"full_membership":not upserts.is_empty(),"needs_order":false,"worker_ms":0.0,"row_patch":{}})
    job.membership_base={"groups":{},"ground":{},"entries":side.world.entries}
    if upserts.is_empty():job.membership_base.ground={"floor":{"entries":[side.floor],"rows":side.floor.batch_rows}}
    for entry in upserts:
        if entry.has("batch_rows"):
            job.native_ground.floor={"entries":[entry],"rows":entry.batch_rows}
            job.result.ground.floor=entry.batch_rows;job.ground_complete.floor=true
        else:
            job.native_groups[entry.placement.id]={"row":entry.placement,"entries":[entry],"source_cursor":1}
            job.result.wanted[entry.placement.id]=entry.placement;job.objects_complete[entry.placement.id]=true
    job.wanted_ids=job.result.wanted.keys();job.ground_keys=job.result.ground.keys()
    return await finish_early_atlas(job)

func finish_early_atlas(job:Node)->Dictionary:
    job._begin_atlas_overlap()
    check(job.atlas_stage=="sources","Exact native inputs start source capture before final membership/order")
    var slices:int=0
    while job.atlas_stage not in ["ready","empty"] and job.media_issue.is_empty() and slices<10000:
        if not job._step_atlas_overlap():await process_frame
        slices+=1
    check(job.media_issue.is_empty() and job.atlas_stage=="ready","Every selected source finishes privately before final membership/order")
    job._begin_atlas_preparation()
    var prefix:Dictionary=job.atlas_prefix
    check(not prefix.has("error") and prefix.get("bound",false),"Exact source rows and output resources finish before admission")
    return prefix

func private_receiver_hidden(receiver:Dictionary)->bool:
    var handle=Atlas.receiver_handle(receiver)
    if handle is Node:return not handle.visible
    return handle.batch!=null and handle.batch.rid.is_valid() and not handle.batch.adopted and handle.parent==handle.batch.rid

func visibility_case(cap:bool=true,normals:bool=false,label:String="visibility")->void:
    var side=make_side(pair_source(),cap,normals)
    var reference:Dictionary={}
    publish(side,true,side.world.entries)
    side.atlas.require_prepared_publication=true
    if DisplayServer.get_name()!="headless":
        reference=make_side(pair_source(),cap,normals);publish(reference,true,reference.world.entries)
        await first_draw(side,reference,label+"-initial")
    var host=make_host(side)
    var entry:Dictionary=side.world.entries[1]
    var old_single:Dictionary=row_receiver(side.atlas,entry)
    var old_floor:Dictionary=row_receiver(side.atlas,side.floor,"1")
    var old_single_handle=Atlas.receiver_handle(old_single);var old_floor_handle=Atlas.receiver_handle(old_floor)
    var old_material:ShaderMaterial=entry.received_material
    var old_buffer:PackedFloat32Array=side.floor.ground_buffer.duplicate()
    var old_positions:Dictionary=positions(side.atlas)
    var old_ground_version:int=side.floor.ground_version
    var job=Preparation.new();host.add_child(job);job.host=host;job.visible=false
    job.membership={"upserts":[],"removed":{},"ground_updates":[]}
    job.result={"visibility":{},"visibility_changes":{entry.placement.id:false,"1":true},"supports":side.atlas.published_supports}
    var prefix:Dictionary=await finish_atlas(job,side)
    check(job.atlas_jobs.size()==2 and job.membership.upserts.size()==2,"Sight-only cut selects its existing single and floor source")
    var selected:Dictionary={}
    for source in job.atlas_jobs:
        for row in source.rows:selected[str(row.id) if row is Dictionary else str(row)]=true
    check(selected=={entry.placement.id:true,"1":true},"Unchanged geometry selects exactly the two visibility rows")
    check(side.floor.ground_version==old_ground_version and side.floor.ground_buffer==old_buffer
        and entry.received_material==old_material and positions(side.atlas)==old_positions,
        "Visibility preparation does not change displayed versions, buffers, outputs or addresses")
    check(old_single.visibility==1.0 and old_floor.visibility==0.0 and Atlas.receiver_handle(old_single)==old_single_handle and Atlas.receiver_handle(old_floor)==old_floor_handle,
        "Displayed receivers keep their old visibility and native identity while preparation is private")
    var prepared:Dictionary={}
    for receiver in prefix.ready_list+prefix.ready_retained:
        prepared[receiver.id]=receiver
        check(private_receiver_hidden(receiver) and Atlas.receiver_handle(receiver)!=Atlas.receiver_handle(side.atlas.receiver_index[receiver.id]),
            "Changed visibility owns a receiving draw hidden by its private batch independently of the displayed receiver")
    check(prepared[old_single.id].visibility==0.0 and prepared[old_floor.id].visibility==1.0,
        "Private receiver groups contain the exact future visibility")
    check(Atlas.Delta.candidate_base_matches(side.atlas,prefix,host),"Visibility-only candidate passes preflight against the unchanged display")
    SourceMaterial.set_parameter(entry,"highlighted",true)
    check(Atlas.Delta.candidate_base_matches(side.atlas,prefix,host),"Current hover changes do not invalidate structural visibility preparation")
    prefix.admitted=true
    var upserts:Array=job.membership.upserts.duplicate()
    job.publish_atlas_receivers()
    check(prepared.values().all(func(receiver):return private_receiver_hidden(receiver)),
        "Binding-directory transfer does not expose future receiving pixels before the published sight cut")
    entry.scenery_value=0.0
    var values:Array=side.floor.scenery_values.duplicate();values[1]=1.0;set_visibility(side.floor,values)
    publish(side,false,upserts)
    if not reference.is_empty():
        var other:Dictionary=reference.world.entries[1]
        SourceMaterial.set_parameter(other,"highlighted",true);other.scenery_value=0.0
        var other_values:Array=reference.floor.scenery_values.duplicate();other_values[1]=1.0
        set_visibility(reference.floor,other_values);publish(reference,true,reference.world.entries)
    check(side.atlas.errors.is_empty() and side.atlas.last_reconcile_phases.get("delta_fallback","").is_empty(),
        "Sight-only publication accepts the prepared cut without recovery planning")
    for id in prepared:
        check(Atlas.receiver_handle(side.atlas.receiver_index[id])==Atlas.receiver_handle(prepared[id]) and side.atlas.receiver_index[id].group==prepared[id].group,
            "Sight-only publication adopts the exact prepared receiver and material group")
        if prepared[id].get("view_visible",false) and prepared[id].has("draw"):
            check(prepared[id].draw.batch.adopted and prepared[id].draw.visible,
                "Current scene visibility exposes the prepared batch only after the exact sight publication")
    check(row_receiver(side.atlas,entry).visibility==0.0 and row_receiver(side.atlas,side.floor,"1").visibility==1.0,
        "Single and floor visibility change at the same published boundary")
    if not normals:
        check(row_receiver(side.atlas,entry).group.material.get_shader_parameter("highlighted")==true,
            "Publication uses the current hover on its receiving target")
        if cap:
            check(entry.received_material.get_shader_parameter("highlighted")==true,
                "Capped publication uses current hover on its source-colour output")
    check(positions(side.atlas)==old_positions and side.floor.ground_version==old_ground_version,
        "Sight-only publication preserves reservations and geometry version")
    if not reference.is_empty():
        await first_draw(side,reference,label+"-published")
        reference.atlas.close();reference.view.queue_free()
    side.atlas.close();side.view.queue_free();await process_frame

func initial_case(cap:bool=true,normals:bool=false,label:String="initial")->void:
    var side=make_side(pair_source(),cap,normals)
    side.atlas.require_prepared_publication=true
    var reference:Dictionary={}
    if DisplayServer.get_name()!="headless":reference=make_side(pair_source(),cap,normals)
    side.world.entries=side.world.entries.slice(1)+[side.floor]
    if not reference.is_empty():reference.world.entries=reference.world.entries.slice(1)+[reference.floor]
    for entry in side.world.entries:entry.node.hide()
    var host=make_host(side)
    var job=Preparation.new();host.add_child(job);job.host=host;job.visible=false
    for entry in side.world.entries:entry.node.reparent(job,false)
    var visible:Dictionary={}
    for entry in side.world.entries:
        if entry.has("batch_rows"):
            for row in entry.batch_rows:
                if entry.scenery_values[entry.ground_indices[row.id]]==1.0:visible[row.id]=true
        elif entry.scenery_value==1.0:visible[entry.placement.id]=true
    job.result={"visibility":visible,"visibility_changes":{},"supports":Atlas.GroundReceiving.heights(side.world.entries)}
    job.membership={"upserts":side.world.entries.duplicate(),"removed":{},"ground_updates":[]}
    var prefix:Dictionary=await finish_atlas(job,side)
    check(side.atlas.entry_specs.is_empty() and side.atlas.receivers.is_empty(),"Initial preparation keeps native membership unpublished")
    check(prefix.ready_list.size()==16 and Atlas.Delta.candidate_base_matches(side.atlas,prefix,host),
        "Empty committed base prepares every exact initial receiver and passes preflight")
    for entry in side.world.entries:
        check(entry.node.material_override==prefix.outputs[entry.node.get_instance_id()].received_material
            and not entry.node.is_visible_in_tree(),"Private initial sources own prepared outputs without exposing pixels")
    prefix.admitted=true;job.publish_atlas_receivers()
    for entry in side.world.entries:entry.node.reparent(side.world,false);entry.node.show()
    publish(side,true,side.world.entries)
    if not reference.is_empty():publish(reference,true,reference.world.entries)
    check(side.atlas.receivers.size()==16 and side.atlas.errors.is_empty()
        and side.atlas.last_reconcile_phases.get("delta_fallback","").is_empty(),"Initial full receipt publishes the exact prepared cut")
    check(side.atlas.last_reconcile_phases.get("output_created",0)==0,"Initial publication adopts outputs constructed during preparation")
    if not reference.is_empty():
        check(positions(side.atlas)==positions(reference.atlas),"Prepared initial reservations match independent complete planning")
        await first_draw(side,reference,label+"-published")
        reference.atlas.close();reference.view.queue_free()
    side.atlas.close();side.view.queue_free();await process_frame

func sparse_packet_case()->void:
    var side=make_side(pair_source(),true,false)
    publish(side,true,side.world.entries)
    side.atlas.require_prepared_publication=true
    var reference:Dictionary={}
    if DisplayServer.get_name()!="headless":
        reference=make_side(pair_source(),true,false);publish(reference,true,reference.world.entries)
    var host=make_host(side)
    var job=Preparation.new();host.add_child(job);job.host=host;job.visible=false
    var prior_packets:Dictionary={}
    for row in side.floor.batch_rows:
        var packet:Dictionary=side.floor.ground_packets[row.id].duplicate()
        packet.row=row;prior_packets[row.id]=packet
    var before:Dictionary=Preparation.GroundData.capture_previous({"packets":prior_packets,
        "receiver_bounds":side.floor.node.multimesh.mesh.get_aabb(),"capacity":2,
        "ground_version":side.floor.ground_version},0,Basis.IDENTITY)
    var changed:Dictionary=side.floor.batch_rows[0].duplicate(true);changed.base_height_steps=1
    var geometry:Dictionary=Preparation.GroundData.prepare_changes({changed.id:changed},[],before.geometry)
    check(not geometry.rebuild_required and geometry.changed==[changed.id],"Actual sparse geometry producer selects a retained row without a membership rebuild")
    var packet:Dictionary={"sparse":true,"geometry_patch":geometry,"row_changes":{changed.id:changed},
        "packets":{changed.id:Preparation.GroundData._packet(geometry.records[changed.id],true)},
        "indices":before.geometry.indices,"rows":before.geometry.rows,
        "geometry_changes":{"base_version":side.floor.ground_version,"changed":geometry.changed,"removed":[]}}
    job.membership_base={"groups":{},"ground":{"floor":{"entries":[side.floor],"rows":side.floor.batch_rows}},"entries":side.world.entries}
    job.result={"wanted":{},"ground":{},"packets":{"floor":packet},"actors":{},"actor_members":{},
        "removed_wanted":[],"full_membership":false,"needs_order":false,"worker_ms":0.0,"row_patch":{},
        "visibility":{"0":true},"visibility_changes":{},"supports":side.atlas.published_supports}
    job.ground_keys=["floor"];job.ground_complete.floor=true
    job.membership={"upserts":[side.floor],"removed":{},"ground_updates":[{"entry":side.floor,"packet":packet}]}
    var old_buffer:PackedFloat32Array=side.floor.ground_buffer.duplicate()
    var prefix:Dictionary=await finish_early_atlas(job)
    var source:Dictionary=prefix.source_patches[side.floor.node.get_instance_id()]
    check(not job.result.ground.has("floor") and job.atlas_jobs[0].packet==packet,
        "Packet-only retained floor carries its exact future geometry despite absent result.ground membership")
    var snapshot:Dictionary=job.atlas_jobs[0].prepared.snapshot
    check(snapshot.sparse_ground and snapshot.ground_row_changes[changed.id]==changed
        and source.by_row[changed.id].row==changed,"Early planner captures the changed future row instead of old floor geometry")
    check(side.floor.ground_buffer==old_buffer and side.floor.batch_rows[0].base_height_steps==0,
        "Sparse preparation leaves current floor row and native buffer untouched")
    prefix.admitted=true;job.publish_atlas_receivers()
    var index:int=side.floor.ground_indices[changed.id]
    side.floor.batch_rows[index]=changed;side.floor.ground_packets[changed.id]=packet.packets[changed.id]
    for channel in 20:side.floor.ground_buffer[index*20+channel]=packet.packets[changed.id].data[channel]
    side.floor.node.multimesh.buffer=side.floor.ground_buffer;side.floor.ground_version+=1
    publish(side,false,[side.floor])
    if not reference.is_empty():
        reference.floor.batch_rows[index]=changed
        reference.floor.ground_packets[changed.id]=packet.packets[changed.id].duplicate(true)
        for channel in 20:reference.floor.ground_buffer[index*20+channel]=packet.packets[changed.id].data[channel]
        reference.floor.node.multimesh.buffer=reference.floor.ground_buffer;reference.floor.ground_version+=1
        publish(reference,true,reference.world.entries)
        await first_draw(side,reference,"world-sparse-packet-only")
        reference.atlas.close();reference.view.queue_free()
    check(side.atlas.errors.is_empty() and side.atlas.last_reconcile_phases.get("delta_fallback","").is_empty(),
        "Packet-only early source publishes without a recovery planner")
    side.atlas.close();side.view.queue_free();await process_frame

func membership_target_case()->void:
    var side=make_side(pair_source(),true,false)
    publish(side,true,side.world.entries)
    var host=make_host(side)
    var job=Preparation.new();host.add_child(job);job.host=host;job.visible=false
    var old:Dictionary=side.world.entries[1];var fresh:Dictionary=side.world.entries[2]
    job.membership_base={"groups":{old.placement.id:{"row":old.placement,"entries":[old]}},"ground":{},"entries":[old]}
    job.result={"wanted":{fresh.placement.id:fresh.placement},"ground":{},"packets":{},"actors":{},"actor_members":{},
        "removed_wanted":[],"full_membership":false,"needs_order":false,"worker_ms":0.0,
        "row_patch":{"prepared_visual_slots":{old.placement.id:0,fresh.placement.id:1}},
        "visibility":{},"visibility_changes":{},"supports":side.atlas.published_supports}
    job.wanted_ids=[fresh.placement.id];job.objects_complete[fresh.placement.id]=true
    job.native_groups[fresh.placement.id]={"row":fresh.placement,"entries":[fresh],"source_cursor":1}
    job._begin_atlas_overlap();job._prepare_membership_inputs()
    check(job.wanted_ids.size()==2 and job.object_target_count==1,
        "Canonical membership expansion preserves the already completed changed-source constructor scope")
    check(job._atlas_inputs_ready() and not job._prepare_object(Time.get_ticks_usec()+100000),
        "Expanded membership never reopens constructors or rescans retained object rows")
    side.atlas.close();side.view.queue_free();await process_frame

func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures/atlas-growth"))
    if DisplayServer.get_name()=="headless":
        await visibility_case();await initial_case()
    else:
        for mode in [[false,false,"ldr"],[true,false,"capped"],[true,true,"normals"]]:
            await visibility_case(mode[0],mode[1],"world-visibility-"+mode[2])
            await initial_case(mode[0],mode[1],"world-initial-"+mode[2])
    await sparse_packet_case()
    await membership_target_case()
    var report={"checks":checks,"failures":failures,"cases":cases,"renderer":RenderingServer.get_current_rendering_method(),
        "scope":"Early source capture before membership/order, packet-only retained sparse floors, sight-only single/floor receivers, initial empty-atlas admission and continuous hover ownership. Native runs compare first received cells and final framebuffer with independent complete source publication in LDR, capped and Normals modes. No performance claim."}
    if DisplayServer.get_name()!="headless":FileAccess.open("res://generated/world_atlas_preparation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("WORLD_ATLAS_PREPARATION_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
