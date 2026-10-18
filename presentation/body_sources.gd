extends RefCounted
## Native body metadata admission. The presentation build
## (tools/build_presentation.gd) writes the index and its layer and clip
## Resources; a fresh catalog cache explicitly admits that index.
const Index=preload("res://presentation/resources/body_source_index.gd")
const Layer=preload("res://presentation/resources/body_source_layer.gd")
const Clip=preload("res://presentation/resources/body_source_clip.gd")
const INDEX="res://build/presentation/characters/body-sources/index.res"
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
        _current=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REUSE) as Index if FileAccess.file_exists(path) else null
        if _current==null:push_error("No built characters body sources at "+path+": run tools/build_presentation.gd -- --only=characters")
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
    return _load(path,cache,"category") as Layer

static func prepare_clip(layer:Layer,name:String,cache:Dictionary)->Clip:
    return _load(layer.clip_sources.get(name,""),cache,"clip") as Clip

static func layer(rig:String,category:String,cache:Dictionary)->Layer:
    # Explicit preparation compatibility for standalone source fixtures.
    return prepare_layer(layer_path(rig,category,cache),cache)

static func _load(path:String,cache:Dictionary,kind:String)->Resource:
    if path.is_empty():return null
    var current:Dictionary=admission(cache)
    var measured:bool=cache.has("__actor_source_profile")
    if current.loaded.has(path):
        if measured:
            var admission_metrics:Dictionary=cache.__actor_source_profile
            var field:String=kind+"_cache_hits"
            admission_metrics[field]=int(admission_metrics.get(field,0))+1
        return current.loaded[path]
    # Revision-specific paths are immutable. Share this physical metadata owner;
    # no scene, Texture2D or mutable occurrence dependency is present here.
    var started:int=Time.get_ticks_usec() if measured else 0
    var resource=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REUSE)
    if measured:
        # Native CACHE_REUSE may return a previously loaded Resource or wait
        # for another loader. This measures that call, not disk-cold I/O.
        var elapsed:int=Time.get_ticks_usec()-started
        var metrics:Dictionary=cache.__actor_source_profile
        var prefix:String=kind+"_resource_load_"
        metrics[prefix+"calls"]=int(metrics.get(prefix+"calls",0))+1
        metrics[prefix+"usec"]=int(metrics.get(prefix+"usec",0))+elapsed
        if not metrics.has(prefix+"paths"):metrics[prefix+"paths"]={}
        var row:Dictionary=metrics[prefix+"paths"].get(path,{"calls":0,"usec":0})
        row.calls+=1;row.usec+=elapsed
        metrics[prefix+"paths"][path]=row
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
    var clip:Clip=current.loaded.get(resource.clip_sources.get(owner[1],"")) as Clip
    if clip==null:return {}
    var slots:Dictionary=clip.descriptors
    return slots.get(slot,slots.get("*",{}))

static func prepare_descriptor(path:String,slot:String,cache:Dictionary)->Dictionary:
    # Media/world preparation workers explicitly admit the selected metadata.
    var current:Dictionary=admission(cache)
    if current.is_empty():return {}
    var owner:Array=current.index.source_owners.get(path,[])
    if owner.is_empty():return {}
    var resource:Layer=prepare_layer(owner[0],cache)
    if resource==null or prepare_clip(resource,owner[1],cache)==null:return {}
    return descriptor(path,slot,cache)

static func header(path:String,cache:Dictionary)->Dictionary:
    var current:Dictionary=admission(cache)
    if current.is_empty():return {}
    var owner:Array=current.index.source_owners.get(path,[])
    if owner.is_empty():return {}
    var resource:Layer=prepare_layer(owner[0],cache)
    return {} if resource==null else resource.headers.get(path,{})

## Gear looks are keyed by the server item id's family (the item whose looks
## it wears) and the visual variant the server sends.
static func equipment(item:Dictionary,slot:String,cache:Dictionary)->Dictionary:
    var selected:Index=index(cache)
    if selected==null:return {"ok":false,"error":{"kind":"authoring","message":"Body source index has not been built"}}
    var gear:Array=selected.gear.get(str(item.get("item_id","")),[])
    var key:Array=["" if gear.is_empty() else gear[0],item.visual_variant_id,slot]
    if selected.equipment.has(key):return {"ok":true,"value":selected.equipment[key]}
    return {"ok":false,"error":{"kind":"authoring","message":selected.equipment_errors.get(key,"No built item visual: "+str([item.get("item_id"),item.visual_variant_id,slot]))}}
