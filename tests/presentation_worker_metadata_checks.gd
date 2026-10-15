extends SceneTree
# Actual admitted journal -> exact original groups and complete media closures.
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const EnvironmentMedia=preload("res://presentation/environment_media.gd")
const Encounter=preload("res://presentation/encounter_media.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Profile=preload("res://frame_profile.gd")
var checks=0
var failures=[]
var phase_boundaries=0
var deferred_sources=0
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("WORKER_METADATA_FAIL ",label)
func _initialize()->void:run.call_deferred()
func phase_checks(state:Dictionary,groups:Array,schedules:Dictionary,oracle:Script,cache:Dictionary)->void:
    var entry:Dictionary=state.duplicate()
    for field in ["tiles","objects","actors","spatial_commit_cursors","combat_log_appends"]:entry[field]=state[field].duplicate()
    for group in groups:
        var schedule:Dictionary=schedules[group.id]
        var whole:Dictionary=oracle.plan(entry,[group],cache).required
        check(EnvironmentMedia.required_at({},0,whole)==whole,"Missing phase schedule retains full readiness fallback")
        var times={0.0:true,float(group.duration_ms):true}
        for commit in group.commits:times[float(commit.at_ms)]=true
        for value in group.staged_tile_at_ms.values():times[float(value)]=true
        for time in times.keys():
            for at_ms in [float(time),maxf(0.0,float(time)-0.001)]:
                var prefix:Dictionary=group.duplicate();prefix.commits=[];prefix.staged_tiles={}
                for commit in group.commits:
                    if float(commit.at_ms)<=at_ms+0.000001:prefix.commits.append(commit)
                for key in group.staged_tiles:
                    if float(group.staged_tile_at_ms.get(key,0.0))<=at_ms+0.000001:prefix.staged_tiles[key]=group.staged_tiles[key]
                var expected:Dictionary=oracle.plan(entry,[prefix],cache).required
                var actual:Dictionary=EnvironmentMedia.required_at(schedule,at_ms,whole)
                check(actual==expected,"Exact cumulative old-source closure at recorded boundary/before: %s/%.3f"%[group.id,at_ms])
                check(actual.is_read_only() and is_same(actual,EnvironmentMedia.required_at(schedule,at_ms,whole)),"Readiness query returns existing immutable phase owner")
                phase_boundaries+=1
        check(EnvironmentMedia.required_at(schedule,INF,whole)==whole,"All phases retain the full original source closure")
        for path in whole:
            if not schedule.initial.has(path):deferred_sources+=1
        for commit in group.commits:Compiler.apply_delta(entry,commit.delta)
func run()->void:
    var directory="";var compiler_path="";var environment_path="";var media_path=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directory=arg.trim_prefix("--recording=")
        if arg.begins_with("--compiler-oracle="):compiler_path=arg.trim_prefix("--compiler-oracle=")
        if arg.begins_with("--environment-oracle="):environment_path=arg.trim_prefix("--environment-oracle=")
        if arg.begins_with("--media-oracle="):media_path=arg.trim_prefix("--media-oracle=")
    if directory.is_empty() or compiler_path.is_empty() or environment_path.is_empty() or media_path.is_empty():printerr("Requires explicit --recording, --compiler-oracle, --environment-oracle, --media-oracle");quit(2);return
    var original_compiler=load(compiler_path);var original_environment=load(environment_path)
    var original_media=load(media_path)
    var old_character_cache={};var phase_cache={}
    var protocol=Protocol.new();var current_cache={};var old_cache={};var environment_cache={};var old_environment_cache={};var timings=[]
    var initial=protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(directory+"/0000000000000000.json"))
    check(initial.ok,"Actual initialization strictly admits")
    if not initial.ok:quit(1);return
    var packet=protocol.normalize("InitializationResponse",initial.value)
    var reduced=Reducer.reduce_initialization(packet.initialization,packet.content_additions)
    check(reduced.ok,"Actual initial state reduces")
    if not reduced.ok:quit(1);return
    var state:Dictionary=reduced.value
    check(Compiler.EventTrace.initialization(packet.initialization)==original_compiler.EventTrace.initialization(packet.initialization),"Entire initialization trace equals original including histories/log hierarchy")
    for sequence in range(1,7):
        var decoded=protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(directory+"/%016d.json"%sequence))
        check(decoded.ok,"Actual operation admits: "+str(sequence))
        if not decoded.ok:break
        packet=protocol.normalize("PlayerOperation",decoded.value)
        reduced=Reducer._reduce_operation_recorded(state,packet)
        check(reduced.ok,"Actual canonical event records reduce: "+str(sequence))
        if not reduced.ok:break
        var actual=Compiler.compile_recorded(state,packet,current_cache,reduced.value,reduced.transitions)
        var expected=original_compiler.compile_recorded(state,packet,old_cache,reduced.value,reduced.transitions)
        check(actual.ok and expected.ok and actual==expected,"Entire compiled groups/state/logs/timing/source histories equal original: "+str(sequence))
        if not actual.ok:break
        var groups:Array=actual.value.groups.slice(0,mini(2,actual.value.groups.size()))
        var paths=EnvironmentMedia.plan(state,groups,environment_cache)
        var old_paths=original_environment.plan(state,groups,old_environment_cache)
        for field in ["required","upcoming","fixtures","disclosed"]:
            check(paths[field]==old_paths[field] and paths[field].keys()==old_paths[field].keys(),"Exact complete environment closure and demand order "+field+"/"+str(sequence))
        var media=Media.prepare_handoff(state,actual.value.groups,current_cache)
        var original_character=original_media.plan(state,groups,old_character_cache)
        for field in ["required","upcoming","errors","upcoming_errors","gpu_only","cpu_required","normal_sets","optical_candidates"]:
            check(media.value[field]==original_character[field],"Exact original character/optical closure and errors "+field+"/"+str(sequence))
        phase_checks(state,groups,media.value.environment_timeline,original_environment,phase_cache)
        check(media.complete and media.source_headers.keys().all(func(path):return media.source_headers[path].has("width") and media.source_headers[path].has("height")),"Required metadata carries already-read actual PNG headers: "+str(sequence))
        if sequence>=5:
            var current_times=[];var previous_times=[]
            for iteration in range(7):
                var began=Time.get_ticks_usec();var now=Compiler.compile_recorded(state,packet,current_cache,reduced.value,reduced.transitions);current_times.append((Time.get_ticks_usec()-began)/1000.0)
                began=Time.get_ticks_usec();var prior=original_compiler.compile_recorded(state,packet,old_cache,reduced.value,reduced.transitions);previous_times.append((Time.get_ticks_usec()-began)/1000.0)
                check(now==prior,"Repeated warmed exact compiler result: %d/%d"%[sequence,iteration])
            timings.append({"sequence":sequence,"current_ms":Profile.distribution(current_times),"original_ms":Profile.distribution(previous_times)})
        state=reduced.value
    var source="res://.runtime/worker-header-witness.png"
    var image=Image.create(3,2,false,Image.FORMAT_RGBA8);image.fill(Color(.2,.4,.6,.8));image.save_png(source)
    var header=Encounter._png_size(ProjectSettings.globalize_path(source))
    DirAccess.remove_absolute(source)
    var reused=Encounter.source_sizes({source:true},{"__encounter_headers":{source:header}})
    check(reused.get(source)==24,"Already-read exact header supplies byte accounting without reopening its source")
    check(Encounter.source_sizes({source:true},{}).is_empty(),"Absent unknown source retains explicit missing metadata fallback")
    check(deferred_sources>0,"Actual received records exercise delayed environment requirements")
    var result={"checks":checks,"failures":failures,"timings":timings,"phase_boundaries":phase_boundaries,"deferred_sources":deferred_sources,"scope":"Actual six admitted operations: full frozen compiler equality, exact original character/environment closures and timed environment prefixes before/at every recorded boundary, immutable zero-copy phase queries and already-read header accounting; isolated CPU, not live packet latency"}
    FileAccess.open("res://.runtime/presentation-worker-metadata-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("PRESENTATION_WORKER_METADATA_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
