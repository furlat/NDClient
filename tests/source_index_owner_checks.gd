extends SceneTree
## Parallel metadata preparation shares one admitted index. Explicit import and
## reload select a new index while earlier workers retain the old definition.
const Catalog=preload("res://source_catalog.gd")
const Spells=preload("res://presentation/native_presentation_sources.gd")
const Bodies=preload("res://presentation/body_sources.gd")
const Builder=preload("res://tools/presentation_build/abilities.gd")
const Common=preload("res://tools/presentation_build/common.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
static func admit(job:Dictionary)->void:
    job.cache={}
    job.snapshot=Catalog.source_snapshot(job.cache)
func parallel()->Array:
    var jobs:Array=[]
    for i in 24:
        var job={"task":-1};job.task=WorkerThreadPool.add_task(admit.bind(job));jobs.append(job)
    for job in jobs:WorkerThreadPool.wait_for_task_completion(job.task)
    return jobs
func run()->void:
    create_timer(30).timeout.connect(func():printerr("Source owner deadline");quit(2))
    Catalog.invalidate_source_indexes()
    var old:Array=parallel()
    var first:Dictionary=old[0].cache
    var old_spell:Resource=Spells.admission(first).index
    var old_body:Resource=Bodies.index(first)
    check(old_spell!=null and old_body!=null,"Concurrent first admission loads both real native indexes")
    for job in old:
        check(is_same(Spells.admission(job.cache).index,old_spell),"Preparation workers share admitted spell index")
        check(is_same(Bodies.index(job.cache),old_body),"Preparation workers share admitted body index")
    var before:Dictionary=Catalog.source_snapshot(first)
    var old_fireball:Resource=Spells.find("spell.fireball",before)
    var rebuilt:Dictionary=Common.report()
    Builder.build(Common.load_root("res://authoring/abilities.tres",rebuilt),"res://build/presentation/abilities",rebuilt)
    check(rebuilt.errors.is_empty(),"A rebuild of the abilities source publishes another native revision")
    Catalog.invalidate_source_indexes()
    var revised:Array=parallel()
    var next_spell:Resource=Spells.admission(revised[0].cache).index
    var next_body:Resource=Bodies.index(revised[0].cache)
    check(next_spell!=null and next_body!=null,"Reload re-admits indexes while old holders remain alive")
    if next_spell==null or next_body==null:finish();return
    check(not is_same(next_spell,old_spell) and next_spell.revision!=old_spell.revision,"Explicit reload selects the newly built spell revision")
    check(is_same(next_body,old_body),"Reload reuses the unchanged immutable body revision")
    for job in revised:
        check(is_same(Spells.admission(job.cache).index,next_spell) and is_same(Bodies.index(job.cache),next_body),"Parallel reload workers share the new indexes")
    check(is_same(Spells.find("spell.fireball",before),old_fireball),"Previously admitted worker retains its old source")
    check(not is_same(Spells.find("spell.fireball",revised[0].cache),old_fireball),"New revision loads its versioned source separately")
    Catalog.adopt_snapshot(before,revised[0].snapshot)
    check(is_same(Spells.admission(before).index,old_spell) and is_same(Bodies.index(before),old_body),"New revision cannot replace the displayed owner through ordinary publication")
    var configured_path:String="res://.runtime/source-index-configured-body.res"
    var configured:Resource=old_body.duplicate(false);configured.revision="configured-source-revision"
    check(ResourceSaver.save(configured,configured_path)==OK,"An independent configured body index is saved")
    var previous:Variant=ProjectSettings.get_setting("source_data/body_source_index")
    ProjectSettings.set_setting("source_data/body_source_index",configured_path)
    var configured_cache:Dictionary={}
    check(Bodies.index(configured_cache).revision=="configured-source-revision","Configured index path selects its own native revision")
    check(is_same(Bodies.index(before),old_body),"Configured source does not alter the prior body owner")
    ProjectSettings.set_setting("source_data/body_source_index",previous)
    Bodies.invalidate();DirAccess.remove_absolute(configured_path)
    finish()
func finish()->void:
    var report={"checks":checks,"failures":failures,"scope":"Actual native indexes, 24 simultaneous worker admissions, real abilities source rebuild, explicit reload with old holders alive and source snapshot ownership. No timing/framebuffer claim."}
    FileAccess.open("res://generated/source_index_owner_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SOURCE_INDEX_OWNER ",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
