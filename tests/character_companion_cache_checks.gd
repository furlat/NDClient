extends SceneTree
## Exact authored companion paths from real Gallery outfits. No renderer, image
## decode, synthetic packets or replacement readiness policy participates here.
const Geometry=preload("res://presentation/character_geometry.gd")
const Characters=preload("res://presentation/characters.gd")
const Construction=preload("res://presentation/actor_construction.gd")
const WorldRows=preload("res://presentation/world.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Tracks=preload("res://presentation/tracks.gd")
const RECORDING="res://.runtime/player-runs/20261015T065402.910432Z/journal"
var checks=0
var failures:Array=[]
var frames:Array=[]
var sources:Dictionary={}
var observations:Dictionary={}

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);push_error(label)

func original(path:String,slot:String,cache:Dictionary)->Dictionary:
    # Frozen pre-memo source_paths implementation. record/normal_paths were not
    # changed by this patch; the control performs their original work each call.
    var source=Geometry.record(path,slot,cache)
    if source.is_empty():return {"ok":true,"value":{}}
    var profiles=Geometry.normal_paths(path,slot,cache)
    if not profiles.ok:return profiles
    var root:String=Geometry._root(source)
    var result={}
    for relative in source.files.values():result[root.path_join(relative)]=true
    for absolute in profiles.value.values():result[absolute]=true
    return {"ok":true,"value":result}

func collect(state:Dictionary,samples:Dictionary,cache:Dictionary)->void:
    var requests:Array=[]
    var index:Dictionary=Characters._read("catalog-index.json",cache)
    var rigs:Dictionary=Characters._read(index.rigs,cache)
    var loadouts=Construction.loadouts(samples,[])
    for id in state.actors:
        var actor:Dictionary=Construction.actor_with_loadout(state.actors[id],loadouts)
        if not WorldRows.visible_actor(actor,state):continue
        var resolved=Characters.resolve(actor,state,cache)
        check(resolved.ok,"Actual Gallery actor resolves")
        if not resolved.ok or resolved.value==null:continue
        var rig:Dictionary=rigs[resolved.value.rig]
        var rest=Characters.rest_sample(actor,rig,cache)
        check(rest.ok,"Actual Gallery rest source resolves")
        if not rest.ok:continue
        var clip:String=samples.get(id,{}).get("clip",rest.value.clip)
        for layer in Characters.layers(resolved.value,rig,cache):
            if not layer.paths.has(clip):continue
            var request:Array=[layer.paths[clip],layer.slot]
            requests.append(request);sources[request]=true
    if not requests.is_empty():frames.append(requests)

func recorded_requests(cache:Dictionary)->void:
    var journal=Journal.new()
    var opened=journal.open(RECORDING,true,false)
    check(opened.ok,"Actual live Gallery journal admitted")
    if not opened.ok:return
    var replayed=journal.replay(58)
    check(replayed.ok,"Actual state before Fireball reduced")
    if not replayed.ok:return
    var state:Dictionary=journal.state
    collect(state,{},cache)
    for sequence in [59,60]:
        var decoded=journal.protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(RECORDING.path_join("%016d.json"%sequence)))
        check(decoded.ok,"Actual Fireball/movement operation decodes")
        if not decoded.ok:return
        var packet:Dictionary=journal.protocol.normalize("PlayerOperation",decoded.value)
        var result=Compiler.compile(state,packet,cache)
        check(result.ok,"Actual Fireball/movement operation compiles")
        if not result.ok:return
        for group in result.value.groups:
            for age in [0.0,group.duration_ms*.5,group.duration_ms]:
                var sampled_state=state.duplicate(true)
                for commit in group.commits:
                    if commit.at_ms<=age:Compiler.apply_delta(sampled_state,commit.delta)
                collect(sampled_state,Tracks.samples(group.actor_tracks,age),cache)
            for commit in group.commits:Compiler.apply_delta(state,commit.delta)

func same_result(actual:Dictionary,expected:Dictionary,label:String)->void:
    check(actual==expected,label+" values")
    if actual.ok:check(actual.value.keys()==expected.value.keys(),label+" exact iteration order")

func ownership_and_invalidation(cache:Dictionary)->void:
    var path="/media/smallscale/modular/Head15/Idle.png"
    var first=Geometry.source_paths(path,"helmet",cache)
    check(first.ok and first.value.size()==6,"Real helmet has original companions and three normal profiles")
    var fork=Construction.source_cache(cache)
    var original_size=cache.size()
    same_result(Geometry.source_paths(path,"shadow",fork),original(path,"shadow",fork),"Worker-only excluded slot")
    check(cache.size()==original_size,"Worker miss does not add entries to parent catalog shell")
    check(is_same(Geometry.source_paths(path,"helmet",cache),first),"Worker admission preserves existing immutable parent result")
    check(first.is_read_only() and first.value.is_read_only(),"Shared completed companion maps are immutable")

    var broken=Construction.source_cache(cache)
    var profiles:Dictionary=cache[Geometry.PROFILE_TABLE].duplicate()
    profiles.records=profiles.records.duplicate()
    profiles.records[path]=profiles.records[path].duplicate()
    profiles.records[path].erase("reference")
    broken[Geometry.PROFILE_TABLE]=profiles
    same_result(Geometry.source_paths(path,"helmet",broken),original(path,"helmet",broken),"Replaced profile document reports missing profile")
    check(not Geometry.source_paths(path,"helmet",broken).ok,"Missing normal profile is never served from prior memo")
    check(Geometry.source_paths(path,"helmet",cache)==first,"Broken worker document never changes live owner")

    var replaced=Construction.source_cache(cache)
    var document:Dictionary=cache[Geometry.TABLE].duplicate()
    document.records=document.records.duplicate()
    document.records[path]=document.records[path].duplicate()
    document.records[path].files=document.records[path].files.duplicate()
    document.records[path].files.depth="exact-replacement/depth.png"
    replaced[Geometry.TABLE]=document
    var changed=Geometry.source_paths(path,"helmet",replaced)
    same_result(changed,original(path,"helmet",replaced),"Replaced geometry document uses new exact companion")
    check(changed!=first,"Replacing source document invalidates old path list")

    var fresh=Characters.Catalog.source_snapshot(cache)
    same_result(Geometry.source_paths(path,"helmet",fresh),original(path,"helmet",fresh),"Fresh Reload catalog reconstructs exact paths")
    check(not is_same(Geometry.source_paths(path,"helmet",fresh),first),"Fresh source snapshot does not inherit derived memo")
    for setting in ["source_data/character_geometry_root","source_data/normal_profiles_root"]:
        var root=ProjectSettings.get_setting(setting)
        ProjectSettings.set_setting(setting,str(root)+"/fixture-replacement")
        same_result(Geometry.source_paths(path,"helmet",cache),original(path,"helmet",cache),"Configured root replacement "+setting)
        check(Geometry.source_paths(path,"helmet",cache)!=first,"Changed root never returns old absolute paths")
        ProjectSettings.set_setting(setting,root)
        same_result(Geometry.source_paths(path,"helmet",cache),first,"Configured root restoration "+setting)

func readiness(requests:Array,cache:Dictionary,textures:Dictionary,memo:bool)->int:
    var available=0
    for request in requests:
        var result:Dictionary=Geometry.source_paths(request[0],request[1],cache) if memo else original(request[0],request[1],cache)
        for companion in result.get("value",{}):
            if textures.has(companion):available+=1
    return available

func stats(values:Array)->Dictionary:
    var sorted=values.duplicate();sorted.sort()
    return {"median_ms":sorted[sorted.size()/2],"p95_ms":sorted[mini(sorted.size()-1,floori(sorted.size()*.95))],"max_ms":sorted.back()}

func run()->void:
    var cache:Dictionary={}
    recorded_requests(cache)
    if sources.is_empty():check(false,"Real Gallery supplies companion requests");finish();return
    var textures:Dictionary={}
    var baseline_cache:Dictionary=Characters.Catalog.source_snapshot(cache)
    var cold_started=Time.get_ticks_usec()
    for request in sources:
        var expected=original(request[0],request[1],baseline_cache)
        same_result(Geometry.source_paths(request[0],request[1],cache),expected,"Recorded path+slot "+str(request))
        if expected.ok:textures.merge(expected.value)
    observations.exact_list_qualification_ms=(Time.get_ticks_usec()-cold_started)/1000.0
    # Include original creature body partitions and excluded slots, which use
    # different source tables from this Gallery's modular actor outfits.
    var creature_table:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Geometry.CREATURE_TABLE))
    for path in creature_table.records:
        for slot in ["body","effect","shadow"]:
            same_result(Geometry.source_paths(path,slot,cache),original(path,slot,baseline_cache),"Delivered creature source/role "+path+"/"+slot)
    for request in [["/media/not-delivered.png","body"],["/media/smallscale/modular/Effect1/Idle.png","effect"]]:
        same_result(Geometry.source_paths(request[0],request[1],cache),original(request[0],request[1],baseline_cache),"Unsupported source retains exact empty result")
    ownership_and_invalidation(cache)
    for requests in frames:
        var expected=readiness(requests,baseline_cache,textures,false)
        check(readiness(requests,cache,textures,true)==expected,"All current texture memberships are still tested")
        var missing=""
        for request in requests:
            var packet=original(request[0],request[1],baseline_cache)
            if packet.ok and not packet.value.is_empty():missing=packet.value.keys()[0];break
        if missing.is_empty():continue
        textures.erase(missing)
        var remaining=readiness(requests,cache,textures,true)
        check(remaining<expected and remaining==readiness(requests,baseline_cache,textures,false),"Removing a resident companion remains immediately observable")
        textures[missing]=true
    var timings={"original":[],"memo":[]}
    var sums={"original":0,"memo":0}
    for round_index in range(20):
        for memo in ([false,true] if round_index%2==0 else [true,false]):
            var key="memo" if memo else "original"
            for requests in frames:
                var started=Time.get_ticks_usec()
                sums[key]+=readiness(requests,cache if memo else baseline_cache,textures,memo)
                timings[key].append((Time.get_ticks_usec()-started)/1000.0)
    check(sums.original==sums.memo,"Alternating measured runs retain every texture membership result")
    observations.merge({"recording":RECORDING,"operations":[59,60],"actual_sampled_frames":frames.size(),"unique_path_slots":sources.size(),"layer_requests_min":frames.map(func(value):return value.size()).min(),"layer_requests_max":frames.map(func(value):return value.size()).max(),"original":stats(timings.original),"memo":stats(timings.memo),"timed_samples_each":timings.original.size()})
    finish()

func finish()->void:
    var report={"checks":checks,"failures":failures,"observations":observations,"scope":"Metadata-only exact source/role/path order and immutable-cache lifetime; alternating actual Gallery per-frame companion lookups plus unchanged texture membership checks. No whole-frame or native pixel claim."}
    FileAccess.open("res://.runtime/character-companion-cache-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CHARACTER_COMPANIONS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
