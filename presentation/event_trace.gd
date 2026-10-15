extends RefCounted
## Passive, bounded diagnostics. No canonical snapshots or packets are retained.
const Authoring = preload("res://presentation/authoring.gd")
const MovementMedia = preload("res://presentation/movement_media.gd")
const Requirements = preload("res://presentation/requirements.gd")
const NativeChannels=preload("res://presentation/native_spell_channels.gd")
const NativeSpells=preload("res://presentation/native_spell_authoring.gd")
const NativePersistent=preload("res://presentation/native_persistent.gd")
const SpellDelivery=preload("res://presentation/spell_delivery.gd")
const LIMIT = 2000

static func create() -> Dictionary:
    return {"rows":{},"order":[],"tracks":{},"logs":[],"log_ids":{},"revision":0,
        "evicted_events":0,"evicted_entries":0}

static func _component(kind: String, reason: String, source: String = "") -> Dictionary:
    return {"id":kind,"kind":kind,"trace_track_id":"","actor_uuid":"","rig":"","clip":"",
        "start_ms":0.0,"end_ms":0.0,"status":"missing","reason":reason,"source":source,
        "sample_count":0,"first_sample_ms":null,"last_sample_ms":null,
        "timing":{"resolved":false,"reason":"authored_timing_not_resolved"}}

static func _version_index(versions: Array) -> Dictionary:
    var lineages = {}; var events = {}
    for version in versions:
        if not lineages.has(version.lineage_uuid): lineages[version.lineage_uuid] = []
        lineages[version.lineage_uuid].append(version)
        events[version.event_uuid] = int(version.source_index)
    return {"lineages":lineages,"events":events}

static func _base(node: Dictionary, sequence: int, group: String, versions: Dictionary) -> Dictionary:
    var fact: Dictionary = node.fact if node.get("fact") != null else {}
    var history: Array = []
    var index: int = versions.events.get(node.uuid,-1)
    for version in versions.lineages.get(node.lineage_uuid,[]): history.append(version.duplicate())
    return {"id":"%s:%s" % [sequence,node.uuid],"sequence":sequence,"group_id":group,
        "event_uuid":node.uuid,"lineage_uuid":node.lineage_uuid,"source_index":index,
        "parent_event":node.get("parent_event"),"parent_lineage":node.get("parent_lineage"),
        "kind":fact.get("kind","undisclosed"),"phase":node.get("phase",""),
        "name":fact.get("name",fact.get("behavior_id",fact.get("kind","undisclosed"))),
        "behavior_id":fact.get("behavior_id"),
        "actor_uuid":fact.get("source_entity_uuid",fact.get("entity_uuid")),"target_uuid":fact.get("target_entity_uuid"),
        "status":"state_only","reasons":[],"components":[],"committed":false,"completed":false,
        "committed_log":null,"versions":history,"parent_id":"",
        "first_source_index":int(history[0].source_index) if not history.is_empty() else index,
        "_log":node.get("combat_log"),"_end_ms":0.0}

static func initialization(initial: Dictionary) -> Array:
    var result: Array = []
    var native_logs = _node_logs(initial.nodes)
    var versions = _version_index(initial.version_rows)
    for node in initial.nodes:
        var row = _base(node,0,"initialization",versions)
        row._display_log = _unique_children(row._log,native_logs) if row._log != null else null
        row.reasons = ["initial_snapshot_no_animation_claim"]
        row.completed = true
        result.append(row)
    result.sort_custom(func(a,b): return a.source_index < b.source_index)
    _bind_parents(result)
    return result

static func _has(row: Dictionary, kind: String, field: String = "", value: Variant = null) -> bool:
    return row.components.any(func(component):return component.kind==kind and (field.is_empty() or component.get(field)==value) and not component.trace_track_id.is_empty())

static func _need(row: Dictionary, kind: String, reason: String, source: String, field: String = "", value: Variant = null, pointer: String = "") -> void:
    if not _has(row,kind,field,value):
        var missing=_component(kind,reason,source)
        if not field.is_empty():missing[field]=value
        if not pointer.is_empty():missing.source_pointer=pointer
        row.components.append(missing)

static func _cast_requirements(row:Dictionary,cast:Dictionary,source:String,binding:String="")->void:
    if cast.is_empty() or not cast.get("enabled",true):return
    _need(row,"body","missing_authored_cast_body",source,"reaction_cast_binding" if not binding.is_empty() else "",binding)
    var layers:Array=[]
    for field in ["weaponGlow","aura"]:
        if cast.get(field)!=null:layers.append(cast[field])
    layers.append_array(cast.get("effects",[]))
    for layer in layers:
        if layer.get("enabled",true) and not layer.get("hidden",false):
            _need(row,"sprite_layer","authored_cast_layer_not_implemented",source+":"+str(layer.get("id","")),"authored_id",layer.get("id",""))

static func _media_needed(row: Dictionary, media: Array, source: String, base_ms: float=INF, pointer: String="",replaced:Array=[]) -> void:
    for index in media.size():
        var item:Dictionary=media[index]
        var asset: String=item.get("assetId","")
        if asset in replaced:continue
        if not asset.is_empty() and row.components.any(func(component):return asset in component.get("asset_ids",[]) and not component.trace_track_id.is_empty()):continue
        var missing=_component("media","authored_media_not_implemented",source+":"+str(item.get("id",asset)))
        missing.authored_id=item.get("id",asset);missing.asset_ids=[asset]
        if not pointer.is_empty():missing.source_pointer=pointer+"/"+str(index)
        if not is_inf(base_ms) and item.has("durationMs"):
            var start=base_ms+float(item.get("startOffsetMs",0))
            missing.timing={"resolved":true,"start_ms":start,"end_ms":start+float(item.durationMs),"reason":"authored_offset_duration_from_occurrence"}
        row.components.append(missing)

static func _recipe_missing(row: Dictionary, recipe: Dictionary, source: String, pointer: String) -> void:
    if recipe.is_empty():
        var unresolved=_component("recipe","action_presentation_owner_unresolved",pointer)
        unresolved.merge(Requirements.row("recipe","Presentation owner unassessed",pointer,"unassessed","missing",[row.kind],"owner","No selected recipe resolves this occurrence's own or delegated presentation. An absent recipe is not an explicit state-only decision."),true)
        row.components.append(unresolved);return
    if recipe.get("disposition") == "state_only": return
    _media_needed(row,recipe.get("media",[]),source+".media",row._start_ms,pointer+"/media")
    if not Requirements.accepted_action_strip(recipe):
        _media_needed(row,recipe.get("actor",{}).get("media",[]),source+".actor.media",row._start_ms,pointer+"/actor/media")
    elif not recipe.get("actor",{}).get("media",[]).is_empty():
        row.reasons.append("accepted_legacy_potion_source_strip_omission")
    if recipe.get("actor",{}).get("enabled",false) and not _has(row,"body"):
        var component = _component("body","authored_body_not_implemented",source+".actor")
        component.clip = recipe.actor.get("clip","")
        row.components.append(component)
    if recipe.get("actionFeedback") != null:
        _need(row,"feedback_text","authored_feedback_not_implemented",source+".actionFeedback","text",recipe.actionFeedback.get("text",""))
    if not recipe.get("effectAudioCue","").is_empty():
        _need(row,"audio","authored_action_audio_not_implemented",recipe.get("_source_fields",{}).get("effectAudioCue",pointer+"/effectAudioCue"),"cue_id",recipe.effectAudioCue)

static func _persistent_condition(row: Dictionary, condition: Dictionary, persistent: Dictionary, cache: Dictionary, rig_id: String) -> void:
    var prefix = str(condition.behavior_id)+"/persistent/"
    var source = "catalog/condition_recipes.json:/"+prefix.trim_suffix("/")
    var mechanisms: Array=[]
    var native=NativeSpells.condition(str(condition.behavior_id),cache)
    var replaced:Array=native.get("lifecycle",{}).get("replaces_media",[])
    for field in ["bodyColor","bodyRamp","bodyOutline","bodyPose","frozenPose"]:
        if persistent.get(field)!=null:mechanisms.append(field)
    if persistent.get("alphaMultiplier",1.0)!=1.0:mechanisms.append("alphaMultiplier")
    for layer in persistent.get("layers",[]):
        if layer.get("assetId","") not in replaced:mechanisms.append("layer:"+str(layer.id))
    var activity_poses:Array=persistent.get("activityPoses",[])
    for i in activity_poses.size():
        if activity_poses[i].rigId==rig_id:mechanisms.append("activityPoses:"+str(i))
    if not activity_poses.is_empty() and not activity_poses.any(func(pose):return pose.rigId==rig_id):
        row.components.append(_component("condition","authored_condition_pose_rig_unassigned",
            Authoring.Catalog.source_pointer("catalog/condition_recipes.json",prefix+"activityPoses",cache)))
    for mechanism in mechanisms:
        var key="condition:"+str(condition.condition_uuid)+":"+mechanism
        var property=mechanism.replace("activityPoses:","activityPoses/")
        var pointer=prefix+property
        var component=_component("condition", "",Authoring.Catalog.source_pointer("catalog/condition_recipes.json",pointer,cache))
        component.legacy_source="catalog/condition_recipes.json:/"+pointer
        component.merge({"id":key,"trace_track_id":key,"actor_uuid":row.actor_uuid,"mechanism":mechanism,
            "start_ms":row.get("_commit_ms",row._admit_ms),"persistent":true,"status":"playing"},true)
        row.components.append(component)
    _native_persistent_components(row,native,"condition:"+str(condition.condition_uuid),row.target_uuid,cache)
    # These authoring mechanisms remain separate requirements until a real
    # implementation emits their exact samples; a body or marker is insufficient.
    for field in ["equipmentModifiers","appearanceLayers"]:
        if not persistent.get(field,[]).is_empty():row.components.append(_component("condition","authored_condition_"+field+"_not_implemented",source+"."+field))
    for field in ["bodyScale","bodyDistortion","liveCopies","absenceEcho"]:
        if persistent.get(field)!=null:row.components.append(_component("condition","authored_condition_"+field+"_not_implemented",source+"."+field))

static func _native_persistent_components(row:Dictionary,selected:Dictionary,owner_id:String,actor_uuid:Variant,cache:Dictionary)->void:
    var native_index=0
    for phase in NativeSpells.condition_phases(selected):
        var sample=phase.duplicate()
        sample.merge({"id":owner_id+":native:"+str(native_index),"kind":"native_effect","native_spell":true,
            "actor_uuid":actor_uuid,"start_ms":row.get("_commit_ms",row._admit_ms),"duration_ms":INF},true)
        var component=_compiled_component(sample,cache)
        component.persistent=true
        row.components.append(component)
        for channel in NativeChannels.channels(sample):
            var child=_compiled_component(channel,cache)
            child.persistent=true
            row.components.append(child)
        native_index+=1

static func _compiled_component(component: Dictionary, cache: Dictionary) -> Dictionary:
    var row=_component(component.kind,component.get("reason",""),component.get("source",""))
    row.merge({"id":component.id,"trace_track_id":component.id,"actor_uuid":component.get("actor_uuid",""),
        "start_ms":component.start_ms,"end_ms":component.start_ms+component.duration_ms,
        "status":"missing" if component.get("status")=="missing" else "playing",
        "timing":{"resolved":true,"start_ms":component.start_ms,"end_ms":component.start_ms+component.duration_ms,"reason":"compiled_source_clock"}},true)
    # Only finite diagnostic identities are retained. No actor/world snapshots,
    # source tracks, materials or native handles enter the bounded live trace.
    for field in ["attachment","text","source_id","authored_id","cue_id","intercepted_by_condition_uuid"]:
        if component.has(field):row[field]=component[field]
    if component.has("layer"):
        row.slot=component.layer.get("slot","");row.authored_id=component.layer.get("id","")
    if component.kind=="native_effect":
        row.selected_weapon_pose=not component.get("weapon_pose",{}).is_empty()
        var selected:Dictionary=Authoring.load_data("native_effects/index.json",cache).get("sources",{}).get(component.get("source_id"),{})
        row.asset_ids=selected.get("media_ids",[component.asset_id] if component.has("asset_id") else []).duplicate()
    elif component.has("asset_id"):row.asset_ids=[component.asset_id]
    return row

static func _requirements(row: Dictionary, node: Dictionary, actor: Dictionary, cache: Dictionary, resolved_recipe: Dictionary, spell_sources: Dictionary = {}) -> void:
    var fact: Dictionary = node.fact if node.get("fact") != null else {}
    if node.get("canceled",false):
        # Canceling the hostile outcome does not cancel the condition response
        # which actually intercepted it. Preserve only that compiled evidence.
        row.components=row.components.filter(func(component):return component.has("intercepted_by_condition_uuid"))
        row.reasons=["canceled"];return
    if fact.is_empty(): row.reasons = ["fact_not_disclosed"]; return
    match row.kind:
        "sensory":
            # The disclosed after-value owns this diagnostic requirement. It
            # creates no effect and requires no private source actor identity.
            for id in fact.get("spatial_effects_changed",{}):
                var selected=NativePersistent.spatial_selection(fact.spatial_effects_changed[id],cache)
                _native_persistent_components(row,selected,"spatial:"+str(id),null,cache)
        "movement": row.reasons = ["movement_container_visuals_belong_to_steps"]
        "step":
            if not fact.get("committed",false): row.components = []; row.reasons = ["uncommitted_step"]; return
            _need(row,"body","missing_authored_movement", "catalog/movement_context.json")
            var phase:Dictionary={}
            for component in row.components:
                if component.kind=="body" and component.has("motion_phase"):phase=component.motion_phase
            for binding in MovementMedia.selected(actor,fact.get("trajectory",""),cache,phase):
                var media:Dictionary=binding.media
                if row.components.any(func(component):return media.assetId in component.get("asset_ids",[])):continue
                # A very short fast edge can fall between emission markers.
                # Source absence is still a gap; a zero-emission interval is not.
                var duration=0.0
                for component in row.components:
                    if component.kind=="body":duration=maxf(duration,component.end_ms-component.start_ms)
                if not MovementMedia.native_source(media.assetId,cache).is_empty() and media.role=="trail" and duration<float(media.get("emitIntervalMs",0)):continue
                var missing=_component("native_effect","authored_movement_media_not_implemented",binding.source)
                missing.asset_ids=[media.assetId];missing.authored_id=media.id
                row.components.append(missing)
        "attack":
            var recipe = resolved_recipe
            if recipe.is_empty():
                row.components.append(_component("body","missing_authored_attack_recipe","catalog/attack_recipes.json"))
            else:
                var source = "catalog/attack_recipes.json:"+str(fact.behavior_id)
                if recipe.get("actor",{}).get("enabled",false):_need(row,"body","missing_authored_clip",source+".actor")
                if recipe.get("projectile") != null:
                    if not _has(row,"geometry_projectile") and not _has(row,"native_effect","attachment","projectile"):
                        row.components.append(_component("projectile","authored_projectile_not_implemented",source+".projectile"))
                var outcome: String = {"Hit":"hit","Miss":"miss","Crit":"critical","Crit Miss":"critical_miss"}.get(fact.get("attack_outcome"),"")
                var effect: String = "onCrit" if outcome == "critical" else ("onHit" if outcome == "hit" else "onMiss")
                var vfx:Dictionary=recipe.get("attackVfx",{}).get(effect,{})
                var native_trail=row.components.any(func(component):return component.kind=="native_effect" and component.get("source_id")=="class.martial.slash" and component.get("selected_weapon_pose",false) and not component.trace_track_id.is_empty())
                for slot in vfx:
                    if slot=="slash" and native_trail and fact.get("damage_types",[]).all(func(type):return type in ["Bludgeoning","Piercing","Slashing"]):continue
                    _need(row,"sprite_layer","authored_attack_vfx_not_implemented",source+".attackVfx."+effect+"."+slot,"slot",slot)
                if recipe.get("attackFeedback",{}) != null and recipe.get("attackFeedback",{}).get(outcome) != null:
                    _need(row,"feedback_text","authored_attack_feedback_not_implemented",source+".attackFeedback."+outcome,"text",recipe.attackFeedback[outcome].get("text",""))
                var trail: Dictionary = recipe.get("weaponTrail",{}) if recipe.get("weaponTrail") != null else {}
                if recipe.get("projectile")==null and fact.get("attack_source_kind")=="equipped" and (fact.behavior_id in trail.get("behaviorIds",[]) or outcome in trail.get("outcomes",[])):
                    var trail_pointer="catalog/attack_recipes.json:/"+str(fact.behavior_id)+"/weaponTrail"
                    for variant_index in recipe.get("variants",[]).size():
                        var variant:Dictionary=recipe.variants[variant_index]
                        if variant.id==recipe.get("selected_variant","") and variant.has("weaponTrail"):trail_pointer="catalog/attack_recipes.json:/"+str(fact.behavior_id)+"/variants/"+str(variant_index)+"/weaponTrail"
                    if not native_trail:_need(row,"weapon_trail","authored_weapon_trail_not_implemented",source+".weaponTrail","",null,trail_pointer)
                    elif fact.get("attack_outcome") in ["Hit","Crit"]:_need(row,"native_effect","authored_weapon_impact_not_implemented",source+".weaponTrail.impactAssetId","source_id","class.martial.impact")
        "damage":
            if fact.get("stage") != "applied" or fact.get("applied_damage",0) <= 0:
                row.reasons = ["no_applied_damage_visual"]; return
            # Terminal/lethal damage deliberately has no TakeDamage body; its
            # actual Life fact owns the death pose. Keep that choice inspectable.
            if row.get("damage_timing",{}).get("body_enabled",true):
                _need(row,"body","missing_authored_clip","catalog/damage_context.json.bodyClip")
            var context = Authoring.load_data("catalog/damage_context.json",cache)
            for field in ["flashEnabled","numberEnabled"]:
                if context.get(field,false):_need(row,"material_flash" if field=="flashEnabled" else "damage_number","authored_damage_feedback_not_implemented","catalog/damage_context.json."+field)
            var release:Dictionary=fact.get("body_release",{}) if fact.get("body_release")!=null else {}
            if release.get("release_id")=="body.blood" and not release.get("regions",[]).is_empty() and not _has(row,"residue_deposit"):
                var residue=_component("residue_deposit","authoritative_residue_renderer_not_implemented","world.json:/residue_ground/residue.blood")
                residue.source_pointer=residue.source
                residue.actor_uuid=fact.target_entity_uuid
                residue.gap_kind="renderer"
                residue.authority_source="DamageResultFact.body_release.regions"
                residue.body_release=release.duplicate(true)
                residue.timing={"resolved":false,"reason":"persistent_residue_follows_authoritative_tile_state"}
                row.components.append(residue)
        "life":
            var role = "death" if fact.new_state == "dead" else "life"
            var body = Authoring.body(role,actor,fact,cache)
            if body.get("actor",{}).get("enabled",false) and not _has(row,"body"):
                row.components.append(_component("body","missing_authored_clip","catalog/"+role+"_context.json"))
            if role == "death":
                if fact.get("remains_disposition","intact")=="disintegrated" and not Authoring.load_data("catalog/death_context.json",cache).get("silhouetteDust",{}).is_empty():
                    row.components.append(_component("death_dust","authored_death_dust_not_implemented","catalog/death_context.json.silhouetteDust"))
            else:
                var key: String = "revived" if fact.new_state == "alive" else fact.new_state
                var feedback: Dictionary=Authoring.load_data("catalog/life_state_context.json",cache).get(key,{})
                if feedback.get("enabled",false):
                    _need(row,"feedback_text","authored_life_feedback_not_implemented","catalog/life_state_context.json."+key,"text",feedback.get("text",""))
        "equipment":
            if resolved_recipe.get("actor",{}).get("enabled",false):
                _need(row,"body","authored_equipment_body_not_implemented",resolved_recipe.source)
        "heal":
            var healing: Dictionary=Authoring.load_data("catalog/healing_context.json",cache)
            if fact.get("actual_healing",0) > 0 and healing.get("feedbackEnabled",false):
                _need(row,"feedback_text","authored_healing_feedback_not_implemented","catalog/healing_context.json","text",str(fact.actual_healing)+" "+str(healing.feedbackLabel))
        "forced_movement":
            if fact.get("start_position") != fact.get("end_position"):
                _need(row,"body","authored_forced_movement_not_implemented","catalog/forced_movement_context.json","motion",true)
        "death_save":
            var key="criticalSuccess" if fact.natural_roll==20 else ("criticalFailure" if fact.natural_roll==1 else ("success" if fact.succeeded else "failure"))
            var feedback: Dictionary=Authoring.load_data("catalog/death_save_context.json",cache).get(key,{})
            if feedback.get("enabled",false):_need(row,"feedback_text","authored_death_save_feedback_not_implemented","catalog/death_save_context.json:/"+key,"text",feedback.get("text",""))
        "condition":
            var key: String = str(fact.condition.get("behavior_id",""))
            row.behavior_id = key
            row.name = fact.condition.get("name",key)
            var recipe: Dictionary = resolved_recipe
            if fact.event_type not in ["condition_application","condition_removal"]:
                row.reasons=["condition_state_change_no_application_replay"]
            else:
                var phase = "removal" if fact.event_type == "condition_removal" else "application"
                var change: Dictionary = recipe.get(phase,{})
                var source="catalog/condition_recipes.json:"+key+"."+phase
                if change.get("feedbackEnabled",false):
                    _need(row,"feedback_text","authored_condition_feedback_not_implemented",
                        Authoring.Catalog.source_pointer("catalog/condition_recipes.json",key+"/"+phase+"/feedbackEnabled",cache))
                var replaced:Array=NativeSpells.condition(key,cache).get("lifecycle",{}).get("replaces_media",[])
                _media_needed(row,change.get("effects",[]),source+".effects",row._commit_ms,"catalog/condition_recipes.json:/"+key+"/"+phase+"/effects",replaced)
                if phase=="application":_persistent_condition(row,fact.condition,recipe.get("persistent",{}),cache,Authoring.rig_id(actor,cache))
                if phase=="application" and recipe.get("reactionCastBinding")!=null:
                    var binding:String=recipe.reactionCastBinding
                    var cast_recipe:Dictionary=spell_sources[binding].recipe if spell_sources.has(binding) else NativeSpells.recipe({"behavior_id":binding},cache)
                    var pointer=Authoring.Catalog.source_pointer("catalog/condition_recipes.json",key+"/reactionCastBinding",cache)
                    if cast_recipe.is_empty():_need(row,"body","condition_reaction_binding_recipe_missing",pointer)
                    else:_cast_requirements(row,cast_recipe.get("cast",{}),pointer,binding)
        "action", "shove":
            var file = "catalog/shove_recipes.json" if row.kind == "shove" else "catalog/body_action_recipes.json"
            var recipe_id: String = str(fact.get("behavior_id",""))
            if row.kind == "action":
                recipe_id = Authoring.load_data("catalog/body_action_bindings.json",cache).get(recipe_id,{}).get("source_recipe",recipe_id)
            _recipe_missing(row,resolved_recipe,resolved_recipe.get("_resource_source",file+":"+recipe_id),file+":/"+recipe_id)
        "spell":
            var recipe:Dictionary=resolved_recipe
            if recipe.is_empty():row.components.append(_component("spell","spell_presentation_not_implemented"))
            else:
                var source="spells/"+str(fact.behavior_id)+".json"
                var cast:Dictionary=recipe.get("cast",{})
                if row.get("cast_owner_event",node.uuid)==node.uuid and not cast.is_empty() and cast.get("enabled",true):
                    _cast_requirements(row,cast,source+".cast")
                var behavior:String=str(fact.behavior_id)
                var selected:Dictionary=spell_sources[behavior].selection if spell_sources.has(behavior) else NativeSpells.selection(behavior,cache)
                var shared_area:bool=not selected.is_empty() and SpellDelivery.selected_for(selected,fact).get("delivery",{}).get("scope")=="area"
                if fact.get("application")!=null and not shared_area and recipe.get("projectile")!=null and not _has(row,"native_effect","attachment","projectile") and not _has(row,"geometry_projectile"):
                    row.components.append(_component("projectile","authored_projectile_not_implemented",source+".projectile"))
    _operation_requirements(row,node,resolved_recipe,cache)
    if row.components.is_empty() and row.reasons.is_empty():
        row.reasons = ["state_only_no_animation_claim" if row.kind in Requirements.STATE_ONLY else "no_independent_component_selected"]
    # A visual actor was never disclosed; this is not evidence of missing art.
    if row.actor_uuid != null and actor.get("last_visual_position") == null and not row.components.is_empty():
        row.components = []; row.status = "not_visible"; row.reasons = ["actor_not_visually_disclosed"]

static func _operation_requirements(row:Dictionary,node:Dictionary,recipe:Dictionary,cache:Dictionary)->void:
    var source:String=recipe.get("_legacy_source","")
    if source.is_empty():
        if row.kind=="spell":source="spells/"+str(node.fact.get("behavior_id",""))+".json:"
        elif row.kind in ["action","shove","attack"]:source="catalog/"+{"action":"body_action_recipes","shove":"shove_recipes","attack":"attack_recipes"}[row.kind]+".json:/"+str(node.fact.get("behavior_id",""))
        else:source="catalog/"+str(row.kind)+"_context.json:"
    for expected in Requirements.occurrence(node.fact,recipe,source,cache):
        if expected.status!="missing":continue
        # A shared cast's equipment/recovery belongs only to the cast owner.
        if expected.participant=="caster" and row.get("cast_owner_event",node.uuid)!=node.uuid:continue
        var matched=false
        for component in row.components:
            if component.trace_track_id.is_empty():continue
            if component.source==expected.source and component.kind==expected.kind:matched=true
            for asset in expected.get("asset_ids",[]):
                if not str(asset).is_empty() and asset in component.get("asset_ids",[]) and not str(expected.get("authored_id","")).is_empty() and component.get("authored_id")==expected.authored_id:matched=true
        if matched:continue
        if row.components.any(func(c):return c.get("source_pointer",c.source)==expected.source and c.kind==expected.kind):continue
        var required=_component(expected.kind,expected.reason,expected.source)
        required.merge(expected,true)
        required.trace_track_id=""
        row.components.append(required)

static func compile_rows(lineage: Dictionary, group: Dictionary, graph: Dictionary, cache: Dictionary) -> Array:
    var result: Array = []
    var commits = {}
    var native_logs = _node_logs(lineage.events)
    var versions = _version_index(lineage.version_rows)
    var tracks = {}; var components = {}
    for track in group.actor_tracks:
        if int(track.priority) < 10: continue
        if not tracks.has(track.source_event_uuid): tracks[track.source_event_uuid] = []
        tracks[track.source_event_uuid].append(track)
    for component in group.get("components",[]):
        if not components.has(component.source_event_uuid): components[component.source_event_uuid] = []
        components[component.source_event_uuid].append(component)
    for commit_row in group.commits:
        if commit_row.has("event_uuid"): commits[commit_row.event_uuid] = float(commit_row.at_ms)
    for node in lineage.events:
        var row = _base(node,int(group.operation_sequence),group.id,versions)
        row._display_log = _unique_children(row._log,native_logs) if row._log != null else null
        row._end_ms = graph.ends.get(node.uuid,0.0)
        row._start_ms = graph.starts.get(node.uuid,0.0)
        row._group_duration_ms = group.duration_ms
        row._admit_ms = commits.get(node.uuid,group.duration_ms)
        row._commit_ms = row._admit_ms
        if graph.get("damage_timings",{}).has(node.uuid):
            var timing:Dictionary=graph.damage_timings[node.uuid]
            row.damage_timing={}
            for field in ["start","hp","flash","number","body_enabled","terminal","lethal"]:
                row.damage_timing[field]=timing[field]
        if row.kind=="spell":
            var cast_key:String=SpellDelivery.cast_key(node,graph)
            row.cast_owner_event=graph.get("casts",{}).get(cast_key,{}).get("source_event_uuid",node.uuid)
        if row.kind in ["damage","condition","heal","forced_movement"]: row.actor_uuid = row.target_uuid
        for track in tracks.get(node.uuid,[]):
            row._admit_ms = minf(row._admit_ms,float(track.start_ms))
            var component = _component("body","", "catalog/rigs.json:"+track.rig+".clips."+track.clip)
            component.merge({"id":track.trace_track_id,"trace_track_id":track.trace_track_id,"actor_uuid":track.actor_uuid,
                "rig":track.rig,"clip":track.clip,"start_ms":track.start_ms,"end_ms":track.start_ms+track.duration_ms,
                "status":"playing","holding_pose":track.get("holding_pose",false),"motion":track.get("motion",false)},true)
            if track.has("motion_fraction_from"):
                component.motion_phase={"from":track.motion_fraction_from,"to":track.motion_fraction_to}
            if track.has("reaction_cast_binding"):
                component.reaction_cast_binding=track.reaction_cast_binding
                component.source=track.source
                component.condition_uuid=track.condition_uuid
            row.components.append(component)
        for component in components.get(node.uuid,[]):
            row.components.append(_compiled_component(component,cache))
            for channel in NativeChannels.channels(component):row.components.append(_compiled_component(channel,cache))
        var actor: Dictionary = graph.actor_inputs.get(node.uuid,{}).get(row.actor_uuid,{})
        _requirements(row,node,actor,cache,graph.recipes.get(node.uuid,{}),graph.get("spell_sources",{}))
        if row.components.is_empty(): row._admit_ms = commits.get(node.uuid,group.duration_ms)
        result.append(row)
    result.sort_custom(func(a,b): return a.source_index < b.source_index)
    _bind_parents(result)
    return result

static func _refresh(row: Dictionary) -> bool:
    var previous: Array = [row.status,row.reasons.duplicate()]
    if row.components.is_empty(): return false
    var missing: Array = []
    var hidden: Array = []
    var pending = false
    for component in row.components:
        if component.status == "missing": missing.append(component.reason)
        elif component.status == "not_visible": hidden.append(component.reason)
        elif component.status not in ["presented","inactive"]: pending = true
    row.reasons = missing if not missing.is_empty() else hidden
    if not missing.is_empty(): row.status = "missing"
    elif pending or not row.completed: row.status = "playing"
    elif not hidden.is_empty(): row.status = "not_visible"
    else: row.status = "presented"
    return previous != [row.status,row.reasons]

static func _append_log(trace: Dictionary, id: String, event: Dictionary, entry: Dictionary, flatten: bool) -> void:
    if trace.log_ids.has(id): return
    var copied = entry.duplicate(true)
    if flatten: copied.sub_entries = []
    trace.logs.append({"id":id,"event_id":event.get("id",""),"sequence":event.sequence,
        "source_index":event.source_index,"first_source_index":event.get("first_source_index",event.source_index),
        "parent_id":event.get("_log_parent_id",""),"entry":copied})
    trace.log_ids[id] = true
    while trace.logs.size() > LIMIT:
        trace.log_ids.erase(trace.logs.pop_front().id)
        trace.evicted_entries += 1
    trace.revision += 1

static func activate(trace: Dictionary, rows: Array, start_ms: float) -> void:
    for source in rows:
        if trace.rows.has(source.id): continue
        # Runtime changes only the event shell and each component's status and
        # sample counters. Authored histories/logs/material payloads are passive;
        # public snapshot/log accessors still return independent deep copies.
        var row: Dictionary = source.duplicate()
        row.components = []
        for component in source.components: row.components.append(component.duplicate())
        row._start_ms = start_ms
        row._admitted = float(row.get("_admit_ms",0.0)) <= 0.0
        _refresh(row)
        trace.rows[row.id] = row
        trace.order.append(row.id)
        for component in row.components:
            if component.trace_track_id.is_empty():continue
            if not trace.tracks.has(component.trace_track_id):trace.tracks[component.trace_track_id]=[]
            trace.tracks[component.trace_track_id].append({"row":row,"component":component})
        while trace.order.size() > LIMIT:
            var expired: Dictionary = trace.rows[trace.order.pop_front()]
            for component in expired.components:
                var key: String=component.trace_track_id
                if not trace.tracks.has(key):continue
                trace.tracks[key]=trace.tracks[key].filter(func(binding):return binding.row.id!=expired.id)
                if trace.tracks[key].is_empty():trace.tracks.erase(key)
            trace.rows.erase(expired.id)
            trace.evicted_events += 1
        trace.revision += 1

static func commit(trace: Dictionary, sequence: int, event_uuid: String) -> void:
    var row: Dictionary = trace.rows.get("%s:%s" % [sequence,event_uuid],{})
    if row.is_empty() or row.committed: return
    row.committed = true
    row._admitted = true
    if row._log != null:
        row.committed_log = row._log
        _append_log(trace,row.id,row,row.get("_display_log",row._log),false)
    row.erase("_log")
    row.erase("_display_log")
    trace.revision += 1

static func append_logs(trace: Dictionary, logs: Array) -> void:
    for record in logs:
        _append_log(trace,record.id,record,record.entry,record.get("flatten",false))

static func tick(trace: Dictionary, rows: Array, local_ms: float) -> void:
    for source in rows:
        var row: Dictionary = trace.rows.get(source.id,{})
        if row.is_empty(): continue
        if not row._admitted and local_ms+0.000001 >= float(row.get("_admit_ms",0.0)):
            row._admitted = true
            trace.revision += 1
        if row.completed or local_ms+0.000001 < float(row._end_ms): continue
        row.completed = true
        for component in row.components:
            if component.status == "playing":
                component.status = "missing"; component.reason = "no_rendered_sample"
        _refresh(row)
        trace.revision += 1

static func record(trace: Dictionary, evidence: Array) -> void:
    for sample in evidence:
        # A refreshed condition UUID can belong to several retained events.
        # Each binding retains its own admission and time boundary; eviction
        # removes it from this same bounded index.
        for found in trace.tracks.get(sample.get("trace_track_id",""),[]):
            var row: Dictionary = found.row
            if not row._admitted: continue
            var component: Dictionary = found.component
            var previous: Array = [component.status,component.reason]
            if sample.get("visible",false):
                var at = float(sample.get("display_ms",-1.0))
                var end = INF if component.get("persistent",false) else (float(row._group_duration_ms) if component.get("holding_pose",false) else float(component.end_ms))
                if at < row._start_ms+component.start_ms or at > row._start_ms+end: continue
                if component.last_sample_ms != null and at <= float(component.last_sample_ms): continue
                component.status = "presented"; component.reason = ""
                component.sample_count += 1
                if component.first_sample_ms == null: component.first_sample_ms = at
                component.last_sample_ms = at
            elif component.sample_count == 0 and sample.get("inactive",false):
                component.status="inactive";component.reason=sample.get("reason","not_selected")
            elif component.sample_count == 0:
                var reason: String = sample.get("reason","renderer_missing")
                component.status = "not_visible" if reason in ["offscreen","not_visible"] else "missing"
                component.reason = reason
            var changed = _refresh(row)
            # Sampling statistics remain available on demand, without rebuilding
            # a visible UI every frame after the coverage status stabilizes.
            if changed or previous != [component.status,component.reason]: trace.revision += 1

static func snapshot(trace: Dictionary, limit: int, selected: String, queued: int, status_filter: String = "") -> Dictionary:
    var admitted = {}
    var counts = {}
    for id in trace.order:
        var row: Dictionary = trace.rows[id]
        if not row._admitted:
            queued += 1
            continue
        admitted[id] = row
        var public_status: String = _coverage(row).status
        counts[public_status] = int(counts.get(public_status,0))+1
    var ordered = _hierarchy(admitted,trace.rows)
    var events: Array = []
    var selection: Dictionary = {}
    for placement in ordered:
        if placement.row.id == selected:
            selection = _public(placement.row,true)
            selection.parent_id = placement.parent_id
            selection.depth = placement.depth
            break
    for placement in _window(ordered,limit,status_filter):
        var row = _public(placement.row,false)
        row.parent_id = placement.parent_id
        row.depth = placement.depth
        row.context = not status_filter.is_empty() and row.status != status_filter
        events.append(row)
    return {"revision":trace.revision,"events":events,"selected":selection,
        "counts":counts,"queued_events":queued,"retained_events":trace.order.size(),"evicted_events":trace.evicted_events}

static func _public(row: Dictionary, detailed: bool) -> Dictionary:
    var result = {}
    for key in row:
        if str(key).begins_with("_"): continue
        if not detailed and key in ["versions","committed_log"]: continue
        result[key] = row[key]
    var coverage = _coverage(row)
    for key in ["status","reasons","components","completed"]: result[key] = coverage[key]
    return result.duplicate(true)

static func _coverage(row: Dictionary) -> Dictionary:
    if row.committed or row.components.is_empty(): return row
    # A chosen attack recipe can encode a future hit/miss/critical result.
    # Before the native commit, expose only body tracks already scheduled for
    # presentation; even aggregate red/green counts must use this same view.
    var visible = {"components":row.components.filter(func(c): return c.kind == "body" and not c.trace_track_id.is_empty()),
        "status":"playing","reasons":[],"completed":false}
    _refresh(visible)
    return visible

static func logs(trace: Dictionary, limit: int) -> Dictionary:
    var admitted = {}
    var retained = {}
    for row in trace.logs: retained[row.id] = row
    for row in trace.logs:
        var parent: String = row.parent_id
        var seen = {}
        var ready = true
        # Native summaries can contain future results. Like the original
        # Pygame log, wait for known logged ancestors instead of showing their
        # children first or publishing a parent's summary prematurely.
        while not parent.is_empty() and not seen.has(parent):
            seen[parent] = true
            var ancestor: Dictionary = trace.rows.get(parent,{})
            if not ancestor.is_empty() and not ancestor.committed:
                ready = false; break
            parent = retained.get(parent,{}).get("parent_id","")
        if ready: admitted[row.id] = row
    var entries: Array = []
    for placement in _window(_hierarchy(admitted,retained),limit,""):
        var row: Dictionary = placement.row.duplicate(true)
        row.parent_id = placement.parent_id
        row.depth = placement.depth
        entries.append(row)
    return {"revision":trace.revision,"entries":entries,"evicted_entries":trace.evicted_entries}

static func _bind_parents(rows: Array) -> void:
    var by_lineage = {}
    var by_event = {}
    for row in rows:
        by_lineage[row.lineage_uuid] = row
        by_event[row.event_uuid] = row
        for version in row.versions: by_event[version.event_uuid] = row
    for row in rows:
        var parent: Dictionary = by_lineage.get(row.parent_lineage,by_event.get(row.parent_event,{}))
        row.parent_id = parent.get("id","")
        var seen = {row.id:true}
        while not parent.is_empty() and not seen.has(parent.id):
            seen[parent.id] = true
            if parent.get("_log") != null:
                row._log_parent_id = parent.id
                break
            parent = by_lineage.get(parent.parent_lineage,by_event.get(parent.parent_event,{}))

static func _hierarchy(admitted: Dictionary, retained: Dictionary) -> Array:
    var children = {}
    for row in admitted.values():
        var parent: String = row.get("parent_id","")
        var seen = {row.id:true}
        while not parent.is_empty() and not admitted.has(parent):
            if seen.has(parent): parent = ""; break
            seen[parent] = true
            parent = retained.get(parent,{}).get("parent_id","")
        if parent == row.id: parent = ""
        if not children.has(parent): children[parent] = []
        children[parent].append(row)
    for siblings in children.values():
        siblings.sort_custom(func(a,b):
            if a.sequence != b.sequence: return a.sequence < b.sequence
            var ai = a.get("first_source_index",a.source_index)
            var bi = b.get("first_source_index",b.source_index)
            return ai < bi if ai != bi else a.id < b.id)
    var result: Array = []
    var pending: Array = []
    var roots: Array = children.get("",[])
    for i in range(roots.size()-1,-1,-1): pending.append({"row":roots[i],"parent_id":"","depth":0})
    var visited = {}
    while not pending.is_empty():
        var placement: Dictionary = pending.pop_back()
        if visited.has(placement.row.id): continue
        visited[placement.row.id] = true
        result.append(placement)
        var nested: Array = children.get(placement.row.id,[])
        for i in range(nested.size()-1,-1,-1):
            pending.append({"row":nested[i],"parent_id":placement.row.id,"depth":placement.depth+1})
    return result

static func _window(ordered: Array, limit: int, status_filter: String) -> Array:
    var capacity = clampi(limit,0,LIMIT)
    var by_id = {}
    for placement in ordered: by_id[placement.row.id] = placement
    var included = {}
    for index in range(ordered.size()-1,-1,-1):
        var placement: Dictionary = ordered[index]
        if not status_filter.is_empty() and _coverage(placement.row).status != status_filter: continue
        var chain: Array = []
        while not included.has(placement.row.id):
            chain.append(placement.row.id)
            if not by_id.has(placement.parent_id): break
            placement = by_id[placement.parent_id]
        if included.size()+chain.size()>capacity: continue
        for id in chain: included[id] = true
    return ordered.filter(func(p):return included.has(p.row.id))

static func operation_logs(packet: Dictionary) -> Array:
    # The append protocol can repeat the native log already attached to a node.
    # Match within this operation only; repeated text in later actions is valid.
    var available: Array = []
    for lineage in packet.lineages:
        for node in lineage.events:
            if node.combat_log != null: available.append(node.combat_log)
    var native_logs = available.duplicate()
    var result: Array = []
    for append in packet.get("combat_log_appends",[]):
        var index = available.find(append.entry)
        if index >= 0: available.remove_at(index); continue
        result.append({"id":"append:%s:%s" % [append.generation,append.encounter_log_index],"event_id":"",
            "sequence":int(packet.cursor.sequence),"source_index":append.operation_end_cursor,"entry":_unique_children(append.entry,native_logs)})
    return result


static func _node_logs(nodes: Array) -> Array:
    var logs: Array = []
    for node in nodes:
        if node.get("combat_log") != null: logs.append(node.combat_log)
    return logs

static func _unique_children(entry: Dictionary, native_logs: Array) -> Dictionary:
    # Child trees are rebuilt below. Copying them here would duplicate every
    # descendant before immediately discarding that copy at each ancestor.
    var result = entry.duplicate()
    for field in result:
        if field=="sub_entries": continue
        var value: Variant = result[field]
        if value is Dictionary or value is Array: result[field]=value.duplicate(true)
    result.sub_entries = []
    var unmatched: Array=native_logs.duplicate()
    for child in entry.get("sub_entries",[]):
        var match_index=-1
        for index in range(unmatched.size()):
            if _same_embedded_log(child,unmatched[index]): match_index=index; break
        if match_index>=0: unmatched.remove_at(match_index)
        else: result.sub_entries.append(_unique_children(child,unmatched))
    return result

static func _same_embedded_log(child: Dictionary, native: Dictionary) -> bool:
    if child == native: return true
    # Subjective projection gives standalone steps path_index=0, then numbers
    # the same children inside an aggregate movement (subjective_combat_log.py).
    # Only this finite, typed difference is normalized; source logs stay intact.
    if child.get("data") == null or native.get("data") == null: return false
    if child.data.get("kind") != "step_movement" or native.data.get("kind") != "step_movement": return false
    var compared = child.duplicate()
    compared.data = child.data.duplicate()
    compared.data.path_index = native.data.get("path_index")
    return compared == native
