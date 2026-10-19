extends SceneTree
# Independent exhaustive path oracle retained from the prior planner. Both sides
# consume real admitted gallery operation after-values, including shared walls.
const Media = preload("res://presentation/environment_media.gd")
const Journal = preload("res://sdk/journal.gd")
const Compiler = preload("res://presentation/compiler.gd")
const Rows = preload("res://presentation/world.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var checks = 0
var failures: Array = []
var exhaustive_us = 0
var incremental_us = 0
func check(ok: bool,label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("ENVIRONMENT_DELTA_FAIL ",label)
func collect(state: Dictionary,paths: Dictionary,cache: Dictionary) -> void:
    var rows = Rows.rows(state,cache)
    for row in rows.visual_rows:
        paths.merge(Media.row_paths(row,cache))
        for member in row.get("wall_members",[]): paths.merge(Media.row_paths(member,cache))
func exhaustive(state: Dictionary,groups: Array,cache: Dictionary) -> Dictionary:
    var required = {}; var upcoming = {}
    var future={"tiles":state.tiles.duplicate(),"objects":state.objects.duplicate(),"senses":state.senses}
    collect(future,required,cache)
    for index in range(groups.size()):
        var paths: Dictionary = required if index==0 else upcoming
        if index>0: collect(future,paths,cache)
        for key in groups[index].get("staged_tiles",{}):
            if not future.tiles.has(key): collect({"tiles":{key:groups[index].staged_tiles[key]},"objects":{},"senses":future.senses},paths,cache)
        for commit in groups[index].commits:
            var delta: Dictionary=commit.delta; var changed=false
            for key in delta.tiles: future.tiles[key]=delta.tiles[key]; changed=true
            for key in delta.objects: future.objects[key]=delta.objects[key]; changed=true
            for key in delta.objects_removed: future.objects.erase(key); changed=true
            if delta.set.has("senses"): future.senses=delta.set.senses; changed=true
            if changed: collect(future,paths,cache)
    var fixtures={}
    for paths in [required,upcoming]:
        for path in paths:
            if cache.get("__live_fixture_frames",{}).has(path): fixtures[path]=true
    return {"required":required,"upcoming":upcoming,"fixtures":fixtures}
func _initialize() -> void:
    var directory:String=Fixtures.journal("gallery")
    var journal=Journal.new()
    var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,"Select original current-schema Gallery recording identity")
    if not opened.ok:print(JSON.stringify({"checks":checks,"failures":failures,"error":opened.error}));quit(1);return
    var cache={}; var oracle_cache={}; var compiler_cache={}
    var count=0; var worlds=0
    var filenames:PackedStringArray=DirAccess.get_files_at(directory);filenames.sort()
    for filename in filenames:
        if not filename.ends_with(".json"): continue
        var raw=FileAccess.get_file_as_bytes(directory.path_join(filename))
        var before: Dictionary=journal.state
        var decoded=journal.decode_record(count,raw)
        if not decoded.ok: check(false,"Admit original packet "+filename); break
        var accepted=journal._consume_admitted(decoded.value,raw)
        if not accepted.ok: check(false,"Reduce original packet "+filename); break
        var groups: Array=[]
        if count>0:
            var compiled=Compiler.compile_admitted(before,accepted.normalized,compiler_cache,journal.state)
            if not compiled.ok: check(false,"Compile original packet "+filename); break
            groups=compiled.value.groups
        else: before=journal.state
        var displayed: Dictionary=before.duplicate(true)
        # Exact current/one-upcoming window; all source scopes come from native
        # committed/staged rows. Reusing cache also tests rollback from lookahead.
        for index in range(maxi(1,groups.size())):
            var window=groups.slice(index,index+2)
            var start=Time.get_ticks_usec(); var expected=exhaustive(displayed,window,oracle_cache); exhaustive_us+=Time.get_ticks_usec()-start
            start=Time.get_ticks_usec(); var actual=Media.plan(displayed,window,cache); incremental_us+=Time.get_ticks_usec()-start
            for field in ["required","upcoming","fixtures"]:
                check(actual[field]==expected[field],filename+" group "+str(index)+" exact "+field+" paths")
            worlds+=1
            if not groups.is_empty():
                for commit in groups[index].commits: Compiler.apply_delta(displayed,commit.delta)
        count+=1
    check(count>1 and worlds>1,"The complete real Gallery journal exercises multiple operation/source windows")
    var settled_plan:Dictionary=Media.plan(journal.state,[],cache)
    var settled:int=settled_plan.diagnostics.changed_row_builds
    var repeated:Dictionary=Media.plan(journal.state,[],cache)
    check(repeated.diagnostics.changed_row_builds==settled,"Repeated unchanged map performs no row/source reconstruction")
    var report={"checks":checks,"failures":failures,"packets":count,"windows":worlds,"exhaustive_ms":exhaustive_us/1000.0,"incremental_ms":incremental_us/1000.0,
        "scope":"Metadata CPU only; authentic retained Gallery journal. Not renderer frame time or a whole-game speedup.","changed_row_builds":settled}
    FileAccess.open("res://generated/environment_media_delta_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ENVIRONMENT_MEDIA_DELTA_CHECKS ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
