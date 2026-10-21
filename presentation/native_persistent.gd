extends RefCounted
## Presentation lifetimes follow disclosed after-values. No rule or expiration
## is inferred from a Factory clip's finite demonstration duration.
## Conditions play the package's lifecycles (application, sustain, removal):
## one occurrence per owner and lifecycle, its phase and ages supplied as the
## clip's `owner_state` input from the owner's real application and removal.
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Effects=preload("res://presentation/effect_package.gd")
const SpatialInputs=preload("res://presentation/spatial_inputs.gd")
## Client marker rotation: one overhead symbol group at a time per actor.
const MARKER_TURN_MS:=1800.0

static func fade_ms(selected:Dictionary)->float:
    return phase_fade_ms(Spells.condition_phases(selected))

static func phase_fade_ms(phases:Array)->float:
    var result=0.0
    for phase in phases:
        result=maxf(result,(float(phase.lifecycle.get("exit_end_seconds",0))-float(phase.lifecycle.get("exit_start_seconds",0)))*1000.0)
    return result

## The package lifecycles this condition plays: each selection naming its id
## whose `when` matches the disclosed condition state (Reduce, not Enlarge).
static func lifecycles(condition:Dictionary)->Array:
    var state:Dictionary=condition.state if condition.get("state") is Dictionary else {}
    return Effects.conditions(str(condition.get("behavior_id",""))).filter(func(selection):
        var when:Dictionary=selection.condition.get("when",{})
        return when.keys().all(func(field):return state.get(field)==when[field]))

## The longest removal among these lifecycles, in ms.
static func removal_ms(selections:Array)->float:
    var result:=0.0
    for selection in selections:result=maxf(result,float(Effects.clip(str(selection.condition.phases.removal)).get("seconds",0.0))*1000.0)
    return result

## Recipe media the package draws instead: its application and removal
## phases take the recipe's application/removal effects; an overhead marker
## lifecycle takes the marker layers (markerGroup), a lifecycle carrying the
## spell's body visual the others. Only a lifecycle selected by this owner's
## disclosed state replaces media; a declared but unmatched variant does not.
static func replaced_media(condition:Dictionary,recipe:Dictionary)->Array:
    var selections:Array=lifecycles(condition)
    var markers:bool=selections.any(func(selection):return not selection.condition.get("marker",{}).is_empty())
    var body:bool=selections.any(func(selection):return selection.condition.get("body_channel_included",false))
    var result:Array=[]
    for cue in recipe.get("persistent",{}).get("nativeEffects",[]):result.append_array(cue.get("replaces_media",[]))
    if selections.is_empty():return result
    for layer in recipe.get("persistent",{}).get("layers",[]):
        if (markers if layer.get("markerGroup")!=null else body):result.append(str(layer.get("assetId","")))
    for phase in ["application","removal"]:
        var change:Variant=recipe.get(phase)
        if change is Dictionary:result.append_array(change.get("effects",[]).map(func(effect):return str(effect.get("assetId",""))))
    return result

## An explicitly authored native hold uses the same UUID owner as package
## lifecycles. Cache only its immutable phase; the owner clock remains private.
static func authored_samples(common:Dictionary,cache:Dictionary)->Array:
    var result:Array=[]
    for phase in authored_phases(common.recipe,Authoring.Catalog.condition_key(common.condition),cache,str(common.source)):
        var when:Dictionary=phase.native_cue.get("when",{})
        var state:Dictionary=common.condition.state if common.condition.get("state") is Dictionary else {}
        if not when.keys().all(func(field):return state.get(field)==when[field]):continue
        var application:bool=phase.native_cue.authored_at=="application"
        var start:float=float(common.start_ms)+float(phase.start_ms) if application else float(common.start_ms)
        var duration:float=minf(float(phase.duration_ms),float(common.duration_ms)-float(phase.start_ms)) if application else float(common.duration_ms)
        if application and (common.initial or float(common.age_ms)<float(phase.start_ms) or float(common.age_ms)>=float(phase.start_ms)+duration):continue
        var row:Dictionary=common.merged(phase,true)
        row.merge({"id":str(common.id)+":authored:"+str(phase.native_cue.source_index),"kind":"native_effect","native_spell":true,
            "persistent_owner":true,"target_uuid":common.actor_uuid,"cast_recipe":{"enabled":false},
            "start_ms":start,"absolute_start_ms":float(common.absolute_start_ms)+float(phase.start_ms) if application else common.absolute_start_ms,
            "duration_ms":duration,"age_ms":float(common.age_ms)-float(phase.start_ms) if application else common.age_ms,
            "from_position":[0,0],"to_position":[0,0],"from_elevation_feet":0.0,"to_elevation_feet":0.0,
            "ground_target":false,"sample_hz":60.0},true)
        # This source consumes the exact owner removal age and owns its own
        # authored fade. Do not attenuate that same fade a second time.
        if "actual_owner_state" in row.native_clip.get("inputs",[]):row.alpha=1.0
        var payload:Dictionary=phase.native_cue.get("constructor_input",{})
        if payload.get("kind")=="retained_payload":
            var bound:Dictionary=common.get("creation_binding",{})
            if not bound.get("ready",false) or bound.get("payload_kind")!=payload.get("payload_kind"):continue
            row.native_payload=true;row.ground_target=true;row.target_uuid=null;row.alpha=1.0
            row.native_constructor_inputs=[{"component_path":payload.component_path,"input_field":str(payload.get("input_field","")),"values":{
                "item_uuid":str(bound.identity.created_item_uuid),"lifetime_uuid":str(bound.identity.lifetime_condition_uuid),
                "original_caster_uuid":str(bound.identity.caster_uuid)}}]
            row.native_constructor_evidence=bound.evidence
        elif payload.get("kind")=="quarry_owner":
            var bound:Dictionary=common.get("creation_binding",{})
            if not bound.get("ready",false) or bound.get("quarry_kind")!=payload.get("quarry_kind"):continue
            var identity:Dictionary=bound.identity
            row.actor_uuid=str(identity.recipient_uuid);row.target_uuid=str(identity.recipient_uuid)
            row.native_rule_caster_uuid=str(identity.caster_uuid)
            row.native_quarry=true;row.alpha=1.0
            row.native_constructor_inputs=[{"component_path":payload.component_path,"input_field":str(payload.get("input_field","")),"values":{
                "source_actor_uuid":str(identity.caster_uuid),"recipient_uuid":str(identity.recipient_uuid),
                "owner_uuid":str(identity.sustain_condition_uuid),"owner_id":str(bound.owner_id),
                "condition_uuid":str(identity.recipient_condition_uuid),"condition_id":str(bound.recipient_id),
                "item_uuid":"","attack_uuid":"","strike":{},"owner":{},"condition":{},"quarry_state":{},"tick":{},"healing":{},
                "lifecycle_mode":"owned_state"}}]
            row.native_constructor_evidence=bound.evidence
        # The authored setter observes this actual member's lifetime, not a
        # spell duration or a Factory fixture default. NativeInputs owns its
        # ordinary deduplicated setter publication.
        var membership:String=str(row.native_cue.get("membership_input",""))
        if not membership.is_empty():row.native_inputs={membership:common.removal_age_ms==null}
        row.trace_keys=[row.id]
        result.append(row)
    return result

## The existing typed held-effect description is independent of whether its
## actual owner is an actor condition or a disclosed spatial instance.
static func authored_phases(config:Dictionary,identity:String,cache:Dictionary,source:String="")->Array:
    var key:String="condition-native:"+identity
    if not cache.has(key):
        var phases:Array=[]
        for original in config.get("persistent",{}).get("nativeEffects",[]):
            var cue:Dictionary=original.duplicate()
            cue.authored_at=cue.get("at","owner_start");cue.at="release"
            var selected={"id":str(cue.get("selection","")),"source":str(config.get("_resource_source",source))+"::effects",
                "source_bounds":{},"palette":{},"staging":{"decorative_light_multiplier":float(cue.get("light_multiplier",0.0))}}
            var phase:Dictionary=Spells._phase(selected,cue,{"prepare":0.0},0.0,0.0,0)
            phase.erase("spell_id")
            phase.condition_authored=true
            phase.source=str(cue.get("source",str(config.get("_resource_source",source))+"::effects/"+str(cue.source_index)))
            phase.lifecycle={}
            phase.native_cue=phase.native_cue.duplicate()
            phase.native_cue.begin=0.0
            if cue.authored_at in ["application","spatial_removal"]:
                # A witnessed application is a finite source on the actual
                # member's clock, not another indefinite held visual.
                phase.native_cue.erase("lifecycle")
                var offset:float=float(cue.get("source_start",0.0))/float(cue.get("source_rate",1.0))
                phase.duration_ms=maxf(0.0,float(phase.duration_ms)-offset*1000.0)
                phase.native_cue.begin=-offset;phase.native_cue.end=float(phase.duration_ms)/1000.0
            else:phase.native_cue.end=INF
            phase.removal_retention_ms=float(cue.get("fade_out_seconds",0.0))*1000.0
            # The source's observed owner projection owns its return. Generic
            # finite-clip fading would evaluate smoothstep(INF, INF, age).
            phase.native_cue.erase("fade_out_seconds")
            phase.source_id=str(cue.clip)
            phases.append(phase)
        cache[key]=phases
    return cache[key]

static func authored_removal_ms(config:Dictionary)->float:
    var result:float=0.0
    for cue in config.get("persistent",{}).get("nativeEffects",[]):
        if cue.get("at")=="application":continue
        if cue.get("at")=="spatial_removal":
            result=maxf(result,(float(cue.get("source_end",0.0))-float(cue.get("source_start",0.0)))/float(cue.get("source_rate",1.0))*1000.0)
            continue
        result=maxf(result,float(cue.get("fade_out_seconds",0.0))*1000.0)
    return result

## Lifecycle occurrences of one owner. `common` carries the owner's clock
## (start, duration up to its removal, age, removal age, initial).
static func lifecycle_samples(common:Dictionary,selections:Array,cache:Dictionary)->Array:
    var result:Array=[]
    var spell:Dictionary=common.get("selected_spell",{}) if common.get("spatial_owner",false) else Spells.condition(str(common.condition.behavior_id),cache)
    for selection in selections:
        var lifecycle:Dictionary=selection.condition
        var opt_ins:Array=common.get("recipe",{}).get("persistent",{}).get("lifecycleOptIns",[])
        var public_rows:Array=opt_ins.filter(func(row):return row.key==selection.key)
        var public_source:Dictionary=public_rows[0] if public_rows.size()==1 else {}
        var phases:Dictionary={}
        if public_source.is_empty():
            for phase in ["application","sustain","removal"]:phases[phase]=Effects.clip(str(lifecycle.phases[phase]))
        else:
            var source_key:String="public-condition-lifecycle:"+str(selection.key)+":"+str(common.recipe.get("_resource_source",""))
            if not cache.has(source_key):
                var selected:Dictionary={}
                for phase in ["application","sustain","removal"]:
                    var source:Dictionary=public_source.phases[phase]
                    var clip:Dictionary=Effects.clip(str(source.clip_id)).duplicate(false)
                    clip.approach_id=str(source.approach_id);clip.seconds=float(source.source_seconds)
                    selected[phase]=clip
                cache[source_key]=selected
            phases=cache[source_key]
        var key:String=str(selection.key)
        var id:String=str(common.id)+":lifecycle:"+key
        var source:String="assets/vfx/index.json#/selections/"+key+"/condition"
        if phases.values().any(func(clip):return clip.is_empty()):
            result.append(common.merged({"id":id,"kind":"native_effect","native_spell":true,"persistent_owner":true,"status":"missing",
                "reason":"effect_not_in_package","native_cue":{"role":"attached"},"native_clip":{},"source":source,"source_id":key,"trace_keys":[id]},true))
            continue
        if common.removal_age_ms!=null and float(common.removal_age_ms)>=float(phases.removal.seconds)*1000.0:continue
        var registration:Dictionary=lifecycle.registration
        var offset:Array=registration.get("offset",[0,0,0])
        # The occurrence is placed at its registration (the constructor already
        # holds the source's placement scale); a marker faces the camera in its
        # own shader.
        var cue:Dictionary={"role":"attached","attachment":str(registration.attachment),"anchor":str(registration.get("anchor","body_center")),
            "scale":float(registration.get("scale",1.0)),"offset":[float(offset[0]),float(offset[1]),float(offset[2])],"orientation":"world",
            "begin":0.0,"end":INF,"launch":0.0,"contact":0.0,"clip":phases.application,"staged_clip":str(phases.application.id)}
        if not str(registration.get("origin_path","")).is_empty():cue.origin_path=str(registration.origin_path)
        if not public_source.is_empty():cue.entity_geometry=common.recipe.persistent.get("lifecycleGeometry",{})
        var aim:String=str(common.get("recipe",{}).get("persistent",{}).get("nativeAim",""))
        if not aim.is_empty():cue.aim_policy=aim
        # The spell's own staging decides only the finish (palette ramp) of
        # the spell's body visual and its light: Light's is the server's light.
        var optical:Dictionary={"energy_multiplier":float(selection.get("staging",{}).get("decorative_light_multiplier",0.0))}
        if spell.get("lifecycle",{}).get("optical_owner")=="authoritative_light":optical={"energy_multiplier":0.0,"owner":"authoritative_light"}
        var row:Dictionary=common.duplicate()
        row.merge({"id":id,"kind":"native_effect","native_spell":true,"persistent_owner":true,"status":"available",
            "target_uuid":common.get("actor_uuid"),"cast_recipe":{"enabled":false},"from_position":[0,0],"to_position":common.get("position",[0,0]),
            "from_elevation_feet":common.get("elevation_feet",0),"to_elevation_feet":common.get("elevation_feet",0),"ground_target":common.get("spatial_owner",false),
            "native_cue":cue,"native_clip":phases.application,"lifecycle_phases":phases,"lifecycle_key":key,
            "native_body_owner":lifecycle.get("body_channel_included",false),
            "lifecycle_marker":lifecycle.get("marker",{}),"lifecycle_visibility":lifecycle.get("visibility",{}),
            "spell_id":str(spell.get("id","")),"finish_profile":spell.get("palette",{}) if lifecycle.get("body_channel_included",false) else {},
            "optical":optical,"native_lights":[],"source":source,"source_id":key,"sample_hz":60.0,"trace_keys":[id]},true)
        if not public_source.is_empty():
            row.native_readiness_gate=public_source.event_gate
            row.native_observation_revision=int(common.get("observation_revision",0))
        result.append(row)
    return result

## The lifecycle at owner age `seconds` (the clip's owner_state input):
## application from the real application, sustain while the owner lasts,
## removal from the real removal on the same age. An owner already present
## when the record began finished its application before it.
static func lifecycle_state(component:Dictionary,seconds:float)->Dictionary:
    var application:float=float(component.lifecycle_phases.application.seconds)
    var shift:float=application if component.get("initial",false) else 0.0
    var age:float=maxf(0.0,seconds)+shift
    var removed:float=float(component.duration_ms)/1000.0+shift
    if age>=removed:return {"phase":"removal","phase_age_seconds":age-removed,"owner_age_seconds":age,"removal_started_at_owner_age_seconds":removed}
    if age<application:return {"phase":"application","phase_age_seconds":age,"owner_age_seconds":age}
    return {"phase":"sustain","phase_age_seconds":age-application,"owner_age_seconds":age}

## Owner age at which the application ends; later ages are drawn directly.
static func application_end(component:Dictionary)->float:
    return 0.0 if component.get("initial",false) else float(component.lifecycle_phases.application.seconds)

## Displayed lifecycles: the visibility each declares (activity, life state,
## hidden with an invisible actor) and one overhead marker group at a time
## per actor, live markers before removing ones, groups in priority order.
static func select_lifecycles(rows:Array,at_ms:float,activities:Dictionary,invisible:Dictionary)->Array:
    var eligible:Array=rows.filter(func(row):
        var visibility:Dictionary=row.lifecycle_visibility
        if visibility.get("hide_with_invisible_actor",false) and invisible.has(row.actor_uuid):return false
        if visibility.has("activities") and activities.get(row.actor_uuid,"idle") not in visibility.activities:return false
        return not visibility.has("life_states") or row.get("life_state","alive") in visibility.life_states)
    var result:Array=eligible.filter(func(row):return row.lifecycle_marker.is_empty())
    var actors:Dictionary={}
    for row in eligible:
        if not row.lifecycle_marker.is_empty():actors[row.actor_uuid]=true
    for actor in actors:
        var markers:Array=eligible.filter(func(row):return row.actor_uuid==actor and not row.lifecycle_marker.is_empty())
        var live:Array=markers.filter(func(row):return row.get("removal_age_ms")==null)
        if not live.is_empty():markers=live
        var groups:Dictionary={}
        for row in markers:
            var group:String=str(row.lifecycle_marker.group)
            # One symbol per group: its earliest owner.
            if not groups.has(group) or str(row.condition_uuid)<str(groups[group].condition_uuid):groups[group]=row
        var order:Array=groups.keys()
        order.sort_custom(func(a,b):
            var left:int=int(groups[a].lifecycle_marker.get("priority",0));var right:int=int(groups[b].lifecycle_marker.get("priority",0))
            return left>right if left!=right else a<b)
        result.append(groups[order[int(maxf(0,at_ms)/MARKER_TURN_MS)%order.size()]])
    return result

## Older spatial sources retain their explicit staged deployment/close window.
## A delivered package lifecycle takes precedence when its exact owner exists.
static func phase_samples(common:Dictionary,phases:Array)->Array:
    # Phase descriptions are owner-independent. Each output receives its own
    # cue before adding occurrence age/removal state; never mutate the input.
    var result:Array=[]
    var index=0
    for phase in phases:
        var close_ms:float=(float(phase.lifecycle.get("exit_end_seconds",0))-float(phase.lifecycle.get("exit_start_seconds",0)))*1000.0
        if float(common.age_ms)>=float(common.duration_ms)+close_ms:index+=1;continue
        var row=common.duplicate()
        row.merge(phase,true)
        row.merge({"id":common.id+":native:"+str(index),"kind":"native_effect","native_spell":true,"persistent_owner":true,
            "status":phase.get("status","available"),"target_uuid":common.get("actor_uuid"),"cast_recipe":{"enabled":false},
            "start_ms":common.start_ms,"absolute_start_ms":common.absolute_start_ms,"duration_ms":common.duration_ms,
            "from_position":[0,0],"to_position":common.get("position",[0,0]),
            "from_elevation_feet":common.get("elevation_feet",0),"to_elevation_feet":common.get("elevation_feet",0),
            "ground_target":common.get("spatial_owner",false),"sample_hz":60.0},true)
        row.native_cue=row.native_cue.duplicate(true)
        row.native_cue.lifecycle=row.lifecycle
        row.native_cue.initial=common.initial
        row.native_cue.owner_end_seconds=float(common.duration_ms)/1000.0
        row.trace_keys=[row.id]
        result.append(row);index+=1
    return result

static func spatial_selection(effect:Dictionary,cache:Dictionary)->Dictionary:
    var ref:Dictionary=effect.get("content_ref",{})
    var identity:String=str(ref.get("content_id",""))
    var entries:Dictionary=Authoring.load_data("native_effects/index.json",cache).get("spells",{})
    for spell_id in entries:
        var lifecycle:Dictionary=entries[spell_id].get("lifecycle",{})
        if lifecycle.get("owner_kind")!="spatial_effect":continue
        if identity in lifecycle.get("owner_ids",[]) or "spatial_effect."+identity in lifecycle.get("owner_ids",[]):return Spells.selection(spell_id,cache)
    return {}

static func spatial_lifecycles(effect:Dictionary)->Array:
    var identity:String=str(effect.get("content_ref",{}).get("content_id",""))
    var selected:Array=Effects.conditions(identity)
    return Effects.conditions("spatial_effect."+identity) if selected.is_empty() else selected

## Keep only newly disclosed cells, once, at their actual ordered observation.
## Earlier source batches never grow when another part of this UUID is seen.
static func _spatial_disclosure(owner:Dictionary,effect:Dictionary,supports:Dictionary={})->void:
    var known:Dictionary=owner.get("source_disclosed_cells",{})
    var added:Array=[]
    for position in effect.get("positions",[]):
        if known.has(position):continue
        if added.is_empty():known=known.duplicate()
        known[position]=true;added.append(position)
    if added.is_empty():return
    var previous:Array=owner.get("source_disclosures",[])
    added.make_read_only();known.make_read_only()
    var disclosure:Dictionary={"cells":added,"original":previous.is_empty(),
        "anchor":effect.anchor_position if effect.get("anchor_position")!=null else added[0],
        "elevation_steps":effect.get("anchor_elevation_steps")}
    if disclosure.elevation_steps==null:
        var tile:Dictionary=supports.get("%d,%d"%disclosure.anchor,{})
        if not tile.is_empty():disclosure.elevation_steps=tile.elevation_steps
    disclosure.make_read_only()
    owner.source_disclosures=previous+[disclosure]
    owner.source_disclosed_cells=known

static func observe_spatial(owners:Dictionary,effects:Dictionary,at_ms:float,initial:bool=false,rows:Array=[],supports:Dictionary={})->bool:
    var changed:bool=false
    for id in effects:
        if not owners.has(id):
            owners[id]={"id":id,"start_ms":at_ms,"end_ms":INF,"initial":initial,"effect":effects[id],"source_effect":effects[id],
                "spatial_observations":[],"spatial_removals":[],"spatial_observation_keys":{},"physical_end_ms":INF,"observed":true}
            _spatial_disclosure(owners[id],effects[id],supports)
            changed=true
        elif is_inf(float(owners[id].physical_end_ms)):
            if not is_same(owners[id].effect,effects[id]):_spatial_disclosure(owners[id],effects[id],supports)
            changed=changed or not is_same(owners[id].effect,effects[id]) or not is_inf(owners[id].end_ms)
            owners[id].effect=effects[id];owners[id].end_ms=INF;owners[id].observed=true
    # The owner still carries its original before-cut topology when the final
    # sensory after-value removes it. Keep that actual event before visibility
    # closes the presentation interval below.
    for row in rows:
        var identity:String=str(row.spatial_effect_uuid)
        if not owners.has(identity):continue
        var owner:Dictionary=owners[identity]
        var key:Array=[row.event_uuid,row.lineage_uuid]
        if owner.spatial_observation_keys.has(key):continue
        owner.spatial_observation_keys[key]=true
        var observed:Dictionary=row.merged({"at_ms":at_ms+float(row.get("contact_offset_ms",0.0))})
        # Replace the small immutable operand arrays once per actual event.
        # Earlier prepared/Studio cuts keep their own before-removal values.
        owner.spatial_observations=owner.spatial_observations+[observed]
        if not row.removed_positions.is_empty():owner.spatial_removals=owner.spatial_removals+[SpatialInputs.removal(owner,observed)]
        if row.operation=="removed":
            owner.physical_end_ms=at_ms;owner.end_ms=minf(float(owner.end_ms),at_ms);owner.observed=false
        changed=true
    for id in owners:
        if not effects.has(id) and is_inf(owners[id].end_ms):
            owners[id].end_ms=at_ms;owners[id].observed=false;changed=true
    return changed

## Project each new, factual retirement once in this private presentation
## owner. Per-frame sampling visits only its still-active finite sources.
static func spatial_removal_samples(owner:Dictionary,phase:Dictionary,at_ms:float)->Array:
    if not owner.has("native_removal_sources"):owner.native_removal_sources={}
    var key:int=int(phase.native_cue.source_index)
    var projected:Dictionary=owner.native_removal_sources.get(key,{})
    if projected.is_empty() or not is_same(projected.phase,phase):
        projected={"phase":phase,"seen":0,"active":[]};owner.native_removal_sources[key]=projected
    var removed:Array=owner.get("spatial_removals",[])
    for observation in removed.slice(int(projected.seen)):
        var when:Dictionary=phase.native_cue.get("spatial_removal_when",{})
        if when.is_empty() or not when.keys().all(func(field):return observation.get(field)==when[field]):continue
        if at_ms>=float(observation.at_ms)+float(phase.duration_ms):continue
        var construction:Dictionary=SpatialInputs.removal_construction(str(owner.id),owner.source_effect,observation,phase.native_cue)
        var anchor:Variant=owner.source_effect.get("anchor_position")
        if anchor==null:anchor=owner.source_effect.positions[0]
        var elevation:float=float(owner.source_effect.anchor_elevation_steps)*5.0 if owner.source_effect.get("anchor_elevation_steps")!=null else 0.0
        var row:Dictionary=phase.duplicate()
        row.merge({"id":"spatial:"+str(owner.id)+":authored:"+str(key)+":removal:"+str(observation.event_uuid)+":"+str(observation.lineage_uuid),
            "kind":"native_effect","native_spell":true,"persistent_owner":true,"spatial_owner":true,
            "spatial_removal":true,"spatial_effect_uuid":owner.id,"spatial_content_id":SpatialInputs.content_id(owner.source_effect),
            "actor_uuid":null,"target_uuid":null,"cast_recipe":{"enabled":false},
            "start_ms":observation.at_ms,"absolute_start_ms":observation.at_ms,"duration_ms":phase.duration_ms,
            "initial":false,"alpha":1.0,"removal_age_ms":null,
            "position":anchor,"from_position":anchor,"to_position":anchor,"elevation_feet":elevation,
            "from_elevation_feet":elevation,"to_elevation_feet":elevation,
            "ground_target":true,"resolved_area_positions":observation.positions,
            "source_event_uuid":observation.event_uuid,"sample_hz":60.0},true)
        if construction.ready:
            row.native_constructor_inputs=construction.operands
            row.native_constructor_evidence=construction.evidence
            row.spatial_surface_records=construction.surface_records
        else:row.status="missing";row.reason=construction.reason;row.native_input_gaps=[construction.reason]
        row.trace_keys=[row.id];projected.active.append(row)
    projected.seen=removed.size()
    var active:Array=[];var result:Array=[]
    for source in projected.active:
        if at_ms>=float(source.start_ms)+float(source.duration_ms):continue
        active.append(source)
        if at_ms<float(source.start_ms):continue
        result.append(source.merged({"age_ms":at_ms-float(source.start_ms)},true))
    projected.active=active
    return result

## Environment-owned effects use their canonical typed ground resource. Older
## compatible condition entries retain the same compiler and owner sampler.
static func spatial_config(identity:String,cache:Dictionary)->Dictionary:
    var key:String="native-spatial-config:"+identity
    if not cache.has(key):
        var authored:Dictionary=Authoring.Catalog.environment_index(cache).get("native_spatial_effects",{}).get(identity,{})
        cache[key]=authored if not authored.is_empty() else Authoring.load_data("catalog/condition_recipes.json",cache).get(identity,{})
    return cache[key]

## The first exact cell distinguishes additional immutable draws within one
## real owner; it is never another spatial UUID or a packet-local batch index.
static func surface_component(row:Dictionary,disclosure:Dictionary,construction:Dictionary)->Dictionary:
    var result:Dictionary=row.duplicate(false)
    var base:String=str(row.get("spatial_coverage_base_id",row.id))
    var first:Array=disclosure.cells[0]
    result.id=base if disclosure.original else base+":coverage:"+str(first[0])+","+str(first[1])
    result.spatial_coverage_base_id=base
    if not construction.get("ready",true):
        result.status="missing";result.reason=construction.reason;result.native_input_gaps=[construction.reason]
        result.trace_keys=[result.id];return result
    result.native_constructor_inputs=construction.operands
    result.native_constructor_evidence=construction.evidence
    result.spatial_surface_records=construction.surface_records
    var anchor:Array=construction.source_anchor
    var elevation:float=float(construction.source_elevation_steps)*5.0 if construction.source_elevation_steps!=null else 0.0
    var admitted:Array=row.get("spatial_coverage_positions",row.get("resolved_area_positions",[]))
    result.merge({"position":anchor,"from_position":anchor,"to_position":anchor,
        "elevation_feet":elevation,"from_elevation_feet":elevation,"to_elevation_feet":elevation,
        "spatial_source_cells":construction.source_cells,"spatial_observed_removals":[],
        "spatial_coverage_positions":admitted,
        "resolved_area_positions":admitted.filter(func(position):return position in disclosure.cells),
        "trace_keys":[result.id]},true)
    if result.has("preparation_key"):result.preparation_key=str(row.preparation_key)+":"+result.id
    return result

static func surface_samples(owner:Dictionary,phase:Dictionary,row:Dictionary,at_ms:float)->Array:
    var result:Array=[]
    var original:Dictionary=owner.source_effect
    var origin:Dictionary=SpatialInputs.surface_origin(original,owner.get("source_disclosures",[]))
    if origin.anchor==null:return result
    var anchor:Array=origin.anchor
    var key:int=int(phase.native_cue.source_index)
    var constructions:Dictionary=owner.get("surface_constructions",{}).get(key,{})
    var birth_observed:bool=not owner.initial and not original.get("positions",[]).is_empty() and owner.get("spatial_observations",[]).any(func(observation):
        return observation.operation=="created" and float(observation.at_ms)==float(owner.start_ms))
    var presented:Array=SpatialInputs.presentation_cells(owner,at_ms,float(phase.removal_retention_ms))
    for disclosure in owner.get("source_disclosures",[]):
        var first:Array=disclosure.cells[0]
        var batch:String=str(first[0])+","+str(first[1])
        if not constructions.has(batch):
            constructions=constructions.duplicate()
            constructions[batch]=SpatialInputs.surface_construction(str(owner.id),SpatialInputs.content_id(owner.effect),
                disclosure.cells,anchor,origin.elevation_steps,phase.native_cue.constructor_input)
            owner.surface_constructions=owner.get("surface_constructions",{}).duplicate()
            owner.surface_constructions[key]=constructions
        var sample:Dictionary=row.duplicate(false)
        sample.resolved_area_positions=presented;sample.spatial_coverage_positions=presented
        sample=surface_component(sample,disclosure,constructions[batch])
        sample.spatial_creation_observed=birth_observed and disclosure.original
        # New visibility supplies coverage, not another water-creation event.
        if not sample.spatial_creation_observed:sample.age_ms+=float(phase.native_cue.get("initial_source_seconds",0.0))*1000.0
        result.append(sample)
    return result

## Immutable constructed vegetation grows only from each actual disclosure.
## New cells get their own draw, never a synthetic owner or a replayed birth.
static func owned_cell_samples(owner:Dictionary,phase:Dictionary,row:Dictionary)->Array:
    var origin:Dictionary=SpatialInputs.surface_origin(owner.source_effect,owner.get("source_disclosures",[]))
    var result:Array=[]
    for disclosure in owner.get("source_disclosures",[]):
        var original:Dictionary=owner.source_effect.duplicate(false)
        original.positions=disclosure.cells
        var construction:Dictionary=SpatialInputs.construction(str(owner.id),owner.effect,phase.native_cue,original,[],origin)
        var sample:Dictionary=row.duplicate(false)
        var first:Array=disclosure.cells[0]
        sample.id=str(row.id)+":coverage:"+str(first[0])+","+str(first[1]);sample.trace_keys=[sample.id]
        if not construction.ready:
            sample.status="missing";sample.reason=construction.reason;sample.native_input_gaps=[construction.reason];result.append(sample);continue
        sample.native_constructor_inputs=construction.operands;sample.native_constructor_evidence=construction.evidence
        sample.spatial_source_cells=disclosure.cells
        sample.resolved_area_positions=SpatialInputs.admitted_cells(owner.effect).filter(func(position):return position in disclosure.cells)
        var anchor:Array=construction.source_anchor;var elevation:float=float(construction.source_elevation_steps)*5.
        sample.merge({"position":anchor,"from_position":anchor,"to_position":anchor,"elevation_feet":elevation,
            "from_elevation_feet":elevation,"to_elevation_feet":elevation},true)
        if sample.has("preparation_key"):sample.preparation_key=str(sample.preparation_key)+":"+sample.id
        result.append(sample)
    return result

static func partition_samples(owner:Dictionary,phase:Dictionary,row:Dictionary)->Array:
    var descriptor:Dictionary=phase.native_cue.constructor_input
    var origin:Dictionary=SpatialInputs.surface_origin(owner.source_effect,owner.get("source_disclosures",[]))
    var construction:Dictionary=SpatialInputs.construction(str(owner.id),owner.effect,phase.native_cue,owner.source_effect,[],origin)
    if not construction.ready:
        row.status="missing";row.reason=construction.reason;row.native_input_gaps=[construction.reason];row.trace_keys=[row.id];return [row]
    var cells:Array=SpatialInputs.admitted_cells(owner.effect)
    var key:int=int(phase.native_cue.source_index)
    var cached:Dictionary=owner.get("surface_partitions",{}).get(key,{})
    if cached.get("cells")!=cells or cached.get("anchor")!=construction.source_anchor:
        var planned:Dictionary=SpatialInputs.surface_partitions(str(owner.id),cells,construction.source_anchor,descriptor)
        cached={"cells":cells,"anchor":construction.source_anchor,"planned":planned}
        owner.surface_partitions=owner.get("surface_partitions",{}).duplicate();owner.surface_partitions[key]=cached
    if not cached.planned.get("error","").is_empty():
        row.status="missing";row.reason=cached.planned.error;row.native_input_gaps=[row.reason];row.trace_keys=[row.id];return [row]
    var result:Array=[]
    for index in cached.planned.partitions.size():
        var sample:Dictionary=row.duplicate(false)
        sample.id=str(row.id)+":partition:"+str(index);sample.trace_keys=[sample.id]
        sample.native_constructor_inputs=construction.operands;sample.native_constructor_evidence=construction.evidence
        sample.spatial_surface_partition=cached.planned.partitions[index]
        sample.spatial_source_cells=cells;sample.resolved_area_positions=cells
        var anchor:Array=construction.source_anchor;var elevation:float=float(construction.source_elevation_steps)*5.
        sample.merge({"position":anchor,"from_position":anchor,"to_position":anchor,"elevation_feet":elevation,
            "from_elevation_feet":elevation,"to_elevation_feet":elevation},true)
        if sample.has("preparation_key"):sample.preparation_key=str(sample.preparation_key)+":partition:"+str(index)
        result.append(sample)
    return result

static func spatial_samples(owners:Dictionary,at_ms:float,cache:Dictionary)->Array:
    var result:Array=[]
    for id in owners.keys():
        var owner:Dictionary=owners[id]
        var selected=spatial_selection(owner.effect,cache)
        var effect:Dictionary=owner.effect
        var lifecycles:Array=spatial_lifecycles(effect)
        var config:Dictionary=spatial_config(SpatialInputs.content_id(effect),cache)
        var authored:Array=authored_phases(config,SpatialInputs.content_id(effect),cache) if not config.get("persistent",{}).get("nativeEffects",[]).is_empty() else []
        if selected.is_empty() and lifecycles.is_empty() and authored.is_empty():continue
        var close_ms:float=removal_ms(lifecycles) if not lifecycles.is_empty() else fade_ms(selected)
        close_ms=maxf(close_ms,authored_removal_ms(config))
        var retained_until:float=float(owner.end_ms)+close_ms
        if not owner.get("spatial_removals",[]).is_empty():retained_until=maxf(retained_until,float(owner.spatial_removals.back().at_ms)+close_ms)
        if at_ms>=retained_until:owners.erase(id);continue
        for phase in authored:
            if phase.native_cue.authored_at=="spatial_removal":result.append_array(spatial_removal_samples(owner,phase,at_ms))
        var positions:Array=SpatialInputs.admitted_cells(effect)
        var wall:bool=authored.any(func(phase):return phase.native_cue.get("constructor_input",{}).get("cell_input")=="wall_assembly")
        var coverage:bool=authored.any(func(phase):return phase.native_cue.get("constructor_input",{}).get("cell_input")=="surface_groups")
        if positions.is_empty() and not wall and not coverage:continue
        var anchor:Variant=effect.get("anchor_position")
        if coverage:anchor=SpatialInputs.surface_origin(owner.source_effect,owner.get("source_disclosures",[])).anchor
        elif anchor==null and not positions.is_empty():anchor=positions[0]
        if anchor==null:continue
        var common={"id":"spatial:"+str(id),"spatial_effect_uuid":id,"spatial_owner":true,"actor_uuid":null,
            "start_ms":owner.start_ms,"absolute_start_ms":owner.start_ms,"duration_ms":owner.end_ms-owner.start_ms,
            "age_ms":maxf(0,at_ms-owner.start_ms),"initial":owner.initial,"alpha":1.0,
            "removal_age_ms":null if is_inf(owner.end_ms) else maxf(0,at_ms-owner.end_ms),
            "position":anchor,"elevation_feet":float(effect.anchor_elevation_steps)*5.0 if effect.get("anchor_elevation_steps")!=null else 0.0,
            "resolved_area_positions":positions,"source_event_uuid":"","recipe":{}}
        if not lifecycles.is_empty():
            common.selected_spell=selected
            result.append_array(lifecycle_samples(common,lifecycles,cache))
        elif not selected.is_empty():result.append_array(phase_samples(common,Spells.condition_phases(selected)))
        for phase in authored:
            if phase.native_cue.authored_at=="spatial_removal":continue
            var grouped:bool=phase.native_cue.get("constructor_input",{}).get("cell_input")=="surface_groups"
            if positions.is_empty() and not wall and not grouped:continue
            var when:Dictionary=phase.native_cue.get("when",{})
            if not when.keys().all(func(field):return effect.get(field)==when[field]):continue
            var geometry_when:Dictionary=phase.native_cue.get("constructor_input",{}).get("geometry_when",{})
            if not geometry_when.is_empty():
                var actual_geometry:Dictionary=effect.get("area_geometry",{}) if effect.get("area_geometry")!=null else {}
                if not geometry_when.keys().all(func(field):return actual_geometry.get(field)==geometry_when[field]):continue
            var wall_forms:Array=phase.native_cue.get("wall_forms",[])
            if not wall_forms.is_empty():
                var geometry:Dictionary=effect.area_geometry if effect.get("area_geometry")!=null else {}
                if geometry.get("path",{}).get("form") not in wall_forms:continue
            var row:Dictionary=common.merged(phase,true)
            row.merge({"id":str(common.id)+":authored:"+str(phase.native_cue.source_index),"kind":"native_effect","native_spell":true,
                "persistent_owner":true,"target_uuid":null,"cast_recipe":{"enabled":false},
                "start_ms":common.start_ms,"absolute_start_ms":common.absolute_start_ms,"duration_ms":common.duration_ms,
                "from_position":anchor,"to_position":anchor,"from_elevation_feet":common.elevation_feet,"to_elevation_feet":common.elevation_feet,
                "ground_target":true,"spatial_content_id":SpatialInputs.content_id(effect),
                "area_geometry":effect.area_geometry if effect.get("area_geometry")!=null else {},"sample_hz":60.0},true)
            # Named optical receivers bind only the current disclosed anchor.
            # A spatial owner is not its caster or an invented actor member.
            if effect.get("anchor_entity_uuid")!=null:
                row.native_actor_uuids={"spatial_anchor":str(effect.anchor_entity_uuid)}
            if phase.native_cue.get("requires_spatial_anchor",false) and effect.get("anchor_position")==null:
                row.status="missing";row.reason="actual_spatial_anchor_not_disclosed"
                row.native_input_gaps=[row.reason];row.trace_keys=[row.id]
                result.append(row);continue
            if not phase.native_cue.get("lifecycle",{}).is_empty():
                row.native_cue=phase.native_cue.duplicate(true)
                row.native_cue.initial=common.initial
                row.native_cue.owner_end_seconds=float(common.duration_ms)/1000.0
            if phase.native_cue.get("constructor_input",{}).get("cell_input")=="wall_assembly":
                row.native_wall=true;row.alpha=1.0
                row.wall_removal_at_seconds=null if is_inf(float(owner.physical_end_ms)) else (float(owner.physical_end_ms)-float(owner.start_ms))/1000.0
                row.wall_contact_prefix=owner.get("spatial_observations",[]).filter(func(observation):return observation.has("contact") and float(observation.at_ms)<=at_ms)
            if grouped:
                result.append_array(surface_samples(owner,phase,row,at_ms));continue
            if phase.native_cue.get("constructor_input",{}).get("cell_input")=="partitioned_surface":
                result.append_array(partition_samples(owner,phase,row));continue
            if phase.native_cue.get("constructor_input",{}).get("cell_input")=="owned_field" and phase.native_cue.constructor_input.get("construct_cells",false):
                result.append_array(owned_cell_samples(owner,phase,row));continue
            var source_effect:Dictionary=owner.get("source_effect",{})
            var source_anchor:Variant=source_effect.get("anchor_position")
            if source_anchor==null and not source_effect.get("positions",[]).is_empty():source_anchor=source_effect.positions[0]
            var observed_removals:Array=owner.get("spatial_removals",[])
            var construction:Dictionary=SpatialInputs.construction(str(id),effect,phase.native_cue,source_effect,observed_removals,SpatialInputs.surface_origin(source_effect,owner.get("source_disclosures",[])))
            if construction.ready:
                row.native_constructor_inputs=construction.operands
                row.native_constructor_evidence=construction.evidence
                if construction.has("source_anchor"):
                    source_anchor=construction.source_anchor
                    var elevation:float=float(construction.source_elevation_steps)*5.0 if construction.source_elevation_steps!=null else 0.0
                    row.merge({"position":source_anchor,"from_position":source_anchor,"to_position":source_anchor,
                        "elevation_feet":elevation,"from_elevation_feet":elevation,"to_elevation_feet":elevation,
                        "spatial_source_cells":construction.source_cells,"spatial_observed_removals":construction.observed_removals,
                        "resolved_area_positions":SpatialInputs.presentation_cells(owner,at_ms,float(phase.removal_retention_ms))},true)
                    if row.resolved_area_positions.is_empty() and not row.get("native_wall",false):continue
            else:
                row.status="missing";row.reason=construction.reason;row.native_input_gaps=[construction.reason]
            row.trace_keys=[row.id]
            result.append(row)
    return result
