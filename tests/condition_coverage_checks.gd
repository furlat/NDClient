extends SceneTree
## Catalog inventory/evidence semantics. Does not claim rendered indicators.
const Coverage=preload("res://presentation/condition_coverage.gd")
const Authoring=preload("res://presentation/authoring.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("CONDITION_COVERAGE_FAIL ",label)
func run()->void:
    var cache={}
    var recipes:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache)
    var original=recipes.duplicate(true)
    var report=Coverage.build(cache)
    check(report.entries.size()==recipes.size() and report.entries.size()==160,"Every delivered recipe has one coverage entry")
    var entries={};var requirement_count=0
    for entry in report.entries:
        check(not entries.has(entry.id) and recipes.has(entry.id),"Unique real condition identity "+entry.id)
        entries[entry.id]=entry
        check(entry.source==Authoring.Catalog.source_pointer("catalog/condition_recipes.json",entry.id,cache) and entry.legacy_source=="catalog/condition_recipes.json:/"+entry.id and entry.definition_ref==recipes[entry.id].definitionRef,"Exact authoring identity and source "+entry.id)
        var ids={}
        for requirement in entry.requirements:
            check(not ids.has(requirement.id),"Unique source/mechanism requirement "+requirement.id)
            ids[requirement.id]=true;requirement_count+=1
            check(not requirement.rendered and requirement.evidence.is_empty(),"Catalog availability is never execution evidence "+requirement.id)
            if requirement.implementation=="missing" or requirement.availability=="missing":
                check(requirement.status=="missing" and not requirement.reason.is_empty(),"Unsupported/missing-source mechanism remains explicit "+requirement.id)
        var recipe:Dictionary=recipes[entry.id]
        var selected=Coverage.NativeSpells.condition(entry.id,cache)
        var replaced:Array=selected.get("lifecycle",{}).get("replaces_media",[])
        var ramp:Variant=recipe.persistent.get("bodyRamp")
        if ramp!=null:
            var rows=entry.requirements.filter(func(row):return row.mechanism=="bodyRamp")
            check(rows.size()==1 and (rows[0].implementation=="implemented")== (ramp.get("mapping")=="flowing_film"),"Only actual flowing-film ramp implementation qualifies "+entry.id)
        for phase in ["application","removal"]:
            for i in recipe[phase].get("effects",[]).size():
                var pointer=Authoring.Catalog.source_pointer("catalog/condition_recipes.json",entry.id+"/"+phase+"/effects/"+str(i),cache)
                if recipe[phase].effects[i].get("assetId","") in replaced:
                    check(not entry.requirements.any(func(row):return row.source==pointer),"Explicitly superseded phase media is not a false missing requirement "+pointer)
                else:check(entry.requirements.any(func(row):return row.source==pointer and row.status=="missing"),"Uncompiled phase media cannot hide behind a working persistent sibling "+pointer)
        for i in recipe.persistent.layers.size():
            var pointer=Authoring.Catalog.source_pointer("catalog/condition_recipes.json",entry.id+"/persistent/layers/"+str(i),cache)
            if recipe.persistent.layers[i].assetId in replaced:
                check(not entry.requirements.any(func(row):return row.source==pointer),"Explicitly superseded persistent source is replaced in coverage "+pointer)
            else:check(entry.requirements.any(func(row):return row.source==pointer and row.get("asset_id")==recipe.persistent.layers[i].assetId),"Every retained persistent source is enumerated "+pointer)
        if not selected.is_empty():
            var native_rows=entry.requirements.filter(func(row):return row.mechanism.begins_with("native:"))
            check(native_rows.size()==Coverage.NativeSpells.condition_phases(selected).size() and native_rows.all(func(row):return row.implementation=="implemented" and row.availability=="available" and row.status=="unexercised"),"Selected native phases replace media without claiming recorded execution "+entry.id)
            var contacts=entry.requirements.filter(func(row):return row.mechanism.begins_with("native_contact:"))
            check(contacts.size()==Coverage.NativeSpells.contact_phases(selected).size() and contacts.all(func(row):return row.implementation=="implemented" and row.availability=="available" and row.status=="unexercised" and row.evidence.is_empty()),"Native interception source availability does not claim a recorded hit "+entry.id)
        for direction in recipe.get("interceptionEffectsByDirection",{}):
            for effect in recipe.interceptionEffectsByDirection[direction]:
                check(entry.requirements.any(func(row):return row.get("asset_id","")==effect.assetId)==(effect.assetId not in replaced),"Only explicitly superseded interception media is removed "+effect.assetId)
    check(requirement_count==report.totals.requirements,"Report denominator counts all actual mechanism requirements")
    var authoring_missing:Array=[]
    var ground_assigned=0
    for entry in report.entries:
        var assignments=entry.requirements.filter(func(row):return row.get("gap_kind")=="authoring_assignment")
        if not assignments.is_empty():authoring_missing.append(entry.id)
        if entry.classification.presentationDomains.has("ground_zone"):
            ground_assigned+=1
            check(assignments.is_empty() and not entry.get("indicator_assignments",[]).is_empty(),"Actual ground indicator remains owned by existing world authoring "+entry.id)
        if entry.disposition=="state_only":check(assignments.is_empty(),"Explicit state-only condition does not acquire invented VFX "+entry.id)
    var expected_unassigned=["class_feature.sorcerer.draconic_presence","condition.aegis_spark","condition.concentrating",
        "condition.environment.wet","condition.spell.blindness_deafness","condition.spell.chill_touch",
        "condition.spell.color_spray","condition.spell.divine_word","condition.spell.fear","condition.spell.heroes_feast",
        "condition.spell.ice_storm.terrain","condition.spell.prismatic_spray.restrained","condition.spell.silence.deafened",
        "condition.underwater","trait.skeleton_archer_marked"]
    authoring_missing.sort();expected_unassigned.sort()
    check(authoring_missing==expected_unassigned and report.totals.authoring_assignments==expected_unassigned.size() and ground_assigned==15,"Only the exact remaining15 empty actor indicators remain;15 ground indicators retain their assignments")
    var dash:Dictionary=entries["condition.dashing"]
    check(dash.indicator_assignments.size()==6 and dash.indicator_assignments.all(func(row):return row.kind=="movement_media"),"Dash retains its six conditional movement assignments instead of an invented sustained contour")
    check(not dash.requirements.any(func(row):return row.mechanism=="bodyOutline") and dash.requirements.filter(func(row):return row.phase=="movement").all(func(row):return row.status=="missing" and not row.rendered),"Original Dash movement source assignments remain missing renderer work, not rendering evidence")
    for name in ["dodging","disengaging"]:
        var id="condition."+name
        var outline=entries[id].requirements.filter(func(row):return row.mechanism=="bodyOutline")
        check(outline.size()==1 and outline[0].source=="res://authoring/presentation/conditions/"+name+".tres::body_outline" and outline[0].legacy_source=="catalog/condition_recipes.json:/"+id+"/persistent/bodyOutline","Basic indicator has an actual native assignment with precise provenance: "+id)
        check(outline[0].implementation=="implemented" and outline[0].status=="unexercised" and not outline[0].rendered,"Catalog alone does not manufacture recorded/rendered evidence: "+id)
    for id in ["condition.spell.fear","trait.skeleton_archer_marked","condition.aegis_spark"]:
        var missing:Array=entries[id].requirements.filter(func(row):return row.get("gap_kind")=="authoring_assignment")
        check(missing.size()==1 and entries[id].status=="missing","Empty authored indicator is visible even with transition feedback "+id)
        if missing.is_empty():continue
        check(missing[0].source==entries[id].source+"/persistent" and missing[0].expected_source==missing[0].source,"Unassigned indicator points to exact authoring owner "+id)
        check(missing[0].implementation=="not_applicable" and missing[0].availability=="not_assigned" and missing[0].status=="missing","Authoring gap does not pretend to be renderer or source-file failure "+id)
        if recipes[id].application.feedbackEnabled:
            check(entries[id].requirements.any(func(row):return row.mechanism=="feedback_text" and row.implementation=="implemented"),"Existing application badge remains independently supported "+id)
    var hidden:Dictionary=entries["condition.hidden"]
    check(not hidden.requirements.any(func(row):return row.get("gap_kind")=="authoring_assignment"),"Native Hidden crouch/opacity is an actual persistent assignment")
    var opacity=hidden.requirements.filter(func(row):return row.mechanism=="alphaMultiplier")
    check(opacity.size()==1 and opacity[0].source==recipes["condition.hidden"]._source_fields["persistent/alphaMultiplier"] and opacity[0].legacy_source=="catalog/condition_recipes.json:/condition.hidden/persistent/alphaMultiplier","Effective opacity points at the exact native Resource property while retaining legacy ownership")
    var activity=hidden.requirements.filter(func(row):return row.mechanism.begins_with("activityPoses:"))
    check(activity.size()==recipes["condition.hidden"].persistent.activityPoses.size() and not activity.is_empty(),"Every native activity-specific crouch assignment is inventoried")
    check(activity.all(func(row):return row.source.begins_with("res://") and ".tres::" in row.source and row.legacy_source.begins_with("catalog/condition_recipes.json:/condition.hidden/persistent/activityPoses/")),"Crouch requirements expose native properties, never fictitious JSON assignments")
    check(hidden.requirements.filter(func(row):return row.phase in ["application","removal"]).all(func(row):return row.mechanism!="material_flash"),"Condition phase badges cannot be mislabeled as material flashes")
    check(entries["condition.spell.darkness.zone"].indicator_assignments.size()==1 and entries["condition.spell.darkness.zone"].indicator_assignments[0].source=="world.json:/spatial_media/spatial_effect.spell.darkness","Cleansing Daylight trigger cannot count as Darkness indicator assignment")
    _assignment_boundaries(cache,recipes)
    check(entries["condition.spell.mirror_image"].requirements.any(func(row):return row.mechanism=="liveCopies" and row.status=="missing"),"Lifecycle capture does not pretend Mirror Image copies are implemented")
    check(entries["condition.poisoned"].requirements.any(func(row):return row.mechanism.ends_with(":markerGroup") and row.implementation=="implemented"),"Original shared grouping policy is supported without inventing render evidence")
    check(entries["condition.charmed"].requirements.any(func(row):return row.get("resolved_asset_id","").begins_with("control.charmed.") and row.reason=="native_source_not_authored" and row.status=="missing"),"Condition metadata aliases name the sprite asset that still needs a native source")
    check(entries["condition.spell.guidance"].requirements.any(func(row):return row.mechanism=="native:0" and row.availability=="available" and row.implementation=="implemented" and row.status=="unexercised"),"Guidance now uses its actual native owner source instead of the replaced static sprite")
    for id in ["condition.blinded","condition.spell.bestow_curse.ability"]:
        var offsets=entries[id].requirements.filter(func(row):return row.mechanism.ends_with(":offsetY"))
        check(not offsets.is_empty() and offsets.all(func(row):return row.implementation=="implemented" and row.status=="unexercised" and not row.rendered),"Implemented registered offsets remain unexercised rather than missing "+id)
    for id in ["condition.frightened","condition.spell.eyebite.asleep"]:
        var attachments=entries[id].requirements.filter(func(row):return row.mechanism.ends_with(":attachment"))
        check(not attachments.is_empty() and attachments.all(func(row):return row.implementation=="implemented" and row.status=="unexercised" and not row.rendered),"Implemented ground/face registration remains distinct from source or pixel evidence "+id)
    var selected_report=Coverage.build(cache,[],{"condition.spell.hold_person":true})
    check(selected_report.entries.size()==1 and selected_report.totals.entries==1,"Witnessed condition filter preserves exact finite denominator")
    var banks:Array=selected_report.entries[0].requirements.filter(func(row):return row.mechanism.ends_with(":application_asset_id") or row.mechanism.ends_with(":removal_asset_id"))
    check(not banks.is_empty() and banks.all(func(row):return row.implementation=="missing" and row.reason=="native_source_not_authored"),"Sprite-sheet entry/release banks are reported as needing a native source")
    var recorded=[{"id":"recorded-poison-material","kind":"condition_material","recording":"explicit semantic fixture",
        "start_ms":10.0,"end_ms":20.0,"source_start_ms":0.0,"owner":{"id":"owner","condition":{"behavior_id":"condition.poisoned"}},
        "operations":{"bodyColor":recipes["condition.poisoned"].persistent.bodyColor}}]
    var observed=Coverage.build(cache,recorded)
    var poison=observed.entries.filter(func(entry):return entry.id=="condition.poisoned")[0]
    var color=poison.requirements.filter(func(row):return row.mechanism=="bodyColor")[0]
    check(color.status=="implemented" and color.evidence.size()==1 and not color.rendered,"Recorded resolved material receives bounded semantic evidence, never native proof")
    check(color.evidence[0].start_ms==10.0 and color.evidence[0].source_start_ms==0.0,"Recorded occurrence keeps lifetime and independent source clock")
    check(poison.status!="implemented","One recorded supported member cannot qualify unexercised siblings")
    check(recipes==original,"Inventory leaves original authoring untouched")
    var result={"checks":checks,"failures":failures,"totals":report.totals,"unassigned_actor_indicators":authoring_missing,"ground_indicators_assigned":ground_assigned,"scope":"All authored condition identities, finite mechanisms, exact sources and honest semantic evidence; no GPU/audio claim"}
    FileAccess.open("res://generated/condition_coverage_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("CONDITION_COVERAGE_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)

func _assignment_boundaries(cache:Dictionary,recipes:Dictionary)->void:
    var source:Dictionary=recipes["condition.hidden"]
    for mode in ["neutral","material_assigned","state_only","hud_only","passive_unlock","icon_only"]:
        var recipe=source.duplicate(true)
        recipe.persistent.erase("activityPoses");recipe.persistent.alphaMultiplier=1.0
        recipe.erase("_source_fields");recipe.erase("_resource_source")
        if mode=="material_assigned":recipe.persistent.bodyColor={"tintRgb":0xffffff,"brightness":1.0,"saturation":1.0}
        elif mode=="state_only":recipe.disposition="state_only"
        elif mode=="hud_only":recipe.classification.presentationDomains=["hud_only"]
        elif mode=="passive_unlock":recipe.classification.runtimeRole="passive_unlock"
        elif mode=="icon_only":recipe.classification.visualIntensity="icon_only"
        var local=cache.duplicate();local["catalog/condition_recipes.json"]={"condition.hidden":recipe}
        var row=Coverage.build(local).entries[0]
        check(row.requirements.any(func(value):return value.get("gap_kind")=="authoring_assignment")==(mode=="neutral"),"Authoring intent and neutral defaults remain distinct: "+mode)
    var zone:Dictionary=recipes["condition.spell.fog_cloud.zone"].duplicate(true)
    zone.relationships.incomingTriggers[0].sourceRef.content_id="spell.unassigned_fixture"
    var local=cache.duplicate();local["catalog/condition_recipes.json"]={"condition.spell.fog_cloud.zone":zone}
    var row=Coverage.build(local).entries[0]
    var unresolved=row.requirements.filter(func(value):return value.get("gap_kind")=="authoring_review")
    check(unresolved.size()==1 and unresolved[0].availability=="unresolved" and unresolved[0].related_source=="world.json:/spatial_media","Unknown ground ownership requests review instead of inventing an absent VFX")
    check(not row.requirements.any(func(value):return value.get("gap_kind")=="authoring_assignment"),"Unresolved ground binding is separate from proven empty actor assignment")
    var world=Authoring.load_data("world.json",cache).duplicate()
    world.spatial_media=world.spatial_media.duplicate()
    world.spatial_media["spatial_effect.spell.unassigned_fixture"]={"variants":[{"layers":[{"assetId":"declared-ground-source"}]}]}
    local["world.json"]=world
    row=Coverage.build(local).entries[0]
    check(not row.indicator_assignments.is_empty() and not row.requirements.any(func(value):return value.get("gap_kind") in ["authoring_review","authoring_assignment"]),"Explicit variant-owned ground source is an assignment without a render claim")
