extends RefCounted
## Native body metadata admission. The presentation build
## (tools/build_presentation.gd) writes the index and its layer and clip
## Resources; a fresh catalog cache explicitly admits that index.
const Index=preload("res://presentation/resources/body_source_index.gd")
const Layer=preload("res://presentation/resources/body_source_layer.gd")
const Clip=preload("res://presentation/resources/body_source_clip.gd")
const Metadata=preload("res://presentation/source_metadata.gd")
const INDEX="res://build/presentation/characters/body-sources/index.res"
const KEY="__body_source_admission"
static var _current:Index
static var _current_path:String=""
static var _attempted:bool=false
static var _admission_mutex:Mutex=Mutex.new()
# One physical metadata owner per admitted index. Worker cache shells borrow
# these exact Resources; ending a short-lived preparation cannot unload them.
static var _sources:Dictionary={}

static func invalidate()->void:
    _admission_mutex.lock()
    _current=null;_current_path="";_attempted=false;_sources={}
    _admission_mutex.unlock()

static func _current_index(path:String)->Index:
    _admission_mutex.lock()
    if not _attempted or path!=_current_path:
        _current=Metadata.read(path,ResourceLoader.CACHE_MODE_IGNORE) as Index if FileAccess.file_exists(path) else null
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
    # Serialize cold admission, not preparation/sampling. Loaded metadata has
    # one physical lifetime for this index, independent of any worker snapshot.
    var started:int=Time.get_ticks_usec() if measured else 0
    _admission_mutex.lock()
    if not _sources.has(current.index):_sources[current.index]={}
    var physical:Dictionary=_sources[current.index]
    var resource:Resource=physical.get(path)
    var physical_hit:bool=resource!=null
    var read_profile:Dictionary={"measured":true} if measured else {}
    if resource==null:
        resource=Metadata.read(path,ResourceLoader.CACHE_MODE_IGNORE,read_profile)
        if resource!=null:physical[path]=resource
    _admission_mutex.unlock()
    if measured:
        # Separate source decoding from OS thread startup/collection. The outer
        # time also includes waiting for the one physical admission owner.
        var elapsed:int=Time.get_ticks_usec()-started
        var metrics:Dictionary=cache.__actor_source_profile
        var prefix:String=kind+("_physical_cache_" if physical_hit else "_resource_load_")
        metrics[prefix+"calls"]=int(metrics.get(prefix+"calls",0))+1
        metrics[prefix+"usec"]=int(metrics.get(prefix+"usec",0))+elapsed
        if not metrics.has(prefix+"paths"):metrics[prefix+"paths"]={}
        var row:Dictionary=metrics[prefix+"paths"].get(path,{"calls":0,"usec":0})
        row.calls+=1;row.usec+=elapsed
        for field in ["native_read_usec","thread_start_usec","thread_total_usec"]:
            if read_profile.has(field):row[field]=int(row.get(field,0))+read_profile[field]
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
    var selected:Dictionary=slots.get(slot,slots.get("*",{}))
    return selected.banks.get(path,{}) if selected.has("banks") else selected

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
    var key:Array=["" if gear.is_empty() else gear[0],item.get("visual_variant_id"),slot]
    if selected.equipment.has(key):return {"ok":true,"value":selected.equipment[key]}
    return {"ok":false,"error":{"kind":"authoring","message":selected.equipment_errors.get(key,"No built item visual: "+str([item.get("item_id"),item.get("visual_variant_id"),slot]))}}

## The current public variant is authoritative. A null variant admits only the
## base row; unrelated variants never inherit a base appearance.
static func ground(item:Dictionary,cache:Dictionary)->Dictionary:
    var selected:Index=index(cache)
    if selected==null:return {}
    var authored:Dictionary=selected.ground_equipment.get(str(item.get("item_id","")),{})
    var actual:Variant=item.get("visual_variant_id")
    var variant:String="" if actual==null else str(actual)
    var own:Dictionary=authored.get("variants",{})
    if own.has(variant):return own[variant]
    var family:String=str(authored.get("family",""))
    if family.is_empty():return {}
    return selected.ground_equipment.get(family,{}).get("variants",{}).get(variant,{})
