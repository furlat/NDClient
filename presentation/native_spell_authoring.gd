extends RefCounted
## Selected native phase data. Event ordering/count/recipients stay in Compiler.
const Authoring=preload("res://presentation/authoring.gd")
const Feedback=preload("res://presentation/spell_feedback.gd")

static func recipe(fact:Dictionary,cache:Dictionary)->Dictionary:
    var raw:=Authoring.spell(fact,cache)
    var selected:=selection(str(fact.get("behavior_id","")),cache)
    if raw.is_empty() or selected.is_empty():return raw
    var treatment=Feedback.prepare(raw,selected.palette,selected.staging,Authoring.load_data("sandbox/feedback.json",cache))
    var result=raw.duplicate(true)
    result.cast=treatment.cast
    if result.get("damage")!=null and not treatment.flash.is_empty():result.damage.hitFlash=treatment.flash
    return result

static func selection(behavior_id:String,cache:Dictionary)->Dictionary:
    var entry:Dictionary=Authoring.load_data("native_effects/index.json",cache).get("spells",{}).get(behavior_id,{})
    if entry.is_empty():return {}
    var manifest:Dictionary=Authoring.load_data(entry.manifest,cache)
    var authored:Dictionary=Authoring.load_data(entry.staging,cache).spells[entry.id]
    var nested:bool=authored.has("staging")
    var original:Dictionary=authored.staging if nested else authored
    # Offline targets, probe attacks and finite demo holds are not game facts.
    var staging:Dictionary={}
    for field in ["cues","bends","light_color","light_color_source","decorative_light_multiplier","feedback_palette"]:
        if original.has(field):staging[field]=original[field].duplicate(true) if original[field] is Array or original[field] is Dictionary else original[field]
    for i in staging.get("cues",[]).size():staging.cues[i].source_index=i
    for spell in manifest.spells:
        if spell.id==entry.id:
            return {"id":entry.id,"clips":spell.clips,"palette":spell.get("palette",{}),
                "source_bounds":entry.get("source_bounds",{}),"lifecycle":entry.get("lifecycle",{}),
                "delivery":entry.get("delivery",{"scope":"single"}),
                "event_cue_indices":entry.get("event_cue_indices",[]).map(func(value):return int(value)),"explicit_event_cues":entry.has("event_cue_indices"),
                "excluded_cue_indices":entry.get("excluded_cue_indices",[]).map(func(value):return int(value)),
                "staging":staging,"source":entry.staging+":/spells/"+entry.id+("/staging" if nested else "")}
    return {}

static func phases(selected:Dictionary,owner:Dictionary,launch_ms:float,travel_ms:float,application_index:int,include_cast:bool)->Array:
    var rows:Array=[]
    var persistent:Array=selected.get("lifecycle",{}).get("cue_ids",[]).map(func(value):return int(value))
    for choice in selected.staging.cues:
        var source_index:int=choice.get("source_index",selected.staging.cues.find(choice))
        if source_index in selected.get("excluded_cue_indices",[]):continue
        if selected.get("explicit_event_cues",false) and source_index not in selected.event_cue_indices:continue
        if source_index in persistent:continue
        if choice.role=="cast" and not include_cast:continue
        rows.append(_phase(selected,choice,owner,launch_ms,travel_ms,application_index))
    return rows

static func _phase(selected:Dictionary,choice:Dictionary,owner:Dictionary,launch_ms:float,travel_ms:float,application_index:int)->Dictionary:
    var staging:Dictionary=selected.staging
    var launch:float=launch_ms/1000.0
    var contact:float=(launch_ms+travel_ms)/1000.0
    var preparation:float=owner.get("prepare",owner.get("start",launch_ms))/1000.0
    var source_index:int=choice.get("source_index",staging.cues.find(choice))
    var source:String=selected.source+"/cues/"+str(source_index)
    var found:Array=selected.clips.filter(func(clip):return clip.id==choice.clip)
    if found.is_empty():
        return {"start_ms":launch_ms,"duration_ms":maxf(1.0,travel_ms),"status":"missing",
            "reason":"native_source_not_imported","native_cue":choice,"native_clip":{},
            "spell_id":selected.id,"source_id":choice.clip,"source":source}
    var clip:Dictionary=found[0]
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
            begin={"cast":preparation,"release":launch,"contact":contact}[cue.get("at","release")]+float(cue.get("delay_seconds",0.0))
            end=begin+native_end/rate
        _:
            return {"start_ms":launch_ms,"duration_ms":maxf(1.0,travel_ms),"status":"missing","reason":"native_phase_role_unsupported",
                "native_cue":cue,"native_clip":clip,"spell_id":selected.id,"source_id":choice.clip,"source":source}
    var bounds:Dictionary=selected.source_bounds.get(clip.id,{})
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
        "clip":clip,"index":application_index},true)
    var row={"start_ms":begin*1000.0,"duration_ms":(end-begin)*1000.0,
        "native_cue":cue,"native_clip":clip,"spell_id":selected.id,"native_lights":bounds.get("lights",[]),
        "source_id":"spell."+selected.id+".native."+str(cue.role),"finish_profile":selected.palette,
        "optical":{"energy_multiplier":staging.get("decorative_light_multiplier",1.0)},"source":source}
    if staging.has("light_color"):row.optical.color=Color(staging.light_color)
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
    # Admitted authoring documents are immutable. Reload replaces the source
    # document; workers receive private cache shells. Publish a complete index
    # once, preserving the original first-match order for duplicate owner IDs.
    var document:Dictionary=Authoring.load_data("native_effects/index.json",cache)
    var spells:Dictionary=document.get("spells",{})
    var held:Dictionary=cache.get("__native_spell_owners",{})
    if not held.is_empty() and is_same(held.document,document) and is_same(held.spells,spells):return held.conditions
    var conditions:Dictionary={}
    for spell_id in spells:
        var lifecycle:Dictionary=spells[spell_id].get("lifecycle",{})
        if lifecycle.get("owner_kind","")!="condition":continue
        for id in lifecycle.get("owner_ids",[]):
            if not conditions.has(id):conditions[id]=spell_id
    held={"document":document,"spells":spells,"conditions":conditions}
    cache.__native_spell_owners=held
    return conditions

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
    var selected:=selection(behavior_id,cache)
    if selected.is_empty():return {}
    var definition:Dictionary=Authoring.load_data("sandbox/body_materials.json",cache).spells.get(selected.id,{})
    var result={"spell_id":selected.id,"definition":definition,"finish_profile":selected.palette}
    if definition.get("status")!="available":return result
    for clip in selected.clips:
        if clip.id==definition.clip:result.clip=clip;break
    return result
