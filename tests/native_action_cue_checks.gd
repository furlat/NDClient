extends SceneTree
## Typed action cues use the same package clock without pretending to be spells.
const Action=preload("res://presentation/source/abilities/action.gd")
const Use=preload("res://presentation/source/effect_use.gd")
const Body=preload("res://presentation/source/abilities/body_use.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Actions=preload("res://presentation/native_action_authoring.gd")
const Components=preload("res://presentation/components.gd")
const Renderer=preload("res://presentation/native_spell_renderer.gd")
const BodyIndex=preload("res://presentation/resources/body_source_index.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Results=preload("res://presentation/application_results.gd")
const Constructed=preload("res://presentation/native_constructed_occurrence.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Timeline=preload("res://presentation/timeline.gd")
class World extends Node:
    var timeline=Timeline.new()
const BODY_KEY="__body_source_admission"
const ID="action.class.fighter.action_surge"
const CLIP="fighter_action_surge_native"
var checks:int=0
var failures:Array=[]
const SELECTED=["action.class.barbarian.rage","action.class.barbarian.frenzy","action.class.barbarian.intimidating_presence",
    "action.class.barbarian.frenzied_strike","action.class.fighter.action_surge","action.class.fighter.second_wind",
    "action.class.sorcerer.quickened_spell","action.class.sorcerer.twinned_spell","action.class.sorcerer.distant_spell",
    "action.class.sorcerer.elemental_affinity.resistance","action.class.sorcerer.draconic_presence"]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_ACTION_CUE_FAIL ",label)

func authored()->void:
    var entries={};var paths={};var index=BodyIndex.new()
    index.rigs={"rig":{"clips":{}}}
    for id in SELECTED:
        var path="res://authoring/abilities/actions/"+id+".tres"
        var entry:Resource=load(path)
        check(entry!=null and not entry.effects.is_empty(),id+" has its exact selected typed Factory cues")
        if entry==null:continue
        entries[id]=entry;paths[id]=path
        check(entry.unported.get("media",[]).is_empty(),id+" does not replay its replaced old sprite media")
        if entry.body!=null:index.rigs.rig.clips[entry.body.clip]={"fps":12.0,"frames":16}
    index.rigs.rig.clips.Attack6={"fps":12.0,"frames":16}
    var built:Dictionary=Build.documents({"actions":entries},{"actions":paths})
    var cache={BODY_KEY:{"index":index,"loaded":{}}}
    for id in entries:
        var entry:Resource=entries[id]
        var recipe:Dictionary=built.docs["catalog/body_action_recipes.json"].get(id,{})
        var clip:String=entry.body.clip if entry.body!=null else "Attack6"
        if entry.body==null:recipe={"anchors":[{"name":"action_start","frame":0},{"name":"contact","frame":7}]}
        var track={"rig":"rig","clip":clip,"start_ms":100.0,"duration_ms":1000.0,"source_start_seconds":0.0,"source_end_seconds":1.0}
        var fact={"kind":"attack" if id.ends_with("frenzied_strike") else "action","behavior_id":id,"source_entity_uuid":"actor"}
        var phases:Array=Actions.phases(built.docs["catalog/body_action_bindings.json"][id],fact,recipe,track,
            {"event.start":100.0,"body.contact":683.333333},cache)
        check(phases.size()==entry.effects.size() and phases.all(func(row):return row.get("status")!="missing"),id+" resolves every exact cue through the production phase compiler")
        check(phases.all(func(row):return row.ability_kind==fact.kind and row.ability_id==id and not row.has("spell_id")),id+" preserves its actual action/attack domain")
        check(phases.all(func(row):return row.source.begins_with(paths[id]+"::effects/")),id+" retains its editable typed source pointer")

func observations()->void:
    var action={"id":"21","lineage_id":"4","parent_lineage":null,"fact":{"kind":"action","behavior_id":"action.class.fighter.second_wind","source_entity_uuid":"actor"}}
    var heal={"id":"22","lineage_id":"5","parent_event":"20","parent_lineage":"4","fact":{"kind":"heal","source_entity_uuid":"actor","target_entity_uuid":"actor","actual_healing":7,"was_blocked":false,"source_condition_uuid":null}}
    var phase={"start_ms":100.0,"native_clip":{"inputs":["owner_projection"]}}
    var graph={"nodes":{"4":action,"5":heal},"condition_cues":{},"starts":{"21":0.0,"22":100.0}}
    var original:Dictionary=graph.duplicate(true)
    var result:Dictionary=Actions.inputs(action,{},phase,graph)
    check(result.gaps.is_empty() and result.values.has("owner_projection"),"The native positive self-heal is sufficient observed owner evidence")
    if result.values.has("owner_projection"):
        var projection:Dictionary=result.values.owner_projection
        check(projection.actor_id=="actor" and projection.actor_uuid=="actor" and projection.behavior_id==action.fact.behavior_id and projection.healing.actual_healing==7,"Healing projection contains actual public fact values and matches the actual geometry owner")
        check(projection.action_uuid=="20" and projection.healing.parent_event_uuid=="20" and projection.healing.event_uuid=="22","The earlier native parent version and heal occurrence are encoded directly, never fabricated UUIDs")
        check(result.evidence.action_occurrence=="21" and result.evidence.action_lineage=="4" and result.evidence.native_action_parent_occurrence=="20","Diagnostics retain fact occurrence, lineage and earlier native parent separately")
    heal.fact.was_blocked=true
    check(not Actions.inputs(action,{},phase,graph).values.has("owner_projection"),"A blocked heal cannot activate recovery art")
    heal.fact.was_blocked=false;heal.fact.target_entity_uuid="other"
    check(not Actions.inputs(action,{},phase,graph).values.has("owner_projection"),"An unrelated recipient cannot qualify a successful self-heal")
    heal.fact.target_entity_uuid="actor";heal.parent_lineage="missing"
    check(not Actions.inputs(action,{},phase,graph).values.has("owner_projection"),"Unlinked healing cannot be attributed to an action by name")
    heal.parent_lineage="4"
    check(graph==original,"Observation projection leaves native graph, fact and parent identity unchanged")
    var owner={"condition_uuid":"actual-condition","behavior_id":"class_feature.barbarian.raging"}
    var apply={"id":"31","lineage_id":"8","parent_lineage":"4","fact":{"kind":"actor_change"}}
    var remove={"id":"32","lineage_id":"9","parent_lineage":"4","fact":{"kind":"actor_change"}}
    graph.nodes={"4":action,"8":apply,"9":remove};graph.condition_cues={"31":[{"phase":"application","actor_uuid":"actor","condition":owner}]}
    graph.starts={"31":100.0,"32":300.0}
    phase.native_clip.inputs=["owner_projection","activation_projection"]
    var binding={"applies_conditions":[owner.behavior_id]}
    var held:Dictionary=Actions.inputs(action,binding,phase,graph)
    check(held.gaps.is_empty() and held.values.owner_projection.removed_seconds==-1.0,"A live held condition supplies the source's explicit unknown-removal sentinel without inventing an expiry")
    graph.condition_cues["32"]=[{"phase":"removal","actor_uuid":"actor","condition":owner}]
    var ended:Dictionary=Actions.inputs(action,binding,phase,graph)
    check(ended.gaps.is_empty() and is_equal_approx(ended.values.owner_projection.removed_seconds,.2),"A real observed removal supplies the actual relative end")
    check(ended.values.activation_projection.action_uuid=="21" and ended.values.activation_projection.parent_owner_uuid=="actual-condition","Activation references the real action and observed condition UUID")
    var before:Dictionary=Actions.inputs(action,binding,phase,graph,[action,remove,apply])
    check(before.gaps.is_empty() and before.values.owner_projection.removed_seconds==-1.0,"An earlier removal cannot close a newly reapplied equal UUID")
    graph.condition_cues["31"].append({"phase":"removal","actor_uuid":"actor","condition":owner})
    var transient:Dictionary=Actions.inputs(action,binding,phase,graph,[action,apply])
    check(transient.gaps.is_empty() and transient.values.owner_projection.removed_seconds==0.0,"A same-occurrence ordered transient application/removal retains its zero-duration lifetime")

func held_conditions()->void:
    var id:String="class_feature.barbarian.raging"
    var entry:Resource=load("res://authoring/abilities/conditions/"+id+".tres")
    var built:Dictionary=Build.documents({"conditions":{id:entry}},{"conditions":{id:"res://authoring/abilities/conditions/"+id+".tres"}})
    var config:Dictionary=built.docs["catalog/condition_recipes.json"][id]
    check(config.persistent.nativeEffects.size()==1 and config.persistent.nativeEffects[0].clip=="barbarian_rage_source_v176","The mantle is authored on its condition, not on a finite action")
    var action:Resource=load("res://authoring/abilities/actions/action.class.barbarian.rage.tres")
    check(action.effects.size()==1 and action.effects[0].clip=="barbarian_rage_onset_v191_pressure","Only the finite onset remains action-owned")
    var cache={"catalog/condition_recipes.json":{id:config},"catalog/condition_media.json":{},"native_effects/index.json":{"sources":{}},"audio/bindings.json":{"conditions":{}}}
    var owner={"condition_uuid":"actual-owner","behavior_id":id,"state":{}}
    var actors={"actor":{"conditions":[owner],"life_state":"alive"}}
    var owners:Dictionary={}
    var row={"actor_uuid":"actor","row":{"field":"condition"},"before":null,"after":owner}
    Conditions.observe(owners,actors,100.0,false,[row])
    var samples:Array=Conditions.native_samples(owners,6100.0,cache,true)
    check(samples.size()==1 and samples[0].condition_uuid==owner.condition_uuid and is_inf(samples[0].duration_ms),"A held source survives the old four-second clip boundary without duplicating replaced media")
    if not samples.is_empty():
        check(samples[0].age_ms==6000.0 and not samples[0].native_cue.has("lifecycle") and is_inf(samples[0].native_cue.end),"Its free-running source uses actual owner age, not a frozen spatial hold pose")
        check(samples[0].native_cue.entity_geometry.actor=="caster" and samples[0].trace_keys==[samples[0].id],"The condition retains its shared geometry provider and inspectable track")
        var root_node:Node3D=Node3D.new()
        var handle={"root":root_node,"light_units":{},"opacity_bindings":[]}
        preload("res://presentation/native_spell_playback.gd").controls(handle,samples[0].native_cue,3600.0)
        check(is_finite(handle.opacity) and handle.opacity==1.0,"An indefinite hold never feeds infinite clip-end bounds into the finite fade controller; the source owns its observed return")
        root_node.free()
    var long_hold:Array=Conditions.native_samples(owners,3600100.0,cache)
    check(long_hold.size()==1 and long_hold[0].age_ms==3600000.0,"A disclosed indefinite owner has no fabricated round or inspection-duration expiry")
    actors.actor.conditions=[];row.before=owner;row.after=null
    Conditions.observe(owners,actors,3600200.0,false,[row])
    var ended:Array=Conditions.native_samples(owners,3600300.0,cache)
    check(ended.size()==1 and ended[0].duration_ms==3600100.0 and ended[0].removal_age_ms==100.0,"Only an observed removal starts the same owner's authored return")
    var second:Dictionary=owner.duplicate();second.condition_uuid="second-owner"
    actors.actor.conditions=[second];row.before=null;row.after=second
    Conditions.observe(owners,actors,3600300.0,false,[row])
    var overlap:Array=Conditions.native_samples(owners,3600350.0,cache)
    check(owners.size()==2 and overlap.size()==1 and overlap[0].condition_uuid==second.condition_uuid and overlap[0].age_ms==50.0,"A new UUID gets its own clock; the existing exclusive-group policy selects its live owner over the retiring one")
    var final:Array=Conditions.native_samples(owners,3600550.0,cache)
    check(final.size()==1 and final[0].condition_uuid==second.condition_uuid,"The removal tail retires precisely; a later application remains held")

func factual_events()->void:
    var id:String="action.class.cleric.preserve_life"
    var path:String="res://authoring/abilities/actions/"+id+".tres"
    var entry:Resource=load(path)
    var built:Dictionary=Build.documents({"actions":{id:entry}},{"actions":{id:path}})
    var binding:Dictionary=built.docs["catalog/body_action_bindings.json"][id]
    var action={"id":"51","lineage_id":"50","parent_lineage":null,"fact":{"kind":"action","behavior_id":id,"source_entity_uuid":"caster"}}
    var first={"id":"61","lineage_id":"60","parent_lineage":"50","fact":{"kind":"heal","source_entity_uuid":"caster","target_entity_uuid":"ally","actual_healing":7,"was_blocked":false}}
    var second={"id":"71","lineage_id":"70","parent_lineage":"50","fact":{"kind":"heal","source_entity_uuid":"caster","target_entity_uuid":"other","actual_healing":9,"was_blocked":false}}
    var blocked={"id":"81","lineage_id":"80","parent_lineage":"50","fact":{"kind":"heal","source_entity_uuid":"caster","target_entity_uuid":"other","actual_healing":9,"was_blocked":true}}
    var zero={"id":"91","lineage_id":"90","parent_lineage":"50","fact":{"kind":"heal","source_entity_uuid":"caster","target_entity_uuid":"ally","actual_healing":0,"was_blocked":false}}
    var unrelated={"id":"101","lineage_id":"100","parent_lineage":null,"fact":{"kind":"heal","source_entity_uuid":"caster","target_entity_uuid":"ally","actual_healing":8,"was_blocked":false}}
    var life={"id":"111","lineage_id":"110","parent_lineage":"50","fact":{"kind":"life","entity_uuid":"revived","previous_state":"dead","new_state":"alive"}}
    var removal={"id":"121","lineage_id":"120","parent_lineage":"50","fact":{"kind":"actor_change"}}
    var events:Array=[action,first,second,blocked,zero,unrelated,life,removal]
    var graph={"nodes":{},"condition_cues":{"121":[{"phase":"removal","actor_uuid":"ally","condition":{"condition_uuid":"actual-removed"}}]},
        "positions":{"caster":[3,7],"ally":[4,7],"other":[4,8],"revived":[3,8]},"contacts":{},"starts":{}}
    for node in events:graph.nodes[node.lineage_id]=node;graph.starts[node.id]=float(graph.starts.size())*100.0
    graph.observed_results=Results.observed_index(events,graph)
    var original:Dictionary=graph.duplicate(true)
    var group={"operation_sequence":7,"components":[]}
    Components.native_action(group,action,binding,{}, {},{"event.start":0.0},graph,{},events)
    check(group.components.size()==3,"One source invocation and two actual positive recipient heals are compiled without blocked, zero or unrelated outcomes")
    var recipient_rows:Array=group.components.filter(func(row):return row.native_cue.scope=="recipient")
    check(recipient_rows.map(func(row):return row.target_uuid)==["ally","other"],"Each receiving occurrence uses its actual native recipient")
    check(recipient_rows.map(func(row):return row.source_event_uuid)==["61","71"],"Receiving effects attach to the real result occurrence, with source lineage retained separately")
    for row in recipient_rows:
        var operand:Dictionary=row.native_constructor_inputs[0]
        check(operand.input_field.is_empty() and operand.values.actor_roles.target==row.target_uuid and operand.values.geometry_actor==row.target_uuid,"Construction remaps root identity/geometry scalars to the actual actor before make")
        check(operand.values.event.is_empty() and operand.values.lease.is_empty() and not operand.values.plan_only,"Successful review event and lease are cleared before constructing a real occurrence")
        check(row.native_inputs.event_input.actual_healing in [7,9] and row.native_input_evidence.source_occurrence=="51","The later input packet carries observed healing and separate original action evidence")
        var source:Resource=load(Effects.choice(row.native_clip).approaches[0].source_phase)
        var before:Dictionary=source.to_clip()
        var constructed:Dictionary=Constructed.clip_with_inputs(source,row.native_constructor_inputs)
        check(constructed.components[0].input.recipient_entity_uuid==row.target_uuid and source.to_clip()==before,"Whole-component input projection is private and leaves the delivered Resource unchanged")
    check(Actions.effect_clips(id,{"catalog/body_action_bindings.json":{id:binding}}).all(func(clip):return clip.requires_constructor_input),"Choice preparation cannot instantiate a divine source with its successful review fixture")
    var descriptor={"outcome":"revival","geometry_actor":"target"}
    var revived:Array=Results.observed(action,descriptor,graph)
    check(revived.size()==1 and revived[0].event.revived_entity_uuid=="revived" and not revived[0].event.has("actual_healing"),"Committed dead-to-alive revival needs no invented positive HealFact")
    descriptor.outcome="removal"
    var removed:Array=Results.observed(action,descriptor,graph)
    check(removed.size()==1 and removed[0].event.removed_condition_uuids==["actual-removed"],"Cure inputs name only recipient-local accepted removal UUIDs")
    check(graph==original,"Observed projections do not rewrite server facts, graph rows or condition members")

func retained_occurrences()->void:
    var world:World=World.new();var renderer=Renderer.new()
    var delayed={"id":"actual-delayed-result","kind":"native_effect","native_spell":true,"start_ms":350.0,"duration_ms":1100.0}
    renderer.handles[delayed.id]={"component":delayed}
    world.timeline.retained_components=[{"component":delayed,"group_start_ms":500.0}]
    world.timeline.display_ms=504.0
    check(renderer._queued_ids(world).has(delayed.id),"The timeline owns an already prepared delayed receiver after its zero-time operation completes, before its first active sample")
    check(renderer._queued_ids(world).has(delayed.id),"Unchanged retained ownership reuses the same native instance")
    world.timeline.retained_components=[];world.timeline.resource_revision+=1
    check(not renderer._queued_ids(world).has(delayed.id),"Timeline expiry invalidates retention and permits precise teardown")
    renderer.handles.clear();world.free()
    renderer._missing({"id":"known-input-gap","status":"missing","native_input_gaps":["native_condition_parent_link_unavailable"]},"native_condition_parent_link_unavailable")
    check(renderer.issues.is_empty() and renderer.diagnostics["known-input-gap"].native_input_gaps==["native_condition_parent_link_unavailable"],"A declared unimplemented provider stays visible missing work without rejecting unrelated playback")
    renderer._missing({"id":"runtime-error","status":"available"},"unexpected_source_failure")
    check(renderer.issues.size()==1,"An actual source failure remains a presentation error")
    var untouched={"application":{"effects":[{"assetId":"not-replaced-apply"}]},"removal":{"effects":[{"assetId":"not-replaced-remove"}]},
        "persistent":{"nativeEffects":[{"replaces_media":["only-this-layer"]}]}}
    check(Conditions.NativePersistent.replaced_media("condition.test.no_package",untouched)==["only-this-layer"],"An authored hold only replaces its declared media; unrelated missing apply/remove effects remain requirements")

func run()->void:
    var use=Use.new();use.clip=CLIP;use.selection="fighter_action_surge_native"
    use.role="attached";use.at="body.effect";use.attachment="caster_ground";use.follow=true
    use.source_start=.1;use.source_end=.7;use.source_rate=2.0;use.delay=.025
    use.light_multiplier=0.0;use.offset=Vector3(.1,.2,.3);use.extra={"entity_geometry":{"actor":"caster","slots":["body"]}}
    var action=Action.new();action.id=ID;action.kind="action";action.disposition="authored";action.body=Body.new()
    action.body.clip="Idle4";action.body.role="act"
    action.body.markers.action_start=0.0;action.body.markers.effect=3.0;action.body.markers.recover=12.0
    action.effects.append(use)
    action.applies_conditions.append("class_feature.fighter.test_owner")
    var alias=Action.new();alias.id="action.test_alias";alias.kind="action";alias.plays=ID;alias.effects.append(use)
    var path="res://authoring/abilities/actions/"+ID+".tres"
    var built:Dictionary=Build.documents({"actions":{ID:action,alias.id:alias}}, {"actions":{ID:path,alias.id:"res://authoring/abilities/actions/action.test_alias.tres"}})
    var bindings:Dictionary=built.docs["catalog/body_action_bindings.json"]
    check(bindings.has(ID) and bindings[ID].effect_cues.size()==1,"A direct action owns its typed Factory cue")
    check(bindings[alias.id].source_recipe==ID and bindings[alias.id].effect_cues.size()==1,"An action body alias keeps its own effect binding")
    var cue:Dictionary=bindings[ID].effect_cues[0]
    check(cue.selection==use.selection and cue.source_index==0.0 and cue.follow_attachment,"Selected package identity and attachment policy survive the builder")
    check(cue.source_start==.1 and cue.source_end==.7 and cue.source_rate==2.0 and cue.delay_seconds==.025,"Source window and speed survive the shared EffectUse conversion")
    check(Vector3(cue.offset[0],cue.offset[1],cue.offset[2]).is_equal_approx(use.offset) and cue.light_multiplier==0.0 and cue.entity_geometry.actor=="caster","Per-cue optical and provider fields retain authored values")
    check(bindings[ID].source==path+"::effects","The cue points at its actual typed source")
    check(bindings[ID].applies_conditions==["class_feature.fighter.test_owner"],"Selection gets only the action's explicitly authored possible owner IDs")
    var index=BodyIndex.new();index.rigs={"rig":{"clips":{"Idle4":{"fps":12.0,"frames":16}}}}
    var cache={BODY_KEY:{"index":index,"loaded":{}},
        "audio/bindings.json":{"actions":{}},"native_effects/index.json":{"sources":{}},
        "catalog/body_action_bindings.json":bindings}
    var recipe:Dictionary=built.docs["catalog/body_action_recipes.json"][ID]
    var track={"rig":"rig","clip":"Idle4","start_ms":100.0,"duration_ms":1000.0,"source_start_seconds":0.0,"source_end_seconds":1.0}
    var markers={"event.start":100.0,"body.contact":500.0,"body.end":1100.0}
    check(is_equal_approx(Actions.anchor("body.effect",recipe,track,markers,cache),350.0),"A cue uses the actual body source-frame crossing")
    var warped=track.duplicate();warped.source_time_keys=[[0.0,0.0],[.5,.25],[1.0,1.0]]
    check(is_equal_approx(Actions.anchor("effect",recipe,warped,markers,cache),600.0),"Piecewise body timing is inverted rather than assuming a fixed rate")
    var reversed=track.duplicate();reversed.source_start_seconds=1.0;reversed.source_end_seconds=0.0
    check(is_equal_approx(Actions.anchor("body.effect",recipe,reversed,markers,cache),850.0),"Reversed body timing retains the real crossing")
    check(Actions.anchor("body.unknown",recipe,track,markers,cache)==null,"An unauthored anchor has no invented contact fallback")
    var fact={"kind":"action","behavior_id":ID,"source_entity_uuid":"actor"}
    var original:Dictionary=fact.duplicate(true)
    var phases:Array=Actions.phases(bindings[ID],fact,recipe,track,markers,cache)
    check(Actions.effect_clips(ID,cache).map(func(clip):return clip.id)==[CLIP],"Selection can expose the exact action clip before receiving an event")
    check(phases.size()==1 and phases[0].get("status")!="missing","The existing Factory clip resolves without construction or a GPU")
    if not phases.is_empty():
        var phase:Dictionary=phases[0]
        check(is_equal_approx(phase.start_ms,375.0),"Authored delay starts after the resolved effect frame")
        check(phase.ability_id==ID and phase.ability_kind=="action" and not phase.has("spell_id"),"The action never becomes a pretend SpellFact")
        check(phase.timing_selector=="body.effect" and phase.native_cue.authored_at=="body.effect","Diagnostics retain the original action anchor")
        check(phase.optical.energy_multiplier==0.0,"Decorative light remains explicitly authored")
        check(phase.native_cue.source_start==.1 and phase.native_cue.source_rate==2.0,"The renderer receives the original source clock")
    var missing:Dictionary=bindings[ID].duplicate(true);missing.effect_cues[0].at="body.unknown"
    var missing_phase:Array=Actions.phases(missing,fact,recipe,track,markers,cache)
    check(missing_phase[0].status=="missing" and missing_phase[0].reason=="native_action_anchor_unavailable","A missing anchor stays an inspectable gap")
    # Exercise production component dispatch from the actual action kind. An
    # event-start anchor deliberately needs no artificial body track fixture.
    var direct:Dictionary=bindings[ID].duplicate(true);direct.effect_cues[0].at="event.start"
    cache["catalog/body_action_bindings.json"]={ID:direct}
    var node={"id":"17","lineage_id":"12","parent_lineage":null,"fact":fact,"canceled":false}
    var group={"operation_sequence":4,"actor_tracks":[],"components":[]}
    var graph={"starts":{"17":100.0},"recipes":{"17":{}},"actor_inputs":{"17":{"actor":{"uuid":"actor"}}},
        "positions":{"actor":[3,7]},"contacts":{"actor":{"from_elevation_feet":10.0}}}
    check(Components.compile(group,{"events":[node]},graph,cache).ok,"Production component compilation accepts typed action cues")
    check(group.components.size()==1 and Renderer.accepts(group.components[0]),"Action cues enter the existing Factory renderer")
    if not group.components.is_empty():
        var component:Dictionary=group.components[0]
        check(component.source_event_uuid=="17" and component.source_lineage=="12" and component.parent_id=="4:17","The native occurrence and parent lineage remain unchanged")
        check(component.ability_kind=="action" and component.ability_id==ID and not component.has("spell_id"),"Production dispatch preserves the original domain kind")
        check(component.actor_uuid=="actor" and component.target_uuid=="actor" and component.to_position==[3,7] and component.to_elevation_feet==10.0,"A caster-owned cue uses that actual actor and elevation")
    graph.positions={};group.components=[]
    Components.compile(group,{"events":[node]},graph,cache)
    check(group.components.size()==1 and group.components[0].status=="missing" and group.components[0].reason=="native_action_position_unavailable","Missing public placement never creates an effect at a fixture origin")
    check(fact==original,"Cue preparation and component dispatch do not mutate authoritative facts")
    authored();observations();held_conditions();factual_events();retained_occurrences()
    print(JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
