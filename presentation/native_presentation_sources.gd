extends RefCounted
## One admitted revision for approved spells and shared passive asset metadata.
## Snapshots share immutable Resource refs and replace the small loaded shell.
## Historical package/cache names remain stable; neither contains live state.
## Spells come from the abilities build (build/presentation/abilities); the
## passive environment metadata is owned by the environment build.
const AbilityDocuments=preload("res://presentation/ability_documents.gd")
const Metadata=preload("res://presentation/source_metadata.gd")
const CACHE_KEY="__native_spell_admission"
static var _current:Resource
static var _attempted:bool=false
static var _admission_mutex:Mutex=Mutex.new()

## The marker naming the current native spell index of the abilities build.
static func current()->String:
    return AbilityDocuments.root().path_join("native_spells/current")

static func invalidate()->void:
    _admission_mutex.lock()
    _current=null;_attempted=false
    _admission_mutex.unlock()

static func _current_index()->Resource:
    _admission_mutex.lock()
    if not _attempted:
        var selected:String=FileAccess.get_file_as_string(current()).strip_edges()
        _current=Metadata.read(selected,ResourceLoader.CACHE_MODE_REUSE)
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
        loaded[behavior_id]=Metadata.read(path,ResourceLoader.CACHE_MODE_REUSE)
        cache[CACHE_KEY]=make_admission(owner.index,loaded)
        if loaded[behavior_id]==null:_load_error(cache,path)
        return loaded[behavior_id]
    return owner.loaded[behavior_id]

static func snapshot(owner:Dictionary)->Dictionary:
    return owner

static func make_admission(index:Resource,loaded:Dictionary)->Dictionary:
    loaded.make_read_only()
    var result={"index":index,"loaded":loaded};result.make_read_only()
    return result

static func _load_error(cache:Dictionary,path:String)->void:
    if not cache.has("native_authoring_errors"):cache.native_authoring_errors=[]
    cache.native_authoring_errors.append("Cannot load admitted native presentation Resource: "+path)
