extends SceneTree
## Expected operations are independent of compiled output and replay inventory.
const Requirements=preload("res://presentation/requirements.gd")
const Audit=preload("res://studio/authoring_audit.gd")
const Trace=preload("res://presentation/event_trace.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Context=preload("res://presentation/source/abilities/context.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
var checks=0
var failures:Array=[]
var cache={}
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("REQUIREMENT_FAIL ",label)
func trace(fact:Dictionary,recipe:Dictionary,components:Array=[],canceled:bool=false)->Dictionary:
    var node={"id":"1","lineage_id":"1","parent_event":null,"parent_lineage":null,"fact":fact,"canceled":canceled,"combat_log":null,"children_lineages":[]}
    var group={"operation_sequence":1,"id":"group","duration_ms":100.0,"actor_tracks":[],"components":components,"commits":[{"event_uuid":"1","at_ms":50.0}]}
    var graph={"starts":{"1":0.0},"ends":{"1":100.0},"actor_inputs":{"1":{"actor":{"uuid":"actor","last_visual_position":[0,0]}}},"recipes":{"1":recipe},"condition_cues":{}}
    return Trace.compile_rows({"events":[node],"version_rows":{"occurrences":[1],"lineages":[1]}},group,graph,cache)[0]
func context_policies()->void:
    for pair in [["death","silhouetteDust"],["movement_reaction","movementLeadInMs"]]:
        var resource:String="res://authoring/abilities/contexts/"+str(pair[0])+".tres"
        var entry:Resource=load(resource)
        var document:Dictionary=Records.context_document(entry,str(pair[0]))
        var field:String=str(pair[1])
        check(document.inactiveLegacyFields==[field] and document[field]==entry.unported[field],"Inactive Context choice retains exact original field/value: "+field)
        var imported:Resource=Context.new();Records.context_from(imported,str(pair[0]),document)
        var rebuilt:Dictionary=Records.context_document(imported,str(pair[0]))
        check(rebuilt.inactiveLegacyFields==document.inactiveLegacyFields and rebuilt[field]==document[field],"Context import/export preserves inactive policy and raw values: "+field)
        var rows:Array=Requirements.context(document,"catalog/"+str(pair[0])+"_context.json:",str(pair[0])+"_context")
        var references:Array=rows.filter(func(row):return row.get("legacy_field")==field)
        check(references.size()==1 and references[0].disposition=="inactive_reference" and references[0].status=="explicit_none" \
            and references[0].source==resource+"::unported/"+field and references[0].authored_value==document[field] and not references[0].rendered,
            "Inactive reference remains exact source inspection, not source parity or output: "+field)
        var valid:Dictionary=Build.Common.report();Build._check_context_inactive_fields(entry,"control",valid)
        check(valid.errors.is_empty(),"Exact declared legacy field is admitted: "+field)
        var invalid:Resource=entry.duplicate(true);invalid.inactive_legacy_fields=PackedStringArray([field,"absent_field",field+"/nested",field])
        var invalid_report:Dictionary=Build.Common.report();Build._check_context_inactive_fields(invalid,"control",invalid_report)
        check(invalid_report.errors.size()==3,"Unknown, nested and duplicate inactive fields cannot disable other presentation: "+field)
    var saved:Variant=cache.get("catalog/death_context.json")
    var death:Dictionary=Records.context_document(load("res://authoring/abilities/contexts/death.tres"),"death")
    cache["catalog/death_context.json"]=death
    var life:Dictionary={"kind":"life","entity_uuid":"actor","new_state":"dead","previous_state":"alive","remains_disposition":"disintegrated"}
    var life_row:Dictionary=trace(life,{})
    check(not life_row.components.any(func(component):return component.kind=="death_dust") and life_row.inactive_legacy_fields.size()==1,
        "Actual disintegrated Life exposes the selected inactive dust reference without demanding particles")
    var active:Dictionary=death.duplicate(true);active.erase("inactiveLegacyFields");cache["catalog/death_context.json"]=active
    check(trace(life,{}).components.any(func(component):return component.kind=="death_dust" and component.status=="missing"),
        "Absent explicit disposition still reports the real authored dust consumer gap")
    var reaction:Resource=load("res://authoring/abilities/contexts/movement_reaction.tres")
    var unsupported:Resource=reaction.duplicate(true);unsupported.inactive_legacy_fields=PackedStringArray(["recovery"])
    var unsupported_report:Dictionary=Build.Common.report();Build._check_context_inactive_fields(unsupported,"control",unsupported_report)
    check(unsupported_report.errors.size()==1,"An existing unrelated raw field cannot silently become an inactive reference")
    if saved==null:cache.erase("catalog/death_context.json")
    else:cache["catalog/death_context.json"]=saved

func _initialize()->void:
    context_policies()
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
    var environment:Dictionary=Authoring.Catalog.environment_index(cache)
    var inspection:Dictionary=environment.inspection
    for kind in ["world_animation","portal","device"]:
        check(not inspection[kind].is_empty(),"The environment build lists its "+kind+" owners")
        for id in inspection[kind]:
            var program:Dictionary=environment.get("spatial_media",{}).get(id,{})
            var active:bool=kind in ["world_animation","portal"] and program.get("native_world_media",false)
            var identity:String=("spatial_media" if active else kind)+":"+id
            check(index.has(identity),"Selected owner remains visible without a recorded occurrence: "+identity)
            if active and index.has(identity):
                var methods:Array=index[identity].requirements.filter(func(row):return row.get("kind","")==kind)
                check(methods.size()==1,"Active source has exactly one classified method among its separate authoring fields: "+identity)
                if methods.size()==1:
                    check(methods[0].source==program.source and methods[0].implementation=="implemented" \
                        and methods[0].status=="unexercised" and not methods[0].rendered,
                        "Active source retains exact method ownership without a render claim: "+identity)
    for pair in [["catalog/action_materials.json","action_material"],["catalog/action_intakes.json","action_intake"],["catalog/body_materials.json","body_material"],["catalog/item_attachments.json","item_attachment"]]:
        var source:Dictionary=Authoring.load_data(pair[0],cache)
        for id in source:check(index.has(pair[1]+":"+id),"Selected owner remains visible without a recorded occurrence: "+pair[1]+":"+id)
    var characters=load("res://authoring/characters.tres")
    for section in [["rigs","rig"],["characters","creature_rig"]]:
        for id in characters.sections[section[0]]:check(index.has(section[1]+":"+id),"Typed character owner remains visible without a recording: "+id)
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
    check(fireball_requirements.any(func(r):return r.kind=="damage_number" \
        and r.source=="res://authoring/abilities/spells/spell.fireball.tres::unported/damage/floatingNumber" \
        and r.legacy_source=="spells/spell.fireball.json:/damage/floatingNumber" \
        and r.implementation=="implemented" and r.disposition=="parent_owned" and r.authored_policy==fireball.damage.floatingNumber and not r.rendered),
        "Shared damage number support exposes its exact parent policy without claiming recorded output")
    check(fireball_requirements.any(func(r):return r.kind=="damage_death" and r.execution_owner=="fact:life" and r.unused_legacy_fields==["frame"]),
        "Legacy death frame remains inspectable unused metadata beside the actual Life owner, never a new delay")
    check(Requirements.recipe(blight,"spells/spell.blight.json:").any(func(r):return r.kind=="contact_policy" and r.gap_kind=="unassessed"),"Authored non-projectile contact policy is not silently omitted")
    var source_materials:Array=Requirements.recipe(blight,"spells/spell.blight.json:").filter(func(r):return r.kind=="bodyMaterials")
    check(source_materials.size()==2 and source_materials[0].source=="spells/spell.blight.json:/bodyMaterials/0" \
        and source_materials[1].source=="spells/spell.blight.json:/bodyMaterials/1" \
        and source_materials[0].id!=source_materials[1].id and blight==before,
        "Fresh typed body provenance preserves both independent raw material owners and immutable recipe values")
    var mechanism_fact={"kind":"mechanism_activation","mechanism_content_id":"spatial_effect.environment.dart_launcher","committed":true}
    var mechanism_requirements:Array=Requirements.occurrence(mechanism_fact,{},"",cache)
    var mechanism_program:Dictionary=environment.spatial_media[mechanism_fact.mechanism_content_id]
    check(mechanism_requirements.any(func(c):return c.kind=="world_animation" and c.source==mechanism_program.source \
        and c.implementation=="implemented" and c.methods.finite_activation=="implemented" and not c.rendered \
        and not c.timing.resolved and c.availability=="not_examined"),"Actual mechanism identity resolves its finite authored program without inventing placement, time or pixels")
    check(not Requirements.occurrence({"kind":"mechanism_activation","mechanism_content_id":mechanism_fact.mechanism_content_id,"committed":false},{},"",cache).any(func(c):return c.kind=="world_animation"),"Uncommitted activation does not demand an executed finite program")
    check(Requirements.owner("world_animation","unbound","typed:unbound",{}).implementation=="missing","A final sprite without an admitted source program still cannot certify finite animation")
    var unrelated={"id":"cast","kind":"native_effect","source_event_uuid":"1","start_ms":0.0,"duration_ms":100.0,"status":"available","source":"unrelated","source_id":"class.martial.burst"}
    check(trace(event,blight,[unrelated]).components.any(func(c):return c.kind=="bodyMaterials" and c.status=="missing"),"A compiled sibling does not erase an unimplemented material operation")
    check(trace(event,blight,[],true).components.is_empty(),"Canceled event produces no executed missing-component demand")
    check(blight==before,"Expectation projection never mutates admitted authoring")
    var equipment=trace({"kind":"equipment","source_entity_uuid":"actor"},{})
    var appearance=equipment.components.filter(func(c):return c.kind=="fact:equipment")
    check(appearance.size()==1 and appearance[0].gap_kind=="inspection" and appearance[0].implementation=="implemented","Equipment appearance is an inspection gap, not an invented missing renderer")
    var portal_fact={"kind":"portal_transfer","portal_content_id":"spatial_effect.environment.portal","committed":true}
    var portal=trace(portal_fact,{})
    var portal_program:Dictionary=environment.spatial_media[portal_fact.portal_content_id]
    check(Requirements.occurrence(portal_fact,{},"",cache).any(func(c):return c.kind=="portal" and c.source==portal_program.source \
        and c.implementation=="implemented" and c.methods.portal_transfer=="implemented" and c.methods.actor_aperture=="implemented" \
        and not c.rendered and not c.timing.resolved),"Actual portal identity resolves its exact authored owner method without an output claim")
    check(not "state_only_no_animation_claim" in portal.reasons,"Portal transfer no longer silently falls through as nonvisual")
    var feast_id="action.environment.heroes_feast.eat"
    var feast=trace({"kind":"action","behavior_id":feast_id,"source_entity_uuid":"actor"},Authoring.load_data("catalog/body_action_recipes.json",cache).get(feast_id,{}))
    var feast_binding:Dictionary=Authoring.load_data("catalog/body_action_bindings.json",cache)[feast_id]
    var feast_uses:Array=feast_binding.effect_cues
    check(feast_uses.size()==1 and feast_uses[0].clip=="native/feast/consume" and feast_uses[0].at=="body.effect", "Actual Eat action owns its finite native use on the authored body marker")
    var feast_methods:Array=index[feast_id].requirements.filter(func(row):return row.get("kind","")=="native_effect")
    check(feast_methods.size()==1,"Eat action exposes exactly its one selected native use among separate authoring fields")
    if feast_uses.size()==1 and feast_methods.size()==1:
        var pointer:String=str(feast_uses[0].get("source",str(feast_binding.source)+"/"+str(feast_uses[0].source_index)))
        check(pointer=="res://authoring/abilities/actions/action.environment.heroes_feast.eat.tres::effects/0" \
            and feast_methods[0].source==pointer and feast_methods[0].authored_use==feast_uses[0] \
            and feast_methods[0].implementation=="implemented" and not feast_methods[0].rendered,"Native action source is independently inspectable without an emitted component")
    check(not Authoring.load_data("catalog/action_materials.json",cache).has(feast_id) \
        and not Authoring.load_data("catalog/action_intakes.json",cache).has(feast_id) \
        and not feast.components.any(func(c):return c.kind in ["action_material","action_intake"]),"Retired Feast side sheets do not demand duplicate material or intake effects")
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
