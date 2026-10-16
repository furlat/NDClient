extends SceneTree
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Catalog=preload("res://source_catalog.gd")
const Profile=preload("res://frame_profile.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("REQUIRED_ACTOR_REUSE_FAIL ",label)
func same(actual:Dictionary,expected:Dictionary,label:String)->void:
    for field in ["required","upcoming","errors","upcoming_errors","gpu_only","cpu_required","optical_candidates","normal_sets"]:
        check(actual[field]==expected[field],label+"/"+field)
        if actual[field] is Dictionary:check(actual[field].keys()==expected[field].keys(),label+"/order/"+field)
func _initialize()->void:run.call_deferred()
func run()->void:
    var directory="";var oracle_path=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directory=arg.trim_prefix("--recording=")
        if arg.begins_with("--media-oracle="):oracle_path=arg.trim_prefix("--media-oracle=")
    if directory.is_empty() or oracle_path.is_empty():printerr("Requires actual recording and frozen media oracle");quit(2);return
    var original=load(oracle_path);var protocol=Protocol.new();var cache={};var old_cache={};var timing=[];var actual_hits=0
    var initial=protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(directory+"/0000000000000000.json"))
    check(initial.ok,"Actual initialization strictly admits")
    var packet=protocol.normalize("InitializationResponse",initial.value)
    var state:Dictionary=Reducer.reduce_initialization(packet.initialization,packet.content_additions).value
    var final_groups=[];var final_before={}
    for sequence in range(1,7):
        var decoded=protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(directory+"/%016d.json"%sequence))
        check(decoded.ok,"Actual operation admits")
        packet=protocol.normalize("PlayerOperation",decoded.value)
        var reduced=Reducer._reduce_operation_retained(state,packet,true)
        check(reduced.ok,"Actual retained canonical operation reduces")
        var compiled=Compiler.compile_recorded(state,packet,cache,reduced.value,reduced.transitions)
        check(compiled.ok,"Actual transitions compile")
        old_cache.merge(Catalog.source_snapshot(cache),false)
        var source=var_to_bytes([state,compiled.value.groups])
        var first_started=Time.get_ticks_usec()
        var actual=Media.plan(state,compiled.value.groups,cache)
        var first_current=(Time.get_ticks_usec()-first_started)/1000.0
        first_started=Time.get_ticks_usec()
        var expected=original.plan(state,compiled.value.groups,old_cache)
        var first_original=(Time.get_ticks_usec()-first_started)/1000.0
        var first_hits=cache.__required_actor_closures.hits
        var first_misses=cache.__required_actor_closures.misses
        same(actual,expected,"Actual recorded operation "+str(sequence))
        check(var_to_bytes([state,compiled.value.groups])==source,"Canonical inputs and compiled source remain unchanged")
        actual_hits+=cache.__required_actor_closures.hits
        check(cache.__required_actor_closures.entries.size()<=cache.__required_actor_closures.hits+cache.__required_actor_closures.misses,"Only finite successful requests in current plan are retained")
        if sequence>=5:
            var current_times=[];var previous_times=[]
            for iteration in range(11):
                var began=Time.get_ticks_usec();var now=Media.plan(state,compiled.value.groups,cache);current_times.append((Time.get_ticks_usec()-began)/1000.0)
                began=Time.get_ticks_usec();var prior=original.plan(state,compiled.value.groups,old_cache);previous_times.append((Time.get_ticks_usec()-began)/1000.0)
                same(now,prior,"Repeated exact full result "+str(sequence)+"/"+str(iteration))
            timing.append({"first_current_ms":first_current,"first_original_ms":first_original,"first_hits":first_hits,"first_misses":first_misses,"sequence":sequence,"current_ms":Profile.distribution(current_times),"original_ms":Profile.distribution(previous_times),"hits":cache.__required_actor_closures.hits,"misses":cache.__required_actor_closures.misses})
        final_before=state;final_groups=compiled.value.groups
        state=reduced.value
    check(actual_hits>0,"Actual retained canonical operation sequence exercises selector reuse")
    var retained:Dictionary=cache.__required_actor_closures
    check(not Media._actor_reuse(cache).previous.is_empty(),"Current static owners prove retained closures")
    for path in retained.sources:
        var value:Variant=cache[path]
        if not value is Dictionary and not value is Array:continue
        cache[path]=value.duplicate()
        check(Media._actor_reuse(cache).previous.is_empty(),"Replacement of any captured source document invalidates reuse: "+path)
        cache[path]=value
    for setting in ["source_data/authoring_root","source_data/media_root","source_data/character_geometry_root","source_data/creature_geometry_root","source_data/normal_profiles_root"]:
        var value=ProjectSettings.get_setting(setting)
        ProjectSettings.set_setting(setting,str(value)+"-test-replacement")
        check(Media._actor_reuse(cache).previous.is_empty(),"Changed path root invalidates all source closures: "+setting)
        ProjectSettings.set_setting(setting,value)
    var witness:Dictionary=final_before.actors.values()[0]
    var base=Media._actor_selector(witness)
    var position_only=witness.duplicate();position_only.last_visual_position=[999,998,0]
    check(Media._same_actor_selector(base,Media._actor_selector(position_only)),"Position changes keep exact source selectors")
    var leaf=witness.duplicate();leaf.appearance=witness.appearance.duplicate()
    check(Media._same_actor_selector(base,Media._actor_selector(leaf)),"Equal decoded appearance preserves source selection")
    leaf=witness.duplicate();leaf.visual_loadout=witness.visual_loadout.duplicate();leaf.visual_loadout.layers=witness.visual_loadout.layers.duplicate()
    check(Media._same_actor_selector(base,Media._actor_selector(leaf)),"Equal decoded equipment layers preserve source selection")
    leaf=witness.duplicate();leaf.visual_loadout=witness.visual_loadout.duplicate();leaf.visual_loadout.active_weapon_set="ranged" if witness.visual_loadout.active_weapon_set=="melee" else "melee"
    check(not Media._same_actor_selector(base,Media._actor_selector(leaf)),"Changed active equipment selector invalidates")
    leaf=witness.duplicate();leaf.life_state="dying" if witness.life_state=="alive" else "alive"
    check(not Media._same_actor_selector(base,Media._actor_selector(leaf)),"Changed authored lifecycle selector invalidates")
    leaf=witness.duplicate();leaf.present=not witness.get("present",true)
    check(not Media._same_actor_selector(base,Media._actor_selector(leaf)),"Changed drawability invalidates")
    var failed_actor=witness.duplicate();failed_actor.creature_content_ref="__test_unregistered_rig__"
    var reuse={"current":[],"previous":[],"hits":0,"misses":0};var requested=[];var errors=[]
    for attempt in range(2):Media._add_actor_once({},failed_actor,[],cache,errors,{},{},true,{},{},requested,reuse)
    check(errors.size()==2 and reuse.current.is_empty() and reuse.hits==0 and reuse.misses==2,"Failed resolutions retain identical errors and are never memoized")
    var cleared=Media.plan(state,[],cache)
    check(cache.__required_actor_closures.entries.size()<retained.entries.size(),"Next plan drops previous action-clip history")
    same(cleared,original.plan(state,[],old_cache),"Final current-only plan closure")
    var result={"checks":checks,"failures":failures,"timing":timing,"actual_hits":actual_hits,"scope":"Actual retained canonical six-operation requests; exact complete ordered paths/roles/normal/optical results, immutable inputs, source replacement and all roots, selector boundaries, no failed caching and previous/current bound; isolated CPU only"}
    FileAccess.open("res://.runtime/required-actor-reuse-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("REQUIRED_ACTOR_REUSE_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
