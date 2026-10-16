extends SceneTree
# Actual compiled Fireballs, two independent runtime owners, exact old evidence.
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Trace=preload("res://presentation/event_trace.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Profile=preload("res://frame_profile.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("TRACE_ISOLATION_FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var directory="";var old_path=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directory=arg.trim_prefix("--recording=")
        if arg.begins_with("--trace-oracle="):old_path=arg.trim_prefix("--trace-oracle=")
    if directory.is_empty() or old_path.is_empty():printerr("Requires explicit --recording and --trace-oracle");quit(2);return
    var old=load(old_path);var protocol=Protocol.new();var cache={};var timing=[]
    var packet=protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(directory+"/0000000000000000.json"))
    check(packet.ok,"Actual initialization admits")
    if not packet.ok:quit(1);return
    var initial=protocol.normalize("InitializationResponse",packet.value)
    var state:Dictionary=Reducer.reduce_initialization(initial.initialization,initial.content_additions).value
    for sequence in range(1,7):
        packet=protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(directory+"/%016d.json"%sequence))
        check(packet.ok,"Actual operation admits: "+str(sequence))
        if not packet.ok:break
        var normalized=protocol.normalize("PlayerOperation",packet.value)
        var reduced=Reducer._reduce_operation_recorded(state,normalized)
        check(reduced.ok,"Actual canonical event records reduce: "+str(sequence))
        if not reduced.ok:break
        var compiled=Compiler.compile_recorded(state,normalized,cache,reduced.value,reduced.transitions)
        check(compiled.ok,"Actual recorded transitions compile: "+str(sequence))
        if not compiled.ok:break
        if sequence<5:state=reduced.value;continue
        var accepted_bytes:PackedByteArray=var_to_bytes(normalized)
        var source_bytes=var_to_bytes(compiled.value.groups)
        var a=Trace.create();var b=Trace.create();var prior_a=old.create();var prior_b=old.create()
        var current_times=[];var previous_times=[]
        for group in compiled.value.groups:
            var accepted_versions:Dictionary={};var native_logs:Dictionary={}
            for lineage in normalized.lineages:
                for version in lineage.version_rows:accepted_versions[version.event_uuid]=version
                for node in lineage.events:
                    if node.get("combat_log")!=null:native_logs[node.uuid]=node.combat_log
            var history_count:int=0;var payload_count:int=0
            for row in group.events:
                for version in row.versions:
                    history_count+=1
                    check(is_same(version,accepted_versions[version.event_uuid]),"Historical version remains its exact passive accepted operand")
                if row.get("_display_log")!=null and native_logs.has(row.event_uuid):
                    for field in native_logs[row.event_uuid]:
                        if field=="sub_entries":continue
                        var value:Variant=native_logs[row.event_uuid][field]
                        if value is Dictionary or value is Array:
                            payload_count+=1
                            check(is_same(row._display_log[field],value),"Pruned log retains its exact passive non-child payload")
            check(history_count>0 and payload_count>0,"Real Fireball exercises borrowed complete histories and structured log data")
            Trace.activate(a,group.events,0);Trace.activate(b,group.events,0)
            old.activate(prior_a,group.events,0);old.activate(prior_b,group.events,0)
            check(a==prior_a and b==prior_b,"Exact old activated rows/track bindings/history: "+str(sequence))
            var untouched=var_to_bytes(b)
            var sample_count=0
            for row in a.rows.values():
                if not row._admitted:continue
                for component in row.components:
                    if component.trace_track_id.is_empty():continue
                    var sample={"trace_track_id":component.trace_track_id,"visible":true,"display_ms":component.start_ms}
                    Trace.record(a,[sample]);old.record(prior_a,[sample]);sample_count+=1
            check(sample_count>0,"Actual caster body produces admitted sample evidence")
            check(a==prior_a,"Exact original rendered evidence after actual component samples")
            check(var_to_bytes(b)==untouched and b==prior_b,"Sampling one runtime cannot mutate another")
            for commit in group.commits:
                if commit.has("event_uuid"):
                    Trace.commit(a,int(group.operation_sequence),commit.event_uuid);old.commit(prior_a,int(group.operation_sequence),commit.event_uuid)
                Trace.append_logs(a,commit.get("trace_logs",[]));old.append_logs(prior_a,commit.get("trace_logs",[]))
                Trace.tick(a,group.events,commit.at_ms);old.tick(prior_a,group.events,commit.at_ms)
                check(a==prior_a,"Exact original evidence/log state at each actual commit")
            check(var_to_bytes(b)==untouched,"Committing/ticking one runtime cannot mutate another")
            var snapshot=Trace.snapshot(a,200,group.events[0].id,0)
            if not snapshot.selected.get("versions",[]).is_empty():snapshot.selected.versions[0].source_index+=1000
            var logs=Trace.logs(a,200)
            if not logs.entries.is_empty():
                logs.entries[0].entry.sub_entries.clear()
                for log_row in logs.entries:
                    if log_row.entry.get("data") is Dictionary:log_row.entry.data.clear()
            check(a==prior_a,"Public detailed snapshots/logs retain independent deep copies")
            for iteration in range(15):
                var transient=Trace.create();var began=Time.get_ticks_usec();Trace.activate(transient,group.events,0);current_times.append((Time.get_ticks_usec()-began)/1000.0)
                transient=old.create();began=Time.get_ticks_usec();old.activate(transient,group.events,0);previous_times.append((Time.get_ticks_usec()-began)/1000.0)
        check(var_to_bytes(compiled.value.groups)==source_bytes,"Runtime sampling/commit/public mutation preserves all compiled source metadata")
        var first=Timeline.new();var second=Timeline.new()
        first.state=state.duplicate(true);second.state=state.duplicate(true)
        first.queue=compiled.value.groups.duplicate();second.queue=compiled.value.groups.duplicate()
        first.advance(0);second.advance(0)
        var other=var_to_bytes(second.trace)
        var duration=compiled.value.groups.reduce(func(total,group):return total+group.duration_ms,0.0)+1
        first.advance(duration)
        check(var_to_bytes(second.trace)==other,"Actual Timeline advancement cannot mutate independent Timeline evidence")
        second.advance(duration)
        check(first.state==reduced.value and second.state==reduced.value and first.trace==second.trace,"Both independent timelines reach exact canonical state and same unsampled evidence")
        check(var_to_bytes(compiled.value.groups)==source_bytes,"Both timeline owners preserve the exact compiled source groups")
        check(var_to_bytes(normalized)==accepted_bytes,"Sampling, commits and mutated public results preserve accepted log/version operands")
        timing.append({"sequence":sequence,"activate_ms":Profile.distribution(current_times),"original_activate_ms":Profile.distribution(previous_times)})
        state=reduced.value
    var result={"checks":checks,"failures":failures,"timing":timing,"scope":"Actual recorded Fireballs: independent trace/timeline state, frozen original activation/sample/commit/log evidence, source immutability and deep public snapshots; isolated CPU, not live frame-time claim"}
    FileAccess.open("res://.runtime/event-trace-isolation-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("EVENT_TRACE_ISOLATION_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
