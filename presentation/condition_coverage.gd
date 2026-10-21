extends RefCounted
## Passive source/implementation inventory. A compiled row is not render proof.
const Authoring=preload("res://presentation/authoring.gd")
const Catalog=preload("res://source_catalog.gd")
const NativeSpells=preload("res://presentation/native_spell_authoring.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const Responses=preload("res://presentation/condition_responses.gd")

static func _require(entry: Dictionary,phase: String,mechanism: String,source: String,implemented: bool,reason: String="",availability: String="not_required",details: Dictionary={}) -> Dictionary:
    var row={"id":source+"#"+mechanism,"phase":phase,"mechanism":mechanism,"source":source,
        "implementation":"implemented" if implemented else "missing","availability":availability,
        "status":"missing" if not implemented or availability=="missing" else "unexercised",
        "reason":reason,"evidence":[],"rendered":false}
    row.merge(details,true);entry.requirements.append(row);return row

static func _motion_assignments(entry:Dictionary,cache:Dictionary)->void:
    var movement:Dictionary=Authoring.load_data("catalog/movement_context.json",cache)
    var motion_assignments:Array=[]
    for field in ["walkMedia","jumpMedia"]:
        var tracks:Array=movement.get(field,[])
        for i in tracks.size():
            var track:Dictionary=tracks[i]
            if entry.id not in track.get("whenConditions",[]):continue
            motion_assignments.append({"kind":"movement_media","source":"catalog/movement_context.json:/"+field+"/"+str(i)+"/assetId",
                "asset_id":track.assetId,"role":track.role,"when_conditions":track.whenConditions.duplicate(),
                "unless_conditions":track.get("unlessConditions",[]).duplicate(),
                "qualification":"Existing conditional movement assignment; not a sustained body filter or rendering witness."})
    if not motion_assignments.is_empty():
        entry.indicator_assignments=motion_assignments
        for assignment in motion_assignments:
            var uses:Array=movement.get("nativeEffects",[]).filter(func(cue):
                var rule:Dictionary=cue.get("movement",{})
                return assignment.asset_id in rule.get("replaces_media",[]) \
                    and rule.get("when_conditions",[])==assignment.when_conditions and rule.get("unless_conditions",[])==assignment.unless_conditions)
            var available:bool=uses.any(func(cue):return not Effects.for_cue(cue,"movement",str(cue.role)).is_empty())
            _require(entry,"movement",assignment.role,assignment.source,available,"" if available else "authored_movement_media_not_implemented","assigned",
                {"label":"Movement "+str(assignment.role)+" · "+str(assignment.asset_id),"asset_id":assignment.asset_id,
                "gap_kind":"" if available else "renderer","when_conditions":assignment.when_conditions,"unless_conditions":assignment.unless_conditions,
                "native_sources":uses.map(func(cue):return {"clip":cue.clip,"source":cue.source,"at":cue.at}),
                "qualification":"Actual Step tracks select these native assignments; current source output and human review remain separate."})

static func _indicator_assignment(entry: Dictionary,recipe: Dictionary,cache: Dictionary) -> void:
    var classification:Dictionary=recipe.get("classification",{})
    var domains:Array=classification.get("presentationDomains",[]).filter(func(domain):return domain not in ["none","hud_only"])
    if (recipe.get("disposition")!="authored" or domains.is_empty()) and str(recipe.get("surfaceOwner","")).is_empty():return
    if classification.get("runtimeRole")=="passive_unlock" or classification.get("visualIntensity") in ["state_only","icon_only"]:return
    var persistent:Dictionary=recipe.get("persistent",{})
    if float(persistent.get("alphaMultiplier",1))!=1:return
    for field in ["bodyColor","bodyOutline","bodyPose","frozenPose","bodyRamp","bodyScale","bodyDistortion","liveCopies","absenceEcho","label"]:
        if persistent.get(field)!=null:return
    for field in ["equipmentModifiers","appearanceLayers","layers","activityPoses"]:
        if not persistent.get(field,[]).is_empty():return
    if not entry.get("indicator_assignments",[]).is_empty():return
    if "ground_zone" in domains or not str(recipe.get("surfaceOwner","")).is_empty():
        var spatial:Dictionary=Catalog.environment_index(cache).get("spatial_media",{})
        var triggers:Array=recipe.get("relationships",{}).get("incomingTriggers",[])
        var assignments:Array=[]
        var declared:String=str(recipe.get("surfaceOwner",""))
        var owner_ids:Array=[] if declared.is_empty() else [declared]
        for trigger in triggers:
            if trigger.get("effect")=="apply":
                var candidate:String="spatial_effect."+str(trigger.get("sourceRef",{}).get("content_id",""))
                if candidate not in owner_ids:owner_ids.append(candidate)
        for owner_id in owner_ids:
            var config:Dictionary=Persistent.spatial_config(str(owner_id),cache)
            var uses:Array=config.get("persistent",{}).get("nativeEffects",[])
            if uses.is_empty():
                # The ordinary world sampler can select an indexed spatial
                # condition lifecycle instead of an authored Ground EffectUse.
                for selection in Persistent.spatial_lifecycles({"content_ref":{"content_id":owner_id}}):
                    var package_source:String="assets/vfx/index.json#/selections/"+str(selection.key)+"/condition"
                    assignments.append({"kind":"native_spatial_owner","spatial_content_id":owner_id,"source":package_source,
                        "declared_owner_source":entry.source+"/surfaceOwner" if owner_id==declared else entry.source+"/relationships/incomingTriggers",
                        "selection_key":str(selection.key),"when":selection.condition.get("when",{}).duplicate(),
                        "native_sources":["application","sustain","removal"].map(func(phase):return {
                            "clip":selection.condition.phases[phase],"source":package_source+"/phases/"+phase,"at":phase}),
                        "qualification":"The exact indexed spatial lifecycle owns this declared field; actual observed UUID, unsuppressed cells, source inputs and native output remain separate."})
                continue
            assignments.append({"kind":"native_spatial_owner","spatial_content_id":owner_id,
                "source":str(config.get("_resource_source",Catalog.source_pointer("catalog/condition_recipes.json",str(owner_id),cache))),
                "declared_owner_source":entry.source+"/surfaceOwner" if owner_id==declared else entry.source+"/relationships/incomingTriggers",
                "native_sources":uses.map(func(cue):return {"clip":cue.get("clip",""),"source":cue.get("source",""),"at":cue.get("at","")}),
                "qualification":"The declared spatial owner has a native source assignment. Actual owner inputs, playback and rendered evidence remain separate; no duplicate actor indicator is created."})
        for i in triggers.size():
            if triggers[i].get("effect")!="apply":continue
            var ref:Dictionary=triggers[i].get("sourceRef",{})
            var effect_id="spatial_effect."+str(ref.get("content_id",""))
            if not spatial.has(effect_id):continue
            var media:Dictionary=spatial[effect_id]
            if media.get("layers",[]).is_empty() and media.get("variants",[]).is_empty():continue
            assignments.append({"kind":"spatial_media","source":"authoring/environment/surfaces/"+effect_id+".tres::legacy/spatial_media",
                "trigger_source":entry.source+"/relationships/incomingTriggers/"+str(i)+"/sourceRef",
                "source_ref":ref.duplicate(true),"qualification":"Existing world assignment for the declared trigger; no renderer or recorded execution claim."})
        entry.indicator_assignments=assignments
        if not assignments.is_empty():return
        _require(entry,"persistent","persistent_indicator",entry.source+"/persistent",false,
            "indicator_ownership_unresolved" if declared.is_empty() else "declared_spatial_owner_source_not_assigned","unresolved",{
                "gap_kind":"authoring_review" if declared.is_empty() else "source","implementation":"not_applicable","presentation_domains":domains,
                "expected_source":entry.source+"/persistent","related_source":"authoring/environment/surfaces",
                "spatial_content_id":declared,
                "note":"Indicator ownership unresolved between this ground condition and world spatial media. Review authoring; this is not evidence of absent VFX." if declared.is_empty() else "The Resource names its actual spatial presentation owner, but that owner has no selected native assignment here. Keep its source boundary explicit; no duplicate actor effect is required."})
        return
    # Assignment and execution are separate. A real package lifecycle or typed
    # held source owns an indicator even when its runtime inputs remain absent.
    if not persistent.get("nativeEffects",[]).is_empty() or not Persistent.lifecycle_candidates(str(entry.id),cache).is_empty():return
    _require(entry,"persistent","persistent_indicator",entry.source+"/persistent",false,
        "persistent_visual_assignment_missing","not_assigned",{
            "gap_kind":"authoring_assignment","implementation":"not_applicable",
            "presentation_domains":domains,"classification_source":entry.source+"/classification/presentationDomains",
            "expected_source":entry.source+"/persistent",
            "note":"No persistent visual assignment in this condition recipe. Application/removal feedback is separate; no effect is prescribed."})

static func _media(asset: String,cache: Dictionary,availability: Dictionary) -> Dictionary:
    if availability.has(asset):return availability[asset]
    var result={"asset_id":asset,"kind":"sprite_vfx","source_id":"","availability":"missing","missing_paths":[],"reason":"native_source_not_authored"}
    var selected:Dictionary=Authoring.load_data("native_effects/index.json",cache).get("sources",{})
    for id in selected:
        var record:Dictionary=selected[id]
        if asset not in record.get("media_ids",[]):continue
        result.kind="native_effect";result.source_id=id;result.reason=""
        for path in record.get("preload_paths",[record.get("scene",record.get("script",""))]):
            if not FileAccess.file_exists(path):result.missing_paths.append(path)
        result.availability="available" if result.missing_paths.is_empty() else "missing"
        if result.availability=="missing":result.reason="selected_native_source_missing"
        availability[asset]=result;return result
    var metadata:Dictionary=Authoring.load_data("catalog/condition_media.json",cache).get(asset,{})
    result.metadata=metadata
    if metadata.has("images_by_facing"):
        result.kind="condition_static_image";result.reason=""
        for image in metadata.images_by_facing.values():
            if not FileAccess.file_exists(Catalog.media_path(image.path)):result.missing_paths.append(image.path)
        result.availability="available" if result.missing_paths.is_empty() else "missing"
        if result.availability=="missing":result.reason="condition_static_image_missing"
        availability[asset]=result;return result
    # Sprite-sheet effects have no renderer. The asset shows nothing until a
    # native source is authored for it (native_effects/index.json media_ids).
    result.kind="sprite_vfx";result.reason="native_source_not_authored"
    result.resolved_asset_id=metadata.get("asset_id",asset)
    availability[asset]=result;return result

static func _layer(entry: Dictionary,phase: String,layer: Dictionary,pointer: String,implemented: bool,cache: Dictionary,availability: Dictionary) -> void:
    var asset:String=layer.get("assetId","")
    var media=_media(asset,cache,availability)
    var source_implemented=implemented and media.kind not in ["condition_static_image","sprite_vfx"]
    var reason:String=media.reason if media.availability=="missing" else ("" if source_implemented else ("condition_static_image_not_implemented" if implemented else "condition_phase_effect_not_compiled"))
    _require(entry,phase,"layer:"+str(layer.id),pointer,source_implemented,reason,media.availability,{"asset_id":asset,"component_kind":media.kind,"source_id":media.source_id,"resolved_asset_id":media.get("resolved_asset_id",asset),"missing_paths":media.missing_paths.duplicate()})
    if not implemented:return
    # These authored controls are separate from having the source and a draw
    # mechanism. Keeping them visible prevents source availability becoming a
    # false claim that the whole condition recipe executes correctly.
    for field in ["markerGroup","whenEnergyType","whenAbility","whenMetamagicMode","whenSizeChange"]:
        if layer.get(field)!=null:_require(entry,phase,"layer:"+str(layer.id)+":"+field,pointer+"/"+field,true)
    for field in ["startOffsetMs","phaseOffsetMs"]:
        if float(layer.get(field,0))!=0:_require(entry,phase,"layer:"+str(layer.id)+":"+field,pointer+"/"+field,true)
    if float(layer.get("offsetY",0))!=0:
        var offset_supported=media.kind!="native_effect"
        _require(entry,phase,"layer:"+str(layer.id)+":offsetY",pointer+"/offsetY",offset_supported,"" if offset_supported else "native_condition_offset_not_implemented")
    if layer.get("attachment","body") not in ["body","head"]:
        var attachment_supported=layer.attachment in ["ground","face","hand"]
        _require(entry,phase,"layer:"+str(layer.id)+":attachment",pointer+"/attachment",attachment_supported,"" if attachment_supported else "condition_attachment_not_implemented")
    var full_modes=["idle","move","jump","forced_move","attack","cast","act","hit"]
    if layer.has("activeDuring") and full_modes.any(func(mode):return mode not in layer.activeDuring):
        _require(entry,phase,"layer:"+str(layer.id)+":activeDuring",pointer+"/activeDuring",true)
    if layer.has("lifeStates"):
        _require(entry,phase,"layer:"+str(layer.id)+":lifeStates",pointer+"/lifeStates",true)

    var metadata:Dictionary=media.get("metadata",{})
    # Application and removal banks were sprite-sheet crossfades: nothing draws
    # them until a native source is authored.
    for field in ["application_asset_id","removal_asset_id","removal_mask_asset_id"]:
        if metadata.get(field)!=null:
            var source=_media(metadata[field],cache,availability)
            var bank_reason:String="native_source_not_authored" if source.kind=="sprite_vfx" else "condition_media_lifecycle_not_implemented"
            _require(entry,phase,"layer:"+str(layer.id)+":"+field,"catalog/condition_media.json:/"+asset+"/"+field,false,bank_reason,source.availability,{"asset_id":metadata[field],"missing_paths":source.missing_paths})
    for field in ["loop_crossfade_ms","sustain_start_ms"]:
        if float(metadata.get(field,0))!=0:
            var supported=field=="sustain_start_ms" and metadata.get("application_mode","crossfade")=="crossfade"
            _require(entry,phase,"layer:"+str(layer.id)+":"+field,"catalog/condition_media.json:/"+asset+"/"+field,supported,"" if supported else "condition_media_clock_not_implemented")

static func _effects(entry: Dictionary,phase: String,effects: Array,pointer: String,cache: Dictionary,availability: Dictionary,replaced:Array=[]) -> void:
    for i in effects.size():
        if effects[i].get("assetId","") not in replaced:_layer(entry,phase,effects[i],pointer+"/"+str(i),false,cache,availability)

## Inspection has no current actor state. Compare declared conditional media
## with the exact native predicate instead of treating an empty state as a
## refusal of every supported branch. Unknown/mismatched predicates stay open.
static func _inspection_replaced_media(id:String,recipe:Dictionary,cache:Dictionary)->Array:
    var result:Array=Persistent.replaced_media({"behavior_id":id},recipe,cache)
    var selectors:Dictionary={"energy_type":"whenEnergyType","enhanced_ability":"whenAbility",
        "metamagic_mode":"whenMetamagicMode","size_change":"whenSizeChange"}
    for selection in Persistent.lifecycle_candidates(id,cache):
        var lifecycle:Dictionary=selection.condition
        var when:Dictionary=lifecycle.get("when",{})
        if when.is_empty():continue # Ordinary unconditional lookup already handled it.
        for layer in recipe.get("persistent",{}).get("layers",[]):
            if not when.keys().all(func(field):return selectors.has(field) and layer.get(selectors[field])==when[field]):continue
            var covered:bool=not lifecycle.get("marker",{}).is_empty() if layer.get("markerGroup")!=null else lifecycle.get("body_channel_included",false)
            var asset:String=str(layer.get("assetId",""))
            if covered and not asset.is_empty() and asset not in result:result.append(asset)
        for phase in ["application","removal"]:
            for effect in recipe.get(phase,{}).get("effects",[]):
                if not when.keys().all(func(field):return selectors.has(field) and effect.get(selectors[field])==when[field]):continue
                var asset:String=str(effect.get("assetId",""))
                if not asset.is_empty() and asset not in result:result.append(asset)
    return result

## The package lifecycles of this condition and the spell's contact source.
static func _native(entry:Dictionary,recipe:Dictionary,selected:Dictionary,cache:Dictionary)->void:
    var common:Dictionary={"id":"condition:"+str(entry.id),"actor_uuid":null,"condition":{"behavior_id":entry.id},"start_ms":0.0,"absolute_start_ms":0.0,
        "duration_ms":INF,"age_ms":0.0,"removal_age_ms":null,"initial":false,"recipe":recipe}
    if recipe.get("ownerKind")=="temporary_hp_grant":
        common.id="grant-source:"+str(entry.id);common.owner_behavior_id=str(entry.id)
        common.native_grant=true;common.erase("condition")
    for phase in Persistent.lifecycle_samples(common,Persistent.lifecycle_candidates(str(entry.id),cache),cache):
        _native_phase(entry,phase,"persistent","native:"+str(phase.source_id))
    for phase in Persistent.authored_phases(recipe,str(entry.id),cache,str(entry.source)):
        _native_phase(entry,phase,"persistent","native_authored:"+str(phase.native_cue.source_index))
    for cue in recipe.get("nativeResponses",[]):
        var pointer:String=str(cue.get("source",str(entry.source)+"/nativeResponses/"+str(cue.source_index)))
        var selection:Dictionary={"id":str(entry.id),"source":pointer,"staging":{},"source_bounds":{},"palette":{}}
        var phase:Dictionary=NativeSpells._phase(selection,cue,{"prepare":0.0},0.0,0.0,0)
        phase.source=pointer;phase.source_id=str(entry.id)+".response."+str(cue.source_index)
        _native_phase(entry,phase,"response","native_response:"+str(cue.source_index))
        var requirement:Dictionary=entry.requirements.back()
        if not Responses.supported(cue.get("condition_response",{})):
            requirement.implementation="missing";requirement.status="missing";requirement.reason="condition_response_not_compiled"
    var index=0
    for phase in NativeSpells.contact_phases(selected):
        _native_phase(entry,phase,"interception","native_contact:"+str(index))
        index+=1

static func _native_phase(entry:Dictionary,phase:Dictionary,owner_phase:String,mechanism:String)->void:
    var missing:Array=[]
    for path in Effects.resource_paths(phase.native_clip):
        if not FileAccess.file_exists(path):missing.append(path)
    var lifecycle:Dictionary=phase.get("lifecycle",{}).duplicate()
    for name in phase.get("lifecycle_phases",{}):
        lifecycle[name]=str(phase.lifecycle_phases[name].id)
        for path in Effects.resource_paths(phase.lifecycle_phases[name]):
            if not FileAccess.file_exists(path) and path not in missing:missing.append(path)
    var present=not phase.native_clip.is_empty() and missing.is_empty()
    var unavailable_inputs:Array=phase.get("unbound_constructor_inputs",[])
    var requirement:Dictionary=_require(entry,owner_phase,mechanism,phase.source,true,
        phase.get("reason","") if present else "selected_native_source_missing","available" if present else "missing",
        {"component_kind":"native_effect","source_id":phase.source_id,"missing_paths":missing,
        "lifecycle":lifecycle,"unbound_constructor_inputs":unavailable_inputs.duplicate(),
        "input_status":"unavailable" if not unavailable_inputs.is_empty() else "not_assessed",
        "label":("Lifecycle · " if phase.has("lifecycle_phases") else str(phase.native_cue.role).capitalize()+" · ")+str(phase.source_id)})
    if phase.get("status")=="missing":requirement.status="missing"

static func _recorded(entry: Dictionary,rows: Array) -> void:
    for row in rows:
        if row.kind in ["condition","condition_exit","condition_state"]:continue
        var persistent=Catalog.condition_key(row.get("owner",{}).get("condition",{}))==entry.id
        var component:Dictionary=row.get("component",{})
        var owner:Dictionary=row.get("owner",{})
        var spatial:bool=owner.get("effect",{}).get("content_ref",{}).get("content_id")==entry.id \
            and component.get("spatial_effect_uuid")!=null and component.spatial_effect_uuid==owner.get("id")
        var component_source:String=row.get("component",{}).get("source",row.get("track",{}).get("source",""))
        if not persistent and not entry.requirements.any(func(requirement):return component_source in [requirement.source,requirement.get("legacy_source",requirement.source)]):continue
        for requirement in entry.requirements:
            var matched=false
            if requirement.mechanism.begins_with("native_response:"):
                matched=row.kind=="native_effect" and component.get("condition_response",{}).get("condition_id")==entry.id and component_source==requirement.source
            elif requirement.mechanism.begins_with("native_contact:"):
                matched=row.kind=="native_effect" and row.get("component",{}).has("intercepted_by_condition_uuid") and component_source in [requirement.source,requirement.get("legacy_source",requirement.source)]
            elif requirement.mechanism=="cast_binding":
                matched=row.kind=="body" and row.get("track",{}).get("reaction_cast_binding")==requirement.binding and component_source in [requirement.source,requirement.get("legacy_source",requirement.source)]
            elif row.kind=="native_effect" and component.get("native_spell",false) and (requirement.mechanism.begins_with("native:") or requirement.mechanism.begins_with("native_authored:")):
                matched=(persistent or spatial) and component_source in [requirement.source,requirement.get("legacy_source",requirement.source)]
            elif not persistent:
                matched=component_source in [requirement.source,requirement.get("legacy_source",requirement.source)] and requirement.mechanism==row.kind
            elif row.kind=="condition_material":matched=requirement.mechanism in row.get("operations",{})
            elif row.kind=="condition_pose":
                matched=requirement.mechanism in ["bodyPose","frozenPose"]
                if requirement.mechanism.begins_with("activityPoses:"):
                    matched=row.get("pose",{}).get("source")==requirement.source
            else:
                var layer:Dictionary=row.get("component",{}).get("layer",{})
                matched=requirement.mechanism=="layer:"+str(layer.get("id",""))
            if not matched or (persistent and requirement.phase!="persistent"):continue
            var evidence:Dictionary={"kind":"indexed_candidate" if row.get("selection_policy")=="sampled" else "resolved_recording","recording":row.get("recording",""),"row_id":row.id,
                "condition_uuid":null if spatial else component.get("condition_uuid",component.get("intercepted_by_condition_uuid",row.get("track",{}).get("condition_uuid",owner.get("id")))),"start_ms":row.start_ms,"end_ms":row.end_ms,"source_start_ms":row.get("source_start_ms",row.start_ms)}
            if spatial:evidence.spatial_effect_uuid=component.spatial_effect_uuid
            requirement.evidence.append(evidence)
            if requirement.status!="missing" and row.get("selection_policy")!="sampled":requirement.status="implemented"

static func build(cache: Dictionary={},recorded_rows: Array=[],condition_ids: Dictionary={}) -> Dictionary:
    var recipes:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache)
    var resources:Dictionary=Authoring.load_data("catalog/resources.json",cache)
    var rigs:Dictionary=Authoring.rigs(cache)
    var entries:Array=[]
    var availability={}
    var totals={"entries":0,"requirements":0,"implemented":0,"unexercised":0,"missing":0,"state_only":0,"authoring_assignments":0}
    for id in recipes:
        if not condition_ids.is_empty() and not condition_ids.has(id):continue
        totals.entries+=1
        var recipe:Dictionary=recipes[id]
        var native=NativeSpells.condition(id,cache)
        var replaced:Array=_inspection_replaced_media(str(id),recipe,cache)
        # The spell's native contact source draws an actual interception.
        if not NativeSpells.contact_phases(native).is_empty():
            for effects in recipe.get("interceptionEffectsByDirection",{}).values():replaced.append_array(effects.map(func(effect):return str(effect.get("assetId",""))))
        var source="catalog/condition_recipes.json:/"+id
        var entry={"id":id,"label":recipe.get("label",id),"definition_ref":recipe.get("definitionRef",{}).duplicate(true),
            "source":source,"disposition":recipe.get("disposition",""),"owner_kind":recipe.get("ownerKind","condition"),"classification":recipe.get("classification",{}).duplicate(true),"requirements":[],"status":"unexercised"}
        _motion_assignments(entry,cache)
        _indicator_assignment(entry,recipe,cache)
        _native(entry,recipe,native,cache)
        var persistent:Dictionary=recipe.get("persistent",{})
        for field in ["bodyColor","bodyOutline","bodyPose","frozenPose"]:
            if persistent.get(field)!=null:_require(entry,"persistent",field,source+"/persistent/"+field,true)
        for i in persistent.get("activityPoses",[]).size():
            var pose:Dictionary=persistent.activityPoses[i]
            var present=rigs.get(pose.rigId,{}).get("clips",{}).has(pose.clip)
            _require(entry,"persistent","activityPoses:"+str(i),source+"/persistent/activityPoses/"+str(i),true,
                "" if present else "condition_pose_clip_not_registered","available" if present else "missing",
                {"label":str(pose.activity).capitalize()+" pose · "+str(pose.clip),"pose":pose.duplicate()})
        if persistent.get("alphaMultiplier",1.0)!=1.0:_require(entry,"persistent","alphaMultiplier",source+"/persistent/alphaMultiplier",true)
        if persistent.get("bodyRamp")!=null:
            var ramp:Dictionary=persistent.bodyRamp
            var supported=ramp.get("mapping")=="flowing_film"
            var path:String=resources.get(ramp.get("texture"),"")
            var present=not path.is_empty() and FileAccess.file_exists(Catalog.media_path(path))
            _require(entry,"persistent","bodyRamp",source+"/persistent/bodyRamp",supported,
                "" if supported and present else ("body_ramp_mapping_not_implemented" if not supported else "body_ramp_texture_missing"),
                "available" if present else "missing",{"mapping":ramp.get("mapping"),"texture_path":path})
        for n in persistent.get("equipmentModifiers",[]).size():
            _require(entry,"persistent","equipmentModifiers:"+str(n),source+"/persistent/equipmentModifiers/"+str(n),false,"condition_equipmentModifiers_not_implemented")
        var appearance_bound:bool=Persistent.lifecycles({"behavior_id":entry.id},cache).any(func(selection):return "appearance_provider" in Effects.clip(selection.condition.phases.application).get("inputs",[]))
        for n in persistent.get("appearanceLayers",[]).size():
            _require(entry,"persistent","appearanceLayers:"+str(n),source+"/persistent/appearanceLayers/"+str(n),appearance_bound,
                "" if appearance_bound else "condition_appearance_provider_not_authored","assigned",
                {"layer":persistent.appearanceLayers[n],"renderer":"res://presentation/condition_appearance.gd","qualification":"Current modular outfit; native witness and compatible actual rig remain separate."})
        if persistent.get("bodyScale")!=null:
            _require(entry,"persistent","bodyScale",source+"/persistent/bodyScale",true,"","not_required",
                {"renderer":"res://play.gd::_sample_actors","selection":"Public size_change selects this authored factor; exact owner draw evidence remains separate."})
        for field in ["bodyDistortion","liveCopies","absenceEcho"]:
            if persistent.get(field)!=null:_require(entry,"persistent",field,source+"/persistent/"+field,false,"condition_"+field+"_not_implemented")
        if persistent.get("liveCopies")!=null:
            for field in ["applicationEffects","removalEffects"]:_effects(entry,"persistent",persistent.liveCopies.get(field,[]),source+"/persistent/liveCopies/"+field,cache,availability)
        if persistent.get("absenceEcho")!=null:
            for field in ["back","front"]:
                var asset:String=persistent.absenceEcho.get(field,"")
                if not asset.is_empty():_layer(entry,"persistent",{"id":"absenceEcho:"+field,"assetId":asset},source+"/persistent/absenceEcho/"+field,false,cache,availability)
        for n in persistent.get("layers",[]).size():
            if persistent.layers[n].get("assetId","") not in replaced:_layer(entry,"persistent",persistent.layers[n],source+"/persistent/layers/"+str(n),true,cache,availability)
        for phase in ["application","removal"]:
            var change:Dictionary=recipe.get(phase,{})
            if change.get("feedbackEnabled",false):_require(entry,phase,"feedback_text",source+"/"+phase+"/feedbackEnabled",true)
            if not change.get("bodyAnimation",{}).is_empty():_require(entry,phase,"body",source+"/"+phase+"/bodyAnimation",true)
            _effects(entry,phase,change.get("effects",[]),source+"/"+phase+"/effects",cache,availability,replaced)
        if not recipe.get("activation",{}).is_empty():
            _require(entry,"activation","trigger",source+"/activation/trigger",false,"condition_activation_not_compiled")
            _effects(entry,"activation",recipe.activation.get("effects",[]),source+"/activation/effects",cache,availability)
        for n in recipe.get("responses",[]).size():
            _require(entry,"response","trigger:"+str(n),source+"/responses/"+str(n)+"/trigger",false,"condition_response_not_compiled")
            _effects(entry,"response",recipe.responses[n].get("effects",[]),source+"/responses/"+str(n)+"/effects",cache,availability)
        for direction in recipe.get("interceptionEffectsByDirection",{}):
            _effects(entry,"interception",recipe.interceptionEffectsByDirection[direction],source+"/interceptionEffectsByDirection/"+direction,cache,availability,replaced)
        if recipe.get("reactionCastBinding")!=null:
            var bound=NativeSpells.recipe({"behavior_id":recipe.reactionCastBinding},cache)
            var assigned:bool=not bound.get("cast",{}).is_empty()
            _require(entry,"reaction","cast_binding",source+"/reactionCastBinding",assigned,
                "" if assigned else "condition_reaction_binding_recipe_missing","available" if assigned else "missing",
                {"binding":recipe.reactionCastBinding,"bound_source":"spells/"+str(recipe.reactionCastBinding)+".json:/cast"})
        # Resolve effective Resource fields only after collecting canonical
        # pointers, keeping the original JSON ownership available for inspection.
        entry.legacy_source=source
        entry.source=Catalog.source_pointer("catalog/condition_recipes.json",id,cache)
        for requirement in entry.requirements:
            requirement.legacy_source=requirement.source
            var boundary:int=requirement.source.find(":/")
            if boundary>=0 and not requirement.source.begins_with("res://"):
                requirement.source=Catalog.source_pointer(requirement.source.substr(0,boundary),requirement.source.substr(boundary+2),cache)
        _recorded(entry,recorded_rows)
        if entry.requirements.is_empty():entry.status="state_only" if entry.disposition=="state_only" else "missing"
        elif entry.requirements.any(func(row):return row.status=="missing"):entry.status="missing"
        elif entry.requirements.all(func(row):return row.status=="implemented"):entry.status="implemented"
        for row in entry.requirements:
            totals.requirements+=1;totals[row.status]+=1
            if row.get("gap_kind")=="authoring_assignment":totals.authoring_assignments+=1
        if entry.status=="state_only":totals.state_only+=1
        entries.append(entry)
    return {"entries":entries,"totals":totals,"scope":"Every current authored condition. Implementation/source availability are distinct from resolved recorded occurrences; rendered is always false here. Missing policy or phase remains missing even when its layer file exists. Native pixel/audio qualification is separate."}
