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
func run()->void:
    var directory="";var oracle_path=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directory=arg.trim_prefix("--recording=")
        if arg.begins_with("--environment-oracle="):oracle_path=arg.trim_prefix("--environment-oracle=")
    if directory.is_empty() or oracle_path.is_empty():printerr("Requires explicit recorded journal and environment oracle");quit(2);return
    var oracle=load(oracle_path);var protocol=Protocol.new();var compile_cache={};var continuous={};var original={};var interleaved={};var mismatch={};var reset={};var timing=[]
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
        state=reduced.value
    var over_cache={};var over_groups=[{"id":"first","commits":[]},{"id":"second","commits":[]},{"id":"third","commits":[]}]
    var handoff=Media.prepare_handoff(state,over_groups,over_cache,state)
    check(handoff.complete and handoff.groups.size()==2,"Oversized operation still prepares only established first-two window")
    check(not over_cache.__environment_demand_index.has("final_owner"),"Partial operation never proves final canonical ownership")
    var no_final=EnvironmentMedia.plan(state,[],continuous,state)
    check(not no_final.diagnostics.skipped_initial and not continuous.__environment_demand_index.has("final_owner"),"Unknown final owner forces scan and clears prior proof")
    var result={"checks":checks,"failures":failures,"timing":timing,"scope":"Actual six-operation exact full closures/order/phase schedules; strict canonical identity continuity, equal-value/mismatched/interleaved/reset/partial/unknown fallbacks and source immutability; isolated CPU only"}
    FileAccess.open("res://.runtime/environment-owner-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("ENVIRONMENT_OWNER_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
