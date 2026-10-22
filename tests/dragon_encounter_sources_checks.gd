extends SceneTree
## Actual recorded Dragon -> optional source closure, independently checked
## against authored banks. No image decoding, clip geometry admission or GPU.
const Encounter=preload("res://presentation/encounter_media.gd")
const Characters=preload("res://presentation/characters.gd")
const Journal=preload("res://sdk/journal.gd")
const Reducer=preload("res://sdk/reducer.gd")
const CASE="condition.summon.draconic_breath_cadence/multiattack_breath_readiness"
const RIG="summon.draconic_spirit.violet-astral"
var checks:int=0
var failures:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("DRAGON_ENCOUNTER_SOURCES_FAIL ",label)

func run()->void:
    var index_path:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--index="):index_path=argument.trim_prefix("--index=")
    if index_path.is_empty():printerr("Pass --index=<current paid Multiattack/Breath recording index>");quit(2);return
    var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(index_path))
    var cases:Array=index.get("cases",[]).filter(func(row):return row.id==CASE)
    check(cases.size()==1 and cases[0].get("status")=="recorded","Exact successful current Dragon recording exists")
    if cases.size()!=1:finish();return
    var directory:String=cases[0].journals.amber
    var journal:RefCounted=Journal.new()
    var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,"Original initialization retains its exact producer contract")
    if not opened.ok:finish();return
    var packet:Dictionary=journal.decode_record(0,FileAccess.get_file_as_bytes(directory.path_join("0000000000000000.json")))
    check(packet.ok,"Original Dragon initialization decodes")
    if not packet.ok:finish();return
    var reduced:Dictionary=Reducer.reduce_initialization(packet.value.initialization,packet.value.content_additions)
    check(reduced.ok,"Original Dragon initialization reduces through the canonical SDK")
    if not reduced.ok:finish();return
    var state:Dictionary=reduced.value
    var dragons:Array=state.actors.values().filter(func(actor):return Characters.rig_id(actor,{})==RIG)
    check(dragons.size()==1,"Original audience discloses exactly one actual Dragon")
    if dragons.size()!=1:finish();return
    state=state.duplicate();state.actors={dragons[0].uuid:dragons[0]}
    var before:PackedByteArray=var_to_bytes(state)
    var rig:Resource=load("res://authoring/characters/rigs/"+RIG+".tres")
    var priority_clips:Array=[rig.fallbacks.Idle]
    for context in rig.contexts:
        if context.role=="movement" and context.enabled:priority_clips.append(context.clip)
    var colours:Dictionary={};var companions:Dictionary={};var priority:Dictionary={};var banks:int=0
    for clip in rig.clips:
        for art in clip.body_banks.values():
            banks+=1
            var colour:String="res://assets/"+art.path
            colours[colour]=true
            var surface:Resource=art.surface
            var paths:Array=[surface.depth,surface.masks.support,surface.masks.normal_valid]
            if surface.normal_profile.is_empty():paths.append_array(surface.normals.values())
            else:paths.append(surface.normals[surface.normal_profile])
            if clip.name in priority_clips:priority[colour]=true
            for path in paths:
                var actual:String="res://assets/"+path
                companions[actual]=true
                if clip.name in priority_clips:priority[actual]=true
    var expected:Dictionary=colours.duplicate();expected.merge(companions)
    check(banks==120,"Independent authoring covers all 120 actual facing banks")
    var cache:Dictionary={}
    for profile in ["original","reference","gentle"]:
        var plan:Dictionary=Encounter.plan(state,{},{},cache,[],profile)
        check(plan.errors.is_empty(),"Optional bank discovery succeeds: "+profile+" "+str(plan.errors))
        check(plan.paths.size()==expected.size() and expected.keys().all(func(path):return plan.paths.has(path)),"Every exact colour and allowed optical companion is retained: "+profile)
        check(plan.cpu_required==colours and plan.gpu_only==companions,"Colour keeps CPU residency; companions stay GPU-only: "+profile)
        check(plan.priority.size()==priority.size() and priority.keys().all(func(path):return plan.priority.has(path)),"Every facing of resting/walking/flying sources keeps priority: "+profile)
        check(is_same(plan,Encounter.plan(state,{},{},cache,[],profile)),"Unchanged complete bank closure reuses its owner: "+profile)
    var layer_path:String=Characters.BodySources.layer_path(RIG,rig.slot_categories.body[0],cache)
    var layer:Resource=Characters.BodySources.prepared_layer(layer_path,cache)
    check(layer!=null and layer.clip_sources.values().all(func(path):return not cache[Characters.BodySources.KEY].loaded.has(path)),"Optional discovery admits no clip geometry/socket Resources")
    check(var_to_bytes(state)==before,"Optional discovery leaves canonical actors and conditions unchanged")
    finish()

func finish()->void:
    print("DRAGON_ENCOUNTER_SOURCES ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual recorded Dragon optional source closure, raw authored facing/profile paths, priority and residency roles; no geometry loading or native rendering."}))
    quit(0 if failures.is_empty() else 1)
