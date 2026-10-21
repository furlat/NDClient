extends RefCounted
## Passive expectations from the received fact contract and selected authoring.
## This does not compile, schedule, select outcomes, or certify rendered pixels.
const Authoring=preload("res://presentation/authoring.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const SCHEMA="res://sdk/player-api-v1.schema.json"
const REFERENCE="dnd_engine/game_obsolete/"
const STATE_ONLY=["temporary_hit_points","spatial","turn","sensory","item_charge","faction"]
const ACTOR_ACCOUNTING=["normal_hp","maximum_hp","temporary_hp","temporary_hp_grant","armor_class","inventory","condition_duration"]
const ITEM_ACCOUNTING=["stack_count","charges","concentration_slots","is_lit"]
const ACCEPTED_ACTION_STRIPS=["action.item.potion_greater_invisibility.drink","action.item.potion_haste.drink","action.item.potion_healing.drink"]
const FACT_OWNERS={
    "action":"body action and actual child outcomes", "attack":"attack and recipient contact",
    "spell":"cast and application delivery", "area_reach":"area propagation and structural clearance",
    "movement":"container of actual movement steps", "step":"movement body and attachments",
    "forced_movement":"recipient displacement", "shove":"source body and actual child displacement",
    "damage":"recipient body, material and feedback", "heal":"recipient healing feedback",
    "life":"lifecycle body and retained remains", "death_save":"actual outcome feedback",
    "saving_throw":"factual save; optional authored avoidance", "equipment":"appearance transition",
    "condition":"owner lifetime and selected appearance", "item_effect":"item attachment membership and clock",
    "portal_transfer":"independently disclosed departure and arrival", "spatial_effect_state":"observed field lifecycle",
    "mechanism_activation":"finite mechanism discharge and contact", "object_destroyed":"witnessed destruction and remnant",
    "object_damage":"confirmed object damage response"
}
# These have canonical/world consumers but no independently indexed operation.
# Their finite animation coverage must not be inferred from a final-state sprite.
const FACT_INSPECTION=["equipment","object_destroyed","spatial_effect_state"]
const FACT_UNASSESSED=["area_reach","saving_throw","item_effect","object_damage"]
const REFERENCES={
    "equipment_override":"animation.py::sample_cast", "body_recovery":"animation.py::compile_cast + sample_cast",
    "cast_slash":"animation_draw.py::animation_draw_commands", "bodyMaterials":"cast_media.py::sample_cast_body_materials",
    "arcs":"animation.py::_compile_anchored_cast", "directed":"directed_media.py::directed_draw_commands",
    "displacementLayers":"choreography.py::bind_choreography", "cancellationMedia":"cast_media.py",
    "childAttack":"choreography.py::bind_choreography", "counterspellFeedback":"body_action.py::bind_body_action",
    "area_geometry":"animation.py::sample_cast", "area_sprite":"animation_draw.py::animation_draw_commands",
    "area_surfaceReveal":"world_animation.py::surface_reveal_delay", "media":"cast_media.py",
    "action_material":"choreography.py::sample_choreography", "action_intake":"choreography_draw.py",
    "body_material":"animation_draw.py::_body_image", "portal":"portal_animation.py + portal_draw.py",
    "item_attachment":"item_attachment_lifetime.py + item_draw.py", "contact_media":"spatial_contact_media.py",
    "world_animation":"world_animation.py::world_transition_end", "interruption_effects":"interruption_draw.py",
    "damage_clock":"animation.py::compile_damage", "damage_flash":"animation.py::resolve_damage",
    "damage_number":"animation.py::resolve_damage", "damage_death":"animation.py::compile_damage",
    "condition_policy":"choreography.py::bind_choreography", "contact_policy":"animation.py::_compile_anchored_cast",
    "death_dust":"animation_draw.py::_actor_blit", "entity_arrival":"choreography.py::bind_choreography",
    "entity_bond":"choreography.py::bind_choreography", "entity_departure":"choreography.py::bind_choreography"
}

static func pointer(value:String)->String:
    return value.replace("~","~0").replace("/","~1")

static func accepted_action_strip(recipe:Dictionary)->bool:
    return recipe.get("definitionRef",{}).get("content_id","") in ACCEPTED_ACTION_STRIPS

static func row(kind:String,label:String,source:String,implementation:String="missing",inspection:String="missing",events:Array=[],participant:String="owner",reason:String="")->Dictionary:
    var gap="renderer" if implementation=="missing" else ("unassessed" if implementation=="unassessed" else ("inspection" if inspection=="missing" else "unexercised"))
    if implementation=="not_applicable":gap="explicit_none"
    return {"id":"operation:"+source+":"+kind,"kind":kind,"mechanism":kind,"label":label,"source":source,"source_pointer":source,
        "event_kinds":events,"participant":participant,"implementation":implementation,"inspection":inspection,
        "gap_kind":gap,"status":"missing" if gap in ["renderer","inspection","unassessed"] else ("explicit_none" if gap=="explicit_none" else "unexercised"),
        "reason":reason if not reason.is_empty() else ("Authored operation has no shared renderer consumer." if gap=="renderer" else ("Current state is rendered; the operation has no separate inspection track." if gap=="inspection" else "Selected operation requires source-to-renderer assessment.")),
        "next_step":{"renderer":"Implement this authored operation in the shared presentation pipeline.","inspection":"Expose the existing operation and its evidence in Studio; do not invent a second renderer.","unassessed":"Trace this declared owner through binding, rendering and Studio before assigning support.","explicit_none":"No independent presentation is required by this explicit choice.","unexercised":"Qualify this operation on an actual occurrence."}[gap],
        "availability":"not_examined","rendered":false,"reference_source":REFERENCE+REFERENCES.get(kind,"presentation_coverage.py::presentation_inventory"),
        "timing":{"resolved":false,"reason":"No source-backed schedule resolved for this operation."}}

static func fact(kind:String,cache:Dictionary={})->Dictionary:
    # This is lookup only: compilation has already admitted its source owner.
    # Unknown/custom contract kinds keep their explicit extraction below.
    var index:Resource=cache.get(Sources.CACHE_KEY,{}).get("index")
    if index!=null and index.fact_requirements.has(kind):return index.fact_requirements[kind]
    var source=SCHEMA+":/$defs/PlayerNode/properties/fact/anyOf/0/discriminator/mapping/"+pointer(kind)
    if kind=="actor_change":
        var container=row("fact:actor_change","Ordered actor rows",source,"implemented","projected",[kind],"container","The container owns ordered publication only; each actual row has a separate declared owner and assessment. No body or render witness follows from this classification.")
        container.disposition="ordered_rows"
        return container
    if kind in STATE_ONLY:
        return row("fact:"+kind,"State publication · "+kind,source,"not_applicable","projected",[kind],"state","Canonical publication; no separate actor animation is required. State changes can still affect lights, visibility, or other retained owners.")
    var implementation="unassessed" if not FACT_OWNERS.has(kind) or kind in FACT_UNASSESSED else "implemented"
    var inspection="missing" if implementation=="unassessed" or kind in FACT_INSPECTION else "projected"
    var result=row("fact:"+kind,FACT_OWNERS.get(kind,"Unassessed fact presentation · "+kind),source,implementation,inspection,[kind])
    result.reference_source=REFERENCE+"choreography.py::FACT_PRESENTATION"
    if kind in ["portal_transfer","mechanism_activation"]:
        result.reason="Actual committed facts have shared source-backed consumers. Each selected source still reports unsupported or missing placement/geometry independently; runtime output and artwork remain unqualified."
    if not FACT_OWNERS.has(kind):result.reason="Current schema fact has no classified presentation owner; it is not implicitly state-only."
    return result

static func facts(cache:Dictionary)->Array:
    const KEY="presentation:fact_discriminators"
    if not cache.has(KEY):
        var schema:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SCHEMA))
        cache[KEY]=schema["$defs"].PlayerNode.properties.fact.anyOf[0].discriminator.mapping.keys()
    var result:Array=[]
    for kind in cache[KEY]:result.append(fact(kind,cache))
    const ROW_KEY="presentation:actor_row_discriminators"
    if not cache.has(ROW_KEY):
        var schema:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SCHEMA))
        cache[ROW_KEY]=schema["$defs"].ActorRows.properties.rows.items.discriminator.mapping.keys()
    for field in cache[ROW_KEY]:result.append(actor_field(field))
    return result

static func actor_field(field:String)->Dictionary:
    var source=SCHEMA+":/$defs/ActorRows/properties/rows/items/discriminator/mapping/"+pointer(field)
    var implementation="implemented";var inspection="projected";var participant="state"
    var reason="Ordered canonical field publication; no independent body or effect is required."
    var disposition="state_only"
    if field in ["layer","active_weapon_set"]:
        participant="equipment";disposition="delegated"
        reason="Actual loadout publication and its enabled equipment body belong to this actor's existing equipment/appearance consumer."
    elif field=="condition":
        participant="condition";disposition="delegated"
        reason="Actual condition UUID membership delegates to its existing lifetime, phase and independently authored visual requirements."
    elif field=="spatial_disposition":
        participant="visibility";disposition="delegated"
        reason="Current disclosed body visibility and light/audio eligibility consume disposition; departure/echo art remains separately authored."
    elif field in ["item_effects","item_effect_duration"]:
        participant="item_effect";disposition="unresolved";implementation="unassessed";inspection="missing"
        reason="Ordered dynamic membership/duration reaches the exact item/effect owner; this occurrence still requires an explicitly selected Gear cue and per-use output qualification. Intrinsic decorations cannot qualify a dynamic member."
    elif field=="resolved_size":
        participant="size";disposition="unresolved";implementation="unassessed";inspection="missing"
        reason="Resolved mechanical size is stored; the mapping to authored sprite/condition scale remains unassessed."
    elif field=="item_state":
        participant="item";disposition="per_key"
        reason="Assess the actual item-state keys; canonical item accounting does not imply an emitted body, light or construction effect."
    elif field not in ACTOR_ACCOUNTING:
        disposition="unresolved";implementation="unassessed";inspection="missing"
        reason="Current actor row has no classified presentation owner; it is not implicitly state-only."
    if disposition=="state_only":implementation="not_applicable"
    var result=row("actor_row:"+field,"Actor field · "+field,source,implementation,inspection,["actor_change"],participant,reason)
    result.disposition=disposition;result.actor_field=field
    return result

static func actor_rows(value:Dictionary)->Array:
    var result:Array=[]
    var actors:Array=value.get("actors",[])
    for actor_index in actors.size():
        var actor:Dictionary=actors[actor_index]
        for row_index in actor.rows.size():
            var change:Dictionary=actor.rows[row_index]
            var expected:Dictionary=actor_field(str(change.field))
            expected.id="actor-row:%d:%d:%s"%[actor_index,row_index,str(change.field)]
            expected.actor_uuid=str(actor.actor_uuid);expected.actor_index=actor_index;expected.row_index=row_index
            expected.wire_path="actors/%d/rows/%d"%[actor_index,row_index]
            expected.inspection_links=[]
            for field in ["item_uuid","condition_uuid"]:
                if change.has(field):expected[field]=str(change[field])
            if change.field=="condition_duration":expected.condition_uuid=str(change.key)
            elif change.field=="item_effect_duration":expected.effect_uuid=str(change.key)
            elif change.field=="item_effects":expected.effect_uuids=change.effects.map(func(effect):return str(effect.effect_uuid))
            elif change.field=="condition":expected.phase="removal" if change.get("member")==null else "set"
            elif change.field=="layer":
                expected.equipment_slot=str(change.slot)
                if change.get("layer")!=null:expected.item_uuid=str(change.layer.item_uuid)
            elif change.field=="item_state":
                expected.changed_keys=change.changes.keys()
                var unsupported:Array=expected.changed_keys.filter(func(key):return key not in ITEM_ACCOUNTING)
                if unsupported.is_empty():
                    expected.implementation="not_applicable";expected.disposition="state_only";expected.status="explicit_none";expected.gap_kind="explicit_none"
                else:
                    expected.implementation="unassessed";expected.inspection="missing";expected.status="missing";expected.gap_kind="unassessed"
                    expected.reason="Item-state presentation is unassessed for actual keys: "+", ".join(unsupported)
            result.append(expected)
    # Item records may disclose dynamic effect membership independently of a
    # body row. That evidence names the exact item/effects, never its holder or
    # current equipment admission. Empty metadata ingress has no visual claim.
    var records:Array=value.get("items",[])
    for item_index in records.size():
        var item:Dictionary=records[item_index]
        if item.get("effects",[]).is_empty():continue
        var expected:Dictionary=actor_field("item_effects")
        expected.merge({"id":"item-record:%d:effects"%item_index,"actor_uuid":"","actor_index":-1,"row_index":item_index,
            "wire_path":"items/%d/effects"%item_index,"item_uuid":str(item.item_uuid),"inspection_links":[],
            "effect_uuids":item.effects.map(func(effect):return str(effect.effect_uuid)),"membership_source":"item_record",
            "label":"Item record effects","source":SCHEMA+":/$defs/ItemRecord/properties/effects",
            "source_pointer":SCHEMA+":/$defs/ItemRecord/properties/effects"},true)
        result.append(expected)
    return result

static func _active(value:Variant)->bool:
    if value==null:return false
    if value is Array or value is Dictionary:return not value.is_empty()
    if value is bool:return value
    if value is String:return not value.is_empty()
    return true

static func _add(result:Array,value:Variant,kind:String,label:String,source:String,implementation:String="missing",events:Array=[],participant:String="owner")->void:
    if not _active(value):return
    var disabled=value is Dictionary and (value.get("enabled",true)==false or value.get("hidden",false))
    result.append(row(kind,label,source,"not_applicable" if disabled else implementation,"projected" if disabled else "missing",events,participant))

static func _selectors(value:Dictionary)->Dictionary:
    var result={}
    for key in ["requireRemovedConditionTag","requiredSaveSuccess","requireAppliedConditionId","requiredLifeState","whenPresenceMode"]:
        if value.get(key)!=null:result[key]=value[key]
    for key in ["requireDamageApplied","requireHealingApplied"]:
        if value.get(key,false):result[key]=true
    if not value.get("rigIds",[]).is_empty():result.rigIds=value.rigIds
    if value.get("onMiss")=="omit":result.onMiss="omit"
    return result

static func recipe(value:Dictionary,source:String,events:Array=[],cache:Dictionary={})->Array:
    var result:Array=[]
    if value.get("disposition")=="state_only":return result
    var cast:Dictionary=value.get("cast",{})
    if not cast.is_empty() and cast.get("enabled",true):
        var equipment:Dictionary=cast.get("equipment",{}) if cast.get("equipment")!=null else {}
        if not equipment.is_empty():
            var mode:String=equipment.get("kind","unchanged")
            _add(result,equipment,"equipment_override","Cast equipment · "+mode,source+"/cast/equipment","not_applicable" if mode=="unchanged" else ("implemented" if mode=="hidden" else "missing"),events,"caster")
        _add(result,cast.get("recovery"),"body_recovery","Cast recovery pose",source+"/cast/recovery","missing",events,"caster")
        _add(result,cast.get("slash"),"cast_slash","Cast slash layer",source+"/cast/slash","missing",events,"caster")
    for field in ["bodyMaterials","arcs","directed","displacementLayers","cancellationMedia","childAttack","counterspellFeedback","castPalettes"]:
        if not _active(value.get(field)):continue
        var items:Variant=value[field]
        if items is Array:
            for n in items.size():
                var count=result.size()
                _add(result,items[n],field,str(items[n].get("id",field)) if items[n] is Dictionary else field,source+"/"+field+"/"+str(n),"missing",events,"recipient" if field=="bodyMaterials" else "owner")
                if result.size()>count and items[n] is Dictionary:result[-1].outcome_selectors=_selectors(items[n])
        else:_add(result,items,field,field.capitalize(),source+"/"+field,"missing",events)
    # Damage callbacks already consume delay/frame overrides. Separate those
    # from still unconsumed option fields; one working flash is not full parity.
    var damage:Dictionary=value.get("damage",{}) if value.get("damage")!=null else {}
    if not damage.is_empty():
        var clock=row("damage_clock","Recipient damage callback clocks",source+"/damage","implemented","projected",["damage"],"recipient","DamageTiming consumes this parent recipe's delay and callback frames at the actual applied damage child.")
        clock.disposition="parent_owned";result.append(clock)
        for definition in [["hitFlash","damage_flash","Hit-flash override"],["floatingNumber","damage_number","Floating-number override"],["death","damage_death","Lethal presentation policy"]]:
            if not damage.has(definition[0]) or damage[definition[0]]==null:continue
            var policy:Dictionary=damage[definition[0]]
            var supported:bool=definition[0]!="death" or policy.get("enabled",true)
            var reason:String="Actual applied-result feedback consumes the authored enable, colour/palette, label, duration and existing callback frame; native hit programs retain their own palette/envelope."
            if definition[0]=="death":reason="The actual Life fact owns terminal publication/body timing. The exported legacy death.frame is retained as unused metadata, matching the original lethal path; it never schedules a fabricated death delay."
            var option=row(definition[1],definition[2],source+"/damage/"+definition[0],"implemented" if supported else "unassessed","projected" if supported else "missing",["damage","life"],"recipient",reason)
            option.disposition="parent_owned";option.authored_enabled=policy.get("enabled",true);option.authored_policy=policy.duplicate(true)
            if definition[0]=="death":
                option.execution_owner="fact:life"
                option.unused_legacy_fields=["frame"] if policy.has("frame") else []
            result.append(option)
    for definition in [["condition","condition_policy","Condition effect/feedback policy","condition"],["contact","contact_policy","Authored delivery/contact policy","spell"]]:
        if value.get(definition[0])!=null:
            var policy=row(definition[1],definition[2],source+"/"+definition[0],"unassessed","missing",[definition[3]],"recipient","This selected source controls an existing causal consequence; verify its fields against the shared compiler rather than create another effect or assume generic timing is equivalent.")
            policy.disposition="parent_owned";result.append(policy)
    var area:Dictionary=value.get("area",{}) if value.get("area")!=null else {}
    for field in ["geometry","sprite","surfaceReveal"]:
        _add(result,area.get(field),"area_"+field,"Area · "+field,source+"/area/"+field,"missing",events,"area")
    if value.get("handlerResponse",false):
        result.append(row("handler_response","Causal handler response",source+"/handlerResponse","unassessed","missing",events,"owner","The recipe declares a response handler; inspect actual child ownership rather than inventing an independent body."))
    # Media source presence is separate. Finite spell media were formerly only
    # inventoried as asset IDs, with no missing operation on actual spell nodes.
    if not cast.is_empty():
        for n in value.get("media",[]).size():
            var media:Dictionary=value.media[n]
            var item=row("media",str(media.get("id","Finite spell media")),source+"/media/"+str(n),"missing","missing",events,str(media.get("attachment","owner")))
            item.asset_ids=[media.get("assetId","")];item.authored_id=media.get("id","")
            item.outcome_selectors=_selectors(media)
            result.append(item)
    if accepted_action_strip(value) and not value.get("actor",{}).get("media",[]).is_empty():
        var omission=row("action_source_strip","Accepted legacy potion-strip omission",source+"/actor/media","not_applicable","projected",events,"owner","The original body_action.ACCEPTED_SOURCE_STRIP_RECIPES explicitly retains body/effect timing without this source strip; no extension to other actions or sibling media.")
        omission.disposition="accepted_omission";omission.reference_source=REFERENCE+"body_action.py::ACCEPTED_SOURCE_STRIP_RECIPES"
        result.append(omission)
    if value.has("_resource_source"):
        for item in result:
            item.legacy_source=item.source
            var relative:String=item.source.trim_prefix(source).trim_prefix("/")
            item.source=Authoring.recipe_source(value,relative,cache);item.source_pointer=item.source
            item.id="operation:"+item.source+":"+item.kind
    return result

static func context(value:Dictionary,source:String,key:String)->Array:
    var result:Array=[]
    # Non-media operations with their actual owning fields. Scalar timing and
    # palette parameters remain children of the operation, not pretend effects.
    var fields:Dictionary={
        "movement_context":{"walkRecovery":"body_recovery","jumpRecovery":"body_recovery","flight":"flight_phases","connectorProfiles":"connector_registration"},
        "movement_reaction_context":{"feedbackEnabled":"reaction_feedback","movementLeadInMs":"reaction_lead_in","recovery":"body_recovery"},
        "forced_movement_context":{"motionCurve":"motion_curve","facingPolicy":"facing_policy","recovery":"body_recovery"},
        "death_context":{"silhouetteDust":"death_dust","hiddenSlots":"lifecycle_equipment"},
        "life_state_context":{"bodyPoses":"lifecycle_pose"},
        "interruptions":{"rules":"interruption_policy","reactions":"interruption_effects"},
        "entity_lifecycle_media":{"arrival":"entity_arrival","bond":"entity_bond","departure":"entity_departure"}
    }.get(key,{})
    for field in fields:
        if not _active(value.get(field)):continue
        var implementation="unassessed"
        if fields[field] in ["body_recovery","reaction_feedback","reaction_lead_in","death_dust","lifecycle_equipment","interruption_effects","entity_arrival","entity_bond","entity_departure"]:implementation="missing"
        if fields[field] in ["connector_registration","lifecycle_pose"]:implementation="implemented"
        _add(result,value[field],fields[field],field.capitalize(),source+"/"+field,implementation)
    return result

## The environment source entry that owns a server id (objects or surfaces).
static func environment_source(id:String)->String:
    return "authoring/environment/"+("objects/" if id.begins_with("environment.") else "surfaces/")+id+".tres"

static func owner(kind:String,id:String,source:String,value:Variant)->Dictionary:
    var implemented="unassessed"
    var label=kind.replace("_"," ").capitalize()+" · "+id
    if kind in ["rig","creature_rig","environment_bank","environment_door","environment_trap","environment_prop","environment_wreck"]:implemented="implemented"
    if kind in ["action_material","action_intake","body_material","portal","item_attachment","entity_lifecycle","contact_media","world_animation"]:implemented="missing"
    var result=row(kind,label,source,implemented,"missing")
    result.reference_source=REFERENCE+REFERENCES.get(kind,"presentation_coverage.py::presentation_inventory")
    if kind in ["environment_door","environment_trap","environment_prop","environment_wreck"]:
        result.reason="Observed-state selection exists; finite transition and source-phase inspection are not established by the final sprite."
    if kind in ["world_animation","portal"] and value is Dictionary and value.get("native_world_media",false):
        result.implementation="implemented";result.inspection="projected";result.gap_kind="unexercised";result.status="unexercised"
        result.reason="Typed source program is consumed by actual spatial-owner state and committed finite events through the shared environment sprites. Runtime output and artwork remain unqualified."
        result.methods={"observed_state":"implemented","finite_activation":"implemented" if not value.get("activation_frames",[]).is_empty() else "not_applicable",
            "projectile":"implemented" if value.has("projectile") else "not_applicable",
            "actor_depth":"implemented_with_order_refusal" if value.has("actor_depth") else "not_applicable",
            "authored_avoidance":"implemented" if value.has("successful_save_hop") else "not_applicable"}
        if kind=="portal":result.methods.portal_transfer="implemented";result.methods.actor_aperture="implemented"
    elif kind=="world_animation":result.reason="The selected finite world-animation sequence has no production consumer. Final-state scenery selectors do not execute its activation frames, contact, projectile or avoidance controls."
    if kind=="rig":result.inspection="projected";result.gap_kind="unexercised";result.status="unexercised"
    if value is Dictionary and value.get("enabled",true)==false:
        result.implementation="not_applicable";result.gap_kind="explicit_none";result.status="explicit_none"
    return result

static func _prepared_recipe(selected:Dictionary,source:String,kind:String,behavior:String,cache:Dictionary)->Array:
    # The Resource identity qualifies both the selected value and its source
    # revision. A behavior name alone cannot qualify a changed/custom recipe.
    if kind=="spell":
        var record:Resource=cache.get(Sources.CACHE_KEY,{}).get("loaded",{}).get(behavior)
        if record!=null:
            if is_same(record.recipe,selected) and record.requirement_source==source:return record.requirements.duplicate()
            for variant in record.variants:
                if is_same(variant.recipe,selected) and variant.requirement_source==source:return variant.requirements.duplicate()
    return recipe(selected,source,[kind],cache)

static func occurrence(fact_value:Dictionary,selected:Dictionary,source:String,cache:Dictionary)->Array:
    var kind:String=fact_value.get("kind","")
    if kind=="actor_change":return actor_rows(fact_value)
    # Native facts may deliberately omit their behavior identity to this seat.
    var behavior:String="" if fact_value.get("behavior_id")==null else fact_value.behavior_id
    var result=_prepared_recipe(selected,source,kind,behavior,cache)
    for i in result.size():
        var requirement:Dictionary=result[i]
        if requirement.status!="missing":continue
        if not requirement.get("outcome_selectors",{}).is_empty() or requirement.kind in ["cancellationMedia","childAttack"]:
            # Only this occurrence's applicability fields are mutable. Other
            # static diagnostic rows remain borrowed from the admitted source.
            requirement=requirement.duplicate();result[i]=requirement
            requirement.renderer_support=requirement.implementation
            requirement.implementation="unassessed";requirement.gap_kind="unassessed"
            requirement.applicability="unassessed"
            requirement.reason="Authored conditional operation; its original outcome/child binding has not been resolved for this occurrence. Do not assume mutually exclusive variants executed together."
            requirement.next_step="Bind the declared selectors to actual causal outcomes before classifying this occurrence as required or omitted."
    var declared=fact(kind,cache)
    if declared.status=="missing":result.append(declared)
    if kind=="action":
        for binding in [["action_materials","action_material"],["action_intakes","action_intake"]]:
            var path="catalog/"+binding[0]+".json"
            var values=Authoring.load_data(path,cache)
            var id:String=behavior
            if values.has(id):result.append(owner(binding[1],id,path+":/"+pointer(id),values[id]))
    if fact_value.get("committed",true) and kind in ["portal_transfer","mechanism_activation"]:
        # Resolve the actual active source program before its retained legacy
        # inspection alternative. Presence is a method declaration, never a
        # witness that this occurrence supplied its placement or drew pixels.
        var environment:Dictionary=Authoring.Catalog.environment_index(cache)
        var inspection:Dictionary=environment.get("inspection",{})
        var bindings:Array=[]
        if kind=="portal_transfer":bindings=[["portal",fact_value.get("portal_content_id","")]]
        elif kind=="mechanism_activation":bindings=[["world_animation",fact_value.get("mechanism_content_id","")]]
        for binding in bindings:
            var program:Dictionary=environment.get("spatial_media",{}).get(binding[1],{})
            if program.get("native_world_media",false):
                result.append(owner(binding[0],binding[1],str(program.get("source",environment_source(binding[1]))),program))
            elif inspection.get(binding[0],{}).has(binding[1]):
                result.append(owner(binding[0],binding[1],environment_source(binding[1]),inspection[binding[0]][binding[1]]))
    if kind=="object_destroyed":
        var environment=Authoring.Catalog.environment_index(cache)
        for family in ["doors","props","traps"]:
            if environment.get(family,{}).has(fact_value.item_id):
                result.append(owner("environment_"+{"doors":"door","props":"prop","traps":"trap"}[family],fact_value.item_id,environment_source(fact_value.item_id),environment[family][fact_value.item_id]))
    if kind=="damage" and fact_value.get("stage")=="applied":
        var release:Dictionary=fact_value.get("body_release",{}) if fact_value.get("body_release")!=null else {}
        var id:String=release.get("release_id","")
        if not id.is_empty():
            var selected_releases=Authoring.load_data("catalog/body_release_media.json",cache)
            var release_selection:Dictionary=selected_releases.get(id,{})
            var admitted:bool=not release_selection.is_empty() and (not release.get("regions",[]).is_empty() or not str(release_selection.get("air_source_catalog","")).is_empty())
            result.append(row("body_release","Authoritative release · "+id,"catalog/body_release_media.json:/"+pointer(id),("implemented" if admitted else "missing") if not release_selection.is_empty() else "unassessed","projected" if not release_selection.is_empty() else "missing",[kind],"recipient","Actual source-selected receiving regions and residue after-values use the shared region path." if admitted else "No authored source or actual receiving regions are disclosed; no body proxy or receiving plane is invented."))
    # These property-selected owners have no recipe on the actor fact. Keep
    # source fields attached to their actual occurrence, without scheduling it.
    var context_key={"forced_movement":"forced_movement_context","equipment":"equipment_context"}.get(kind,"")
    if not context_key.is_empty():
        result.append_array(context(Authoring.load_data("catalog/"+context_key+".json",cache),"catalog/"+context_key+".json:",context_key))
    return result
