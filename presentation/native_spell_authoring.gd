extends RefCounted
## Selected native phase data. Event ordering/count/recipients stay in Compiler.
## Staging (cues, timing, lifecycle) is the client's; each cue's effect is the
## VFX package clip it names (EffectPackage.resolve).
const Authoring=preload("res://presentation/authoring.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Effects=preload("res://presentation/effect_package.gd")

## A behavior-owned immutable source. Outcome selection never replaces this
## cache entry or writes into a sibling application's recipe/selection.
static func source(behavior_id:String,cache:Dictionary)->Dictionary:
    var record:Resource=Sources.find(behavior_id,cache)
    return {"recipe":record.recipe,"selection":record.selection,"variants":record.variants} if record!=null else {"recipe":{},"selection":{},"variants":[]}

static func selected(source_value:Dictionary,fact:Dictionary,save_context:Dictionary={})->Dictionary:
    var gaps:Array=[]
    for variant in source_value.get("variants",[]):
        if variant.when.is_empty() or not variant.dispatch_gap.is_empty():continue
        var matches:bool=true
        for field in variant.when:
            if field=="save_succeeded":continue
            if field=="damage_types":
                # The producer discloses the chosen element on the cast even
                # when it misses. These fixed-element recipes require exactly
                # one declared type; later damage is not a selection operand.
                var declared:Array=fact.get("damage_types",[])
                if declared.size()!=1 or declared[0] not in variant.when[field]:matches=false;break
                continue
            if fact.get(field)==null or fact[field] not in variant.when[field]:matches=false;break
        if not matches:continue
        if variant.when.has("save_succeeded"):
            if not save_context.get("applicable",true):continue
            var effect:String=variant.save_effect_id
            var save:Dictionary=save_context.get("by_effect",{}).get(effect,{})
            if not save.get("ready",false):
                var reason:String=save.get("reason","save_effect_unavailable")
                if save.is_empty() and not save_context.get("ready",true):reason=save_context.reason
                gaps.append({"variant_id":variant.id,"effect_id":effect,
                    "reason":reason,
                    "evidence":save.get("evidence",{})})
                continue
            if save.save_succeeded not in variant.when.save_succeeded:continue
            var choice:Dictionary=variant.duplicate()
            choice.variant_evidence=save.evidence
            return choice
        return variant
    if gaps.is_empty():return source_value
    var baseline:Dictionary=source_value.duplicate()
    baseline.variant_dispatch_gaps=gaps
    return baseline

static func recipe(fact:Dictionary,cache:Dictionary)->Dictionary:
    var behavior:String=str(fact.get("behavior_id",""))
    var index:Resource=Sources.admission(cache).index
    if index==null:return {}
    if not index.spells.has(behavior):return Authoring.spell(fact,cache)
    return selected(source(behavior,cache),fact).recipe

## Baseline selection for static inventory and condition-parent ownership.
static func selection(behavior_id:String,cache:Dictionary)->Dictionary:
    return source(behavior_id,cache).selection

static func selection_for(fact:Dictionary,cache:Dictionary)->Dictionary:
    return selected(source(str(fact.get("behavior_id","")),cache),fact).selection

## A variant of an unrelated facet cannot opt into Miss contact. Nor can an
## inherited default cue list acquire new impact semantics merely by selection.
static func miss_impact_authored(selected_value:Dictionary,fact:Dictionary)->bool:
    var variant:Dictionary=selected_value.get("variant",{})
    return variant.get("replaces_effects",false) and fact.get("attack_outcome") in variant.get("when",{}).get("attack_outcome",[])

## A disclosed or selected capability asks for eligible resource alternatives.
## This is preparation-only; received occurrences borrow their exact choice.
static func preparation_selection(behavior_id:String,cache:Dictionary)->Dictionary:
    var value:Dictionary=source(behavior_id,cache)
    var alternatives:Array=[]
    for variant in value.variants:
        if not variant.when.is_empty() and variant.dispatch_gap.is_empty():alternatives.append(variant.selection)
    if alternatives.is_empty():return value.selection
    var result:Dictionary=value.selection.duplicate()
    result.preparation_variants=alternatives
    return result

## The package clips this spell's staged cues play (excluded probes omitted).
static func effect_clips(selected:Dictionary)->Array:
    var result:Array=[];var seen:Dictionary={}
    _effect_clips(selected,result,seen)
    for alternative in selected.get("preparation_variants",[]):_effect_clips(alternative,result,seen)
    return result

static func _effect_clips(selected:Dictionary,result:Array,seen:Dictionary)->void:
    var cues:Array=selected.get("staging",{}).get("cues",[])
    var persistent:Array=owned_cues(selected)
    for at in cues.size():
        if at in selected.get("excluded_cue_indices",[]) or at in persistent:continue
        if not cues[at].get("unbound_constructor_inputs",[]).is_empty():continue
        var clip:Dictionary=Effects.for_cue(cues[at],str(selected.get("id","")),str(cues[at].get("role","")))
        if clip.is_empty():continue
        clip=Effects.occurrence_clip({"native_clip":clip,"native_cue":cues[at]})
        var identity:String=Effects.key(clip)
        if seen.has(identity):continue
        if not cues[at].get("constructor_input",{}).is_empty():clip.requires_constructor_input=true
        seen[identity]=true;result.append(clip)

## Staged cues an owner plays instead of the cast: a spatial owner's cue, and
## the spell's attached visual when the package's lifecycle of its condition
## carries it (Shield's bubble opens at the real application, not twice).
## A condition drawn only by an overhead marker keeps the spell's own cue at
## the cast (Command's glyph) beside its marker.
static func owned_cues(selected:Dictionary)->Array:
    var lifecycle:Dictionary=selected.get("lifecycle",{})
    var carried:bool=lifecycle.get("owner_kind")=="spatial_effect" or lifecycle.get("owner_ids",[]).any(func(id):
        return Effects.conditions(str(id)).any(func(selection):return selection.condition.get("body_channel_included",false)))
    return lifecycle.get("cue_ids",[]).map(func(value):return int(value)) if carried else []

## The same event ownership filter supplies phase compilation and its endpoint
## requirements. Held effects cannot demand a recipient for a caster-only cue.
static func event_cues(selected:Dictionary)->Array:
    var persistent:Array=owned_cues(selected)
    return selected.staging.cues.filter(func(choice):
        var source_index:int=choice.source_index
        return source_index not in selected.get("excluded_cue_indices",[]) \
            and (not selected.get("explicit_event_cues",false) or source_index in selected.event_cue_indices) \
            and source_index not in persistent \
            and choice.get("constructor_input",{}).get("projection") not in ["condition_contact","spatial_contact","weapon_component"])

static func phases(selected:Dictionary,owner:Dictionary,launch_ms:float,travel_ms:float,application_index:int,include_cast:bool)->Array:
    var rows:Array=[]
    for choice in event_cues(selected):
        if choice.role=="cast" and not include_cast:continue
        rows.append(_phase(selected,choice,owner,launch_ms,travel_ms,application_index))
    return rows

static func _phase(selected:Dictionary,choice:Dictionary,owner:Dictionary,launch_ms:float,travel_ms:float,application_index:int)->Dictionary:
    var staging:Dictionary=selected.staging
    var launch:float=launch_ms/1000.0
    var contact:float=(launch_ms+travel_ms)/1000.0
    var preparation:float=owner.get("prepare",owner.get("start",launch_ms))/1000.0
    var source_index:int=choice.get("source_index",choice.source_index)
    var source:String=str(choice.get("source",selected.source+"/cues/"+str(source_index)))
    var clip:Dictionary=Effects.for_cue(choice,str(selected.id),str(choice.role))
    if clip.is_empty():
        return {"start_ms":launch_ms,"duration_ms":maxf(1.0,travel_ms),"status":"missing",
            "reason":"effect_not_in_package","native_cue":choice,"native_clip":{},
            "spell_id":selected.id,"source_id":choice.clip,"source":source}
    if not choice.get("constructor_input",{}).is_empty():
        clip=clip.duplicate();clip.requires_constructor_input=true
    var cue:Dictionary=choice.duplicate(true)
    var rate:float=float(cue.get("source_rate",1.0))
    var native_end:float=cue.get("source_end",clip.seconds)
    var begin:float=launch
    var end:float=contact
    var source_launch:float=cue.get("source_launch",0.2)
    var source_contact:float=cue.get("source_contact",maxf(source_launch+0.15,minf(clip.seconds,0.8)))
    match cue.role:
        "cast":
            begin=maxf(preparation,launch-float(cue.get("before_release",0.35)))
            end=begin+native_end/rate
        "flight":
            begin=maxf(preparation,launch-float(cue.get("charge_seconds",0.3)))
            end=contact+maxf(0.0,native_end-source_contact)
        "strike":
            begin=preparation
            end=contact+maxf(0.0,native_end-source_contact)
        "spray":
            begin=launch;end=begin+native_end/rate
        "impact","area":
            begin=contact+float(cue.get("contact_delay",0.0));end=begin+native_end/rate
        "attached":
            begin={"cast":preparation,"cast_start":preparation,"event.start":preparation,"action_start":preparation,
                "release":launch,"contact":contact}[cue.get("at","release")]+float(cue.get("delay_seconds",0.0))
            end=begin+native_end/rate
        _:
            return {"start_ms":launch_ms,"duration_ms":maxf(1.0,travel_ms),"status":"missing","reason":"native_phase_role_unsupported",
                "native_cue":cue,"native_clip":clip,"spell_id":selected.id,"source_id":choice.clip,"source":source}
    # Measured bounds belong to the staged clip (client staging, unchanged).
    var bounds:Dictionary=selected.source_bounds.get(str(choice.clip),{})
    var animation_end:float=bounds.get("animation_end",0.0)
    if cue.get("duration_policy","")!="authored" and not clip.get("bounded_formation",false):
        if cue.role in ["flight","strike"]:end=maxf(end,contact+animation_end-source_contact)
        else:end=maxf(end,begin+animation_end/rate)
    cue.launch=launch-begin;cue.contact=contact-begin
    if cue.get("stop_emission_at_contact",false):end=maxf(end,contact+retained_particle_tail(bounds,cue,cue.contact))
    if cue.has("emission_seconds"):
        cue.emission_stop=float(cue.emission_seconds)
        end=maxf(end,begin+float(cue.emission_seconds)+retained_particle_tail(bounds,cue,cue.emission_stop))
    if cue.get("stop_emission_at_release",false):
        cue.emission_stop=launch-begin
        end=maxf(end,launch+retained_particle_tail(bounds,cue,cue.emission_stop))
    var bends:Array=staging.get("bends",[[0,0]])
    var bend:Array=bends[application_index%bends.size()] if not bends.is_empty() else [0,0]
    cue.merge({"begin":0.0,"end":end-begin,"launch":launch-begin,"contact":contact-begin,
        "source_launch":source_launch,"source_contact":source_contact,"bend":Vector2(bend[0],bend[1]),
        "clip":clip,"staged_clip":str(choice.clip),"index":application_index},true)
    var row={"start_ms":begin*1000.0,"duration_ms":(end-begin)*1000.0,
        "native_cue":cue,"native_clip":clip,"spell_id":selected.id,"native_lights":bounds.get("lights",[]),
        "source_id":"spell."+selected.id+".native."+str(cue.role),"finish_profile":selected.palette,
        "optical":{"energy_multiplier":cue.get("light_multiplier",staging.get("decorative_light_multiplier",1.0))},"source":source}
    if selected.has("variant"):row.native_variant=selected.variant
    if cue.has("light_color"):row.optical.color=Color(cue.light_color)
    elif staging.has("light_color"):row.optical.color=Color(staging.light_color)
    var unbound:Array=cue.get("unbound_constructor_inputs",[])
    if not unbound.is_empty():
        row.status="missing";row.unbound_constructor_inputs=unbound
        row.reason="native_constructor_inputs_unbound:"+",".join(unbound)
    return row

static func retained_particle_tail(bounds:Dictionary,cue:Dictionary,at_seconds:float)->float:
    var rate:float=1.0 if cue.role in ["flight","strike"] and at_seconds>=float(cue.get("contact",INF)) else float(cue.get("source_rate",1.0))
    if not bounds.has("emitters"):return float(bounds.get("particle_tail",0.0))/rate
    var hidden:Array=cue.get("hide_nodes",[]).duplicate()
    if at_seconds>=float(cue.get("launch",INF)):hidden.append_array(cue.get("release_hide",[]))
    if cue.role=="flight" and cue.get("stop_emission_at_contact",false) and at_seconds>=float(cue.get("contact",INF)):
        hidden.append_array(cue.get("contact_hide",[]))
    var tail:float=0.0
    for emitter in bounds.emitters:
        var path:String=emitter.path
        if hidden.any(func(parent):return path==parent or path.begins_with(str(parent)+"/")):continue
        if not emitter.get("layer_enabled",true) and path not in cue.get("show_nodes",[]):continue
        var clock_rate:float=1.0 if emitter.get("clock","source")=="motion" else rate
        tail=maxf(tail,float(emitter.tail_seconds)/clock_rate)
    return tail

static func condition(behavior_id:String,cache:Dictionary)->Dictionary:
    var owners:Dictionary=_condition_owners(cache)
    return selection(owners[behavior_id],cache) if owners.has(behavior_id) else {}

static func _condition_owners(cache:Dictionary)->Dictionary:
    var index:Resource=Sources.admission(cache).index
    return index.conditions if index!=null else {}

static func condition_phases(selected:Dictionary)->Array:
    var result:Array=[]
    var lifecycle:Dictionary=selected.get("lifecycle",{})
    for source_index in lifecycle.get("cue_ids",[]):
        var cue:Dictionary=selected.staging.cues[source_index].duplicate(true)
        var window:Dictionary=lifecycle.get("cues",{}).get(str(int(source_index)),lifecycle)
        for field in window.get("cue_overrides",{}):cue[field]=window.cue_overrides[field]
        var row:Dictionary=_phase(selected,cue,{"start":0.0,"prepare":0.0},0.0,0.0,0)
        row.lifecycle=window
        row.start_ms=0.0;row.duration_ms=INF
        row.condition_owned=true
        if lifecycle.get("optical_owner")=="authoritative_light":
            row.optical.energy_multiplier=0.0
            row.optical.owner="authoritative_light"
        result.append(row)
    return result

static func contact_phases(selected:Dictionary)->Array:
    # The caller supplies an actual condition-interception event. Only the
    # native contact source is reused; the sandbox's hostile probe is omitted.
    var result:Array=[]
    for source_index in selected.get("lifecycle",{}).get("contact_cue_ids",[]):
        var cue:Dictionary=selected.staging.cues[source_index].duplicate(true)
        for field in ["launch_delay_seconds","from_actor","to_actor","travel_to_target"]:cue.erase(field)
        cue.at="contact";cue.delay_seconds=0.0
        result.append(_phase(selected,cue,{"start":0.0,"prepare":0.0},0.0,0.0,0))
    return result

static func hit(behavior_id:String,cache:Dictionary)->Dictionary:
    var record:Resource=Sources.find(behavior_id,cache)
    if record==null:return {}
    if not record.hit.has("clip"):return record.hit
    # The material comes from the package clip staged under the same id.
    var result:Dictionary=record.hit.duplicate(false)
    var clip:Dictionary=Effects.resolve(str(result.clip.get("id","")),str(result.get("spell_id","")))
    if clip.is_empty():result.erase("clip")
    else:result.clip=clip
    return result
