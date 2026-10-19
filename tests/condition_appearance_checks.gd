extends SceneTree
## Exact native outfit/source cuts plus the delivered public appearance lease.
const Appearance=preload("res://presentation/condition_appearance.gd")
const Characters=preload("res://presentation/characters.gd")
const Construction=preload("res://presentation/actor_construction.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Body=preload("res://modular.gdshader")
const Condition=preload("res://presentation/source/abilities/condition.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
class World extends Node3D:
    var visual_actors:Dictionary={}
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("APPEARANCE_FAIL "+label)
func fly(id:String)->Dictionary:
    return {"condition_uuid":id,"behavior_id":"condition.spell.fly","state":{}}
func run()->void:
    var state:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema16/character_sources.json"))
    var actor:Dictionary={}
    for value in state.actors.values():
        if value.name=="Draconic Sorcerer":actor=value
    state.actors={actor.uuid:actor}
    var cache:Dictionary={};var original:PackedByteArray=var_to_bytes(state)
    var flying:Dictionary=actor.duplicate(false);flying.conditions=actor.conditions+[fly("flight-a")]
    var owners:Dictionary={}
    Compiler.Conditions.observe(owners,{actor.uuid:flying},20.0)
    var layers:Array=Appearance.components(owners,20.0,cache)
    check(layers.size()==1 and layers[0].layer.category=="Bag8","Actual Fly authoring supplies the exact outfit category")
    var loadouts:Dictionary=Construction.loadouts({},layers)
    var staged_actor:Dictionary=Construction.actor_with_loadout(flying,loadouts)
    var resolved:Dictionary=Characters.resolve(staged_actor,state,cache)
    check(resolved.ok,"Fly resolves through the existing actual outfit constructor")
    var rig:Dictionary=Characters.rigs(cache)[resolved.value.rig]
    var selected:Dictionary=Characters.prepare_layers(resolved.value,rig,cache)
    var wings:Array=selected.value.filter(func(layer):return layer.slot=="backpack")
    check(wings.size()==1 and wings[0].category=="Bag8" and wings[0].alpha==0.0,"One prepared hidden wing layer waits for Factory opacity")
    check(wings[0].paths.has("Idle") and wings[0].paths.has("Run"),"Wing sources follow actual idle and movement clips")
    var after:Dictionary=state.duplicate(false);after.actors={actor.uuid:flying}
    var demand:Dictionary=Media.plan(Media._snapshot(after),[],cache)
    check(demand.errors.is_empty() and demand.required.has(wings[0].paths.Idle),"Normal received-state preparation owns the wing sheet before publication")
    var changed:Dictionary=actor.duplicate(false);changed.visual_loadout=actor.visual_loadout.duplicate(true)
    changed.visual_loadout.layers=changed.visual_loadout.layers.filter(func(layer):return layer.slot!="Body")
    var group:Dictionary={"id":"flight","duration_ms":500.0,"actor_tracks":[],"staged_actors":{},"components":[],"commits":[
        {"at_ms":20.0,"delta":{"actors":{actor.uuid:flying}}},
        {"at_ms":200.0,"delta":{"actors":{actor.uuid:actor}},"condition_rows":[{"actor_uuid":actor.uuid,"row":{"field":"condition"},"before":fly("flight-a"),"after":null}]},
        {"at_ms":250.0,"delta":{"actors":{actor.uuid:changed}}}]}
    group.actor_tracks=[{"actor_uuid":actor.uuid,"rig":resolved.value.rig,"clip":"Attack5","start_ms":0.0,"duration_ms":500.0,"priority":1,"presentation_actor":actor,"presentation_item_looks":Characters.item_looks(actor,state)}]
    var casting_demand:Dictionary=Media.plan(Media._snapshot(state),[group],cache)
    var onset:Dictionary=Media.required_at(casting_demand.character_timeline[group.id],20.0)
    check(onset.has(wings[0].paths.Attack5),"A condition admitted midway through casting prepares its new layer on the still-running cast clip")
    Compiler._actor_structure_requirements(state,[group],cache)
    check(20.0 in group.actor_structure_times,"Application schedules an actual prepared outfit boundary")
    check(200.0 not in group.actor_structure_times,"Removal retains the wing layer during its authored fade")
    check(250.0 in group.actor_structure_times,"Equipment changes remain ordered while wings are fading")
    var tail:float=Appearance.removal_ms(fly("flight-a"))
    check(tail>0.0 and 200.0+tail in group.actor_structure_times,"Last wing removal schedules its exact Factory removal endpoint")
    Compiler.Conditions.observe(owners,{actor.uuid:actor},200.0)
    var fading:Array=Appearance.components(owners,200.0+tail*.5,cache)
    check(fading.size()==1 and Appearance.components(owners,200.0+tail,cache).is_empty(),"Half-open membership retains only the real removal tail")
    var restored:Dictionary=Characters.structure(Construction.actor_with_loadout(changed,Construction.loadouts({},Appearance.components(owners,500,cache))),cache,Characters.item_looks(changed,state))
    var expected:Dictionary=Characters.structure(changed,cache,Characters.item_looks(changed,state))
    check(restored.ok and restored.value==expected.value,"Removal restores current authoritative equipment rather than a saved outfit")
    var timeline:RefCounted=Timeline.new();timeline.state=state;timeline.condition_owners={}
    Compiler.Conditions.observe(timeline.condition_owners,state.actors,0.0,true)
    var plan:Dictionary={"display_ms":20.0,"segments":[{"group":group,"first_commit":0,"end_commit":1,"local_ms":20.0,"start_ms":0.0,"complete":false}]}
    group.operation_sequence=1
    var candidate:Dictionary=timeline._world_candidate(plan)
    check(candidate.actor_layers.any(func(layer):return layer.kind=="appearance_layer"),"Future world candidate prepares the actual new wing membership")
    check(timeline.condition_owners.is_empty(),"Preparing future wings publishes no condition owner")
    var retained_owner:Dictionary=owners["flight-a"].duplicate(false)
    retained_owner.end_ms=200.123456789
    timeline.condition_owners={"flight-a":retained_owner}
    var later:Dictionary={"id":"later-operation","duration_ms":500.0,"commits":[]}
    var absolute_end:float=retained_owner.end_ms+tail
    var end_plan:Dictionary=timeline._plan_group_world(later,300.123,0,300.123,600.0,false,[])
    check(end_plan.boundary and end_plan.display_ms==absolute_end,"A removal crossing operations retains its exact absolute structural boundary")
    var removed_candidate:Dictionary=timeline._world_candidate({"display_ms":absolute_end,"segments":[{"group":later.merged({"operation_sequence":2}),"first_commit":0,"end_commit":0,"local_ms":absolute_end-300.123,"start_ms":300.123,"complete":false}]})
    check(removed_candidate.actor_layers.is_empty(),"The cross-operation candidate prepares restored gear at the same removal endpoint")
    timeline.display_ms=300.123;timeline.current={};timeline.queue=[]
    var idle_plan:Dictionary=timeline._plan_world_advance(600.0)
    check(idle_plan.boundary and idle_plan.display_ms==absolute_end and idle_plan.segments.is_empty(),"Queue-empty live playback prepares retained removal without inventing a group")
    var replay_idle:Dictionary=timeline.replay_plan(600.0)
    check(replay_idle.boundary and replay_idle.display_ms==absolute_end and replay_idle.segments.is_empty(),"Queue-empty replay uses the same exact owner endpoint")
    var idle_candidate:Dictionary=timeline._world_candidate(idle_plan)
    check(idle_candidate.actor_layers.is_empty() and idle_candidate.state==state and timeline.condition_owners.has("flight-a"),"Idle preparation restores the current outfit without mutating state or ownership")
    var preview:Dictionary=timeline.preview_world()
    check(preview.retained_boundary and preview.display_ms==absolute_end,"Idle lookahead prepares the endpoint before its display frame")
    timeline.queue=[later.merged({"operation_sequence":2,"preview_start_ms":700.0})]
    var gap:Dictionary=timeline._plan_world_advance(600.0)
    check(gap.boundary and gap.display_ms==absolute_end and gap.segments.is_empty(),"A queued later operation cannot hide the removal in its preceding idle gap")
    timeline._apply_world_plan(gap)
    check(timeline.display_ms==absolute_end and timeline.sequence==-1 and timeline.commit_index==0 and timeline.queue.size()==1,"Idle publication advances no authoritative cursor, group or commit")
    check(not timeline._plan_world_advance(600.0).boundary,"An admitted endpoint is consumed once without repeating an idle cut")

    check(var_to_bytes(state)==original,"Source and constructor planning do not mutate canonical actors/items")
    var first:Resource=Condition.new();first.appearance_layers=[{"id":"same","slot":"backpack","category":"Bag8","priority":90}]
    var conflict:Resource=Condition.new();conflict.appearance_layers=[{"id":"same","slot":"backpack","category":"Bag7","priority":90}]
    var report:Dictionary=Build.Common.report()
    Build._check_appearance_definitions({"one":first,"two":conflict},report)
    check(report.errors.size()==1,"Ambiguous semantic appearance definitions fail during build, never during a frame")
    await lease_contract(actor.uuid,layers[0].layer)
    print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
func lease_contract(actor:String,definition:Dictionary)->void:
    var world:World=World.new();root.add_child(world)
    var node:MeshInstance3D=MeshInstance3D.new();node.mesh=QuadMesh.new();world.add_child(node)
    var material:ShaderMaterial=ShaderMaterial.new();material.shader=Body;node.material_override=material
    var entry:Dictionary={"node":node,"material":material,"actor_layer":{"slot":"backpack","category":"Bag8","effect":definition}}
    world.visual_actors[actor]={"entries":[entry]}
    var bridge:RefCounted=Appearance.new()
    var selected:Dictionary=Effects.conditions("condition.spell.fly")[0]
    var clip:Dictionary=Effects.clip(selected.condition.phases.application)
    Effects._ensure_clock()
    var occurrence:Node3D=load("res://assets/vfx/conditions/condition_fly_persistent/application.gd").make_component({"layer_mask":0})
    world.add_child(occurrence)
    var handle:Dictionary={"occurrence":occurrence,"clip":clip}
    var component:Dictionary={"actor_uuid":actor,"target_uuid":actor,"condition_uuid":"flight-a"}
    check(bridge.bind(world,handle,component).is_empty(),"Delivered Factory appearance setter admits the actual prepared recipient")
    var binding:Object=handle.appearance_binding
    check(bridge.bind(world,handle,component).is_empty() and handle.appearance_binding==binding,"Unchanged frame keeps its lease without configure/release churn")
    check(bridge.leases.size()==1 and bridge.leases.values()[0].condition_uuid=="flight-a","Factory instance lease retains the actual condition UUID")
    occurrence.set_owner_state({"phase":"sustain","phase_age_seconds":0.2,"owner_age_seconds":0.38})
    occurrence.sample(.38);bridge.sampled(handle);bridge.sync(world)
    check(is_equal_approx(float(material.get_shader_parameter("layer_alpha")),1.0),"Factory sustain opacity reaches the original prepared wing material")
    var source_version:int=entry.source_version
    bridge.sync(world)
    check(entry.source_version==source_version,"Unchanged opacity does not dirty lighting or source bindings")
    bridge.begin_sample();bridge.sync(world)
    check(bridge.leases.size()==1 and is_zero_approx(float(material.get_shader_parameter("layer_alpha"))),"A retained invisible/dead/failed effect contributes zero opacity without losing its lease")
    bridge.sampled(handle);bridge.sync(world)
    check(is_equal_approx(float(material.get_shader_parameter("layer_alpha")),1.0),"A resumed actual sample restores the held opacity without reconfiguration")
    check(not binding.acquire_condition_appearance(999,{"actor_uuid":"other","layer":definition}),"Owner binding rejects a different actor")
    bridge.release("other-owner",occurrence.get_instance_id())
    check(bridge.leases.size()==1,"Wrong condition owner cannot release a lease")
    occurrence.set_owner_state({"phase":"removal","phase_age_seconds":.075,"owner_age_seconds":.5,"removal_started_at_owner_age_seconds":.425})
    occurrence.sample(.5);bridge.sampled(handle);bridge.sync(world)
    var alpha:float=material.get_shader_parameter("layer_alpha")
    check(alpha>0.0 and alpha<1.0,"Delivered removal curve controls the same wings rather than another animation")
    definition.condition_uuids.append("flight-b")
    var other:Node3D=load("res://assets/vfx/conditions/condition_fly_persistent/application.gd").make_component({"layer_mask":0})
    world.add_child(other)
    var other_handle:Dictionary={"occurrence":other,"clip":clip}
    check(bridge.bind(world,other_handle,{"actor_uuid":actor,"target_uuid":actor,"condition_uuid":"flight-b"}).is_empty(),"A reapplied new UUID acquires its own lease while the old owner is fading")
    other.set_owner_state({"phase":"sustain","phase_age_seconds":.2,"owner_age_seconds":.38});other.sample(.38)
    bridge.begin_sample();bridge.sampled(handle);bridge.sampled(other_handle);bridge.sync(world)
    check(is_equal_approx(float(material.get_shader_parameter("layer_alpha")),1.0),"Two identical physical appearances use maximum opacity, never additive brightness")
    occurrence.queue_free();await process_frame
    bridge.begin_sample();bridge.sampled(other_handle);bridge.sync(world)
    check(bridge.leases.size()==1 and is_equal_approx(float(material.get_shader_parameter("layer_alpha")),1.0),"Old-owner teardown cannot remove the reapplied owner's wings")
    other.queue_free();await process_frame;bridge.begin_sample();bridge.sync(world)
    check(bridge.leases.is_empty() and is_zero_approx(float(material.get_shader_parameter("layer_alpha"))),"Factory teardown releases only its lease and clears stale opacity")
    world.queue_free();await process_frame
