extends SceneTree
## Catalog inventory/evidence semantics. Does not claim rendered indicators.
const Coverage=preload("res://presentation/condition_coverage.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
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
    var declared:Resource=load("res://authoring/abilities.tres")
    var authored_ids:Array=[];var non_recipe_ids:Array=[];var surfaces:Array=[]
    for id in declared.sections.conditions:
        var source:Resource=load(declared.sections.conditions[id])
        # Native-only spatial owners and explicit creation sources are real
        # built recipes even when their legacy disposition is empty.
        if not source.disposition.is_empty() or not source.creation_source_id.is_empty() or not source.effects.is_empty() or not source.responses.is_empty() or not source.lifecycle_opt_in.is_empty():authored_ids.append(id)
        else:non_recipe_ids.append(id)
        if not source.disposition.is_empty() and "ground_zone" in source.unported.get("classification",{}).get("presentationDomains",[]):surfaces.append(id)
    authored_ids.sort();var built_ids:Array=recipes.keys();built_ids.sort()
    check(recipes.size()==authored_ids.size() and authored_ids.all(func(id):return recipes.has(id)) and report.entries.size()==recipes.size(),"Every explicitly authored/state-only typed recipe has one coverage entry; package-only/internal declarations are separately counted: "+JSON.stringify({"typed":authored_ids.size(),"built":recipes.size(),"not_built":authored_ids.filter(func(id):return not recipes.has(id))}))
    var entries={};var requirement_count=0
    for entry in report.entries:
        check(not entries.has(entry.id) and recipes.has(entry.id),"Unique real condition identity "+entry.id)
        entries[entry.id]=entry
        check(entry.source==Authoring.Catalog.source_pointer("catalog/condition_recipes.json",entry.id,cache) and entry.legacy_source=="catalog/condition_recipes.json:/"+entry.id and entry.definition_ref==recipes[entry.id].get("definitionRef",{}),"Exact typed authoring identity; optional legacy ContentRef is never fabricated "+entry.id)
        var ids={}
        for requirement in entry.requirements:
            check(not ids.has(requirement.id),"Unique source/mechanism requirement "+requirement.id)
            ids[requirement.id]=true;requirement_count+=1
            check(not requirement.rendered and requirement.evidence.is_empty(),"Catalog availability is never execution evidence "+requirement.id)
            if requirement.implementation=="missing" or requirement.availability=="missing":
                check(requirement.status=="missing" and not requirement.reason.is_empty(),"Unsupported/missing-source mechanism remains explicit "+requirement.id)
        var recipe:Dictionary=recipes[entry.id]
        var selected=Coverage.NativeSpells.condition(entry.id,cache)
        var replaced:Array=Coverage.Persistent.replaced_media({"behavior_id":entry.id},recipe)
        if not Coverage.NativeSpells.contact_phases(selected).is_empty():
            for effects in recipe.get("interceptionEffectsByDirection",{}).values():replaced.append_array(effects.map(func(effect):return effect.assetId))
        var persistent:Dictionary=recipe.get("persistent",{})
        var ramp:Variant=persistent.get("bodyRamp")
        if ramp!=null:
            var rows=entry.requirements.filter(func(row):return row.mechanism=="bodyRamp")
            check(rows.size()==1 and (rows[0].implementation=="implemented")== (ramp.get("mapping")=="flowing_film"),"Only actual flowing-film ramp implementation qualifies "+entry.id)
        for phase in ["application","removal"]:
            for i in recipe.get(phase,{}).get("effects",[]).size():
                var pointer=Authoring.Catalog.source_pointer("catalog/condition_recipes.json",entry.id+"/"+phase+"/effects/"+str(i),cache)
                if recipe[phase].effects[i].get("assetId","") in replaced:
                    check(not entry.requirements.any(func(row):return row.source==pointer),"Explicitly superseded phase media is not a false missing requirement "+pointer)
                else:check(entry.requirements.any(func(row):return row.source==pointer and row.status=="missing"),"Uncompiled phase media cannot hide behind a working persistent sibling "+pointer)
        for i in persistent.get("layers",[]).size():
            var pointer=Authoring.Catalog.source_pointer("catalog/condition_recipes.json",entry.id+"/persistent/layers/"+str(i),cache)
            if recipe.persistent.layers[i].assetId in replaced:
                check(not entry.requirements.any(func(row):return row.source==pointer),"Explicitly superseded persistent source is replaced in coverage "+pointer)
            else:check(entry.requirements.any(func(row):return row.source==pointer and row.get("asset_id")==recipe.persistent.layers[i].assetId),"Every retained persistent source is enumerated "+pointer)
        var native_rows=entry.requirements.filter(func(row):return row.mechanism.begins_with("native:"))
        check(native_rows.size()==Coverage.Effects.conditions(entry.id).size() and native_rows.all(func(row):return row.implementation=="implemented" and row.availability=="available" and row.status=="unexercised"),"Package lifecycles replace media without claiming recorded execution "+entry.id)
        var authored_native=entry.requirements.filter(func(row):return row.mechanism.begins_with("native_authored:"))
        var source:Resource=load(declared.sections.conditions[entry.id])
        check(authored_native.size()==source.effects.size(),"Every independently authored typed native hold is inventoried "+entry.id)
        for i in source.effects.size():
            var cue:Resource=source.effects[i]
            check(authored_native[i].source_id==cue.clip and not Coverage.Effects.for_cue(Records.cue_from_effect(cue,i),entry.id,cue.role).is_empty() and authored_native[i].source.begins_with(str(declared.sections.conditions[entry.id])+"::effects"),"Typed hold preserves the exact Factory clip and owning Resource "+entry.id+":"+str(i))
            var unbound:Array=Array(cue.unbound_constructor_inputs)
            check(authored_native[i].availability=="available" and authored_native[i].unbound_constructor_inputs==unbound and authored_native[i].status==("missing" if not unbound.is_empty() else "unexercised") and not authored_native[i].rendered and authored_native[i].evidence.is_empty(),"Typed source presence retains explicit missing inputs and cannot manufacture preparation, rendering or visual approval "+entry.id+":"+str(i))
        if not selected.is_empty():
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
        if entry.classification.get("presentationDomains",[]).has("ground_zone"):
            ground_assigned+=1
            check(assignments.is_empty() and not entry.get("indicator_assignments",[]).is_empty(),"Actual ground indicator remains owned by existing world authoring "+entry.id)
        if entry.disposition=="state_only":check(assignments.is_empty(),"Explicit state-only condition does not acquire invented VFX "+entry.id)
    var expected_unassigned=["class_feature.sorcerer.draconic_presence","condition.concentrating",
        "condition.environment.wet","condition.spell.blindness_deafness",
        "condition.spell.color_spray","condition.spell.divine_word",
        "condition.spell.ice_storm.terrain","condition.spell.prismatic_spray.restrained","condition.spell.silence.deafened",
        "condition.underwater","trait.skeleton_archer_marked"]
    authoring_missing.sort();expected_unassigned.sort()
    check(authoring_missing==expected_unassigned and report.totals.authoring_assignments==expected_unassigned.size() and ground_assigned==surfaces.size(),"Exact remaining unassigned actor indicators stay explicit; every typed ground owner retains its independent surface assignment: "+JSON.stringify({"expected_actor":expected_unassigned,"actual_actor":authoring_missing,"typed_ground":surfaces.size(),"built_ground":ground_assigned}))
    var dash:Dictionary=entries["condition.dashing"]
    check(dash.indicator_assignments.size()==6 and dash.indicator_assignments.all(func(row):return row.kind=="movement_media"),"Dash retains its six conditional movement assignments instead of an invented sustained contour")
    check(not dash.requirements.any(func(row):return row.mechanism=="bodyOutline") and dash.requirements.filter(func(row):return row.phase=="movement").all(func(row):return row.implementation=="implemented" and row.status=="unexercised" and not row.rendered and not row.native_sources.is_empty()),"All original Dash assignments delegate to current native movement sources without claiming rendered output")
    for name in ["dodging","disengaging"]:
        var id="condition."+name
        var outline=entries[id].requirements.filter(func(row):return row.mechanism=="bodyOutline")
        check(outline.size()==1 and outline[0].source=="res://authoring/abilities/conditions/condition."+name+".tres::look" and outline[0].legacy_source=="catalog/condition_recipes.json:/"+id+"/persistent/bodyOutline","Basic indicator has an actual native assignment with precise provenance: "+id)
        check(outline[0].implementation=="implemented" and outline[0].status=="unexercised" and not outline[0].rendered,"Catalog alone does not manufacture recorded/rendered evidence: "+id)
    for id in ["trait.skeleton_archer_marked","condition.concentrating","condition.underwater"]:
        var missing:Array=entries[id].requirements.filter(func(row):return row.get("gap_kind")=="authoring_assignment")
        check(missing.size()==1 and entries[id].status=="missing","Empty authored indicator is visible even with transition feedback "+id)
        if missing.is_empty():continue
        check(missing[0].source==entries[id].source+"/persistent" and missing[0].expected_source==missing[0].source,"Unassigned indicator points to exact authoring owner "+id)
        check(missing[0].implementation=="not_applicable" and missing[0].availability=="not_assigned" and missing[0].status=="missing","Authoring gap does not pretend to be renderer or source-file failure "+id)
        if recipes[id].get("application",{}).get("feedbackEnabled",false):
            check(entries[id].requirements.any(func(row):return row.mechanism=="feedback_text" and row.implementation=="implemented"),"Existing application badge remains independently supported "+id)
    var hidden:Dictionary=entries["condition.hidden"]
    check(not hidden.requirements.any(func(row):return row.get("gap_kind")=="authoring_assignment"),"Native Hidden crouch/opacity is an actual persistent assignment")
    var opacity=hidden.requirements.filter(func(row):return row.mechanism=="alphaMultiplier")
    check(opacity.size()==1 and opacity[0].source==recipes["condition.hidden"]._source_fields["persistent/alphaMultiplier"] and opacity[0].legacy_source=="catalog/condition_recipes.json:/condition.hidden/persistent/alphaMultiplier","Effective opacity points at the exact native Resource property while retaining legacy ownership")
    var activity=hidden.requirements.filter(func(row):return row.mechanism.begins_with("activityPoses:"))
    check(activity.size()==recipes["condition.hidden"].persistent.activityPoses.size() and not activity.is_empty(),"Every native activity-specific crouch assignment is inventoried")
    check(activity.all(func(row):return row.source.begins_with("res://") and ".tres::" in row.source and row.legacy_source.begins_with("catalog/condition_recipes.json:/condition.hidden/persistent/activityPoses/")),"Crouch requirements expose native properties, never fictitious JSON assignments")
    check(hidden.requirements.filter(func(row):return row.phase in ["application","removal"]).all(func(row):return row.mechanism!="material_flash"),"Condition phase badges cannot be mislabeled as material flashes")
    check(entries["condition.spell.darkness.zone"].indicator_assignments.any(func(row):return row.kind=="native_spatial_owner" and row.spatial_content_id=="spatial_effect.spell.darkness" and row.source=="res://authoring/environment/surfaces/spatial_effect.spell.darkness.tres") and not entries["condition.spell.darkness.zone"].indicator_assignments.any(func(row):return row.get("spatial_content_id")=="spatial_effect.spell.daylight"),"Darkness owns its canonical native field; its Daylight removal trigger cannot become the indicator source")
    _assignment_boundaries(cache,recipes)
    check(entries["condition.spell.mirror_image"].requirements.any(func(row):return row.mechanism=="liveCopies" and row.status=="missing"),"Lifecycle capture does not pretend Mirror Image copies are implemented")
    check(entries["condition.blinded"].requirements.any(func(row):return row.mechanism=="native:condition_blinded_native" and row.status=="unexercised") and not entries["condition.blinded"].requirements.any(func(row):return row.mechanism.ends_with(":markerGroup")),"Native Blinded lifecycle explicitly replaces the retired grouped sprite marker, without execution evidence")
    check(not entries["condition.poisoned"].requirements.any(func(row):return row.mechanism.ends_with(":markerGroup")) and entries["condition.poisoned"].requirements.any(func(row):return row.mechanism=="native:condition_poisoned_native" and row.status=="unexercised"),"Poisoned's overhead marker is the package lifecycle, not its sprite layer")
    check(entries["condition.charmed"].requirements.filter(func(row):return row.mechanism.begins_with("native:")).size()==Coverage.Effects.conditions("condition.charmed").size() and not entries["condition.charmed"].requirements.any(func(row):return row.get("asset_id","").begins_with("control.charmed.")),"Exact package Charmed marker/body sources replace the earlier sprite alias rather than leave a false migration gap")
    for id in ["condition.spell.fear","condition.aegis_spark"]:
        check(not entries[id].requirements.any(func(row):return row.get("gap_kind")=="authoring_assignment") and entries[id].requirements.any(func(row):return row.mechanism.begins_with("native:") and row.status=="unexercised"),"Actual native assignment removes a false empty-indicator gap but never supplies an execution witness "+id)
    check(entries["condition.spell.guidance"].requirements.any(func(row):return row.mechanism=="native:condition_guidance_retained_native" and row.availability=="available" and row.implementation=="implemented" and row.status=="unexercised"),"Guidance now uses its actual native owner source instead of the replaced static sprite")
    for id in ["condition.blinded","condition.spell.bestow_curse.ability"]:
        var offsets=entries[id].requirements.filter(func(row):return row.mechanism.ends_with(":offsetY"))
        var retained:Array=recipes[id].persistent.layers.filter(func(layer):return layer.get("offsetY",0)!=0 and layer.assetId not in Coverage.Persistent.replaced_media({"behavior_id":id},recipes[id]))
        check(offsets.size()==retained.size() and offsets.all(func(row):return row.implementation=="implemented" and row.status=="unexercised" and not row.rendered),"Only retained registered offsets remain independently inventoried "+id)
    for id in ["condition.frightened","condition.spell.eyebite.asleep"]:
        var attachments=entries[id].requirements.filter(func(row):return row.mechanism.ends_with(":attachment"))
        var retained:Array=recipes[id].persistent.layers.filter(func(layer):return layer.get("attachment","body") not in ["body","head"] and layer.assetId not in Coverage.Persistent.replaced_media({"behavior_id":id},recipes[id]))
        check(attachments.size()==retained.size() and attachments.all(func(row):return row.implementation=="implemented" and row.status=="unexercised" and not row.rendered),"Retained ground/face registration stays distinct from source or pixel evidence "+id)
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
    _spatial_evidence()
    check(recipes==original,"Inventory leaves original authoring untouched")
    var result={"checks":checks,"failures":failures,"totals":report.totals,"typed_declarations":declared.sections.conditions.size(),"non_recipe_ids":non_recipe_ids,"unassigned_actor_indicators":authoring_missing,"ground_indicators_assigned":ground_assigned,"scope":"All explicit typed condition recipes and finite mechanisms; non-recipe package/internal declarations separately counted, not called complete. Exact source/semantic evidence; no preparation/GPU/audio/visual-approval claim"}
    FileAccess.open("res://generated/condition_coverage_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("CONDITION_COVERAGE_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)

func _assignment_boundaries(cache:Dictionary,recipes:Dictionary)->void:
    var source:Dictionary=recipes["condition.hidden"]
    for mode in ["neutral","material_assigned","state_only","hud_only","passive_unlock","icon_only"]:
        var recipe=source.duplicate(true)
        recipe.persistent={"alphaMultiplier":1.0,"layers":[]}
        recipe.classification={"presentationDomains":["body"],"runtimeRole":"active_combat_state","visualIntensity":"secondary_dynamic"}
        recipe.erase("_source_fields");recipe.erase("_resource_source")
        if mode=="material_assigned":recipe.persistent.bodyColor={"tintRgb":0xffffff,"brightness":1.0,"saturation":1.0}
        elif mode=="state_only":recipe.disposition="state_only"
        elif mode=="hud_only":recipe.classification.presentationDomains=["hud_only"]
        elif mode=="passive_unlock":recipe.classification.runtimeRole="passive_unlock"
        elif mode=="icon_only":recipe.classification.visualIntensity="icon_only"
        # Explicit authoring-policy unit control: this identity has no package
        # assignment, so a real delivered Hidden lifecycle cannot mask it.
        var local=cache.duplicate();local["catalog/condition_recipes.json"]={"condition.test.empty_indicator":recipe}
        var row=Coverage.build(local).entries[0]
        check(row.requirements.any(func(value):return value.get("gap_kind")=="authoring_assignment")==(mode=="neutral"),"Authoring intent and neutral defaults remain distinct: "+mode)
    var zone:Dictionary=recipes["condition.spell.fog_cloud.zone"].duplicate(true)
    zone.disposition="authored";zone.surfaceOwner=""
    zone.relationships.incomingTriggers[0].sourceRef.content_id="spell.unassigned_fixture"
    var local=cache.duplicate();local["catalog/condition_recipes.json"]={"condition.spell.fog_cloud.zone":zone}
    var row=Coverage.build(local).entries[0]
    var unresolved=row.requirements.filter(func(value):return value.get("gap_kind")=="authoring_review")
    check(unresolved.size()==1 and unresolved[0].availability=="unresolved" and unresolved[0].related_source=="authoring/environment/surfaces","Unknown ground ownership requests review instead of inventing an absent VFX")
    check(not row.requirements.any(func(value):return value.get("gap_kind")=="authoring_assignment"),"Unresolved ground binding is separate from proven empty actor assignment")
    var environment:Dictionary=Authoring.Catalog.environment_index(cache).duplicate()
    environment.spatial_media=environment.spatial_media.duplicate()
    environment.spatial_media["spatial_effect.spell.unassigned_fixture"]={"variants":[{"layers":[{"assetId":"declared-ground-source"}]}]}
    local[Authoring.Catalog.ENVIRONMENT+"index.res"]=environment
    row=Coverage.build(local).entries[0]
    check(not row.indicator_assignments.is_empty() and not row.requirements.any(func(value):return value.get("gap_kind") in ["authoring_review","authoring_assignment"]),"Explicit variant-owned ground source is an assignment without a render claim")

func _spatial_evidence()->void:
    const CONTENT="spatial_effect.spell.acid_surface"
    for seat in ["amber","blue"]:
        var index:Dictionary=Fixtures.read("chromatic-orb",seat)
        check(index.ok,"Original Acid "+seat+" independently compiles its actual spatial owner")
        if not index.ok:continue
        var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("spatial_content_id")==CONTENT)
        check(not rows.is_empty(),"Original Acid "+seat+" has exact typed native source spans")
        if rows.is_empty():continue
        var unchanged:PackedByteArray=var_to_bytes(rows)
        var entry:Dictionary=Coverage.build(index.cache,rows,{CONTENT:true}).entries[0]
        var native:Dictionary=entry.requirements.filter(func(row):return row.mechanism=="native_authored:0")[0]
        check(native.status=="implemented" and native.availability=="available" and not native.evidence.is_empty(),"Exact recorded spatial source gets semantic occurrence evidence "+seat)
        check(not native.rendered and native.input_status=="not_assessed" and native.evidence.all(func(proof):return proof.condition_uuid==null and proof.spatial_effect_uuid==rows[0].owner.id),"Spatial evidence retains its actual UUID, without invented condition, optical-input or framebuffer qualification "+seat)
        for boundary in ["foreign_owner","foreign_source"]:
            var unrelated:Dictionary=rows[0].duplicate(true)
            if boundary=="foreign_owner":unrelated.component.spatial_effect_uuid=index.initialization.state.actors.keys()[0]
            else:unrelated.component.source="res://authoring/abilities/conditions/class_feature.barbarian.raging.tres::effects/0"
            var rejected:Dictionary=Coverage.build(index.cache,[unrelated],{CONTENT:true}).entries[0].requirements.filter(func(row):return row.mechanism=="native_authored:0")[0]
            check(rejected.status=="unexercised" and rejected.evidence.is_empty(),"Exact source and actual spatial ownership are both necessary: "+seat+" "+boundary)
        check(var_to_bytes(rows)==unchanged,"Spatial audit preserves the original journal/index rows "+seat)
