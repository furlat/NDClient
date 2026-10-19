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
    check(held.values.is_empty() and "native_owner_projection_removal_not_observed" in held.gaps,"A live held condition does not invent a finite removal from the clip duration")
    graph.condition_cues["32"]=[{"phase":"removal","actor_uuid":"actor","condition":owner}]
    var ended:Dictionary=Actions.inputs(action,binding,phase,graph)
    check(ended.gaps.is_empty() and is_equal_approx(ended.values.owner_projection.removed_seconds,.2),"A real observed removal supplies the actual relative end")
    check(ended.values.activation_projection.action_uuid=="21" and ended.values.activation_projection.parent_owner_uuid=="actual-condition","Activation references the real action and observed condition UUID")
    var before:Dictionary=Actions.inputs(action,binding,phase,graph,[action,remove,apply])
    check(before.values.is_empty() and "native_owner_projection_removal_not_observed" in before.gaps,"An earlier removal cannot close a newly reapplied equal UUID")
    graph.condition_cues["31"].append({"phase":"removal","actor_uuid":"actor","condition":owner})
    var transient:Dictionary=Actions.inputs(action,binding,phase,graph,[action,apply])
    check(transient.gaps.is_empty() and transient.values.owner_projection.removed_seconds==0.0,"A same-occurrence ordered transient application/removal retains its zero-duration lifetime")

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
    authored();observations()
    print(JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
