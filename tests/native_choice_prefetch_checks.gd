extends SceneTree
const ChoiceResources=preload("res://live/choice_resources.gd")
const Choices=preload("res://sdk/choices.gd")
const Catalog=preload("res://source_catalog.gd")
class World extends Node:
    var catalog_cache:Dictionary={}
var checks=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var path="res://.runtime/gallery-sorcerer-20261015-seed3-door/choices-00.json"
    var choices:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
    var immutable=choices.duplicate(true)
    var world=World.new();var renderer=ChoiceResources.new()
    renderer.request(choices,world.catalog_cache)
    var job=renderer._choice_job
    check(not job.is_empty(),"Actual server Sorcerer choices schedule passive authoring preparation")
    renderer.request(choices,world.catalog_cache)
    check(is_same(job,renderer._choice_job),"Repeated identical capability choices retain the existing preparation")
    var deadline=Time.get_ticks_msec()+30000
    while job.task>=0 and not WorkerThreadPool.is_task_completed(job.task) and Time.get_ticks_msec()<deadline:await process_frame
    check(job.task>=0 and WorkerThreadPool.is_task_completed(job.task),"Passive selected-source worker finishes")
    var spent:Dictionary={"frame":Engine.get_process_frames(),"used_usec":2000,"limit_usec":2000}
    renderer.prepare(world.catalog_cache,spent)
    check(renderer._choice_resource_cache.is_empty(),"Choices respect the already-consumed shared frame budget")
    check(not "native_spells" in renderer and not "native_hits" in renderer,"Capability warming owns no renderer, recipient or event instances")
    check(not renderer.choice_preparation.ready and renderer.choice_preparation.pending>0,"Unstarted optional resource work reports pending without claiming ready")
    check(choices==immutable,"Admitted choices remain byte-value equivalent after worker preparation")
    var index:Dictionary=Catalog.read_file("native_effects/index.json",world.catalog_cache)
    var expected:Dictionary={}
    var behaviors:Dictionary={}
    for action in Choices.all_actions(choices):behaviors[action.behavior_id]=true
    for behavior in behaviors:
        if not index.spells.has(behavior):continue
        var entry:Dictionary=index.spells[behavior]
        var manifest:Dictionary=Catalog.read_file(entry.manifest,world.catalog_cache)
        for spell in manifest.spells:
            if spell.id==entry.id:
                for clip in spell.clips:expected[clip.id]=true
    var actual:Dictionary={}
    for clip in job.clips:actual[clip.id]=true
    check(actual==expected and not actual.is_empty(),"Only native clips selected by actual disclosed behaviors enter warmup")
    check(behaviors.has("spell.fire_bolt") and actual.has("spells/fire_bolt/default/travel"),"Disclosed Fire Bolt warms before an attack outcome or target exists")
    # Advancing the frame does not restore a private allowance independent of
    # the shared owner: a spent allowance remains spent for every call now.
    renderer.prepare(world.catalog_cache,spent)
    check(renderer._choice_resource_cache.is_empty() and job.cursor==0,"Repeated same-frame optional calls cannot bypass the constructor/program budget")
    renderer=null;world.free()
    var report={"checks":checks,"failures":failures,"source":path,"selected_native_clips":actual.keys(),"scope":"Actual server choices -> passive authored source selection; shared spent-budget behavior, no invented event/recipient, no native-render timing claim."}
    FileAccess.open("res://.runtime/native-choice-prefetch-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_CHOICE_PREFETCH ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
