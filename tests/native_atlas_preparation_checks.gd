extends "res://tests/native_atlas_frame_native_checks.gd"
## Native prepared receiver publication uses the same atlas and source artwork.
func tracked_material_checks(atlas:RefCounted,world:World,entry:Dictionary,source:Image)->void:
    await super.tracked_material_checks(atlas,world,entry,source)
    var before=await capture(world.get_viewport())
    var members:int=atlas.receivers.size()
    var candidate=Node3D.new();candidate.visible=false;world.add_child(candidate)
    var future:Dictionary=floor_entry(candidate,source)
    future.node.position.y=2.2
    var shells:Array=[];var ids:Array=[]
    for i in 3:
        var node:Sprite2D=atlas.prepare_receiver_node(candidate)
        shells.append(node);ids.append(node.get_instance_id())
    var extra=weakref(shells[0])
    check(atlas.receivers.size()==members and not future.has("received_material"),"Prepared receiver shells never reserve cells or publish a source material")
    var held=await capture(world.get_viewport())
    check(before.get_data()==held.get_data(),"Unadmitted native receiver preparation leaves the displayed framebuffer byte-exact")
    future.node.reparent(world,false);world.entries.append(future)
    atlas.adopt_prepared_receivers(future,shells)
    sync_scene(atlas,world,true,false,sparse([future]))
    check(atlas.last_reconcile_phases.get("prepared_receiver_nodes",0)==2,"Both newly published floor rows consume prepared native receivers")
    check(atlas.entry_specs[future.node.get_instance_id()].receivers.values().all(func(value):return value.node.get_instance_id() in ids),"Publication retains the actual prepared receiver nodes")
    check(not future.has("atlas_receiver_shells") and atlas.prepared_receiver_sources.is_empty(),"Successful atlas admission releases temporary preparation ownership")
    await material_discovery_oracle(atlas,world,"prepared-receivers")
    await process_frame
    check(extra.get_ref()==null,"Unused receiver shell releases after admission")
    candidate.queue_free()
    var removed:int=future.node.get_instance_id();world.entries.erase(future);future.node.queue_free()
    sync_scene(atlas,world,true,false,sparse([],[removed]))
    var cancelled=Node3D.new();world.add_child(cancelled)
    var abandoned=weakref(atlas.prepare_receiver_node(cancelled))
    cancelled.queue_free();await process_frame;await process_frame
    check(abandoned.get_ref()==null and atlas.receivers.size()==members,"Cancelled world candidate releases its unassigned receivers without changing displayed membership")
