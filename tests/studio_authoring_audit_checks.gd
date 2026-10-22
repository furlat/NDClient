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
    var character_sources:Resource=load("res://authoring/characters.tres")
    var admitted_bodies:Resource=Audit.BodySources.index(cache)
    var creature_id:String="creature.spell.draconic_spirit"
    var creature_row:Dictionary=by_id["creature_rig:"+creature_id].requirements[0]
    var selected_rig:String=str(admitted_bodies.creature_rigs.get(creature_id,""))
    check(not selected_rig.is_empty() and creature_row.inspection=="projected" and creature_row.gap_kind=="unexercised" \
        and creature_row.source==character_sources.sections.characters[creature_id] \
        and creature_row.authored_program.rig==selected_rig \
        and creature_row.authored_program.rig_source==character_sources.sections.rigs[selected_rig] \
        and creature_row.render_method.selector=="res://presentation/characters.gd::rig_id" \
        and creature_row.render_method.renderer=="res://presentation/characters.gd::structure",
        "Exact admitted creature binding exposes its current selector/rig source rather than a missing inspection track")
    check(creature_row.render_method.runtime_binding=="not_examined" and creature_row.render_method.prepared=="not_examined" \
        and creature_row.render_method.rendered=="not_witnessed" and creature_row.render_method.artwork=="unreviewed" \
        and not creature_row.rendered and not creature_row.timing.resolved,
        "Static body source inspection does not certify an occurrence, native admission, pixels, timing or artwork")
    var missing_binding:Dictionary=Audit._creature_rig_requirement("unassigned-creature-control","exact-resource-control",admitted_bodies,character_sources.sections.rigs)
    var missing_rig:Dictionary=Audit._creature_rig_requirement(creature_id,creature_row.source,admitted_bodies,{})
    var effect_owned:Dictionary=by_id["creature_rig:creature.spell.spiritual_weapon"].requirements[0]
    check(missing_binding.inspection=="missing" and missing_rig.inspection=="missing" \
        and effect_owned.inspection=="missing" and not effect_owned.has("render_method"),
        "Absent mappings, unavailable rig carriers and effect-owned bodies cannot borrow the sprite inspection method")
    check(Audit.Requirements.owner("environment_bank","control","exact-bank-source",{}).inspection=="missing" \
        and Audit.Requirements.owner("environment_door","control","exact-door-source",{}).gap_kind=="inspection",
        "A source pointer alone cannot close bank or finite environment transition inspection")
    var raw_pointer:String="raw/source.json:/original/field"
    check(Authoring.recipe_source({"_source_fields":{"actual":raw_pointer}},"actual",cache)==raw_pointer,
        "An exact raw field pointer stays unchanged rather than becoming a Resource property")
    check(Authoring.recipe_source({"_legacy_source":"spells/source-control.json:"},"cast/recovery",cache)=="spells/source-control.json:/cast/recovery",
        "Existing spell document-root source admits a real empty member path")
    check(Authoring.recipe_source({"_legacy_source":"catalog/source-control.json:/member"},"actor/media",cache)=="catalog/source-control.json:/member/actor/media",
        "Existing nested legacy document carrier retains its actual member")
    check(Authoring.recipe_source({"_legacy_source":"res://source-control.tres::unported"},"original",cache)=="res://source-control.tres::unported/original",
        "A Resource-property carrier is not split at its res URI")
    check(Authoring.recipe_source({"_legacy_source":"opaque-source-control"},"original",cache)=="opaque-source-control/original" \
        and Authoring.recipe_source({},"original",cache).is_empty(),"Opaque and missing source carriers are preserved without fabricated paths")
    var source_only:Dictionary={"_resource_source":"res://source-control.tres","_source_fields":{"actor/clip":"res://source-control.tres::body/clip"}}
    var source_before:PackedByteArray=var_to_bytes(source_only)
    check(Authoring.recipe_source(source_only,"bodyMaterials/0",cache,"spells/source-control.json:")=="spells/source-control.json:/bodyMaterials/0" \
        and var_to_bytes(source_only)==source_before,"A caller's actual document root supplies unmapped raw provenance without mutating the recipe")
    var catalog_control:Dictionary={"known":{"id":"known","kind":"action","label":"Actual backend label"}}
    Audit._declared_owners(catalog_control,{"action":{"known":{"source_path":"unchanged"},"typed-only":{"source_path":"exact-resource"}},
        "spell":{"typed-spell":{"source_path":"exact-spell-resource"}}})
    check(catalog_control.size()==3 and catalog_control.known.label=="Actual backend label" \
        and catalog_control["typed-only"].kind=="action" and catalog_control["typed-spell"].kind=="spell",
        "Existing typed-root declarations join the inventory without replacing actual backend definitions")
    check(by_id.has("spell.aegis_spark") and by_id["spell.aegis_spark"].requirements.any(func(row):return row.gap_kind=="authoring_review" and row.source==Audit.Library.COVERAGE+"#/coverage/spell/spell.aegis_spark" and row.source_assignment=="res://authoring/abilities/spells/spell.aegis_spark.tres"),"An actual typed stand-in remains visible for review alongside its authored body")
    var absent:Dictionary=cache.duplicate();absent["spells/spell.aegis_spark.json"]={}
    var missing:Dictionary=Audit.build(absent).entries.filter(func(entry):return entry.id=="spell.aegis_spark")[0]
    check(missing.requirements.any(func(row):return row.label=="No spell presentation assignment" and row.gap_kind=="authoring_review" and not row.rendered),"A missing spell draft remains visible although it references no media")
    var loot:Dictionary=Authoring.load_data("catalog/body_action_recipes.json",cache).get("action.environment.storage_chest.loot",{})
    check(loot.get("disposition")=="state_only" and not by_id["action.environment.storage_chest.loot"].requirements.any(func(row):return row.label=="No action presentation assignment"),"Loot explicitly delegates to its actual inventory/object changes without a fabricated body")
    var missing_action_cache:Dictionary=cache.duplicate()
    var action_recipes:Dictionary=Authoring.load_data("catalog/body_action_recipes.json",cache).duplicate()
    action_recipes.erase("action.environment.storage_chest.loot")
    missing_action_cache["catalog/body_action_recipes.json"]=action_recipes
    var missing_action:Dictionary=Audit.build(missing_action_cache).entries.filter(func(entry):return entry.id=="action.environment.storage_chest.loot")[0]
    check(missing_action.requirements.any(func(row):return row.label=="No action presentation assignment" and not row.rendered),"Genuinely absent action decisions remain visible independently of the current explicit delegation")
    check(missing_action.source=="res://authoring/abilities/actions/action.environment.storage_chest.loot.tres" \
        and missing_action.requirements.any(func(row):return row.label=="No action presentation assignment" \
        and row.source==missing_action.source and row.source_assignment==missing_action.source \
        and row.document_source=="catalog/body_action_recipes.json:/action.environment.storage_chest.loot" \
        and row.gap_kind=="authoring_review"),"An omitted document exposes its exact selected resource and expected runtime pointer without inventing active art")
    var missing_intrinsic_cache:Dictionary=cache.duplicate()
    var intrinsic_recipes:Dictionary=Authoring.load_data("catalog/body_action_recipes.json",cache).duplicate()
    var intrinsic_id:String="action.earth_elemental.soil_clogged_slam"
    intrinsic_recipes.erase(intrinsic_id);missing_intrinsic_cache["catalog/body_action_recipes.json"]=intrinsic_recipes
    var absent_intrinsic:Array=Audit.build(missing_intrinsic_cache).entries.filter(func(entry):return entry.id==intrinsic_id)
    check(absent_intrinsic.size()==1 and absent_intrinsic[0].requirements.any(func(row):return row.label=="No action presentation assignment" \
        and row.source=="res://authoring/abilities/actions/"+intrinsic_id+".tres" \
        and row.document_source=="catalog/body_action_recipes.json:/"+intrinsic_id),"A real declared intrinsic cannot vanish from inspection when its compiled body row is omitted")
    check(by_id["action.move"].requirements.any(func(row):return row.gap_kind=="unexercised") and by_id["action.move"].source=="catalog/movement_context.json:/walkClip","Existing shared movement context is not reported as an absent action recipe")
    check(not by_id.has("condition.hidden"),"Existing condition lifecycle inventory retains ownership, avoiding duplicate recipe reports")
    var coat:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache).get("condition.consumable.weapon_coat.basic_poison",{})
    var item_effects:Array=Authoring.load_data("catalog/item_attachments.json",cache).get("nativeEffects",[])
    check(not by_id.has("condition.consumable.weapon_coat.basic_poison") and coat.get("disposition")=="state_only", "Actual coating bookkeeping stays owned by condition coverage rather than a duplicate missing actor recipe")
    check(item_effects.any(func(cue):return cue.get("item_effect_behavior_id")=="condition.consumable.weapon_coat.basic_poison"),"Basic Poison has an explicit actual item-effect owner assignment")
    var missile:Dictionary=by_id["spell.magic_missile"]
    check(missile.requirements.any(func(row):return row.source=="spells/spell.magic_missile.json:/projectile/impact/assetId" and row.gap_kind=="unexercised"),"Authored impact selection is separately visible from native/source/renderer qualification")
    check(missile.requirements.any(func(row):return row.source=="spells/spell.magic_missile.json:/projectile/prepare" and row.gap_kind=="explicit_none"),"Explicitly disabled prepare phase is not an invented missing effect")
    check(by_id["spell.fog_cloud"].requirements.any(func(row):return row.source=="res://authoring/abilities/spells/spell.fog_cloud.tres::body/clip" \
        and row.legacy_source=="spells/spell.fog_cloud.json:/cast/actionClip" and row.gap_kind=="unexercised"),"Active Fog Cloud casting exposes its editable typed body even with recovery explicitly disabled")
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
        check(Authoring.recipe_source(selected,"actor/clip",cache)=="res://authoring/abilities/actions/"+id+".tres::body/clip" \
            and selected._legacy_source=="catalog/shove_recipes.json:/"+id,"Shove body points to its editable typed field while retaining the exact catalog carrier: "+id)
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
