extends SceneTree
## Actual native sensory masks/source dictionaries retain ownership through
## semantic and durability refusal, retry, duplicate, cold replay and rollback.
const Journal=preload("res://sdk/journal.gd")
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ORACLE="res://tests/fixtures/schema16/spool-oracle"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
var later_retries:int=0
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("SDK_SENSORY_JOURNAL_FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var directory:String=ORACLE
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--oracle="):directory=arg.trim_prefix("--oracle=")
    var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("index.json")))
    var states:=ZIPReader.new()
    check(states.open(directory.path_join(index.states_archive))==OK,"Independent frozen Python canonical archive opens")
    for seat in index.seats:original(directory,seat,states)
    states.close()
    check(evidence.size()==4 and evidence.all(func(row):return row.semantic_refusal and row.durable_refusal and row.replay_rollback),"Both actual Door and lethal-OA faction prefixes exercise the full publication-refusal boundary")
    check(later_retries==2,"Both Door originals supply a genuine following operation for retry after replay refusal; final lethal-OA cuts do not invent one")
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"producer_reference":index.reference,
        "scope":"Actual native16 Door/lethal-OA prefixes and independent frozen Python cuts. Late malformed-HUD and durable-write controls preserve canonical masks and exact retained derived-index ownership; recording-on/off equality, actual retry, frozen event captures, duplicate, replay rollback and initialization seek. No synthetic positive operation, compatibility replay or rendering claim."}
    FileAccess.open("res://generated/sdk_sensory_journal_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SDK_SENSORY_JOURNAL_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func original(directory:String,seat:Dictionary,states:ZIPReader)->void:
    var path:String="user://sensory-native-"+str(Time.get_ticks_usec())
    var journal:RefCounted=Journal.new()
    check(journal.open(path).ok,str(seat.id)+": isolated native journal opens")
    journal.protocol=Protocol.new(Protocol.PRE_REVIEW_SCHEMA,Protocol.PRE_REVIEW_IDENTITY)
    var exercised:bool=false;var pending_retry:int=-1;var captures:Array=[];var capture_copies:Array=[]
    var held:Array=[];var frozen:Array=[];var selected:int=-1;var later:bool=false
    for sequence in seat.records.size():
        var record:Dictionary=seat.records[sequence];var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(record.bytes))
        var decoded:Dictionary=journal.protocol.decode("InitializationResponse" if sequence==0 else "PlayerOperation",raw)
        check(decoded.ok,str(seat.id)+": original native packet strictly admits "+str(sequence))
        if not decoded.ok:break
        var packet:Dictionary=decoded.value;var sensory_count:int=0
        for lineage in packet.get("lineages",[]):
            for event in lineage.events:
                if not event.get("canceled",false) and event.get("fact")!=null and event.fact.kind=="sensory":sensory_count+=1
        var candidate:bool=sequence>0 and sensory_count>0 and not exercised
        if candidate:
            selected=sequence
            var owned:Dictionary=journal.state;var before:Dictionary=journal.snapshot();var cursor:Dictionary=journal.cursor.duplicate(true)
            var senses:Dictionary=journal.state.senses;var visible:Dictionary=senses.visible;var seen:Dictionary=senses.seen
            var lights:Dictionary=journal.state.light_sources;var context:Dictionary=journal._sensory_context;var context_copy:Dictionary=context.duplicate(true)
            check(int(visible.width)>0 and int(seen.width)>0 and senses.effective_light_levels.cells==visible,str(seat.id)+": control holds actual native encoded visible/seen/light cells")
            var plain:Dictionary=Reducer._reduce_operation_retained(owned,packet,false,null,context)
            var recorded:Dictionary=Reducer._reduce_operation_retained(owned,packet,true,null,context)
            check(plain.ok and recorded.ok,str(seat.id)+": the same actual sensory operation folds with recording off and on")
            if plain.ok and recorded.ok:
                check(not plain.has("transitions") and recorded.has("transitions") and Compare.difference(plain.value,recorded.value).is_empty(),str(seat.id)+": capture omission preserves the complete canonical result")
                check(is_same(plain.sensory_context.state,plain.value) and is_same(recorded.sensory_context.state,recorded.value),str(seat.id)+": each reduction publishes only its own accepted-state index owner")
                for result in [plain,recorded]:
                    var world:Dictionary=result.sensory_context.world
                    check(world.initialized and is_same(world.source_objects,result.value.objects) and is_same(world.source_connectors,result.value.connectors),str(seat.id)+": disclosure lookup belongs to the exact recording-on/off candidate stores")
                var mismatched:Dictionary=context.duplicate();mismatched.state=owned.duplicate(true)
                var cold:Dictionary=Reducer._reduce_operation_retained(owned,packet,true,null,mismatched)
                check(cold.ok and Compare.difference(cold.value,recorded.value).is_empty() and cold.transitions==recorded.transitions,str(seat.id)+": another state owner takes the cold path without changing canonical/capture output")
            check(journal.state==before and context==context_copy,str(seat.id)+": both private candidates leave the committed state/index unchanged")
            var invalid:Dictionary=packet.duplicate(true)
            # Deliberately malformed final HUD resource key. Every original
            # native lineage, source table and sensory row remains unchanged.
            var sheet:Dictionary=before.hud_snapshot.sheets[0];var resource:Dictionary=sheet.resources[0]
            var bad:Dictionary={"actor_uuid":sheet.actor_uuid,"changes":{},"resource_values":[{"key":str(resource.key)+":not-held-control","current":resource.current,"maximum":resource.maximum}]}
            invalid.hud=packet.hud.duplicate(true) if packet.get("hud")!=null else {}
            var patches:Array=invalid.hud.get("sheets",[]).duplicate(true);patches=patches.filter(func(row):return row.actor_uuid!=sheet.actor_uuid);patches.append(bad);invalid.hud.sheets=patches
            var invalid_copy:Dictionary=invalid.duplicate(true);var original:Dictionary=packet.duplicate(true)
            var invalid_raw:PackedByteArray=JSON.stringify(invalid,"",false,true).to_utf8_buffer()
            check(journal.protocol.decode("PlayerOperation",invalid_raw).ok,str(seat.id)+": malformed final HUD stays schema-admitted")
            var denied:Dictionary=journal._consume_admitted(invalid,invalid_raw,true)
            check(not denied.ok and denied.error.message=="Resource values name a row the sheet does not hold" and not denied.has("transitions"),str(seat.id)+": exact late HUD refusal publishes no event captures")
            check(journal.state==before and journal.cursor==cursor and invalid==invalid_copy and packet==original,str(seat.id)+": late refusal preserves state/cursor and both input packets")
            check(context==context_copy,str(seat.id)+": late semantic refusal leaves the preceding derived index unchanged")
            owned_boundary(journal,owned,senses,visible,seen,lights,context,str(seat.id)+": late semantic refusal")
            var destination:String=path.path_join("%016d.json"%sequence)
            check(not FileAccess.file_exists(destination),str(seat.id)+": semantic refusal never commits malformed bytes")
            check(DirAccess.make_dir_absolute(destination)==OK,str(seat.id)+": obstruct exact durable rename after candidate reduction")
            denied=journal._consume_admitted(packet,raw,true)
            check(not denied.ok and not denied.has("transitions"),str(seat.id)+": durability refusal publishes no captures")
            check(journal.state==before and journal.cursor==cursor and context==context_copy,str(seat.id)+": durability refusal preserves exact preceding cut")
            owned_boundary(journal,owned,senses,visible,seen,lights,context,str(seat.id)+": durable refusal")
            DirAccess.remove_absolute(destination)
        var accepted:Dictionary=journal._consume_admitted(packet,raw,true)
        check(accepted.ok,str(seat.id)+": exact original retry/commit succeeds "+str(sequence))
        if not accepted.ok:break
        check(FileAccess.get_file_as_bytes(journal._file(sequence))==raw,str(seat.id)+": committed original bytes remain exact")
        var expected:Variant=JSON.parse_string(states.read_file(record.expected).get_string_from_utf8())
        var issue:String=Compare.difference(journal.state,expected)
        check(issue.is_empty(),str(seat.id)+": full independent Python prefix "+str(sequence)+" "+issue)
        var world_context:Dictionary=journal._sensory_context.world
        check(world_context.initialized and is_same(world_context.source_objects,journal.state.objects) and is_same(world_context.source_connectors,journal.state.connectors),str(seat.id)+": committed disclosure index has the actual canonical store owner")
        for i in held.size():check(held[i]==frozen[i],str(seat.id)+": later publication leaves earlier native cut unchanged "+str(i))
        for i in captures.size():check(captures[i]==capture_copies[i],str(seat.id)+": later retry preserves earlier event-time captures "+str(i))
        held.append(journal.state);frozen.append(journal.snapshot())
        if accepted.has("transitions"):captures.append(accepted.transitions);capture_copies.append(accepted.transitions.duplicate(true))
        if pending_retry==sequence:
            check(accepted.has("transitions"),str(seat.id)+": actual following operation retries after replay refusal and publishes its real captures")
            later_retries+=1;pending_retry=-1
        if candidate:
            var admitted_context:Dictionary=journal._sensory_context
            check(accepted.has("transitions") and is_same(admitted_context.get("state"),journal.state) and is_same(admitted_context.get("senses"),journal.state.senses),str(seat.id)+": native retry binds captures and derived indexes to the actual committed cut")
            check(is_same(admitted_context.get("cells",{}).get("mask"),journal.state.senses.visible),str(seat.id)+": retained visible index belongs to that exact canonical mask")
            var after:Dictionary=journal.state;var after_copy:Dictionary=journal.snapshot();var after_context:Dictionary=journal._sensory_context
            var after_context_copy:Dictionary=after_context.duplicate(true)
            var at:int=sequence+1 if sequence+1<seat.records.size() else sequence
            later=at>sequence
            var bad_raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(seat.records[at].bytes))
            var next:Dictionary=journal.protocol.decode("PlayerOperation",bad_raw)
            check(next.ok,str(seat.id)+": actual replay-control original strictly admits")
            if not next.ok:break
            var broken:Dictionary=next.value.duplicate(true);broken.lineages[-1].start_cursor+=1
            var bad_path:String=path.path_join("%016d.json"%at)
            var file:=FileAccess.open(bad_path,FileAccess.WRITE);file.store_string(JSON.stringify(broken,"",false,true));file.close()
            var denied:Dictionary=journal.replay()
            check(not denied.ok,str(seat.id)+": strict replay refuses the malformed native lineage gap")
            check(journal.state==after_copy and is_same(journal.state,after) and journal.cursor.sequence==sequence and is_same(journal._sensory_context,after_context) and after_context==after_context_copy,str(seat.id)+": replay rollback restores the complete prior canonical/source/index owner and its contents")
            if later:DirAccess.remove_absolute(bad_path);pending_retry=at
            else:
                file=FileAccess.open(bad_path,FileAccess.WRITE);file.store_buffer(bad_raw);file.close()
                check(journal.replay().ok and journal.state==after_copy,str(seat.id)+": restoring original terminal bytes cold-replays the exact final cut")
            var duplicate_state:Dictionary=journal.state;var duplicate_context:Dictionary=journal._sensory_context
            var duplicate:Dictionary=journal._consume_admitted(packet,raw,true)
            check(duplicate.ok and not duplicate.has("transitions") and journal.state==after_copy and is_same(journal.state,duplicate_state) and is_same(journal._sensory_context,duplicate_context),str(seat.id)+": actual repeated retry cannot republish captures or replace the committed state/index owner")
            exercised=true
    var terminal:Dictionary=journal.snapshot()
    check(journal.replay().ok and journal.state==terminal,str(seat.id)+": strict cold replay equals complete original live result")
    var initial_replay:Dictionary=journal.replay(0)
    check(initial_replay.ok and Compare.difference(journal.state,JSON.parse_string(states.read_file(seat.records[0].expected).get_string_from_utf8())).is_empty(),str(seat.id)+": initialization seek restores original native masks and canonical values")
    var initial_context:Dictionary=journal._sensory_context
    check(is_same(initial_context.state,journal.state) and initial_context.world.initialized and is_same(initial_context.world.source_objects,journal.state.objects) and is_same(initial_context.world.source_connectors,journal.state.connectors),str(seat.id)+": initialization replaces future lookup ownership with its own seeded context")
    check(initial_context.world.object_keys.keys()==journal.state.objects.keys() and initial_context.world.connector_keys.keys()==journal.state.connectors.keys(),str(seat.id)+": initialization contains only actual original world members, no future UUIDs")
    evidence.append({"case":seat.id,"records":seat.records.size(),"control_sequence":selected,"semantic_refusal":exercised,"durable_refusal":exercised,"replay_rollback":exercised,"later_original_available":later})
    for name in DirAccess.get_files_at(path):DirAccess.remove_absolute(path.path_join(name))
    DirAccess.remove_absolute(path)
func owned_boundary(journal:RefCounted,state:Dictionary,senses:Dictionary,visible:Dictionary,seen:Dictionary,lights:Dictionary,context:Dictionary,label:String)->void:
    check(is_same(journal.state,state) and is_same(journal.state.senses,senses) and is_same(journal.state.senses.visible,visible) and is_same(journal.state.senses.seen,seen),label+": exact committed native mask owners survive")
    check(is_same(journal.state.light_sources,lights) and is_same(journal._sensory_context,context),label+": exact light-source and derived-index owners survive")
