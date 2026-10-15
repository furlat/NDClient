extends SceneTree
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const Authoring=preload("res://presentation/authoring.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_BATCH_AUTHORING_FAIL ",label)

func run()->void:
    var cache:Dictionary={}
    var entries:Dictionary=Authoring.load_data("native_effects/index.json",cache).spells
    var manifest:Dictionary=Authoring.load_data("sandbox/projectiles.json",cache)
    var expected:Array=manifest.spells.filter(func(spell):return spell.id not in ["aid","bless","false_life","sacred_flame"]).map(func(spell):return "spell."+spell.id)
    check(entries.size()==30 and entries.keys().all(func(id):return id in expected),"Exactly the30 included native spells are registered")
    for deferred in ["aid","bless","false_life","sacred_flame"]:check(Spells.selection("spell."+deferred,cache).is_empty(),deferred+": explicit deferral stays inactive")
    var roles:Dictionary={}
    for id in expected:
        var selected:Dictionary=Spells.selection(id,cache)
        check(not selected.is_empty(),id+": selected imported source resolves")
        if selected.is_empty():continue
        check(selected.delivery.scope in ["area","application","single"],id+": delivery scope is explicit data")
        for field in ["deliveries","delivery_interval","body_actions","actor_items","target_position","contact_after_release","target_local"]:
            check(not selected.staging.has(field),id+": offline fixture field does not enter production selection: "+field)
        var before:Dictionary=selected.duplicate(true)
        var phases:Array=Spells.phases(selected,{"start":0.0,"prepare":0.0},1000.0,500.0,1,true)
        var conditions:Array=Spells.condition_phases(selected)
        var contacts:Array=Spells.contact_phases(selected)
        check(not phases.is_empty() or not conditions.is_empty(),id+": actual event or persistent owner has native phases")
        for phase in phases+conditions+contacts:
            var cue:Dictionary=phase.native_cue
            roles[cue.role]=true
            check(phase.get("status","available")!="missing",id+": all chosen clips are imported")
            check(selected.source_bounds.has(phase.native_clip.id),id+": chosen clip has measured native source bounds")
            check(phase.source.begins_with(selected.source+"/cues/"),id+": phase keeps the exact authored cue pointer")
            check(phase.duration_ms>0 and not is_nan(phase.duration_ms),id+": phase duration is positive")
            check(cue.end>cue.begin and is_finite(cue.end),id+": native source has a finite visual interval")
            if cue.role in ["flight","strike"]:
                check(is_equal_approx(Playback.source_time(cue,cue.contact),cue.source_contact),id+": source contact is aligned with the actual delivery clock")
            if cue.get("stop_emission_at_contact",false):
                check(cue.end+0.00001>=cue.contact+Spells.retained_particle_tail(selected.source_bounds[phase.native_clip.id],cue,cue.contact),id+": retained source particle tail survives emission cutoff")
        for phase in conditions:
            check(is_inf(phase.duration_ms),id+": finite source duration is not the owner's game expiry")
            var window:Dictionary=phase.lifecycle
            check(window.hold_mode in ["hold","loop"] and not window.source_evidence.is_empty(),id+": source hold has explicit inspected provenance")
            check(window.enter_end_seconds>=0 and window.hold_start_seconds>=window.enter_end_seconds and window.hold_end_seconds>=window.hold_start_seconds,id+": source entry/hold window is ordered")
            check(window.exit_start_seconds>=window.hold_end_seconds and window.exit_end_seconds>=window.exit_start_seconds,id+": source close window is ordered")
            check(not phases.any(func(transient):return transient.source==phase.source),id+": condition-owned application is not duplicated by event phases")
        var lifecycle:Dictionary=selected.lifecycle
        if lifecycle.get("owner_kind")=="condition":
            for condition_id in lifecycle.owner_ids:
                check(Spells.condition(condition_id,cache).id==selected.id,id+": exact disclosed condition behavior selects its source")
        check(before==selected,id+": phase compilation leaves retained authoring immutable")
        evidence.append({"spell_id":selected.id,"scope":selected.delivery.scope,"event_phases":phases.size(),"owner_phases":conditions.size(),"interception_phases":contacts.size(),"owners":lifecycle.get("owner_ids",[])})
    for role in ["cast","flight","impact","strike","spray","area","attached"]:check(roles.has(role),"Whole batch covers native role "+role)
    var shield=Spells.selection("spell.shield",cache)
    check(Spells.phases(shield,{"start":0},0,0,0,true).is_empty(),"Shield casting does not invent a hostile projectile or interception")
    var contact=Spells.contact_phases(shield)
    check(contact.size()==1 and contact[0].native_cue.role=="attached","Real Shield interception has exactly its native contact source")
    for field in ["launch_delay_seconds","from_actor","to_actor","travel_to_target"]:check(not contact[0].native_cue.has(field),"Shield interception omits demonstration field "+field)
    var light=Spells.condition_phases(Spells.selection("spell.light",cache))
    check(light.size()==1 and light[0].optical.energy_multiplier==0 and light[0].optical.owner=="authoritative_light","Native Light visual does not duplicate authoritative optical illumination")
    var ice=Spells.selection("spell.ice_knife",cache)
    check(ice.delivery.effects["spell.ice_knife.burst"].roles==["area"],"Ice Knife burst is separately selected by the actual burst effect ID")
    var report={"checks":checks,"failed":failures.size(),"failures":failures,"spells":evidence,"scope":"All30 existing nondeferred source registrations, authored roles/clocks/tails, real condition behavior selection and exclusion of offline demo facts. This does not replace real-event or native pixel qualification."}
    FileAccess.open("res://.runtime/native-spell-batch-authoring-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_BATCH_AUTHORING ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
    quit(0 if failures.is_empty() else 1)
