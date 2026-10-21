extends SceneTree
## Current native optical after-values against independently frozen producer cuts.
## Old client-side observer union is no longer a schema16 consumer operation.
const Journal=preload("res://sdk/journal.gd")
const Audience=preload("res://sdk/audience.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Protocol=preload("res://sdk/protocol.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ORACLE="res://tests/fixtures/schema16/spool-oracle"
const VECTORS="res://tests/fixtures/schema16/fold"
# Preserve this inventory explicitly. Native originals are precomposed by the
# producer and do not supply the old per-observer inputs needed for these controls.
const PRODUCER_GAPS=[
    "Equal source revisions union only authorized observer footprints",
    "Equal source revisions coalesce only actually disclosed optional anchors",
    "Equal observer tombstone is view loss while another observer retains source",
    "Newer source tombstone suppresses an older other-observer source",
    "Newer source shape replaces obsolete observer footprints",
    "Authoritative empty observer reset clears both source and tombstone history",
    "One native delta removes and re-adds the same light source in producer order",
    "Empty and omitted per-source footprints with multi-observer optional anchors"]
var checks:int=0
var failures:Array=[]
var summaries:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("OPTICAL_SDK_FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var directory:String=ORACLE
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--oracle="):directory=arg.trim_prefix("--oracle=")
    var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("index.json")))
    var states:=ZIPReader.new()
    check(states.open(directory.path_join(index.states_archive))==OK,"Independent Python canonical archive opens")
    for seat in index.seats:original(directory,seat,states)
    states.close()
    frozen_sensory_vectors()
    check(summaries.size()==4,"Both Door and lethal-OA factions retain their independent original prefixes")
    var report:Dictionary={"checks":checks,"failures":failures,"recordings":summaries,"producer_reference":index.reference,
        "unexercised_producer_controls":PRODUCER_GAPS,"complete_legacy_control_inventory":false,
        "scope":"Current native16 canonical optical/contact/cell ownership, exact frozen Python states, native reference vectors, detach/retention and retired schema refusal. Precomposed originals do not qualify the unavailable old multi-observer producer inputs. No renderer, gameplay-light inference or compatibility path."}
    FileAccess.open("res://generated/sdk_optical_sources_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SDK_OPTICAL_SOURCES ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func original(directory:String,seat:Dictionary,states:ZIPReader)->void:
    var source:String=directory.path_join(str(seat.records[0].bytes)).get_base_dir()
    var journal:RefCounted=Journal.new()
    check(journal.open(source,true,false).ok,str(seat.id)+": current original opens without writes")
    var held:Array=[];var frozen:Array=[];var source_counts:Array=[];var patches:int=0;var removals:int=0
    for sequence in seat.records.size():
        var record:Dictionary=seat.records[sequence];var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(record.bytes))
        var admitted:Dictionary=journal.decode_record(sequence,raw)
        check(admitted.ok,str(seat.id)+": exact native16 packet admits "+str(sequence))
        if not admitted.ok:return
        var original_bytes:PackedByteArray=var_to_bytes(admitted.value)
        var accepted:Dictionary=journal._consume_admitted(admitted.value,raw,true)
        check(accepted.ok,str(seat.id)+": actual packet folds "+str(sequence))
        if not accepted.ok:return
        var expected:Variant=JSON.parse_string(states.read_file(record.expected).get_string_from_utf8())
        var issue:String=Compare.difference(journal.state,expected)
        check(issue.is_empty(),str(seat.id)+": complete frozen Python canonical optical/world cut "+str(sequence)+" "+issue)
        check(var_to_bytes(admitted.value)==original_bytes,str(seat.id)+": reducer leaves original native input unchanged")
        for i in held.size():check(held[i]==frozen[i],str(seat.id)+": later optical disclosure preserves prefix "+str(i))
        held.append(journal.state);frozen.append(journal.snapshot())
        var canonical:PackedByteArray=var_to_bytes(journal.state)
        var public:Dictionary=journal.snapshot();public.light_sources.clear();public.senses.entities.clear();public.senses.visible.bits=""
        check(var_to_bytes(journal.state)==canonical,str(seat.id)+": detached public source/contact/mask edits cannot mutate canonical state")
        check(journal.state.light_sources.keys().all(func(id):return journal.state.light_sources[id].source_uuid==id),str(seat.id)+": exact native optical identity is retained")
        source_counts.append(journal.state.light_sources.size())
        var groups:Array=admitted.value.get("lineages",[]) if sequence>0 else []
        for group in groups:
            for event in group.events:
                var fact:Variant=event.get("fact")
                if fact!=null and fact.kind=="sensory":patches+=fact.get("light_sources_patched",[]).size();removals+=fact.get("light_sources_removed",[]).size()
        if sequence==0:retired_refusal(admitted.value,str(seat.id))
    check(journal.replay(0).ok and Compare.difference(journal.state,JSON.parse_string(states.read_file(seat.records[0].expected).get_string_from_utf8())).is_empty(),str(seat.id)+": seek to original optical admission is exact")
    check(journal.replay().ok and journal.state==frozen[-1],str(seat.id)+": cold loop reconstructs complete original optical state")
    summaries.append({"case":seat.id,"records":seat.records.size(),"source_counts":source_counts,"actual_source_patches":patches,"actual_source_removals":removals,"observer_count":journal.state.audience.observers.size()})
func retired_refusal(initial:Dictionary,label:String)->void:
    for version in [6,7,8,9]:
        # Labelled identity corruption, not a fabricated archived wire fixture.
        var stale:Dictionary=initial.duplicate(true);stale.protocol.player_schema_version=version
        var bytes:PackedByteArray=JSON.stringify(stale,"",false,true).to_utf8_buffer()
        check(not Protocol.new().decode("InitializationResponse",bytes).ok,label+": current admission refuses retired schema"+str(version))
        var path:String="user://optical-retired-"+str(Time.get_ticks_usec())+"-"+str(version)
        DirAccess.make_dir_recursive_absolute(path);var file:=FileAccess.open(path.path_join("0000000000000000.json"),FileAccess.WRITE);file.store_buffer(bytes);file.close()
        check(not Journal.new().open(path,true,false).ok,label+": offline mode also refuses retired wire schema"+str(version))
        DirAccess.remove_absolute(path.path_join("0000000000000000.json"));DirAccess.remove_absolute(path)
func frozen_sensory_vectors()->void:
    var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(VECTORS.path_join("index.json")))
    var count:int=0
    for name in index.fixtures:
        var document:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(VECTORS.path_join(name)))
        if document.family!="sensory":continue
        count+=1;var state:Dictionary=document.initial.duplicate(true)
        for step in document.steps:
            var before:Dictionary=state.duplicate(true);var input:Dictionary=step.input;var input_copy:Dictionary=input.duplicate(true)
            var values:Dictionary=Audience.composed_values(input.sensory_rows)
            check(values.ok,str(name)+": native sensory row tables compose")
            if not values.ok:break
            var folded:Dictionary=Audience.fold(Reducer.copy_target(state),input.fact,values.value)
            check(folded.ok,str(name)+": exact frozen sensory input folds")
            if not folded.ok:break
            check(Compare.difference(folded.value,step.expected).is_empty(),str(name)+": independent full expected source/mask/contact/anchor cut")
            check(state==before and input==input_copy,str(name)+": candidate fold leaves held state and original producer rows unchanged")
            state=folded.value
    check(count==8,"All eight current independent sensory vectors qualify movement, anchor clearing, members, masks and removals")
