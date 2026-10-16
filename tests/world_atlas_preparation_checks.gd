extends "res://tests/native_atlas_growth_checks.gd"
# Native-data ownership checks use the actual WorldPreparation inputs. Native
# runs also compare the first draw with independent complete source publication.
const Preparation=preload("res://presentation/world_preparation.gd")
class PreparationHost extends Node3D:
    var native_light_atlas
    var native_light_change_serial:int=0
    var camera:Camera3D
    var source_images:Dictionary={}
    var scenery_consumers:Dictionary={}
    var scenery_batches:Array=[]

func make_host(side:Dictionary)->PreparationHost:
    var host=PreparationHost.new();side.world.add_child(host)
    host.native_light_atlas=side.atlas;host.native_light_change_serial=side.serial
    host.camera=side.world.camera;host.source_images=side.world.source_images
    host.scenery_batches=[side.floor]
    for entry in side.world.entries:
        if not entry.has("batch_rows"):host.scenery_consumers[entry.placement.id]=[{"entry":entry}]
    return host

func finish_atlas(job:Node,side:Dictionary)->Dictionary:
    job._begin_atlas_preparation()
    check(job.phase=="atlas_receivers","Exact native inputs enter preparation")
    while job.atlas_cursor<job.atlas_jobs.size() and job.media_issue.is_empty():job._prepare_atlas_receiver()
    check(job.media_issue.is_empty(),"Every selected source constructs privately")
    var prefix:Dictionary=Atlas.Delta.begin_candidate(side.atlas,job.atlas_jobs,job.membership.removed,job.host)
    while not Atlas.Delta.capture_candidate(side.atlas,prefix,job.host):pass
    Atlas.Delta.compute_candidate(prefix)
    while not Atlas.Delta.prepare_candidate_binding(side.atlas,prefix,job.atlas_shells):pass
    check(not prefix.has("error") and prefix.get("bound",false),"Exact source rows and output resources finish before admission")
    job.atlas_prefix=prefix
    return prefix

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
    var old_single_node:Sprite2D=old_single.node;var old_floor_node:Sprite2D=old_floor.node
    var old_material:ShaderMaterial=entry.received_material
    var old_buffer:PackedFloat32Array=side.floor.ground_buffer.duplicate()
    var old_positions:Dictionary=positions(side.atlas)
    var old_ground_version:int=side.floor.ground_version
    var job=Preparation.new();host.add_child(job);job.host=host;job.visible=false
    job.membership={"upserts":[],"removed":{},"ground_updates":[]}
    job.result={"visibility":{},"visibility_changes":{entry.placement.id:false,"1":true},"supports":side.atlas.published_supports}
    var prefix:Dictionary=finish_atlas(job,side)
    check(job.atlas_jobs.size()==2 and job.membership.upserts.size()==2,"Sight-only cut selects its existing single and floor source")
    var selected:Dictionary={}
    for source in job.atlas_jobs:
        for row in source.rows:selected[str(row.id) if row is Dictionary else str(row)]=true
    check(selected=={entry.placement.id:true,"1":true},"Unchanged geometry selects exactly the two visibility rows")
    check(side.floor.ground_version==old_ground_version and side.floor.ground_buffer==old_buffer
        and entry.received_material==old_material and positions(side.atlas)==old_positions,
        "Visibility preparation does not change displayed versions, buffers, outputs or addresses")
    check(old_single.visibility==1.0 and old_floor.visibility==0.0 and old_single.node==old_single_node and old_floor.node==old_floor_node,
        "Displayed receivers keep their old visibility and native identity while preparation is private")
    var prepared:Dictionary={}
    for receiver in prefix.ready_list+prefix.ready_retained:
        prepared[receiver.id]=receiver
        check(not receiver.node.visible and receiver.node!=side.atlas.receiver_index[receiver.id].node,
            "Changed visibility owns a hidden receiver independently of the displayed receiver")
    check(prepared[old_single.id].visibility==0.0 and prepared[old_floor.id].visibility==1.0,
        "Private receiver groups contain the exact future visibility")
    check(Atlas.Delta.candidate_base_matches(side.atlas,prefix,host),"Visibility-only candidate passes preflight against the unchanged display")
    SourceMaterial.set_parameter(entry,"highlighted",true)
    check(Atlas.Delta.candidate_base_matches(side.atlas,prefix,host),"Current hover changes do not invalidate structural visibility preparation")
    prefix.admitted=true
    var upserts:Array=job.membership.upserts.duplicate()
    job.publish_atlas_receivers()
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
        check(side.atlas.receiver_index[id].node==prepared[id].node and side.atlas.receiver_index[id].group==prepared[id].group,
            "Sight-only publication adopts the exact prepared receiver and material group")
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
    var prefix:Dictionary=finish_atlas(job,side)
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

func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures/atlas-growth"))
    if DisplayServer.get_name()=="headless":
        await visibility_case();await initial_case()
    else:
        for mode in [[false,false,"ldr"],[true,false,"capped"],[true,true,"normals"]]:
            await visibility_case(mode[0],mode[1],"world-visibility-"+mode[2])
            await initial_case(mode[0],mode[1],"world-initial-"+mode[2])
    var report={"checks":checks,"failures":failures,"cases":cases,"renderer":RenderingServer.get_current_rendering_method(),
        "scope":"Sight-only single/floor receivers, initial empty-atlas admission and continuous hover ownership. Native runs compare first received cells and final framebuffer with independent complete source publication in LDR, capped and Normals modes. No performance claim."}
    if DisplayServer.get_name()!="headless":FileAccess.open("res://generated/world_atlas_preparation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("WORLD_ATLAS_PREPARATION_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
