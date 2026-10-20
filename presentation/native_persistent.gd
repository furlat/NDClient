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
    for phase in authored_phases(common.recipe,str(common.condition.behavior_id),cache,str(common.source)):
        var row:Dictionary=common.merged(phase,true)
        row.merge({"id":str(common.id)+":authored:"+str(phase.native_cue.source_index),"kind":"native_effect","native_spell":true,
            "persistent_owner":true,"target_uuid":common.actor_uuid,"cast_recipe":{"enabled":false},
            "start_ms":common.start_ms,"absolute_start_ms":common.absolute_start_ms,"duration_ms":common.duration_ms,
            "from_position":[0,0],"to_position":[0,0],"from_elevation_feet":0.0,"to_elevation_feet":0.0,
            "ground_target":false,"sample_hz":60.0},true)
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
            phase.source=str(config.get("_resource_source",source))+"::effects/"+str(cue.source_index)
            phase.lifecycle={}
            phase.native_cue=phase.native_cue.duplicate()
            phase.native_cue.begin=0.0;phase.native_cue.end=INF
            # The source's observed owner projection owns its return. Generic
            # finite-clip fading would evaluate smoothstep(INF, INF, age).
            phase.native_cue.erase("fade_out_seconds")
            phase.source_id=str(cue.clip)
            phases.append(phase)
        cache[key]=phases
    return cache[key]

static func authored_removal_ms(config:Dictionary)->float:
    var result:float=0.0
    for cue in config.get("persistent",{}).get("nativeEffects",[]):result=maxf(result,float(cue.get("fade_out_seconds",0.0))*1000.0)
    return result

## Lifecycle occurrences of one owner. `common` carries the owner's clock
## (start, duration up to its removal, age, removal age, initial).
static func lifecycle_samples(common:Dictionary,selections:Array,cache:Dictionary)->Array:
    var result:Array=[]
    var spell:Dictionary=common.get("selected_spell",{}) if common.get("spatial_owner",false) else Spells.condition(str(common.condition.behavior_id),cache)
    for selection in selections:
        var lifecycle:Dictionary=selection.condition
        var phases:Dictionary={}
        for phase in ["application","sustain","removal"]:phases[phase]=Effects.clip(str(lifecycle.phases[phase]))
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
            "lifecycle_marker":lifecycle.get("marker",{}),"lifecycle_visibility":lifecycle.get("visibility",{}),
            "spell_id":str(spell.get("id","")),"finish_profile":spell.get("palette",{}) if lifecycle.get("body_channel_included",false) else {},
            "optical":optical,"native_lights":[],"source":source,"source_id":key,"sample_hz":60.0,"trace_keys":[id]},true)
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

static func observe_spatial(owners:Dictionary,effects:Dictionary,at_ms:float,initial:bool=false)->bool:
    var changed:bool=false
    for id in effects:
        if not owners.has(id):
            owners[id]={"id":id,"start_ms":at_ms,"end_ms":INF,"initial":initial,"effect":effects[id],"source_effect":effects[id]}
            changed=true
        else:
            changed=changed or not is_same(owners[id].effect,effects[id]) or not is_inf(owners[id].end_ms)
            owners[id].effect=effects[id];owners[id].end_ms=INF
    for id in owners:
        if not effects.has(id) and is_inf(owners[id].end_ms):owners[id].end_ms=at_ms;changed=true
    return changed

static func spatial_samples(owners:Dictionary,at_ms:float,cache:Dictionary)->Array:
    var result:Array=[]
    for id in owners.keys():
        var owner:Dictionary=owners[id]
        var selected=spatial_selection(owner.effect,cache)
        var effect:Dictionary=owner.effect
        var lifecycles:Array=spatial_lifecycles(effect)
        var config:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache).get(SpatialInputs.content_id(effect),{})
        var authored:Array=authored_phases(config,SpatialInputs.content_id(effect),cache) if not config.get("persistent",{}).get("nativeEffects",[]).is_empty() else []
        if selected.is_empty() and lifecycles.is_empty() and authored.is_empty():continue
        var close_ms:float=removal_ms(lifecycles) if not lifecycles.is_empty() else fade_ms(selected)
        close_ms=maxf(close_ms,authored_removal_ms(config))
        if at_ms>=float(owner.end_ms)+close_ms:owners.erase(id);continue
        var positions:Array=SpatialInputs.admitted_cells(effect)
        if positions.is_empty():continue
        var anchor:Variant=effect.get("anchor_position")
        if anchor==null:anchor=positions[0]
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
            var row:Dictionary=common.merged(phase,true)
            row.merge({"id":str(common.id)+":authored:"+str(phase.native_cue.source_index),"kind":"native_effect","native_spell":true,
                "persistent_owner":true,"target_uuid":null,"cast_recipe":{"enabled":false},
                "start_ms":common.start_ms,"absolute_start_ms":common.absolute_start_ms,"duration_ms":common.duration_ms,
                "from_position":anchor,"to_position":anchor,"from_elevation_feet":common.elevation_feet,"to_elevation_feet":common.elevation_feet,
                "ground_target":true,"spatial_content_id":SpatialInputs.content_id(effect),"sample_hz":60.0},true)
            var construction:Dictionary=SpatialInputs.construction(str(id),effect,phase.native_cue,owner.get("source_effect",{}))
            if construction.ready:
                row.native_constructor_inputs=construction.operands
                row.native_constructor_evidence=construction.evidence
                if construction.has("source_anchor"):
                    var source_anchor:Array=construction.source_anchor
                    var elevation:float=float(construction.source_elevation_steps)*5.0 if construction.source_elevation_steps!=null else 0.0
                    row.merge({"position":source_anchor,"from_position":source_anchor,"to_position":source_anchor,
                        "elevation_feet":elevation,"from_elevation_feet":elevation,"to_elevation_feet":elevation,
                        "spatial_source_cells":construction.source_cells,"spatial_observed_removals":construction.observed_removals},true)
            else:
                row.status="missing";row.reason=construction.reason;row.native_input_gaps=[construction.reason]
            row.trace_keys=[row.id]
            result.append(row)
    return result
