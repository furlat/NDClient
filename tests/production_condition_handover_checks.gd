extends "res://tests/support_spell_event_checks.gd"
## Production metadata and original admitted memberships, not native pixels.
const HANDOVERS={
    "acid_arrow":{"owner":"condition.spell.acid_arrow","cues":[2],"keep":[0,1,3,4],"lifecycle":"condition_acid_arrow_persistent"},
    "branding_smite":{"owner":"condition.spell.branding_smite","cues":[1,2],"keep":[],"results":{0:"weapon_component"},"lifecycle":"condition_branding_smite_persistent","producer_gap":true},
    "divine_favor":{"owner":"condition.spell.divine_favor","cues":[1,2,3],"keep":[0],"lifecycle":"condition_divine_favor_persistent"},
    "ensnaring_strike":{"owner":"condition.spell.ensnaring_strike","cues":[0,1,3],"keep":[],"results":{2:"condition_contact"},"lifecycle":"condition_ensnaring_vines_persistent","producer_gap":true},
    "hex":{"owner":"condition.spell.hex.quarry","cues":[],"keep":[0,1],"lifecycle":"condition_hex_persistent","mode":"quarry"},
    "hunters_mark":{"owner":"condition.spell.hunters_mark.quarry","cues":[],"keep":[0,1],"lifecycle":"condition_hunters_mark_persistent","mode":"quarry"},
    "magic_weapon":{"owner":"condition.spell.magic_weapon","cues":[2,3],"owned":[],"keep":[],"lifecycle":"condition_magic_weapon_persistent","baseline_has_owner":false,"mode":"item"},
    "searing_smite":{"owner":"condition.spell.searing_smite","cues":[1,2],"keep":[],"results":{0:"weapon_component",3:"condition_contact",4:"weapon_component"},"lifecycle":"condition_burning_persistent","producer_gap":true},
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
        var condition:Resource=condition_entries[spec.owner]
        if spec.get("mode")=="quarry":
            check(condition.effects.size()==1 and condition.effects[0].constructor_input.get("kind")=="quarry_owner" \
                and condition.effects[0].constructor_input.get("recipient_condition_id")==spec.owner,id+" actual quarry source requires the distinct public sustain/recipient owners")
        elif spec.get("mode")=="item":
            var context:Resource=load("res://authoring/abilities/contexts/item_attachments.tres")
            var item_uses:Array=context.effects.filter(func(use):return use.item_effect_behavior_id==spec.owner)
            check(not condition.play_package_lifecycle and item_uses.size()==1 and item_uses[0].extra.has("item_lifecycle"),id+" exact global item owner replaces actor-condition review probes")
        else:
            check(condition.play_package_lifecycle,id+" actual typed condition permits its delivered lifecycle")
            var lifecycles:Array=Effects.conditions(spec.owner)
            check(lifecycles.any(func(selection):return selection.key==spec.lifecycle and selection.condition.get("body_channel_included",false) \
                and selection.condition.get("complete_visual_channels",false)),id+" exact delivered complete body lifecycle exists")
    var built:Dictionary=Build.documents({"spells":entries,"conditions":condition_entries,
        "contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}}, {"spells":paths})
    var cache:Dictionary=source_cache(built,paths)
    for name in HANDOVERS:
        var spec:Dictionary=HANDOVERS[name];var selected:Dictionary=built.native.records["spell."+name].selection
        var frozen:PackedByteArray=var_to_bytes(selected)
        check(Spells.owned_cues(selected)==spec.get("owned",spec.cues),name+" existing ownership filter consumes exactly the held/retire duplicates")
        check(Spells.event_cues(selected).map(func(cue):return cue.source_index)==spec.keep,name+" ordinary event cues exclude retained owners and separately admitted result contacts")
        for ordinal in spec.get("results",{}):
            var cue:Dictionary=selected.staging.cues[ordinal]
            check(cue.constructor_input.get("kind")=="observed_event" and cue.constructor_input.get("projection")==spec.results[ordinal] \
                and not cue.get("clip","").is_empty() and ordinal not in Spells.event_cues(selected).map(func(value):return value.source_index),
                name+" result cue"+str(ordinal)+" retains its exact actual-result consumer instead of replaying on every cast")
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
        var rows:Array=samples.filter(func(row):return row.get("condition_uuid")==uuid)
        if spec.get("mode")=="quarry":
            var owner:Dictionary=timeline.condition_owners[uuid]
            check(not owner.get("creation_binding",{}).get("ready",false) and not rows.any(func(row):return row.get("native_quarry",false)),
                label+" this archived child without a public sustain root cannot construct a successful quarry fixture")
        else:
            rows=rows.filter(func(row):return row.get("lifecycle_key")==spec.lifecycle)
            check(rows.size()==1 and rows[0].persistent_owner and rows[0].actor_uuid==actual[uuid] \
                and rows[0].native_clip.id==Effects.conditions(spec.owner).filter(func(value):return value.key==spec.lifecycle)[0].condition.phases.application,
                label+" one exact delivered native occurrence is owned by this actual recipient/condition")
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),label+" presentation drains to this seat's independently folded canonical state")
    evidence.append({"spell":name,"seat":seat,"journal":directory,"actual_condition_uuids":actual.keys(),"finite_duplicates":finite_duplicates})
