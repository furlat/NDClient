extends "res://tests/production_condition_handover_checks.gd"
## Retained root absence is a real public-data boundary, not a rendering owner.
func run()->void:
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
