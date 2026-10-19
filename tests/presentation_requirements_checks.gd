extends SceneTree
## Expected operations are independent of compiled output and replay inventory.
const Requirements=preload("res://presentation/requirements.gd")
const Audit=preload("res://studio/authoring_audit.gd")
const Trace=preload("res://presentation/event_trace.gd")
const Authoring=preload("res://presentation/authoring.gd")
var checks=0
var failures:Array=[]
var cache={}
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("REQUIREMENT_FAIL ",label)
func trace(fact:Dictionary,recipe:Dictionary,components:Array=[],canceled:bool=false)->Dictionary:
    var node={"uuid":"event","lineage_uuid":"lineage","parent_event":null,"parent_lineage":null,"fact":fact,"canceled":canceled,"combat_log":null,"children_lineages":[]}
    var group={"operation_sequence":1,"id":"group","duration_ms":100.0,"actor_tracks":[],"components":components,"commits":[{"event_uuid":"event","at_ms":50.0}]}
    var graph={"starts":{"event":0.0},"ends":{"event":100.0},"actor_inputs":{"event":{"actor":{"uuid":"actor","last_visual_position":[0,0]}}},"recipes":{"event":recipe}}
    return Trace.compile_rows({"events":[node],"version_rows":[{"event_uuid":"event","lineage_uuid":"lineage","source_index":1}]},group,graph,cache)[0]
func _initialize()->void:
    var report=Audit.build(cache)
    var index={}
    for entry in report.entries:index[entry.id]=entry
    var schema:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Requirements.SCHEMA))
    var kinds:Dictionary=schema["$defs"].PlayerNode.properties.fact.anyOf[0].discriminator.mapping
    for kind in kinds:
        check(index.has("fact:"+kind),"Current wire discriminator has a presentation owner: "+kind)
    check(Requirements.fact("future_visual_fact").gap_kind=="unassessed","An unknown future fact cannot silently become state-only")
    check(Requirements.fact("item_charge").gap_kind=="explicit_none","Explicit reducer-only item accounting stays nonvisual")
    check(Requirements.fact("sensory").gap_kind=="explicit_none","Sensory publication does not invent independent effects or duplicate light lanes")
    var inspection:Dictionary=Authoring.Catalog.environment_index(cache).inspection
    for kind in ["world_animation","portal","device"]:
        check(not inspection[kind].is_empty(),"The environment build lists its "+kind+" owners")
        for id in inspection[kind]:check(index.has(kind+":"+id),"Selected owner remains visible without a recorded occurrence: "+kind+":"+id)
    for pair in [["catalog/rigs.json","rig"],["catalog/creature_rigs.json","creature_rig"],["catalog/action_materials.json","action_material"],["catalog/action_intakes.json","action_intake"],["catalog/body_materials.json","body_material"],["catalog/item_attachments.json","item_attachment"]]:
        var source:Dictionary=Authoring.load_data(pair[0],cache)
        for id in source:check(index.has(pair[1]+":"+id),"Selected owner remains visible without a recorded occurrence: "+pair[1]+":"+id)
    var blight:Dictionary=Authoring.load_data("spells/spell.blight.json",cache)
    var before=blight.duplicate(true)
    var event={"kind":"spell","behavior_id":"spell.blight","source_entity_uuid":"actor","application":null}
    var pending=trace(event,blight)
    var materials=pending.components.filter(func(c):return c.kind=="bodyMaterials")
    check(not materials.is_empty(),"Actual authored Blight material is required even with zero compiled components")
    if not materials.is_empty():
        check(materials[0].source=="spells/spell.blight.json:/bodyMaterials/0" and materials[0].gap_kind=="unassessed" and materials[0].renderer_support=="missing","Conditional material names the missing renderer separately from unassessed occurrence applicability")
        check(not materials[0].timing.resolved and materials[0].trace_track_id.is_empty(),"Missing material has no invented duration or rendered evidence")
        check(materials.size()==2 and materials[0].outcome_selectors.requiredSaveSuccess==false and materials[1].outcome_selectors.requiredSaveSuccess==true and materials.all(func(c):return c.applicability=="unassessed"),"Mutually exclusive save variants remain conditional instead of both claiming execution")
    var fireball:Dictionary=Authoring.load_data("spells/spell.fireball.json",cache)
    check(Requirements.recipe(fireball,"spells/spell.fireball.json:").any(func(r):return r.kind=="area_geometry" and r.status=="explicit_none"),"Explicitly disabled original area geometry is not reported as required rendering")
    var fireball_requirements=Requirements.recipe(fireball,"spells/spell.fireball.json:")
    check(fireball_requirements.any(func(r):return r.kind=="damage_clock" and r.implementation=="implemented" and r.disposition=="parent_owned"),"Existing damage callback overrides remain their actual child's owner, not a second spell effect")
    check(fireball_requirements.any(func(r):return r.kind=="damage_number" and r.source=="spells/spell.fireball.json:/damage/floatingNumber" and r.gap_kind=="unassessed"),"A generic damage number does not certify all authored per-spell options")
    check(Requirements.recipe(blight,"spells/spell.blight.json:").any(func(r):return r.kind=="contact_policy" and r.gap_kind=="unassessed"),"Authored non-projectile contact policy is not silently omitted")
    var mechanism_event=trace({"kind":"mechanism_activation","mechanism_content_id":"spatial_effect.environment.dart_launcher","committed":true},{})
    check(mechanism_event.components.any(func(c):return c.kind=="world_animation" and c.gap_kind=="renderer" and c.implementation=="missing"),"Static final sprites do not certify a selected finite dart-launcher sequence")
    var unrelated={"id":"cast","kind":"native_effect","source_event_uuid":"event","start_ms":0.0,"duration_ms":100.0,"status":"available","source":"unrelated","source_id":"class.martial.burst"}
    check(trace(event,blight,[unrelated]).components.any(func(c):return c.kind=="bodyMaterials" and c.status=="missing"),"A compiled sibling does not erase an unimplemented material operation")
    check(trace(event,blight,[],true).components.is_empty(),"Canceled event produces no executed missing-component demand")
    check(blight==before,"Expectation projection never mutates admitted authoring")
    var equipment=trace({"kind":"equipment","source_entity_uuid":"actor"},{})
    var appearance=equipment.components.filter(func(c):return c.kind=="fact:equipment")
    check(appearance.size()==1 and appearance[0].gap_kind=="inspection" and appearance[0].implementation=="implemented","Equipment appearance is an inspection gap, not an invented missing renderer")
    var portal=trace({"kind":"portal_transfer","portal_content_id":"spatial_effect.environment.portal","committed":true},{})
    check(portal.components.any(func(c):return c.source=="authoring/environment/surfaces/spatial_effect.environment.portal.tres"),"Actual portal identity resolves its selected owner source")
    check(not "state_only_no_animation_claim" in portal.reasons,"Portal transfer no longer silently falls through as nonvisual")
    var feast_id="action.environment.heroes_feast.eat"
    var feast=trace({"kind":"action","behavior_id":feast_id,"source_entity_uuid":"actor"},Authoring.load_data("catalog/body_action_recipes.json",cache).get(feast_id,{}))
    check(feast.components.any(func(c):return c.kind=="action_material" and c.source=="catalog/action_materials.json:/"+feast_id),"Actual action-owned finite material is projected without an asset ID")
    check(feast.components.any(func(c):return c.kind=="action_intake" and c.source=="catalog/action_intakes.json:/"+feast_id),"Actual action-owned intake is projected without an emitted component")
    var bone=trace({"kind":"damage","stage":"applied","applied_damage":2,"target_entity_uuid":"actor","body_release":{"release_id":"body.bone"}},{})
    check(bone.components.any(func(c):return c.kind=="body_release" and c.source=="catalog/body_release_media.json:/body.bone"),"Blood implementation cannot hide another authoritative release family")
    var destroyed=trace({"kind":"object_destroyed","item_id":"environment.storage_chest"},{})
    check(destroyed.components.any(func(c):return c.source=="authoring/environment/objects/environment.storage_chest.tres" and c.gap_kind=="inspection"),"Working object endpoint keeps exact authored transition inspection gap")
    for path in ["spells/spell.blight.json","spells/spell.chain_lightning.json","spells/spell.disintegrate.json","spells/spell.true_strike.json"]:
        var recipe:Dictionary=Authoring.load_data(path,cache)
        var expectations=Requirements.recipe(recipe,path+":",["spell"],cache)
        var mechanism={"spells/spell.blight.json":"bodyMaterials","spells/spell.chain_lightning.json":"arcs","spells/spell.disintegrate.json":"directed","spells/spell.true_strike.json":"childAttack"}[path]
        check(expectations.any(func(item):return item.kind==mechanism and item.gap_kind=="renderer"),"Pygame operation is retained independently of sprite IDs: "+mechanism)
    var disabled=Requirements.recipe({"cast":{"enabled":false,"equipment":{"kind":"hidden"},"recovery":{"enabled":true}}},"typed:")
    check(disabled.is_empty(),"Disabled cast does not demand its inactive equipment or recovery")
    check(trace(event,{"cast":{"enabled":false,"aura":{"id":"inactive","enabled":true}}}).components.is_empty(),"Explicitly disabled cast does not produce an occurrence body or hand-layer failure")
    check(trace({"kind":"action","behavior_id":"action.unassigned","source_entity_uuid":"actor"},{}).components.any(func(c):return c.kind=="recipe" and c.gap_kind=="unassessed"),"Missing action ownership is explicit instead of implicitly nonvisual")
    for id in Requirements.ACCEPTED_ACTION_STRIPS:
        var potion:Dictionary=Authoring.load_data("catalog/body_action_recipes.json",cache)[id]
        var receipt=trace({"kind":"action","behavior_id":id,"source_entity_uuid":"actor"},potion)
        check(not receipt.components.any(func(c):return c.kind=="media" and ".actor.media" in c.source),"Original accepted strip omission does not become a renderer failure: "+id)
        check(Requirements.recipe(potion,"catalog/body_action_recipes.json:/"+id).any(func(c):return c.get("disposition")=="accepted_omission"),"Original omission remains inspectable separately from state-only: "+id)
    var result={"checks":checks,"failures":failures,"fact_kinds":kinds.size(),"inventory_totals":report.totals,"scope":"Pure source/occurrence requirement projection, not rendering or timing qualification."}
    FileAccess.open("res://generated/presentation_requirements_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("PRESENTATION_REQUIREMENTS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
