extends SceneTree
## Exact passive operands, lazy worker admission and retained source ownership.
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Catalog=preload("res://source_catalog.gd")
const Import=preload("res://tools/native_spell_import.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func run()->void:
    var empty:Dictionary={}
    check(Catalog.prepared_asset("particles.region.blood",empty).is_empty() and empty.is_empty(),"Lookup-only asset access cannot admit even the index")
    var cache:Dictionary={};var owner:Dictionary=Sources.admission(cache)
    check(owner.index.asset_metadata.size()==13 and owner.loaded.is_empty(),"The admitted index selects all thirteen assets without loading them")
    var before:int=Time.get_ticks_usec()
    var blood:Dictionary=Catalog.asset("particles.region.blood",cache)
    var cold_ms:float=(Time.get_ticks_usec()-before)/1000.0
    check(not blood.is_empty() and cache[Sources.CACHE_KEY].loaded.size()==1,"A selected blood asset admits only its own metadata Resource")
    check(is_same(blood,Catalog.prepared_asset("particles.region.blood",cache)),"Prepared lookup borrows the exact admitted asset value")
    check(not cache.has("catalog/action_media_assets.json"),"Runtime admission does not read the legacy thirteen-asset document")
    var worker:Dictionary=Catalog.source_snapshot(cache)
    var second:Dictionary=Catalog.asset("particles.region.water",worker)
    check(not second.is_empty() and cache[Sources.CACHE_KEY].loaded.size()==1,"Worker asset admission replaces only its private loaded shell")
    Catalog.adopt_snapshot(cache,Catalog.source_snapshot(worker))
    check(is_same(Catalog.prepared_asset("particles.region.water",cache),second) and is_same(Catalog.prepared_asset("particles.region.blood",cache),blood),"Publication retains both independently admitted exact source values")
    var old:Dictionary={};var expected:Dictionary=Catalog.read_file("catalog/action_media_assets.json",old)
    for id in expected:
        var selected:Dictionary=Catalog.asset(id,cache)
        check(selected==expected[id],"Exact authored asset operands: "+id)
        check(Sources.asset(id,cache).asset_id==id,"Exact imported asset identity: "+id)
        check(is_same(selected,Catalog.asset(id,cache)),"Warm access retains immutable source value: "+id)
    check(cache[Sources.CACHE_KEY].loaded.size()==13,"All thirteen selected assets have distinct namespaced owners")
    var fireball:Resource=Sources.find("spell.fireball",cache)
    check(fireball!=null and cache[Sources.CACHE_KEY].loaded.size()==14,"Spell lookup cannot collide with any asset owner")
    var retained:Dictionary=Catalog.source_snapshot(cache)
    var rebuilt:Dictionary=Import.import_all()
    check(rebuilt.failures.is_empty() and rebuilt.assets.size()==13,"Offline reimport validates all thirteen operands before publishing")
    Catalog.invalidate_source_indexes()
    var replacement:Dictionary={};var next:Dictionary=Catalog.asset("particles.region.blood",replacement)
    check(not next.is_empty() and not is_same(next,blood),"A new immutable source revision selects another physical metadata owner")
    Catalog.adopt_snapshot(retained,Catalog.source_snapshot(replacement))
    check(is_same(Catalog.prepared_asset("particles.region.blood",retained),blood),"New publication cannot replace an old replay's admitted asset")
    check(Catalog.asset("unregistered.asset",replacement).is_empty() and not replacement.get("native_authoring_errors",[]).is_empty(),"A genuinely missing selected asset produces the ordinary preparation error")
    var report:Dictionary={"checks":checks,"failures":failures,"cold_selected_blood_ms":cold_ms,"metadata_assets":13,
        "scope":"All current passive asset values, lookup-only sampling seam, lazy per-asset load, disjoint source keys, COW handoff and retained old revisions; no GPU/live timing claim."}
    FileAccess.open("res://generated/native_asset_admission_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_ASSET_ADMISSION ",checks," failures=",JSON.stringify(failures)," cold_selected_blood_ms=",cold_ms)
    quit(0 if failures.is_empty() else 1)
