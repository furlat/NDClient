extends SceneTree
## Cold passive-source admission and replacement/cancel ownership on actual
## recorded actors. No invented events, textures, scene construction or timing holds.
const Journal=preload("res://sdk/journal.gd")
const Selection=preload("res://presentation/selection_media.gd")
const Documents=preload("res://presentation/ability_documents.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("SELECTION_WORKER_FAIL ",label)
static func read_sources(output:Dictionary)->void:
    output.attacks=Documents.read("catalog/attack_recipes.json")
    output.body=Documents.read("catalog/body_action_recipes.json")
    output.lifecycle=Documents.read("condition_lifecycles.json")
    output.conditions=Effects.conditions("condition.spell.blur")
    output.clips=[]
    for selection in output.conditions:
        for id in selection.condition.phases.values():output.clips.append(Effects.clip(id))
    output.source=Sources.find("spell.fireball",{})
func settle(owner:Dictionary)->void:
    var deadline:int=Time.get_ticks_msec()+30000
    while owner.task>=0 and Time.get_ticks_msec()<deadline:
        Selection.poll(owner)
        await process_frame
    check(owner.task<0,"Selected metadata task is joined exactly once")
func run()->void:
    var journal=Journal.new()
    check(journal.open("res://tests/fixtures/schema16/scenarios/gallery/amber",true,false).ok,"Original Gallery journal opens")
    check(journal.replay(0).ok,"Original initialization reduces")
    var before:PackedByteArray=var_to_bytes(journal.state)
    var actor:String=journal.state.audience.controlled[0]
    # Pool callers start cold. Source Resources stay passive and the caller's
    # task remains owned until this test joins it; no main-thread prewarm.
    Documents.invalidate();Effects.invalidate();Sources.invalidate()
    var readers:Array=[]
    for caller in 8:
        var result:Dictionary={}
        readers.append({"task":WorkerThreadPool.add_task(read_sources.bind(result),false,"Concurrent cold selected metadata"),"result":result})
    for job in readers:
        while not WorkerThreadPool.is_task_completed(job.task):await process_frame
        WorkerThreadPool.wait_for_task_completion(job.task)
    var output:Dictionary=readers[0].result
    check(output.attacks is Dictionary and not output.attacks.is_empty(),"Cold pool admission reads actual built attacks")
    check(output.body is Dictionary and not output.body.is_empty(),"Cold pool admission reads actual body recipes")
    check(output.lifecycle is Dictionary and not output.conditions.is_empty() and not output.clips.is_empty(),"Cold pool admission resolves delivered lifecycle and phase metadata")
    check(is_same(output.attacks,Documents.read("catalog/attack_recipes.json")),"Later callers borrow the exact admitted table")
    for job in readers:
        check(is_same(job.result.attacks,output.attacks) and is_same(job.result.body,output.body),"Concurrent callers share one physical record table")
        check(job.result.source!=null and is_same(job.result.source,output.source),"Concurrent cache shells borrow the same admitted native source Resource")
        check(job.result.clips.size()==output.clips.size() and job.result.clips==output.clips,"Concurrent phase requests resolve identical selected metadata")
    var source:WeakRef=weakref(output.source)
    for job in readers:job.result.erase("source")
    check(source.get_ref()!=null,"Native source survives short-lived worker shells until source-owner invalidation")
    for clip in output.clips:check(not clip.is_empty(),"Delivered phase has actual source metadata")
    # A source-operand control on the original actor, not evidence that this
    # archived initialization disclosed an authoritative Fireball choice.
    var spell_hint:Dictionary=Selection.create()
    Selection.request(spell_hint,["spell source candidates"],actor,"",journal.state,16*1024*1024*1024,
        {},{},[],{},"reference",["spell.fireball"])
    await settle(spell_hint)
    var offered:Array=Selection.NativeSpells.effect_clips(Selection.NativeSpells.preparation_selection("spell.fireball",{}))
    var expected_keys:Dictionary={}
    for clip in offered+Selection.NativeActions.effect_clips("spell.fireball",{}):expected_keys[Effects.key(clip)]=true
    var actual_keys:Array=spell_hint.value.get("native_action_clips",[]).map(func(clip):return Effects.key(clip))
    check(not offered.is_empty() and actual_keys.size()==expected_keys.size()
        and actual_keys.all(func(key):return expected_keys.has(key))
        and expected_keys.keys().all(func(key):return key in actual_keys),
        "Actual recorded actor resolves exact default/eligible native source candidates from an explicit candidate request")
    check(not spell_hint.value.is_empty() and spell_hint.value.native_selection.is_empty()
        and spell_hint.value.errors.is_empty() and var_to_bytes(journal.state)==before,
        "Passive native candidates create neither a selected occurrence nor canonical outcomes")
    Selection.close(spell_hint)
    var owner:Dictionary=Selection.create()
    var other:Dictionary=Selection.create()
    Selection.request(owner,[1],actor,"spell.fireball",journal.state,16*1024*1024*1024)
    var first:int=owner.task
    Selection.request(owner,[2],actor,"spell.fireball",journal.state,16*1024*1024*1024)
    check(owner.task==first and owner.pending.key==[2],"Replacement retains the running token and only latest pending request")
    Selection.request(other,[3],actor,"",journal.state,16*1024*1024*1024,{}, {},[],{},"reference",["action.move"])
    Selection.cancel(other)
    await settle(owner);await settle(other)
    check(owner.key==[2] and not owner.value.is_empty() and owner.discarded==1,"Only the replacement publishes after joining discarded work")
    check(other.value.is_empty() and other.discarded==1,"Canceled concurrent work never publishes")
    var jobs:int=owner.jobs
    for frame in 12:
        Selection.poll(owner);Selection.poll(other)
        await process_frame
    check(owner.task==-1 and other.task==-1 and owner.jobs==jobs,"Repeated readiness polling does not query consumed task IDs or launch new work")
    Selection.request(other,[4],actor,"spell.fireball",journal.state,16*1024*1024*1024)
    Selection.close(other);Selection.close(other)
    Selection.poll(other)
    Selection.request(other,[5],actor,"spell.fireball",journal.state,16*1024*1024*1024)
    check(other.closed and other.task==-1 and other.pending.is_empty() and other.value.is_empty(),"Close joins unfinished work once; late requests and polls leave it retired")
    Selection.close(owner)
    check(var_to_bytes(journal.state)==before,"All preparation leaves the actual canonical state unchanged")
    var report:Dictionary={"checks":checks,"failures":failures,"scope":"Cold actual built ability/Factory phase reads from a pool worker; concurrent actual actor selection, replacement, cancel, repeated poll and close. No native graphics or latency claim."}
    print("SELECTION_WORKER_OWNERSHIP_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
