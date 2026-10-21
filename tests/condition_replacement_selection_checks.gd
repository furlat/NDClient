extends SceneTree
## Selector/lifecycle contract controls using the actual sealed package. No
## manufactured server recording, native construction or visual approval.
const Persistent=preload("res://presentation/native_persistent.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Coverage=preload("res://presentation/condition_coverage.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Authoring=preload("res://presentation/authoring.gd")
var checks:int=0
var failures:Array=[]
var conditional_keys:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("CONDITION_REPLACEMENT_FAIL "+label)
func recipe()->Dictionary:
    return {"disposition":"authored","application":{"effects":[{"id":"entry","assetId":"legacy-entry"}]},
        "removal":{"effects":[{"id":"exit","assetId":"legacy-exit"}]},
        "persistent":{"layers":[{"id":"body","assetId":"legacy-body","attachment":"body","priority":0},
            {"id":"marker","assetId":"legacy-marker","attachment":"head","markerGroup":"legacy-marker","priority":0}]}}
func matching(rows:Array,id:String,state:Variant)->Array:
    var selected:Array=[]
    for row in rows:
        var declared:Dictionary=row.get("condition",{})
        if id not in declared.get("owner_ids",[]):continue
        var matches:bool=true
        for field in declared.get("when",{}):
            if state==null or not state.has(field) or state[field]!=declared.when[field]:matches=false
        if matches:selected.append(row)
    return selected
func expected_replacement(selected:Array)->Array:
    var result:Array=[]
    if selected.is_empty():return result
    if selected.any(func(row):return row.condition.get("body_channel_included",false)):result.append("legacy-body")
    if selected.any(func(row):return not row.condition.get("marker",{}).is_empty()):result.append("legacy-marker")
    result.append_array(["legacy-entry","legacy-exit"])
    return result
func inspect(rows:Array,id:String,state:Variant,cache:Dictionary,label:String)->void:
    var condition:Dictionary={"condition_uuid":"selector-contract-owner","behavior_id":id,"state":state}
    var original:PackedByteArray=var_to_bytes(condition)
    var config:Dictionary=recipe()
    var held:PackedByteArray=var_to_bytes(config)
    # Package predicates remain independent controls; explicit client owner
    # policy may delegate a declared event/weapon alternative rather than play
    # an idle lifecycle. This is not a predicate match failure.
    var admitted:Array=Effects.conditions(id).map(func(row):return row.key)
    var expected:Array=matching(rows,id,state).filter(func(row):return row.key in admitted)
    var actual:Array=Persistent.lifecycles(condition)
    check(actual.map(func(row):return row.key)==expected.map(func(row):return row.key),label+": exact package predicates select source identity")
    check(Persistent.replaced_media(condition,config)==expected_replacement(expected),label+": only selected body/marker/phases replace media")
    var common:Dictionary={"id":"condition:selector-contract-owner","condition_uuid":condition.condition_uuid,"actor_uuid":"contract-actor",
        "condition":condition,"recipe":config,"start_ms":100.0,"absolute_start_ms":100.0,"duration_ms":1000.0,"age_ms":0.0,"removal_age_ms":null,"initial":false}
    var samples:Array=Persistent.lifecycle_samples(common,actual,cache)
    check(samples.map(func(row):return row.source_id)==expected.map(func(row):return row.key),label+": sample/preparation set agrees with replacement selection")
    for sample in samples:
        check(sample.condition==condition and sample.condition_uuid==condition.condition_uuid and sample.start_ms==100.0,label+": exact disclosed owner identity and clock retained")
        check(sample.lifecycle_phases.application==Effects.clip(sample.native_clip.id),label+": actual selected package clip retained")
        check(Persistent.lifecycle_state(sample,0.0).phase=="application" and Persistent.lifecycle_state(sample,1.0).phase=="removal",label+": actual owner start/removal owns phases")
    check(var_to_bytes(condition)==original and var_to_bytes(config)==held,label+": selection leaves source and condition immutable")
func fallback_contract(rows:Array)->void:
    var id:String="condition.spell.protection_from_energy"
    var config:Dictionary=recipe()
    # Explicit old-media metadata controls exercise the existing sample path;
    # they are not substitute artwork and are never constructed or drawn.
    var cache:Dictionary={"catalog/condition_recipes.json":{id:config},"catalog/condition_media.json":{
        "legacy-body":{"removal_fade_ms":311.0},"legacy-marker":{"removal_fade_ms":311.0}},
        "native_effects/index.json":{"sources":{"legacy-body-control":{"media_ids":["legacy-body"],"duration":.5,"preload_paths":[]},
            "legacy-marker-control":{"media_ids":["legacy-marker"],"duration":.5,"preload_paths":[]}},"spells":{}}}
    var unknown:Dictionary={"condition_uuid":"same-owner","behavior_id":id,"state":{"energy_type":null}}
    var fire:Dictionary={"condition_uuid":"same-owner","behavior_id":id,"state":{"energy_type":"Fire"}}
    var owner:Dictionary={"id":"same-owner","actor_uuid":"contract-actor","condition":unknown,"initial":false,"start_ms":100.0,"end_ms":INF,"life_state":"alive"}
    var before:PackedByteArray=var_to_bytes(owner)
    var retained:Array=Conditions.samples({owner.id:owner},150.0,cache,{},false)
    check(retained.filter(func(row):return row.has("layer")).map(func(row):return row.layer.assetId)==["legacy-body","legacy-marker"],"Unknown public selector retains the available legacy body and marker")
    check(retained.filter(func(row):return row.has("lifecycle_phases")).is_empty(),"Unknown selector cannot claim a selected native lifecycle")
    check(Conditions.fade_ms(unknown,cache)==311.0,"Retained old-media removal fade remains part of owner readiness")
    var prepared:Array=Conditions.native_samples({owner.id:owner},150.0,cache,true)
    check(prepared.filter(func(row):return row.has("layer")).map(func(row):return row.layer.assetId)==["legacy-body","legacy-marker"],"Preparation includes the same retained old sources as display")
    owner=owner.duplicate();owner.condition=fire
    var selected:Array=Conditions.samples({owner.id:owner},150.0,cache,{},false)
    var wanted:Array=matching(rows,id,fire.state)
    check(not wanted.is_empty() and selected.filter(func(row):return row.has("lifecycle_phases")).map(func(row):return row.lifecycle_key)==wanted.map(func(row):return row.key),"Actual disclosed Fire selector selects its exact lifecycle")
    check(selected.filter(func(row):return row.has("layer")).map(func(row):return row.layer.assetId)==["legacy-marker"],"Selected Fire body replaces only the body, preserving unrelated marker")
    var fire_prepared:Array=Conditions.native_samples({owner.id:owner},150.0,cache,true)
    check(fire_prepared.map(func(row):return row.id)==selected.filter(func(row):return row.kind=="native_effect").map(func(row):return row.id),"Native preparation and displayed source membership agree after actual selector change")
    owner=owner.duplicate();owner.condition=unknown
    check(Conditions.samples({owner.id:owner},150.0,cache,{},false).filter(func(row):return row.has("layer")).size()==2,"A later undisclosed selector restores retained media without cached family-wide retirement")
    check(var_to_bytes({"id":"same-owner","actor_uuid":"contract-actor","condition":unknown,"initial":false,"start_ms":100.0,"end_ms":INF,"life_state":"alive"})==before,"Selection never mutates the original owner cut")
    var report:Dictionary=Coverage.build(cache,[],{id:true})
    check(report.entries.size()==1,"Static inventory retains the exact condition denominator")
    if not report.entries.is_empty():
        var required:Array=report.entries[0].requirements
        for asset in ["legacy-entry","legacy-exit","legacy-body","legacy-marker"]:
            check(required.any(func(row):return row.get("asset_id")==asset),"Static unknown-state coverage cannot erase conditional media: "+asset)
        check(required.filter(func(row):return str(row.mechanism).begins_with("native:")).size()==Effects.conditions(id).size(),"All conditional native sources remain separately inventoried, not claimed selected/rendered")
    var declared:Dictionary=config.duplicate(true)
    declared.persistent.nativeEffects=[{"replaces_media":["explicit-old-layer"]}]
    check(Persistent.replaced_media(unknown,declared)==["explicit-old-layer"],"Explicit typed-hold replacement remains independent of unmatched package variants")
    check(Persistent.replaced_media({"behavior_id":"condition.test.no_package"},declared)==["explicit-old-layer"],"Unrelated phase media survives an explicit hold with no package lifecycle")
    var owners:Dictionary={}
    Conditions.observe(owners,{"contract-actor":{"life_state":"alive","conditions":[unknown]}},100.0)
    var reapplied:Dictionary=fire.duplicate();reapplied.condition_uuid="reapplied-owner"
    var changes:Array=[{"actor_uuid":"contract-actor","before":unknown,"after":null,"row":{"field":"condition"}},
        {"actor_uuid":"contract-actor","before":null,"after":reapplied,"row":{"field":"condition"}}]
    Conditions.observe(owners,{"contract-actor":{"life_state":"alive","conditions":[reapplied]}},250.0,false,changes)
    check(owners[unknown.condition_uuid].end_ms==250.0 and owners[unknown.condition_uuid].condition==unknown,"Ordered removal retains that original owner's undisclosed selector cut")
    check(owners[reapplied.condition_uuid].start_ms==250.0 and owners[reapplied.condition_uuid].condition==reapplied,"Ordered reapplication has its own actual member and new owner clock")
    check(Persistent.replaced_media(owners[unknown.condition_uuid].condition,config).is_empty() and Persistent.replaced_media(owners[reapplied.condition_uuid].condition,config)==["legacy-body","legacy-entry","legacy-exit"],"Removed and reapplied instances use their own selectors at the same boundary")
    Conditions.samples(owners,300.0,cache,{},false)
    check(owners.has(unknown.condition_uuid),"Retained removal media survives through its actual authored fade")
    Conditions.samples(owners,562.0,cache,{},false)
    check(not owners.has(unknown.condition_uuid) and owners.has(reapplied.condition_uuid),"Expiry retires only the removed old owner, preserving the selected reapplication")
func run()->void:
    var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/index.json"))
    var rows:Array=original.selections
    var cache:Dictionary={}
    var seen:Dictionary={}
    for selection in rows:
        var declared:Dictionary=selection.get("condition",{})
        if declared.get("when",{}).is_empty():continue
        conditional_keys.append(selection.key)
        for id in declared.owner_ids:
            var label:String=str(id)+"/"+str(selection.key)
            inspect(rows,id,declared.when,cache,label+"/match")
            if not seen.has(id):
                seen[id]=true
                inspect(rows,id,null,cache,label+"/null-state")
                inspect(rows,id,{},cache,label+"/missing-fields")
            for field in declared.when:
                var absent:Dictionary=declared.when.duplicate();absent.erase(field)
                inspect(rows,id,absent,cache,label+"/missing-"+field)
                var nulled:Dictionary=declared.when.duplicate();nulled[field]=null
                inspect(rows,id,nulled,cache,label+"/null-"+field)
                var mismatch:Dictionary=declared.when.duplicate();mismatch[field]="explicit-mismatch-control"
                inspect(rows,id,mismatch,cache,label+"/different-"+field)
    check(not conditional_keys.is_empty(),"Actual installed package supplies conditional lifecycle cases")
    fallback_contract(rows)
    var report:Dictionary={"checks":checks,"failures":failures,"conditional_selections":conditional_keys,"families":seen.keys(),
        "scope":"Actual sealed condition predicates; source selection, media replacement, preparation/display membership and static coverage. Explicit value-contract controls, no fabricated recording/native output or visual-approval claim."}
    FileAccess.open("res://generated/condition_replacement_selection_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CONDITION_REPLACEMENT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
