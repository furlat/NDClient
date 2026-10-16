extends RefCounted
## Native body metadata admission. JSON joins and file inspection live in the
## offline importer. A fresh catalog cache explicitly admits the current index.
const Index=preload("res://presentation/resources/body_source_index.gd")
const Layer=preload("res://presentation/resources/body_source_layer.gd")
const INDEX="res://.derived/body-sources/index.res"
const CURRENT="res://.derived/body-sources/current"
const KEY="__body_source_admission"
static var _current:Index
static var _current_path:String=""
static var _attempted:bool=false
static var _admission_mutex:Mutex=Mutex.new()

static func invalidate()->void:
    _admission_mutex.lock()
    _current=null;_current_path="";_attempted=false
    _admission_mutex.unlock()

static func _current_index(path:String)->Index:
    _admission_mutex.lock()
    if not _attempted or path!=_current_path:
        var selected:String=FileAccess.get_file_as_string(CURRENT).strip_edges() if path==INDEX else path
        _current=ResourceLoader.load(selected,"",ResourceLoader.CACHE_MODE_REUSE) as Index
        _current_path=path;_attempted=true
    var result:Index=_current
    _admission_mutex.unlock()
    return result

static func admission(cache:Dictionary)->Dictionary:
    if cache.has(KEY):return cache[KEY]
    var path:String=ProjectSettings.get_setting("source_data/body_source_index",INDEX)
    var index:Index=_current_index(path)
    if index==null:return {}
    var loaded={};loaded.make_read_only()
    var result={"index":index,"loaded":loaded};result.make_read_only()
    cache[KEY]=result
    return result

static func index(cache:Dictionary)->Index:
    return admission(cache).get("index")

static func layer_path(rig:String,category:String,cache:Dictionary)->String:
    var current:Dictionary=admission(cache)
    return "" if current.is_empty() else current.index.layers.get(rig,{}).get(category,"")

static func prepared_layer(path:String,cache:Dictionary)->Layer:
    # Sampling may borrow admitted refs only. Even initial index admission is
    # excluded here: no marker read, ResourceLoader or cache mutation.
    return cache.get(KEY,{}).get("loaded",{}).get(path) as Layer

static func prepare_layer(path:String,cache:Dictionary)->Layer:
    return _load(path,cache)

static func layer(rig:String,category:String,cache:Dictionary)->Layer:
    # Explicit preparation compatibility for standalone source fixtures.
    return prepare_layer(layer_path(rig,category,cache),cache)

static func _load(path:String,cache:Dictionary)->Layer:
    if path.is_empty():return null
    var current:Dictionary=admission(cache)
    if current.loaded.has(path):return current.loaded[path]
    # Revision-specific paths are immutable. Share this physical metadata owner;
    # no scene, Texture2D or mutable occurrence dependency is present here.
    var resource=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REUSE) as Layer
    if resource==null:return null
    var loaded:Dictionary=current.loaded.duplicate();loaded[path]=resource;loaded.make_read_only()
    var next={"index":current.index,"loaded":loaded};next.make_read_only();cache[KEY]=next
    return resource

static func descriptor(path:String,slot:String,cache:Dictionary)->Dictionary:
    var current:Dictionary=cache.get(KEY,{})
    if current.is_empty():return {}
    var owner:Array=current.index.source_owners.get(path,[])
    if owner.is_empty():return {}
    var resource:Layer=prepared_layer(owner[0],cache)
    if resource==null:return {}
    var slots:Dictionary=resource.clips.get(owner[1],{})
    return slots.get(slot,slots.get("*",{}))

static func prepare_descriptor(path:String,slot:String,cache:Dictionary)->Dictionary:
    # Media/world preparation workers explicitly admit the selected metadata.
    var current:Dictionary=admission(cache)
    if current.is_empty():return {}
    var owner:Array=current.index.source_owners.get(path,[])
    if owner.is_empty() or prepare_layer(owner[0],cache)==null:return {}
    return descriptor(path,slot,cache)

static func header(path:String,cache:Dictionary)->Dictionary:
    var current:Dictionary=admission(cache)
    if current.is_empty():return {}
    var owner:Array=current.index.source_owners.get(path,[])
    if owner.is_empty():return {}
    var resource:Layer=_load(owner[0],cache)
    return {} if resource==null else resource.headers.get(path,{})

static func equipment(item:Dictionary,slot:String,cache:Dictionary)->Dictionary:
    var selected:Index=index(cache)
    if selected==null:return {"ok":false,"error":{"kind":"authoring","message":"Body source index has not been imported"}}
    var key:Array=[item.visual_item_name,item.visual_variant_id,slot]
    if selected.equipment.has(key):return {"ok":true,"value":selected.equipment[key]}
    return {"ok":false,"error":{"kind":"authoring","message":selected.equipment_errors.get(key,"No imported item visual: "+str(key))}}
