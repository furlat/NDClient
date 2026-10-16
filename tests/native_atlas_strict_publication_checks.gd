extends "res://tests/native_atlas_growth_checks.gd"
# A production owner may adopt prepared work or reject before touching the
# displayed atlas. Direct mathematical/reference owners retain full planning.

func retained(atlas:RefCounted,entry:Dictionary)->Dictionary:
    return {"nodes":atlas.receivers.map(func(r):return r.node),
        "materials":atlas.receivers.map(func(r):return r.group.material),
        "positions":positions(atlas),"groups":atlas.groups.values().duplicate(),
        "size":atlas.viewport.size,"repacks":atlas.repack_count,"serial":atlas.delta_serial,
        "buffer":entry.ground_buffer.duplicate(),"output":entry.received_material}

func rejected_case(kind:String)->void:
    var side=make_side(pair_source(),false,false)
    var actor:Dictionary=single(side.world,side.texture,18,Vector2(512,512),true)
    side.world.entries.append(actor);side.world.actor_entries=[actor]
    publish(side,true,side.world.entries)
    side.atlas.require_prepared_publication=true
    var before:Dictionary=retained(side.atlas,side.floor)
    var receipt={"base":side.serial,"serial":side.serial,"full":false,"upserts":[],"removed":[]}
    var stamp:Array=[side.serial]
    match kind:
        "full":
            receipt.serial+=1;receipt.full=true;stamp=[receipt.serial]
        "missing_receipt":receipt={};stamp=[]
        "dynamic_add":
            var extra:Dictionary=single(side.world,side.texture,19,Vector2(512,512),true)
            side.world.entries.append(extra);side.world.actor_entries.append(extra)
        "dynamic_cell":actor.cell=Vector2(256,512)
        "dynamic_remove":side.world.actor_entries=[]
        "static_remove":
            receipt.serial+=1;receipt.removed=[side.floor.node.get_instance_id()];stamp=[receipt.serial]
        "viewport":side.view.size=Vector2i(480,1200)
    side.atlas.sync(side.world,stamp,stamp,receipt,true)
    side.atlas.sync_output(side.world,stamp,true)
    check(side.atlas.output_admission_failed and not side.atlas.errors.is_empty(),kind+" rejects missing prepared publication")
    check(retained(side.atlas,side.floor)==before,kind+" retains exact displayed receivers, materials, addresses, output and committed serial")
    check(side.floor.node.material_override==before.output,kind+" preserves displayed source binding")
    side.atlas.close();side.view.queue_free();await process_frame

func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    var empty=make_side(pair_source(),false,false)
    var future:Dictionary=empty.world.entries[0]
    for entry in empty.world.entries:entry.node.hide()
    empty.world.entries=[]
    empty.atlas.require_prepared_publication=true
    Atlas.Delta.rebuild(empty.atlas,0)
    publish(empty,true,[])
    check(not empty.atlas.output_admission_failed and empty.atlas.receivers.is_empty()
        and empty.atlas.groups.is_empty() and empty.atlas.delta_serial==empty.serial,
        "A genuinely empty initial view publishes without constructing native resources")
    empty.world.entries=[future]
    publish(empty,false,[future])
    check(empty.atlas.output_admission_failed and empty.atlas.receivers.is_empty(),
        "Empty initial admission cannot authorize the first future receiving source")
    empty.atlas.close();empty.view.queue_free();await process_frame
    var initial=make_side(pair_source(),false,false)
    initial.atlas.require_prepared_publication=true
    publish(initial,true,initial.world.entries)
    check(initial.atlas.output_admission_failed and initial.atlas.receivers.is_empty()
        and initial.atlas.groups.is_empty(),"Initial production publication cannot construct an unprepared atlas")
    check(initial.world.entries.all(func(entry):return entry.node.material_override==entry.material),
        "Rejected initial publication leaves every original source material intact")
    initial.atlas.close();initial.view.queue_free();await process_frame
    for kind in ["full","missing_receipt","dynamic_add","dynamic_cell","dynamic_remove","static_remove","viewport"]:
        await rejected_case(kind)
    var moving=make_side(pair_source(),false,false)
    var actor:Dictionary=single(moving.world,moving.texture,18,Vector2(512,512),true)
    moving.world.entries.append(actor);moving.world.actor_entries=[actor]
    publish(moving,true,moving.world.entries);moving.atlas.require_prepared_publication=true
    var nodes:Array=moving.atlas.receivers.map(func(r):return r.node)
    actor.node.position.x+=.25;SourceMaterial.set_parameter(actor,"source_tint",Color(.5,1,1,1))
    publish(moving,false,[])
    check(not moving.atlas.output_admission_failed and moving.atlas.receivers.map(func(r):return r.node)==nodes,
        "Continuous actor motion and source tint retain admitted resources without preparation")
    check(row_receiver(moving.atlas,actor).group.material.get_shader_parameter("source_tint")==Color(.5,1,1,1),
        "Continuous source values still reach receiving materials")
    moving.atlas.close();moving.view.queue_free();await process_frame
    print("NATIVE_ATLAS_STRICT_PUBLICATION_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
