extends "res://tests/support_spell_event_checks.gd"
## Production metadata and original admitted memberships, not native pixels.
const HANDOVERS={
    "acid_arrow":{"owner":"condition.spell.acid_arrow","cues":[2],"keep":[0,1,3,4],"lifecycle":"condition_acid_arrow_persistent"},
    "branding_smite":{"owner":"condition.spell.branding_smite","cues":[1,2],"keep":[0],"lifecycle":"condition_branding_smite_persistent","producer_gap":true},
    "divine_favor":{"owner":"condition.spell.divine_favor","cues":[2,3],"keep":[0,1,4],"lifecycle":"condition_divine_favor_persistent"},
    "ensnaring_strike":{"owner":"condition.spell.ensnaring_strike","cues":[1,3],"keep":[0,2],"lifecycle":"condition_ensnaring_vines_persistent","producer_gap":true},
    "hex":{"owner":"condition.spell.hex.quarry","cues":[2,4],"keep":[0,1,3],"lifecycle":"condition_hex_persistent"},
    "hunters_mark":{"owner":"condition.spell.hunters_mark.quarry","cues":[2,4],"keep":[0,1,3],"lifecycle":"condition_hunters_mark_persistent"},
    "magic_weapon":{"owner":"condition.spell.magic_weapon","cues":[2,3],"keep":[0,1],"lifecycle":"condition_magic_weapon_persistent","baseline_has_owner":false},
    "searing_smite":{"owner":"condition.spell.searing_smite","cues":[1,2],"keep":[0,3],"lifecycle":"condition_burning_persistent","producer_gap":true},
    "shillelagh":{"owner":"condition.spell.shillelagh","cues":[0],"keep":[],"lifecycle":"condition_shillelagh_persistent"},
    "starry_wisp":{"owner":"condition.spell.starry_wisp","cues":[2,3],"keep":[0,1],"lifecycle":"condition_starry_wisp_persistent"}}
const Conditions=preload("res://presentation/conditions.gd")
var recordings_root:String="res://tests/fixtures/schema16/production-condition-handover"
func run()->void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recordings-root="):recordings_root=argument.trim_prefix("--recordings-root=")
    var entries:Dictionary={};var paths:Dictionary={};var condition_entries:Dictionary={}
    for name in HANDOVERS:
        var id:String="spell."+name;var path:String="res://authoring/abilities/spells/"+id+".tres"
        entries[id]=load(path);paths[id]=path
        var spec:Dictionary=HANDOVERS[name];var entry:Resource=entries[id]
        condition_entries[spec.owner]=load("res://authoring/abilities/conditions/"+spec.owner+".tres")
        check(entry.owner_kind=="condition" and Array(entry.owner_ids)==[spec.owner] and Array(entry.owner_cues)==spec.cues,id+" names the exact existing condition and only held/retire cues")
        check(condition_entries[spec.owner].play_package_lifecycle,id+" actual typed condition permits its delivered lifecycle")
        var lifecycles:Array=Effects.conditions(spec.owner)
        check(lifecycles.any(func(selection):return selection.key==spec.lifecycle and selection.condition.get("body_channel_included",false) \
            and selection.condition.get("complete_visual_channels",false)),id+" exact delivered complete body lifecycle exists")
    var built:Dictionary=Build.documents({"spells":entries,"conditions":condition_entries,
        "contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}}, {"spells":paths})
    var cache:Dictionary=source_cache(built,paths)
    for name in HANDOVERS:
        var spec:Dictionary=HANDOVERS[name];var selected:Dictionary=built.native.records["spell."+name].selection
        var frozen:PackedByteArray=var_to_bytes(selected)
        check(Spells.owned_cues(selected)==spec.cues,name+" existing ownership filter consumes exactly the held/retire duplicates")
        check(Spells.event_cues(selected).map(func(cue):return cue.source_index)==spec.keep,name+" cast/application/impact/hit/tick/reveal accents remain event cues")
        check(Spells.condition(spec.owner,cache).id==name,name+" exact UUID lifecycle resolves the authored spell finish through ordinary ownership")
        check(var_to_bytes(selected)==frozen,name+" ownership inspection does not mutate shared selections")
        if spec.get("producer_gap",false):
            evidence.append({"spell":name,"qualification":"source_handover_only","gap":"frozen211_command_game_failed"})
            continue
        var directory:String=original_directory(name)
        check(not directory.is_empty(),name+" successful original recording is available")
        if directory.is_empty():continue
        for seat in ["amber","blue"]:recorded_owner(name,directory.path_join(seat).path_join("journal"),seat,built,paths)
    print("PRODUCTION_CONDITION_HANDOVER ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Ten exact source handovers, preserved finite accents and seven original two-seat compiler paths (six admitted owners, one actual no-owner cast); three producer failures, native output, unseen retirements and visual acceptance remain separate."}))
    quit(0 if failures.is_empty() else 1)
func original_directory(name:String)->String:
    var root_path:String=recordings_root.path_join("spell."+name+"__baseline")
    var directories:PackedStringArray=DirAccess.get_directories_at(root_path);directories.sort();directories.reverse()
    for directory in directories:
        var path:String=root_path.path_join(directory)
        var receipt:Variant=JSON.parse_string(FileAccess.get_file_as_string(path.path_join("recording.json")))
        if receipt!=null and receipt.get("ok",false):return path
    return ""
func recorded_owner(name:String,directory:String,seat:String,built:Dictionary,paths:Dictionary)->void:
    var label:String=name+"/"+seat;var spec:Dictionary=HANDOVERS[name]
    var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,label+" opens the unchanged original audience journal")
    if not opened.ok:return
    var cache:Dictionary=source_cache(built,paths);var timeline:RefCounted=Timeline.new();var duration:float=0.0
    var actual:Dictionary={};var finite_duplicates:int=0;var casts:int=0
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var sequence:int=int(file.get_basename());var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        var decoded:Dictionary=journal.decode_record(sequence,raw);check(decoded.ok,label+" decode "+str(sequence))
        if not decoded.ok:return
        var before:Dictionary=journal.state;var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,label+" fold "+str(sequence))
        if not folded.ok:return
        if sequence==0:
            timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var immutable:PackedByteArray=var_to_bytes(folded.normalized)
        for lineage in folded.normalized.lineages:
            for node in lineage.events:
                var fact:Variant=node.get("fact")
                if node.get("canceled",false) or fact==null:continue
                if fact.kind=="spell" and fact.get("behavior_id")=="spell."+name:casts+=1
                if fact.kind!="actor_change":continue
                for actor in fact.actors:
                    for change in actor.rows:
                        if change.field=="condition" and change.get("member")!=null and change.member.behavior_id==spec.owner:
                            actual[change.member.condition_uuid]=actor.actor_uuid
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,label+" ordinary compiler accepts original operation "+str(sequence))
        if not compiled.ok:return
        for group in compiled.value.groups:
            for component in group.components:
                if component.get("spell_id")==name and component.get("native_cue",{}).get("source_index",-1) in spec.cues \
                    and not component.get("persistent_owner",false):finite_duplicates+=1
            duration+=group.duration_ms
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        check(var_to_bytes(folded.normalized)==immutable,label+" compilation preserves original operation facts")
    timeline.advance(duration+1000.0)
    check(casts>0,label+" actual cast was disclosed")
    check(not actual.is_empty() if spec.get("baseline_has_owner",true) else actual.is_empty(),label+" original same-family membership presence/absence is preserved")
    check(finite_duplicates==0,label+" handed-over cues are not compiled as bounded cast copies")
    var samples:Array=Conditions.native_samples(timeline.condition_owners,duration+1000.0,cache)
    if not spec.get("baseline_has_owner",true):
        check(not samples.any(func(row):return row.get("condition",{}).get("behavior_id")==spec.owner),label+" cast without a real owner does not synthesize a held lifetime")
    for uuid in actual:
        check(timeline.condition_owners.has(uuid),label+" original condition UUID owns the retained lifetime")
        var rows:Array=samples.filter(func(row):return row.get("condition_uuid")==uuid and row.get("lifecycle_key")==spec.lifecycle)
        check(rows.size()==1 and rows[0].persistent_owner and rows[0].actor_uuid==actual[uuid] \
            and rows[0].native_clip.id==Effects.conditions(spec.owner).filter(func(value):return value.key==spec.lifecycle)[0].condition.phases.application,
            label+" one exact delivered native occurrence is owned by this actual recipient/condition")
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),label+" presentation drains to this seat's independently folded canonical state")
    evidence.append({"spell":name,"seat":seat,"journal":directory,"actual_condition_uuids":actual.keys(),"finite_duplicates":finite_duplicates})
