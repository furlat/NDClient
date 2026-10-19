extends SceneTree
## Offline worklist output against real definitions and current authored JSON.
const Audit=preload("res://studio/authoring_audit.gd")
const Authoring=preload("res://presentation/authoring.gd")
var failures:Array=[]
var checks=0
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("AUTHORING_AUDIT_FAIL ",label)
func _initialize()->void:
    var cache={}
    var started=Time.get_ticks_usec()
    var report=Audit.build(cache)
    var elapsed=(Time.get_ticks_usec()-started)/1000.0
    var by_id={}
    for entry in report.entries:
        check(not by_id.has(entry.id),"One worklist owner per capability: "+entry.id)
        by_id[entry.id]=entry
        var ids={}
        for row in entry.requirements:
            check(not ids.has(row.id),"Distinct authored field: "+row.source)
            ids[row.id]=true
            check(not row.rendered and not row.source.is_empty() and not row.next_step.is_empty(),"Assignment is actionable without a false rendering witness")
    check(report.totals.backend_definitions==347,"Current backend definition denominator is independent of replay cases")
    check(by_id.has("spell.aegis_spark") and by_id["spell.aegis_spark"].requirements.any(func(row):return row.gap_kind=="authoring_review" and row.source=="res://authoring/abilities/spells/spell.aegis_spark.tres::status"),"An actual typed stand-in remains visible for review alongside its authored body")
    var absent:Dictionary=cache.duplicate();absent["spells/spell.aegis_spark.json"]={}
    var missing:Dictionary=Audit.build(absent).entries.filter(func(entry):return entry.id=="spell.aegis_spark")[0]
    check(missing.requirements.any(func(row):return row.label=="No spell presentation assignment" and row.gap_kind=="authoring_review" and not row.rendered),"A missing spell draft remains visible although it references no media")
    check(by_id.has("action.environment.storage_chest.loot") and by_id["action.environment.storage_chest.loot"].requirements[0].gap_kind=="authoring_review","New backend action without a selected recipe remains in the authoring worklist")
    check(by_id["action.move"].requirements.any(func(row):return row.gap_kind=="unexercised") and by_id["action.move"].source=="catalog/movement_context.json:/walkClip","Existing shared movement context is not reported as an absent action recipe")
    check(not by_id.has("condition.hidden"),"Existing condition lifecycle inventory retains ownership, avoiding duplicate recipe reports")
    check(by_id.has("condition.consumable.weapon_coat.basic_poison"),"Unassigned backend condition appears without a fake authored condition")
    var missile:Dictionary=by_id["spell.magic_missile"]
    check(missile.requirements.any(func(row):return row.source=="spells/spell.magic_missile.json:/projectile/impact/assetId" and row.gap_kind=="unexercised"),"Authored impact selection is separately visible from native/source/renderer qualification")
    check(missile.requirements.any(func(row):return row.source=="spells/spell.magic_missile.json:/projectile/prepare" and row.gap_kind=="explicit_none"),"Explicitly disabled prepare phase is not an invented missing effect")
    check(by_id["spell.fog_cloud"].requirements.any(func(row):return row.source=="spells/spell.fog_cloud.json:/cast/actionClip" and row.gap_kind=="unexercised"),"Active Fog Cloud casting is visible even with recovery explicitly disabled")
    var hide:Dictionary=by_id["action.hide"]
    check(hide.requirements.any(func(row):return row.source=="catalog/body_action_recipes.json:/action.hide/previewChildCueKinds/0" and row.gap_kind=="unexercised"),"Native Hide preserves the inherited child condition's actual JSON provenance")
    check(hide.source=="res://authoring/abilities/actions/action.hide.tres" and hide.legacy_source=="catalog/body_action_recipes.json:/action.hide","Worklist identifies selected native action and preserved migration reference")
    check(hide.requirements.any(func(row):return row.source=="res://authoring/abilities/actions/action.hide.tres::body/clip" and row.legacy_source=="catalog/body_action_recipes.json:/action.hide/actor/clip"),"Body assignment points to the editable native property")
    check(hide.requirements.any(func(row):return row.source=="res://authoring/abilities/actions/action.hide.tres::sounds/0/cue" and row.label=="Effect audio cue: hide_transition"),"Audio assignment remains distinct from selected sound media and audible qualification")
    var aliases=Authoring.load_data("catalog/body_action_bindings.json",cache)
    var actions=Authoring.load_data("catalog/body_action_recipes.json",cache)
    for id in aliases:
        var source_id:String=aliases[id].get("source_recipe",id)
        if not actions.has(source_id):continue
        var before=actions[source_id].duplicate(true)
        var selected=Authoring.action({"kind":"action","behavior_id":id},cache)
        check(Authoring.recipe_source(selected,"actor/clip",cache)==Authoring.Catalog.source_pointer("catalog/body_action_recipes.json",source_id+"/actor/clip",cache),"Selected alias preserves its actual source recipe: "+id)
        check(actions[source_id]==before,"Adding selected-recipe provenance does not mutate cached source: "+id)
    var shoves=Authoring.load_data("catalog/shove_recipes.json",cache)
    for id in shoves:
        var selected=Authoring.action({"kind":"shove","behavior_id":id},cache)
        check(Authoring.recipe_source(selected,"actor/clip",cache)=="catalog/shove_recipes.json:/"+id+"/actor/clip","Shove source points to its actual catalog: "+id)
    var reaction:Dictionary=by_id["context:interruptions"]
    check(reaction.requirements.any(func(row):return row.source=="catalog/interruptions.json:/reactions/reaction.spell.counterspell/successByCamera/0" and row.gap_kind=="unexercised"),"Camera-specific source assignments are not lost because their keys lack assetId")
    var original=Authoring.load_data("spells/spell.magic_missile.json",cache)
    var saved=original.projectile.impact.assetId
    original.projectile.impact.assetId=""
    var edited=Audit.build(cache)
    var changed:Dictionary=edited.entries.filter(func(entry):return entry.id=="spell.magic_missile")[0]
    check(changed.requirements.any(func(row):return row.source=="spells/spell.magic_missile.json:/projectile/impact/assetId" and row.gap_kind=="authoring_assignment" and row.status=="missing"),"Clearing an active source field produces an authoring gap, not a renderer gap")
    original.projectile.impact.assetId=saved
    var interruptions=Authoring.load_data("catalog/interruptions.json",cache)
    var selected=interruptions.reactions["reaction.spell.counterspell"].successByCamera[0]
    interruptions.reactions["reaction.spell.counterspell"].successByCamera[0]=""
    var empty_camera=Audit.build(cache).entries.filter(func(entry):return entry.id=="context:interruptions")[0]
    check(empty_camera.requirements.any(func(row):return row.source=="catalog/interruptions.json:/reactions/reaction.spell.counterspell/successByCamera/0" and row.gap_kind=="authoring_assignment"),"Clearing a selected camera source remains an actionable JSON assignment gap")
    interruptions.reactions["reaction.spell.counterspell"].successByCamera[0]=selected
    FileAccess.open("res://generated/studio_authoring_audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    var result={"checks":checks,"failures":failures,"totals":report.totals,"build_ms":elapsed,"scope":report.scope}
    FileAccess.open("res://generated/studio_authoring_audit_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("STUDIO_AUTHORING_AUDIT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
