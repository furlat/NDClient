extends SceneTree
## Offline worklist output against real definitions and current authored JSON.
const Audit=preload("res://studio/authoring_audit.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Report=preload("res://studio/capability_report.gd")
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
            check(not ids.has(row.id),"Distinct authored field: "+entry.id+" / "+row.source)
            ids[row.id]=true
            check(not row.rendered and not row.source.is_empty() and not row.next_step.is_empty(),"Assignment is actionable without a false rendering witness: "+entry.id+" / "+str(row))
    check(report.totals.backend_definitions==347,"Current backend definition denominator is independent of replay cases")
    check(by_id.has("spell.aegis_spark") and by_id["spell.aegis_spark"].requirements.any(func(row):return row.gap_kind=="authoring_review" and row.source=="res://authoring/abilities/spells/spell.aegis_spark.tres::status"),"An actual typed stand-in remains visible for review alongside its authored body")
    var absent:Dictionary=cache.duplicate();absent["spells/spell.aegis_spark.json"]={}
    var missing:Dictionary=Audit.build(absent).entries.filter(func(entry):return entry.id=="spell.aegis_spark")[0]
    check(missing.requirements.any(func(row):return row.label=="No spell presentation assignment" and row.gap_kind=="authoring_review" and not row.rendered),"A missing spell draft remains visible although it references no media")
    check(by_id.has("action.environment.storage_chest.loot") and by_id["action.environment.storage_chest.loot"].requirements[0].gap_kind=="authoring_review","New backend action without a selected recipe remains in the authoring worklist")
    check(by_id["action.move"].requirements.any(func(row):return row.gap_kind=="unexercised") and by_id["action.move"].source=="catalog/movement_context.json:/walkClip","Existing shared movement context is not reported as an absent action recipe")
    check(not by_id.has("condition.hidden"),"Existing condition lifecycle inventory retains ownership, avoiding duplicate recipe reports")
    var coat:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache).get("condition.consumable.weapon_coat.basic_poison",{})
    var item_effects:Array=Authoring.load_data("catalog/item_attachments.json",cache).get("nativeEffects",[])
    check(not by_id.has("condition.consumable.weapon_coat.basic_poison") and coat.get("disposition")=="state_only", "Actual coating bookkeeping stays owned by condition coverage rather than a duplicate missing actor recipe")
    check(item_effects.any(func(cue):return cue.get("item_effect_behavior_id")=="condition.consumable.weapon_coat.basic_poison"),"Basic Poison has an explicit actual item-effect owner assignment")
    var missile:Dictionary=by_id["spell.magic_missile"]
    check(missile.requirements.any(func(row):return row.source=="spells/spell.magic_missile.json:/projectile/impact/assetId" and row.gap_kind=="unexercised"),"Authored impact selection is separately visible from native/source/renderer qualification")
    check(missile.requirements.any(func(row):return row.source=="spells/spell.magic_missile.json:/projectile/prepare" and row.gap_kind=="explicit_none"),"Explicitly disabled prepare phase is not an invented missing effect")
    check(by_id["spell.fog_cloud"].requirements.any(func(row):return row.source=="spells/spell.fog_cloud.json:/cast/actionClip" and row.gap_kind=="unexercised"),"Active Fog Cloud casting is visible even with recovery explicitly disabled")
    var fire:Dictionary=by_id["spell.fire_bolt"]
    var native_fire:Array=fire.requirements.filter(func(row):return row.has("authored_use"))
    check(not native_fire.is_empty(),"Native spell EffectUses remain discoverable independently of legacy projectile slots")
    check(native_fire.all(func(row):return row.has("source_kind") and row.has("required_channels") and row.has("dispatch") and row.has("variant") and row.has("owner_policy") and not row.rendered),"Native spell audit preserves source/input/dispatch/owner methods without inferring rendered output")
    var curse:Dictionary=by_id["spell.bestow_curse"]
    var curse_options:Dictionary={}
    for requirement in curse.requirements:
        var option:String=str(requirement.get("variant",{}).get("when",{}).get("effect_id",""))
        if not option.is_empty() and requirement.dispatch!="inventory_alternative":curse_options[option]=true
    check(curse_options.size()==4,"All four actual Bestow Curse option predicates are inspectable in the native spell audit")
    var font_id:String="action.class.sorcerer.convert_slot_to_sorcery_points"
    var font:Array=by_id[font_id].requirements.filter(func(row):return row.has("native_method"))
    check(font.size()==2,"Both actual Font hand assignments have their own structured native source method")
    var sockets:Array=[]
    for requirement in font:
        sockets.append(requirement.authored_media.poseSocket)
        check(requirement.native_method.program.script=="res://assets/native_effects/class_actions/ClassComponents.gd" \
            and requirement.native_method.program.properties.kind=="charge" \
            and requirement.native_method.program.capture_halves==["all"],"Font inspection resolves the actual native program and capture halves")
        check(requirement.authored_media.timeMap==[{"elapsedMs":0.0,"sourceFrame":39.0},{"elapsedMs":1250.0,"sourceFrame":0.0}] \
            and requirement.source.begins_with("res://authoring/abilities/actions/"+font_id+".tres::media/") \
            and requirement.native_method.assignment_source==requirement.source,"Inspection preserves the actual affine source window and editable typed media field")
        check(requirement.native_method.rendered=="not_witnessed" and requirement.native_method.prepared=="not_examined" \
            and not requirement.rendered,"Program assignment cannot become a preparation, pixel or artwork receipt")
    sockets.sort()
    check(sockets==["hand","other_hand"],"Distinct authored Font sockets are not collapsed in the browser")
    for owner in ["class_feature.fighter.indomitable","class_feature.barbarian.relentless_rage"]:
        var methods:Array=by_id[owner].requirements.filter(func(row):return row.has("native_method"))
        var selector:Dictionary=Authoring.load_data("catalog/body_action_recipes.json",cache)[owner].observedFact
        check(methods.size()==2 and methods.all(func(row):return row.public_fact_selector==selector),"Both actual capture aliases retain the exact public-fact admission predicate: "+owner)
    # Explicit metadata controls only; this is not a recorded public witness or
    # a readiness/pixel claim. The capability report must preserve that scope.
    var descriptor:Dictionary=font[0].authored_media if not font.is_empty() else {}
    if not descriptor.is_empty():
        var component:Dictionary={"kind":"native_effect","source_id":descriptor.source_id,
            "assignment_source":font[0].source,"attachment":descriptor.poseSocket,"requires_pose_socket":true,
            "duration_ms":descriptor.durationMs,"source_time_window":{"begin_seconds":39.0/32.0,"end_seconds":0.0,"duration_ms":1250.0}}
        var method:Dictionary=Report.native_method(component,cache)
        check(method.occurrence.attachment==descriptor.poseSocket and method.occurrence.source_time_window==component.source_time_window \
            and method.source_id==descriptor.source_id and method.runtime_binding=="not_examined","Occurrence inspection uses the same native source mapping without substituting a Factory clip")
        method.program.media_ids.clear();method.occurrence.source_time_window.begin_seconds=-1.0
        check(not Authoring.load_data("native_effects/index.json",cache).sources[descriptor.source_id].media_ids.is_empty() \
            and component.source_time_window.begin_seconds==39.0/32.0,"Editing returned inspector metadata cannot mutate the authored source or occurrence")
        var missing_source:Dictionary=component.duplicate(true);missing_source.source_id="unassigned-native-source-control"
        check(Report.native_method(missing_source,cache).source_availability=="missing","An unresolved native source remains explicitly missing in structured inspection")
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
