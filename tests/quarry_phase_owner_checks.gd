extends "res://tests/production_condition_handover_checks.gd"
## Retained root absence is a real public-data boundary, not a rendering owner.
const Creation=preload("res://presentation/creation_inputs.gd")
func retained_reapplication_controls()->void:
    for name in ["hex","hunters_mark"]:
        var identity:String="action.spell."+name+".reapply"
        var source:Resource=load("res://authoring/abilities/actions/"+identity+".tres")
        var descriptor:Dictionary=source.effects[0].constructor_input
        var caster:String="retained-caster";var target:String="new-recipient"
        var root_id:String="retained-root-from-prior-group";var child_id:String="new-real-member"
        var root_member:Dictionary={"condition_uuid":root_id,"behavior_id":"condition.spell."+name,
            "state":{"condition_uuid":root_id,"behavior_id":"condition.spell."+name,"applied_source_event_cursor":3}}
        var child:Dictionary={"condition_uuid":child_id,"behavior_id":"condition.spell."+name+".quarry",
            "state":{"condition_uuid":child_id,"behavior_id":"condition.spell."+name+".quarry"}}
        var action:Dictionary={"id":"93","lineage_id":"90","phase":"completion","canceled":false,
            "fact":{"kind":"action","behavior_id":identity,"source_entity_uuid":caster,"target_entity_uuid":target}}
        var admission:Dictionary={"id":"91","lineage_id":"91","parent_lineage":"90","phase":"completion","canceled":false,
            "fact":{"kind":"condition","source_entity_uuid":caster,"target_entity_uuid":target}}
        var graph:Dictionary={"nodes":{"90":action,"91":admission},"condition_cues":{},
            "actor_inputs":{"93":{caster:{"uuid":caster,"conditions":[root_member]}}},
            "observed_results":{"93":[{"kind":"condition_application","node":admission,"target_uuid":target,"condition":child}]}}
        var pair:Dictionary=Creation.quarry_binding(action,graph,descriptor)
        check(pair.get("ready",false) and pair.identity.sustain_condition_uuid==root_id \
            and pair.identity.recipient_condition_uuid==child_id and pair.owner_observation_occurrence=="93" \
            and not pair.has("owner_occurrence"),name+": actual Action keeps the old root and observes its cut without a fabricated application")
        var before:PackedByteArray=var_to_bytes(graph)
        var projected:Array=Results.observed(action,descriptor,graph)
        check(projected.size()==1 and projected[0].publication_occurrences==["93"] \
            and projected[0].inputs.owner_input.condition_uuid==root_id \
            and projected[0].inputs.quarry_input.condition.condition_uuid==child_id \
            and var_to_bytes(graph)==before,name+": source receives only real retained/new members without mutating their clocks")
        var publication_cache:Dictionary={"catalog/body_action_bindings.json":{identity:{"effect_cues":[{"constructor_input":descriptor}]}}}
        var publications:Dictionary=Creation.lifetime_bindings([admission,action],graph,[],publication_cache)
        check(publications.keys()==["93"] and publications["93"].has(child_id) \
            and publications["93"][child_id].evidence.publication_occurrence=="93",
            name+": retained prior-group root publishes at the later real Action/child cut")
        var actors:Dictionary={caster:{"uuid":caster,"conditions":[root_member]},target:{"uuid":target,"conditions":[]}}
        var owners:Dictionary={}
        Conditions.observe(owners,actors,100.0)
        actors[target].conditions=[child]
        Conditions.observe(owners,actors,250.0)
        Conditions.observe(owners,actors,350.0,false,[],{},publications["93"])
        check(owners[root_id].start_ms==100.0 and owners[child_id].start_ms==250.0 \
            and owners[child_id].creation_binding.identity.sustain_condition_uuid==root_id \
            and is_inf(owners[root_id].end_ms),
            name+": late identity publication retains both original membership clocks")
        var live:Dictionary=Creation.quarry_state(publications["93"][child_id],{"actors":actors})
        check(live.ready and live.owner.observed and live.quarry.observed,
            name+": current real root and recipient still control live source admission")
        actors[caster].conditions=[]
        live=Creation.quarry_state(publications["93"][child_id],{"actors":actors})
        check(live.ready and not live.owner.observed and not live.quarry.observed,
            name+": removed retained root withdraws source observation without a replacement clock")
        var actor:Dictionary=graph.actor_inputs["93"][caster]
        actor.conditions=[]
        check(not Creation.quarry_binding(action,graph,descriptor).get("ready",false),name+": undisclosed root remains unavailable")
        actor.conditions=[root_member,root_member.duplicate(true)]
        check(not Creation.quarry_binding(action,graph,descriptor).get("ready",false),name+": ambiguous roots are refused")
        actor.conditions=[root_member]
        graph.observed_results["93"]=[]
        check(not Creation.quarry_binding(action,graph,descriptor).get("ready",false),name+": no new member means no reapplication source")

func run()->void:
    retained_reapplication_controls()
    var entries:Dictionary={};var paths:Dictionary={};var conditions:Dictionary={}
    for name in ["hex","hunters_mark"]:
        var id:String="spell."+name;var path:String="res://authoring/abilities/spells/"+id+".tres"
        var entry:Resource=load(path);entries[id]=entry;paths[id]=path
        conditions[HANDOVERS[name].owner]=load("res://authoring/abilities/conditions/"+HANDOVERS[name].owner+".tres")
        check(entry.owner_cues.is_empty() and Array(entry.excluded_cues)==[2,4],name+": fixed review hold/retire are replaced by the typed recipient owner")
        check(entry.effects[0].unbound_constructor_inputs.is_empty() and entry.effects[0].constructor_input.projection=="quarry_application" \
            and entry.effects[0].constructor_input.owner_condition_id=="condition.spell."+name,name+": finite source names the exact real sustain and recipient contracts")
    var built:Dictionary=Build.documents({"spells":entries,"conditions":conditions,
        "contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}}, {"spells":paths})
    for name in ["hex","hunters_mark"]:
        var selection:Dictionary=built.native.records["spell."+name].selection
        check(Spells.owned_cues(selection).is_empty() and Spells.event_cues(selection).map(func(cue):return cue.source_index)==[0,1],name+": finite application/windup remain distinct from typed retained ownership and attributed rider contacts")
        var finite:Array=Spells.phases(selection,{"prepare":0.0},1000.0,0.0,0,true)
        check(finite.size()==2 and finite.all(func(row):return row.native_cue.constructor_input.projection=="quarry_application" \
            and row.native_cue.constructor_input.owner_condition_id=="condition.spell."+name),name+": both finite sources require the real quarry application rather than a successful review fixture")
        var directory:String=original_directory(name)
        check(not directory.is_empty(),name+": unchanged durable originals exist")
        if directory.is_empty():continue
        for seat in ["amber","blue"]:
            var path:String=directory.path_join(seat).path_join("journal")
            # Existing independent fold/compiler/UUID ownership and drain checks.
            recorded_owner(name,path,seat,built,paths)
            var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(path,true)
            check(opened.ok,name+"/"+seat+": independent final canonical state opens")
            if not opened.ok:continue
            var all_members:Array=[]
            for actor in journal.state.actors.values():all_members.append_array(actor.conditions)
            var child:Array=all_members.filter(func(member):return member.behavior_id=="condition.spell."+name+".quarry")
            var roots:Array=all_members.filter(func(member):return member.behavior_id=="condition.spell."+name)
            var concentrating:Array=all_members.filter(func(member):return member.behavior_id=="condition.concentrating")
            check(child.size()==1 and roots.is_empty() and concentrating.size()==1,name+"/"+seat+": actual child and Concentrating do not disclose the distinct retained root")
            if child.size()==1 and concentrating.size()==1:
                check(child[0].condition_uuid!=concentrating[0].condition_uuid,name+"/"+seat+": recipient and concentration UUIDs stay distinct")
    print("QUARRY_PHASE_OWNER ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Both original Hex/HuntersMark child admissions through the ordinary compiler and independent canonical reducer; typed current finite/retained/attributed contracts and no bounded duplicates. These preserved old originals still lack their distinct public caster sustain UUID and cannot admit a fabricated quarry source. No new root, attributed rider, removal recording or native-output qualification claimed."}))
    quit(0 if failures.is_empty() else 1)
