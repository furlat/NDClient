extends SceneTree
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const EnvironmentMedia=preload("res://presentation/environment_media.gd")
const Media=preload("res://presentation/media_warmup.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("ENVIRONMENT_OWNER_FAIL ",label)
func same(actual:Dictionary,expected:Dictionary,label:String)->void:
    for field in ["required","upcoming","fixtures","disclosed","environment_timeline"]:
        check(actual[field]==expected[field],label+"/"+field)
        if field!="environment_timeline":check(actual[field].keys()==expected[field].keys(),label+"/order/"+field)
func _initialize()->void:run.call_deferred()
func partial_owner_controls(state:Dictionary,staged:Dictionary,oracle)->void:
    var clean:Dictionary={}
    var opening:Dictionary={"id":"actual-source-opening","commits":[]}
    var first:Dictionary=EnvironmentMedia.plan(state,[opening],clean,state,{},true)
    same(first,oracle.plan(state,[opening],{}),"Partial initial source closure")
    check(not first.diagnostics.skipped_initial and is_same(clean.__environment_demand_index.get("final_owner"),state),
        "Initial partial synchronization establishes the exact unchanged start owner")
    var second:Dictionary=EnvironmentMedia.plan(state,[opening],clean,state,{},true)
    check(second.diagnostics.skipped_initial and is_same(clean.__environment_demand_index.get("final_owner"),state),
        "Partial opening without world deltas preserves start ownership for its continuation")
    check(is_same(first.required,second.required) and is_same(first.required_records,second.required_records),
        "An unchanged opening borrows its retained source path and role-record owners")
    check(is_same(first.source_sizes,second.source_sizes) and is_same(first.required_family,second.required_family),
        "An unchanged environment closure borrows its admitted size facts and role-family projection")
    check(not staged.is_empty(),"Actual recordings provide staged terrain source enumeration")
    if not staged.is_empty():
        var staged_cache:Dictionary={}
        var staged_group:Dictionary={"id":"actual-staged-source","commits":[],"staged_tiles":staged.tiles,"staged_tile_at_ms":staged.times}
        EnvironmentMedia.plan(staged.state,[],staged_cache,staged.state,staged.state)
        var enumerated:Dictionary=EnvironmentMedia.plan(staged.state,[staged_group],staged_cache,staged.state,{},true)
        same(enumerated,oracle.plan(staged.state,[staged_group],{}),"Actual staged source closure")
        check(enumerated.diagnostics.skipped_initial and is_same(staged_cache.__environment_demand_index.get("final_owner"),staged.state)
            and staged.tiles.keys().all(func(key):return not staged_cache.__environment_demand_index.tiles.has(key)),
            "Staged source collection preserves the origin and does not publish terrain into its index")
    for kind in ["tile","contacts","removal"]:
        var current:Dictionary={}
        var before:Dictionary=EnvironmentMedia.plan(state,[],current,state,state)
        var index:Dictionary=current.__environment_demand_index
        var builds:int=index.changed_row_builds
        var delta:Dictionary={}
        if kind=="tile":
            var key:String=state.tiles.keys()[0]
            delta.tiles={key:state.tiles[key].duplicate()}
        elif kind=="contacts":delta.set={"senses":state.senses.duplicate() if state.senses!=null else null}
        else:
            var id:String=""
            for cell in index.cells:
                if index.cells[cell].size()==1:id=index.cells[cell].keys()[0];break
            check(not id.is_empty(),"Actual world provides a single-object cell removal with no replacement paths")
            if id.is_empty():continue
            delta.objects_removed=[id]
        var group:Dictionary={"id":"actual-data-"+kind,"commits":[{"at_ms":0.0,"delta":delta}]}
        var actual:Dictionary=EnvironmentMedia.plan(state,[group],current,state,{},true)
        same(actual,oracle.plan(state,[group],{}),"Partial actual-data "+kind)
        check(actual.diagnostics.skipped_initial and not index.has("final_owner"),
            "Partial "+kind+" after-value invalidates start ownership even without adding source paths")
        check(index.changed_row_builds==builds,"Partial "+kind+" control adds no replacement source rows")
        if kind=="tile":check(actual.required==before.required and is_same(index.tiles[delta.tiles.keys()[0]],delta.tiles.values()[0]),
            "Equal-material tile record changes index ownership while preserving the exact source closure")
func run()->void:
    var directory="";var oracle_path=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directory=arg.trim_prefix("--recording=")
        if arg.begins_with("--environment-oracle="):oracle_path=arg.trim_prefix("--environment-oracle=")
    if directory.is_empty() or oracle_path.is_empty():printerr("Requires explicit recorded journal and environment oracle");quit(2);return
    var oracle=load(oracle_path);var protocol=Protocol.new();var compile_cache={};var continuous={};var original={};var interleaved={};var mismatch={};var reset={};var timing=[];var staged_fixture:Dictionary={}
    var decoded=protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(directory+"/0000000000000000.json"))
    check(decoded.ok,"Actual initialization admits")
    var packet=protocol.normalize("InitializationResponse",decoded.value)
    var state:Dictionary=Reducer.reduce_initialization(packet.initialization,packet.content_additions).value
    for sequence in range(1,7):
        decoded=protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(directory+"/%016d.json"%sequence))
        check(decoded.ok,"Actual operation admits")
        packet=protocol.normalize("PlayerOperation",decoded.value)
        var reduced=Reducer._reduce_operation_recorded(state,packet)
        check(reduced.ok,"Actual recorded transitions reduce")
        var compiled=Compiler.compile_recorded(state,packet,compile_cache,reduced.value,reduced.transitions)
        check(compiled.ok,"Actual recorded transitions compile")
        var groups:Array=compiled.value.groups
        if staged_fixture.is_empty():
            for group in groups:
                for key in group.get("staged_tiles",{}):
                    if not state.tiles.has(key):staged_fixture={"state":state,"tiles":{key:group.staged_tiles[key]},"times":{key:float(group.get("staged_tile_at_ms",{}).get(key,0.0))}};break
                if not staged_fixture.is_empty():break
        check(groups.size()<=2,"Actual operation fits complete handoff planning")
        var source=var_to_bytes([state,reduced.value,groups])
        var expected:Dictionary=oracle.plan(state,groups,original)
        var actual=EnvironmentMedia.plan(state,groups,continuous,state,reduced.value)
        same(actual,expected,"Exact continuous source closure "+str(sequence))
        check(actual.diagnostics.skipped_initial==(sequence>1),"Only exact immediately previous final owner skips scan")
        timing.append({"sequence":sequence,"actual_initial_ms":actual.diagnostics.phases.initial_update,"original_initial_ms":expected.diagnostics.phases.initial_update})
        var altered_owner=state.duplicate()
        var altered=EnvironmentMedia.plan(state,groups,mismatch,altered_owner,reduced.value)
        same(altered,expected,"Equal-value different owner fallback")
        check(not altered.diagnostics.skipped_initial,"Equal value does not prove canonical identity")
        var interrupted=EnvironmentMedia.plan(state,groups,interleaved,state,reduced.value)
        same(interrupted,expected,"Interleaved planner exact fallback")
        check(not interrupted.diagnostics.skipped_initial,"Interleaved non-session plan invalidates proof")
        EnvironmentMedia.plan(reduced.value,[],interleaved)
        reset.clear()
        var reset_result=EnvironmentMedia.plan(state,groups,reset,state,reduced.value)
        same(reset_result,expected,"Reset cache exact fallback")
        check(not reset_result.diagnostics.skipped_initial,"Reset has no owner proof")
        check(var_to_bytes([state,reduced.value,groups])==source,"Canonical source owners/groups remain immutable")
        if sequence==5:
            var tail_cache:Dictionary={}
            var delayed:Array=[{"id":"source-window-a","commits":[]},{"id":"source-window-b","commits":[]}]
            delayed.append_array(groups)
            var selected:Dictionary=Media.prepare_handoff(state,delayed,tail_cache,reduced.value)
            check(selected.groups.size()==2 and is_same(tail_cache.__environment_demand_index.final_owner,reduced.value),
                "Actual received Fireball deltas beyond the selected window establish exact final selector ownership")
            check(not tail_cache.__environment_demand_index.paths_dirty,
                "Completed world metadata retains its final physical source union before the next opening")
            var after_tail:Dictionary=EnvironmentMedia.plan(reduced.value,[],tail_cache,reduced.value)
            same(after_tail,oracle.plan(reduced.value,[],{}),"Actual received tail final source closure")
            check(after_tail.diagnostics.skipped_initial,"The next opening borrows the actual tail's final world without a full synchronization")
        state=reduced.value
    var over_cache={};var over_groups=[{"id":"first","commits":[]},{"id":"second","commits":[]},{"id":"third","commits":[]}]
    var handoff=Media.prepare_handoff(state,over_groups,over_cache,state)
    check(handoff.complete and handoff.groups.size()==2,"Oversized operation still prepares only established first-two window")
    check(is_same(over_cache.__environment_demand_index.get("final_owner"),state),
        "Remaining received world deltas establish exact final canonical ownership without expanding the displayed first-two window")
    var no_final=EnvironmentMedia.plan(state,[],continuous,state)
    check(no_final.diagnostics.skipped_initial and not continuous.__environment_demand_index.has("final_owner"),"Exact start owner skips initial synchronization without claiming an unknown final owner")
    partial_owner_controls(state,staged_fixture,oracle)
    var result={"checks":checks,"failures":failures,"timing":timing,"scope":"Actual six-operation exact full closures/order/phase schedules; canonical start/final ownership, partial unchanged/staged preservation, tile/contact/removal invalidation, source immutability and fallback controls; isolated CPU only"}
    FileAccess.open("res://.runtime/environment-owner-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("ENVIRONMENT_OWNER_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
