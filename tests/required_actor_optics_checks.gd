extends SceneTree
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Selection=preload("res://presentation/selection_media.gd")
const Catalog=preload("res://source_catalog.gd")
const Profile=preload("res://frame_profile.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("ACTOR_OPTICS_FAIL ",label)
func fields(value:Dictionary)->Array:
    return [value.required,value.upcoming,value.gpu_only,value.cpu_required,value.optical_candidates,value.normal_sets,value.errors,value.upcoming_errors]
func same(actual:Dictionary,expected:Dictionary,label:String)->void:
    check(actual==expected,label+"/all full metadata")
    check(var_to_bytes(fields(actual))==var_to_bytes(fields(expected)),label+"/exact ordered role/path bytes")
func fork_cache(cache:Dictionary)->Dictionary:
    # Fork only worker-owned mutable indexes. Source documents and successful
    # packet leaves remain their exact immutable owners, preserving the proof.
    var result=cache.duplicate()
    if cache.has("__required_headers"):result.__required_headers=cache.__required_headers.duplicate()
    if cache.has("__environment_demand_index"):
        var original:Dictionary=cache.__environment_demand_index
        var index=original.duplicate()
        for field in ["tiles","objects","visual","cells","tile_paths","cell_paths","tile_materials"]:index[field]=original[field].duplicate()
        for cell in index.cells:index.cells[cell]=index.cells[cell].duplicate()
        result.__environment_demand_index=index
    return result
func prewarm(state:Dictionary,cache:Dictionary,other:Dictionary)->void:
    var selected=state.duplicate();selected.tiles={};selected.objects={}
    var result=Selection.plan({"state":selected,"actor_uuid":state.audience.controlled[0],"behavior":"spell.fireball","budget_bytes":17179869184,"profile":"reference"},Catalog.source_snapshot(cache),{"mutex":Mutex.new(),"cancelled":false})
    for target in [cache,other]:
        target.merge(result.source_files,false)
        if not target.has("__required_headers"):target.__required_headers={}
        target.__required_headers.merge(result.source_headers,false)
func project_actors(state:Dictionary,cache:Dictionary,script:Script,native:bool)->Dictionary:
    var result={"required":{},"upcoming":{},"gpu_only":{},"cpu_required":{},"optical_candidates":{},"normal_sets":{},"errors":[],"upcoming_errors":[]}
    var reuse=Media._actor_reuse(cache);var requested=[]
    for actor in state.actors.values():
        if script==Media:Media._add_actor_once(result.required,actor,[],cache,result.errors,result.gpu_only,result.cpu_required,native,result.optical_candidates,result.normal_sets,requested,reuse)
        else:script._add_actor(result.required,actor,[],cache,result.errors,result.gpu_only,result.cpu_required,native,result.optical_candidates,result.normal_sets)
    for path in result.cpu_required:result.gpu_only.erase(path)
    if script==Media:Media._retain_actor_closures(cache,reuse)
    return result
func _initialize()->void:run.call_deferred()
func run()->void:
    var directory="";var oracle_path=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directory=arg.trim_prefix("--recording=")
        if arg.begins_with("--media-oracle="):oracle_path=arg.trim_prefix("--media-oracle=")
    if directory.is_empty() or oracle_path.is_empty():printerr("Requires actual retained journal and immediate media oracle");quit(2);return
    var original=load(oracle_path);var protocol=Protocol.new();var cache={};var old_cache={};var rows=[]
    var decoded=protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(directory+"/0000000000000000.json"))
    check(decoded.ok,"Actual initialization strictly admits")
    var packet=protocol.normalize("InitializationResponse",decoded.value)
    var state:Dictionary=Reducer.reduce_initialization(packet.initialization,packet.content_additions).value
    var first_promotions=0
    for sequence in range(1,7):
        decoded=protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(directory+"/%016d.json"%sequence))
        check(decoded.ok,"Actual operation admits")
        packet=protocol.normalize("PlayerOperation",decoded.value)
        var reduced=Reducer._reduce_operation_retained(state,packet,true)
        check(reduced.ok,"Actual retained journal transaction reduces")
        old_cache.merge(Catalog.source_snapshot(cache),false)
        if sequence>=5:prewarm(state,cache,old_cache)
        var compiled=Compiler.compile_recorded(state,packet,cache,reduced.value,reduced.transitions)
        check(compiled.ok,"Actual recorded group compiles")
        old_cache.merge(Catalog.source_snapshot(cache),false)
        var source=var_to_bytes([state,compiled.value.groups])
        var before=fork_cache(cache);var old_before=fork_cache(old_cache)
        var current=Media.prepare_handoff(state,compiled.value.groups,cache,reduced.value)
        var prior=original.prepare_handoff(state,compiled.value.groups,old_cache,reduced.value)
        same(current.value,prior.value,"Sequential actual operation "+str(sequence))
        check(var_to_bytes([state,compiled.value.groups])==source,"Canonical and compiled source immutable")
        if sequence==5:first_promotions=cache.__required_actor_closures.promotions
        if sequence>=5:
            var current_ms=[];var original_ms=[];var current_chars=[];var old_chars=[]
            for cycle in 9:
                var candidate_cache=fork_cache(before);var original_cache=fork_cache(old_before)
                var actual:Dictionary;var expected:Dictionary
                if cycle%2==0:
                    actual=Media.prepare_handoff(state,compiled.value.groups,candidate_cache,reduced.value)
                    expected=original.prepare_handoff(state,compiled.value.groups,original_cache,reduced.value)
                else:
                    expected=original.prepare_handoff(state,compiled.value.groups,original_cache,reduced.value)
                    actual=Media.prepare_handoff(state,compiled.value.groups,candidate_cache,reduced.value)
                same(actual.value,expected.value,"Independent identical pre-operation cache "+str([sequence,cycle]))
                current_ms.append(actual.elapsed_ms);original_ms.append(expected.elapsed_ms)
                current_chars.append(actual.phases.characters);old_chars.append(expected.phases.characters)
            rows.append({"sequence":sequence,"promotions":cache.__required_actor_closures.promotions,"hits":cache.__required_actor_closures.hits,"misses":cache.__required_actor_closures.misses,
                "worker_current_ms":Profile.distribution(current_ms),"worker_original_ms":Profile.distribution(original_ms),"characters_current_ms":Profile.distribution(current_chars),"characters_original_ms":Profile.distribution(old_chars)})
        state=reduced.value
    check(first_promotions>=5,"Actual first Fireball promotes existing visible rest closures")
    # Exercise both flag directions with the actual final disclosed actors and
    # clips; removing optical demand must restore the exact original CPU roles.
    for flag in [false,true,false,true]:
        var actual=project_actors(state,cache,Media,flag)
        var expected=project_actors(state,old_cache,original,flag)
        same(actual,expected,"Actual actor sources projected to native_optics="+str(flag))
        check(cache.__required_actor_closures.promotions>0,"Opposite flag uses same finite successful base")
        for entry in cache.__required_actor_closures.entries:
            if entry.base.is_empty():continue
            check(entry.base.is_read_only() and entry.base.resolved.is_read_only() and entry.base.resolved.geometry_slots.is_read_only(),"Stored successful base and geometry map immutable")
    var result={"checks":checks,"failures":failures,"timing":rows,"first_promotions":first_promotions,"scope":"Actual six-operation retained canonical history, accepted actor selection documents/headers prewarmed outside timing, same pre-operation cache snapshots alternated nine times; complete full metadata and ordered role/path bytes, immutable inputs and both optical flag directions. Isolated worker CPU, not live latency."}
    FileAccess.open("res://.runtime/required-actor-optics-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("REQUIRED_ACTOR_OPTICS_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
