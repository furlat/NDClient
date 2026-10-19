extends "res://tests/actor_preparation_checks.gd"
## Real transient hand-layer boundaries versus the unchanged full-rebuild path.
class FullRebuild extends Probe:
    func _reconcile_actor_layers(_id:String,_row:Dictionary)->bool:return false
class CountLighting extends "res://presentation/native_source_lights.gd":
    var syncs=0
    func sync(state:Dictionary)->void:
        syncs+=1
        super.sync(state)
func reference_for(index:Dictionary)->FullRebuild:
    var host=FullRebuild.new();host.catalog_cache=Catalog.source_snapshot(index.cache)
    var catalog:Dictionary=Catalog.read_file("catalog-index.json",host.catalog_cache)
    host.rigs=Catalog.read_file(catalog.rigs,host.catalog_cache)
    host.rig_config=Catalog.read_file(catalog.rig,host.catalog_cache)
    host.media_metadata_ready=true;root.add_child(host);return host
func descriptors(host:Probe)->Dictionary:
    var result={}
    for id in host.visual_actors:
        var visual:Dictionary=host.visual_actors[id]
        result[id]={"row":visual.row,"entries":[]}
        for entry in visual.entries:
            result[id].entries.append({"id":entry.id,"layer":entry.layer,"role":entry.role,"source":entry.actor_layer,
                "cell":entry.cell,"pivot":entry.pivot,"scale":entry.scale,"shader":entry.material.shader})
    return result
func run()->void:
    var descriptor:Dictionary=Fixtures.case_record("gallery")
    var bundle:Dictionary=Recording.read_case(descriptor)
    check(bundle.get("ok",false),"Actual spell recording admits: "+str(bundle.get("error","")))
    if not bundle.get("ok",false):quit(1);return
    var index:Dictionary=Recording.view_index(bundle,"amber")
    var host=host_for(index);var reference=reference_for(index)
    reference.timeline=host.timeline
    var boundaries={0.0:true}
    for record in index.groups:
        for component in record.group.get("components",[]):
            if component.kind!="sprite_layer":continue
            var at:float=record.start_ms+component.start_ms
            boundaries[maxf(0.,at-.01)]=true;boundaries[at+.01]=true
            boundaries[at+component.duration_ms+.01]=true
    var ordered=boundaries.keys();ordered.sort()
    var retained_nodes=0;var shifted_nodes=0;var retained_graphs=0;var layer_changes=0
    for at in ordered:
        var plan:Dictionary=host.timeline.replay_plan(at)
        if not plan.segments.is_empty():host.timeline._apply_world_plan(plan)
        var samples:Dictionary=host.timeline.actor_samples()
        var components:Array=host.timeline.component_samples(index.cache)
        var frozen=var_to_bytes(host.timeline.state)
        var previous={};var graphs={}
        for id in host.visual_actors:
            previous[id]={}
            graphs[id]=host.playbacks[id].get_instance_id()
            for entry in host.visual_actors[id].entries:
                if entry.actor_layer.get("effect",{}).is_empty():previous[id][entry.actor_layer.slot]={"node":entry.node,"material":entry.material,"layer":entry.layer}
        for owner in [host,reference]:
            owner.displayed_samples=samples;owner.displayed_components=components
            owner._sync_actor_membership()
        check(descriptors(host)==descriptors(reference),"Exact source paths/attachments/row/order equal full reconstruction at "+str(at))
        check(var_to_bytes(host.timeline.state)==frozen,"Layer reconciliation changes no event/canonical data at "+str(at))
        for id in host.playbacks:
            var pose:Dictionary=samples.get(id,{})
            var clip:String=pose.get("clip","Idle")
            var seconds:float=pose.get("source_seconds",at/1000.)
            var occurrence:String=pose.get("occurrence","idle:"+id)
            var actual=Graphs.sample(host.playbacks[id],clip,seconds,occurrence)
            var expected=Graphs.sample(reference.playbacks[id],clip,seconds,occurrence)
            check(actual==expected and host.playbacks[id].clip==reference.playbacks[id].clip and host.playbacks[id].sample_seconds==reference.playbacks[id].sample_seconds,"Retained playback samples the same causal clip and absolute source clock")
        for id in previous:
            if not host.visual_actors.has(id):continue
            var actual:Dictionary=host.visual_actors[id]
            if host.playbacks[id].get_instance_id()==graphs[id]:retained_graphs+=1
            for entry in actual.entries:
                if not previous[id].has(entry.actor_layer.slot):continue
                var prior:Dictionary=previous[id][entry.actor_layer.slot]
                if entry.node==prior.node:
                    retained_nodes+=1
                    check(entry.material==prior.material and is_same(entry.placement,actual.row),"Retained body preserves private material and shared current placement")
                    if entry.layer!=prior.layer:shifted_nodes+=1
            if actual.row.equipment_layers.any(func(layer):return not layer.get("effect",{}).is_empty()):layer_changes+=1
        host.quarter=(host.quarter+1)%4
        host._sync_actor_membership()
        check(descriptors(host)==descriptors(reference),"Rotation changes no authored actor membership/order")
    check(layer_changes>0 and retained_graphs>0 and retained_nodes>0,"Actual hand-layer windows retain playback and body owners")
    check(shifted_nodes>0,"Actual transient insertion/removal shifts retained authored layer indices correctly")
    host.timeline.accept({"kind":"initialization","sequence":0,"state":host.timeline.state.duplicate(true)})
    for owner in [host,reference]:
        owner.displayed_samples={};owner.displayed_components=[];owner._sync_actor_membership()
    check(descriptors(host)==descriptors(reference),"Epoch replacement retires transient layers with exact full-rebuild membership")
    var controlled:String=host.timeline.state.audience.controlled[0]
    var graph:int=host.playbacks[controlled].get_instance_id()
    host.timeline.state.actors[controlled].appearance.skin_tint^=1
    host.timeline.revision+=1
    for owner in [host,reference]:owner._sync_actor_membership()
    check(host.playbacks[controlled].get_instance_id()!=graph and descriptors(host)==descriptors(reference),"Appearance changes keep full reconstruction fallback")
    graph=host.playbacks[controlled].get_instance_id()
    var loadout:Dictionary=host.timeline.state.actors[controlled].visual_loadout
    loadout.active_weapon_set="ranged" if loadout.active_weapon_set=="melee" else "melee"
    host.timeline.revision+=1
    for owner in [host,reference]:owner._sync_actor_membership()
    check(host.playbacks[controlled].get_instance_id()!=graph and descriptors(host)==descriptors(reference),"Base equipment changes keep full reconstruction fallback")
    var lighting=CountLighting.new();host.source_lighting=lighting
    host._sync_source_lighting();var before=lighting.syncs
    host.timeline.revision+=1;host._sync_source_lighting()
    check(lighting.syncs==before,"Actor-only revision preserves exact observed emitter owner")
    var state:Dictionary=host.timeline.state
    if state.get("light_sources",{}).size()>0:
        state.light_sources=state.light_sources.duplicate(true)
        var id=state.light_sources.keys()[0]
        state.light_sources[id].bright_radius_feet+=5
        host.timeline.revision+=1;host._sync_source_lighting()
        check(lighting.syncs==before+1,"Published replacement optical membership refreshes the retained receiving owner")
    # Schema16 explicitly discloses empty optical membership; absence is not a
    # valid request to revive legacy inferred lights.
    state.light_sources={}
    host.timeline.revision+=1;host._sync_source_lighting();before=lighting.syncs
    host.timeline.revision+=1;host._sync_source_lighting()
    check(lighting.syncs==before,"Unchanged explicit empty optical membership preserves its owner across actor revisions")
    host.queue_free();reference.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"retained_nodes":retained_nodes,"shifted_nodes":shifted_nodes,"retained_graphs":retained_graphs,"scope":"Actual recorded hand-layer boundaries versus full reconstruction, source paths/attachments/order/material identity, rotation/epoch, exact light-input invalidation; headless ownership checks, no framebuffer/performance claim."}
    FileAccess.open("res://.runtime/actor-layer-reuse-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ACTOR_LAYER_REUSE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
