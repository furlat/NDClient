extends SceneTree
## Original fixed-path typed metadata, replaced while old worker/view holders
## remain alive. No build, textures, native scene or backend is involved.
const Sources=preload("res://presentation/body_sources.gd")
const Catalog=preload("res://source_catalog.gd")
const DIRECTORY="res://.runtime/body-source-reload-checks"
const INDEX=DIRECTORY+"/index.res"
const CATEGORY=DIRECTORY+"/category.res"
const CLIP=DIRECTORY+"/clip.res"
const SHEET="/spritesheets/ReloadBody/Idle.png"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("BODY_SOURCE_RELOAD_FAIL ",label)
func save_sources(revision:String,width:int)->void:
    var index=Sources.Index.new()
    # The real body builder deliberately uses this same label on every build.
    # The admitted Resource owner, not that label, must distinguish revisions.
    index.revision="presentation";index.root_rig="reload.rig"
    index.rigs={"reload.rig":{"cell_width":width,"clips":{"Idle":{"frames":width/16,"fps":12.0}}}}
    index.layers={"reload.rig":{"ReloadBody":CATEGORY}}
    index.source_owners={SHEET:[CATEGORY,"Idle"]}
    var category=Sources.Layer.new()
    category.rig_id="reload.rig";category.category="ReloadBody"
    category.headers={SHEET:{"width":width,"height":128}}
    category.clip_sources={"Idle":CLIP}
    category.paths_by_slot={"body":{"Idle":SHEET}}
    var clip=Sources.Clip.new()
    clip.descriptors={"body":{"path":SHEET,"revision":revision,"geometry":{"cell_size":[width,128],"status":"ready"}}}
    check(ResourceSaver.save(index,INDEX)==OK,"Independent typed index saved: "+revision)
    check(ResourceSaver.save(category,CATEGORY)==OK,"Independent typed category saved: "+revision)
    check(ResourceSaver.save(clip,CLIP)==OK,"Independent typed clip saved: "+revision)
static func admit(job:Dictionary)->void:
    job.cache={"__actor_source_profile":{}}
    job.index=Sources.index(job.cache)
    job.category=Sources.prepare_layer(Sources.layer_path("reload.rig","ReloadBody",job.cache),job.cache)
    job.clip=Sources.prepare_clip(job.category,"Idle",job.cache)
    job.descriptor=Sources.descriptor(SHEET,"body",job.cache)
    job.profile=job.cache.__actor_source_profile
func loaded()->Dictionary:
    var job:Dictionary={}
    var task:int=WorkerThreadPool.add_task(admit.bind(job),false,"Body metadata reload fixture")
    while not WorkerThreadPool.is_task_completed(task):await process_frame
    WorkerThreadPool.wait_for_task_completion(task)
    return job
func loads(job:Dictionary)->int:
    return int(job.profile.get("category_resource_load_calls",0))+int(job.profile.get("clip_resource_load_calls",0))
func shared_hits(job:Dictionary)->int:
    return int(job.profile.get("category_physical_cache_calls",0))+int(job.profile.get("clip_physical_cache_calls",0))
func verify_revision(job:Dictionary,revision:String,width:int,label:String)->void:
    check(job.index.revision=="presentation" and job.index.rigs["reload.rig"].cell_width==width,label+" exact index values")
    check(job.category.headers[SHEET]=={"width":width,"height":128},label+" exact category values")
    check(job.clip.descriptors=={"body":{"path":SHEET,"revision":revision,"geometry":{"cell_size":[width,128],"status":"ready"}}},label+" exact clip/geometry values")
    check(is_same(job.descriptor,job.clip.descriptors.body),label+" sampling borrows the admitted descriptor")
func verify_sharing(cold:Dictionary,warm:Dictionary,label:String)->void:
    check(is_same(cold.index,warm.index),label+" independent caches share this admitted index")
    check(is_same(cold.category,warm.category) and is_same(cold.clip,warm.clip),label+" independent caches share exact physical metadata Resources")
    check(loads(cold)==2 and loads(warm)==0 and shared_hits(warm)==2,label+" only the cold worker reads the two selected metadata sources")
    evidence.append({"revision":cold.descriptor.revision,"index_label":cold.index.revision,"cold_loads":loads(cold),"warm_loads":loads(warm),"shared_hits":shared_hits(warm)})
func empty_snapshot(index:Resource)->Dictionary:
    var loaded:Dictionary={};loaded.make_read_only()
    var admission:Dictionary={"index":index,"loaded":loaded};admission.make_read_only()
    return {Sources.KEY:admission}
func run()->void:
    DirAccess.make_dir_recursive_absolute(DIRECTORY)
    var previous:Variant=ProjectSettings.get_setting("source_data/body_source_index")
    ProjectSettings.set_setting("source_data/body_source_index",INDEX)
    Sources.invalidate()
    save_sources("original",128)
    var original:Dictionary=await loaded();var original_warm:Dictionary=await loaded()
    verify_revision(original,"original",128,"Original cold revision")
    verify_sharing(original,original_warm,"Original revision")
    var old_values:PackedByteArray=var_to_bytes([original.index.rigs,original.category.headers,original.clip.descriptors])
    save_sources("replacement",256)
    Sources.invalidate()
    var replacement:Dictionary=await loaded();var replacement_warm:Dictionary=await loaded()
    verify_revision(replacement,"replacement",256,"Replaced fixed-path revision")
    verify_sharing(replacement,replacement_warm,"Replacement revision")
    check(not is_same(original.index,replacement.index) and not is_same(original.category,replacement.category) and not is_same(original.clip,replacement.clip),
        "Explicit invalidation reads fresh Resources at all three unchanged paths")
    check(old_values==var_to_bytes([original.index.rigs,original.category.headers,original.clip.descriptors]),
        "Replacement never mutates the old index, category or clip held by a prior view")
    check(is_same(Sources.index(original.cache),original.index)
        and is_same(Sources.prepare_layer(CATEGORY,original.cache),original.category)
        and is_same(Sources.prepare_clip(original.category,"Idle",original.cache),original.clip),
        "Earlier worker snapshots still resolve their own original immutable Resources")
    verify_revision(original,"original",128,"Retained original revision")
    var fresh:Dictionary=empty_snapshot(replacement.index)
    Catalog.adopt_snapshot(fresh,{Sources.KEY:original.cache[Sources.KEY]})
    check(is_same(fresh[Sources.KEY].index,replacement.index) and fresh[Sources.KEY].loaded.is_empty(),
        "A late old snapshot cannot populate the new index even when both revision labels are identical")
    Catalog.adopt_snapshot(fresh,{Sources.KEY:replacement.cache[Sources.KEY]})
    check(is_same(fresh[Sources.KEY].loaded.get(CATEGORY),replacement.category) and is_same(fresh[Sources.KEY].loaded.get(CLIP),replacement.clip),
        "The same admitted index can publish its exact prepared category/clip references")
    var earlier:Dictionary=empty_snapshot(original.index)
    Catalog.adopt_snapshot(earlier,{Sources.KEY:replacement.cache[Sources.KEY]})
    check(is_same(earlier[Sources.KEY].index,original.index) and earlier[Sources.KEY].loaded.is_empty(),
        "New metadata cannot populate an earlier view's immutable source owner")
    ProjectSettings.set_setting("source_data/body_source_index",previous)
    Sources.invalidate()
    for path in [INDEX,CATEGORY,CLIP]:DirAccess.remove_absolute(path)
    DirAccess.remove_absolute(DIRECTORY)
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Independent typed index/category/clip saved twice at the same temporary paths; explicit reload with original holders alive; exact new and unchanged old data; cold/warm selected worker source sharing. No build, GPU or live performance claim."}
    FileAccess.open("res://generated/body_source_reload_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BODY_SOURCE_RELOAD_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
