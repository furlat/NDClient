extends RefCounted
## One admitted revision for approved spells and shared passive asset metadata.
## Snapshots share immutable Resource refs and replace the small loaded shell.
## Historical package/cache names remain stable; neither contains live state.
## Spells come from the abilities build (build/presentation/abilities); the
## passive asset metadata (blood regions and other environment media) still
## comes from the old .derived admission until the environment source owns it.
const AbilityDocuments=preload("res://presentation/ability_documents.gd")
const ASSETS_CURRENT="res://.derived/native-spells/current"
const CACHE_KEY="__native_spell_admission"
static var _current:Resource
static var _assets:Resource
static var _attempted:bool=false
static var _admission_mutex:Mutex=Mutex.new()

## The marker naming the current native spell index of the abilities build.
static func current()->String:
    return AbilityDocuments.root().path_join("native_spells/current")

static func invalidate()->void:
    _admission_mutex.lock()
    _current=null;_assets=null;_attempted=false
    _admission_mutex.unlock()

static func _current_index()->Resource:
    _admission_mutex.lock()
    if not _attempted:
        var selected:String=FileAccess.get_file_as_string(current()).strip_edges()
        _current=ResourceLoader.load(selected,"",ResourceLoader.CACHE_MODE_REUSE)
        var assets:String=FileAccess.get_file_as_string(ASSETS_CURRENT).strip_edges()
        _assets=ResourceLoader.load(assets,"",ResourceLoader.CACHE_MODE_REUSE) if not assets.is_empty() else null
        _attempted=true
    var result:Resource=_current
    _admission_mutex.unlock()
    return result

static func admission(cache:Dictionary)->Dictionary:
    if not cache.has(CACHE_KEY):
        var index:Resource=_current_index()
        cache[CACHE_KEY]=make_admission(index,{})
        if index==null:_load_error(cache,current())
    return cache[CACHE_KEY]

static func find(behavior_id:String,cache:Dictionary)->Resource:
    var owner:Dictionary=admission(cache)
    if owner.index==null or not owner.index.spells.has(behavior_id):return null
    if not owner.loaded.has(behavior_id):
        var path:String=owner.index.spells[behavior_id]
        var loaded:Dictionary=owner.loaded.duplicate()
        loaded[behavior_id]=load(path)
        cache[CACHE_KEY]=make_admission(owner.index,loaded)
        if loaded[behavior_id]==null:_load_error(cache,path)
        return loaded[behavior_id]
    return owner.loaded[behavior_id]

static func asset(asset_id:String,cache:Dictionary)->Resource:
    # Explicit preparation only. The key cannot collide with a spell behavior.
    var owner:Dictionary=admission(cache)
    if owner.index==null:return null
    _admission_mutex.lock();var assets:Resource=_assets;_admission_mutex.unlock()
    var path:String=assets.asset_metadata.get(asset_id,"") if assets!=null else ""
    if path.is_empty():
        _load_error(cache,"asset:"+asset_id)
        return null
    var key:String="asset:"+asset_id
    if not owner.loaded.has(key):
        var resource:Resource=load(path)
        if resource==null:
            _load_error(cache,path)
            return null
        var loaded:Dictionary=owner.loaded.duplicate();loaded[key]=resource
        cache[CACHE_KEY]=make_admission(owner.index,loaded)
        return resource
    return owner.loaded[key]

static func prepared_asset(asset_id:String,cache:Dictionary)->Resource:
    # Sampling cannot admit an index, read its selector or load a Resource.
    return cache.get(CACHE_KEY,{}).get("loaded",{}).get("asset:"+asset_id)

static func snapshot(owner:Dictionary)->Dictionary:
    return owner

static func make_admission(index:Resource,loaded:Dictionary)->Dictionary:
    loaded.make_read_only()
    var result={"index":index,"loaded":loaded};result.make_read_only()
    return result

static func _load_error(cache:Dictionary,path:String)->void:
    if not cache.has("native_authoring_errors"):cache.native_authoring_errors=[]
    cache.native_authoring_errors.append("Cannot load admitted native presentation Resource: "+path)
