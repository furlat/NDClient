extends RefCounted
## Content-specific disk cache shared by the baker and ordinary Studio requests.
const Packet=preload("res://studio/native_preview_resource.gd")
const Factory=preload("res://presentation/native_factory_source.gd")
const DIRECTORY="res://.derived/studio-native-previews"
const VERSION=1
const MEMORY_LIMIT=64*1024*1024
const CHUNK_FRAMES=64
const SAMPLER_FILES=["res://studio/native_spell_preview.gd","res://presentation/native_factory_source.gd","res://presentation/native_spell_playback.gd","res://presentation/native_particle_units.gd","res://presentation/native_light_units.gd","res://presentation/native_effect_layer.gd"]
var specifications:Dictionary={}
var file_digests:Dictionary={}
var dependency_closures:Dictionary={}
var retained:Dictionary={}
var retained_bytes:int=0
var hits:int=0
var misses:int=0
var last_texture_bytes:int=0
var disk_loads:int=0
var descriptor_usec:int=0
var resource_load_usec:int=0
var issues:Dictionary={}
var manifest:Dictionary={}

func _init()->void:
    var path:String=DIRECTORY.path_join("index.json")
    if FileAccess.file_exists(path):
        var value=JSON.parse_string(FileAccess.get_file_as_string(path))
        if value is Dictionary:manifest=value

static func canonical(value:Variant)->Variant:
    if value is Dictionary:
        # StringName ordering follows the process's intern table. Visual keys
        # are textual, so normalize before sorting for cross-process Resources.
        var normalized:Dictionary={}
        for key in value:normalized[str(key)]=value[key]
        var result:Dictionary={};var keys:Array=normalized.keys();keys.sort()
        for key in keys:result[key]=canonical(normalized[key])
        return result
    if value is Array:return value.map(canonical)
    if value is StringName:return str(value)
    return value

static func visual_specification(component:Dictionary,hz:float)->Dictionary:
    var cue:Dictionary=component.native_cue.duplicate(true)
    # Source swatches are stationary native compositions. These fields only
    # identify or place an occurrence in the game, and are not read by sample.
    for field in ["id","index","source_index","clip","from","to","ground","caster_ground","from_actor","to_actor","actor_uuid","target_uuid","source_event_uuid","source_lineage","application_index","bend","offset","rotation_degrees","orientation","attachment","recipient","target_local","travel_to_target","launch_delay_seconds"]:cue.erase(field)
    return canonical({"version":VERSION,"clip":component.native_clip,"cue":cue,
        "finish":component.finish_profile,"persistent":component.get("persistent_owner",false),
        "lifecycle":component.get("lifecycle",{}),"hz":hz,"size":256,"published_size":128})

func descriptor(component:Dictionary,hz:float)->Dictionary:
    var started:int=Time.get_ticks_usec()
    var specification:Dictionary=visual_specification(component,hz)
    var spec_key:String=var_to_bytes(specification).hex_encode().sha256_text()
    if specifications.has(spec_key):descriptor_usec+=Time.get_ticks_usec()-started;return specifications[spec_key]
    var dependencies:Dictionary={}
    var saved:Dictionary=manifest.get(spec_key,{})
    for path in saved.get("dependencies",{}):dependencies[path]=_stamp(path)
    if saved.is_empty() or dependencies!=saved.get("dependencies",{}):
        dependencies.clear()
        for path in Factory.resource_paths(component.native_clip)+SAMPLER_FILES:_dependencies(path,dependencies)
    var ordered:Dictionary=canonical(dependencies)
    var signature:String=var_to_bytes([specification,ordered]).hex_encode().sha256_text()
    var result={"signature":signature,"spec_key":spec_key,"specification":specification,"dependencies":ordered,"hz":hz}
    specifications[spec_key]=result
    descriptor_usec+=Time.get_ticks_usec()-started
    return result

func _dependencies(path:String,result:Dictionary)->void:
    if result.has(path):return
    if not FileAccess.file_exists(path):return
    result[path]=_stamp(path)
    # Import settings can change the loaded texture without changing its PNG.
    # Track the small source sidecar, not regenerated imported texture binaries.
    if FileAccess.file_exists(path+".import"):result[path+".import"]=_stamp(path+".import")
    if not dependency_closures.has(path):
        var children:Array=[]
        if path.get_extension() in ["tscn","tres","res","scn","gd"]:
            for dependency in ResourceLoader.get_dependencies(path):children.append(str(dependency).split("::")[-1])
        if path.get_extension() in ["gd","gdshader","gdshaderinc"]:
            var source:String=FileAccess.get_file_as_string(path)
            var expression=RegEx.new();expression.compile('(?:res://[^"\\s]+|#include\\s+"[^"\\n]+")')
            for found in expression.search_all(source):
                var child:String=found.get_string()
                if child.begins_with("#include"):
                    child=child.get_slice('"',1)
                    if not child.begins_with("res://"):child=path.get_base_dir().path_join(child)
                if child!=path and child.get_extension() in ["gd","gdshader","gdshaderinc","tscn","scn","tres","res","png","jpg","webp","exr","svg"] and FileAccess.file_exists(child):children.append(child)
        dependency_closures[path]=children
    for child in dependency_closures[path]:_dependencies(child,result)

func _stamp(path:String)->Dictionary:
    if not file_digests.has(path):
        var file=FileAccess.open(path,FileAccess.READ)
        file_digests[path]={"modified":float(FileAccess.get_modified_time(path)),"bytes":float(file.get_length()) if file!=null else -1.0}
    return file_digests[path]

func record(descriptor:Dictionary)->void:
    manifest[descriptor.spec_key]={"signature":descriptor.signature,"dependencies":descriptor.dependencies}

func save_manifest()->Error:
    DirAccess.make_dir_recursive_absolute(DIRECTORY)
    var path:String=DIRECTORY.path_join("index.json")
    var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
    if file==null:return FileAccess.get_open_error()
    file.store_string(JSON.stringify(manifest));file.close()
    return DirAccess.rename_absolute(path+".tmp",path)

static func resource_path(signature:String,quarter:int,tick:int=0)->String:
    return DIRECTORY.path_join(signature+"-q"+str(quarter)+"-b"+str(floori(float(tick)/CHUNK_FRAMES))+".res")

func lookup(descriptor:Dictionary,tick:int,quarter:int)->Texture2D:
    var path:String=resource_path(descriptor.signature,quarter,tick)
    var resource:Resource
    if retained.has(path):
        resource=retained[path];retained.erase(path);retained[path]=resource
    elif FileAccess.file_exists(path):
        var started:int=Time.get_ticks_usec()
        resource=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
        disk_loads+=1;resource_load_usec+=Time.get_ticks_usec()-started
        if not resource is Packet or resource.format_version!=VERSION or resource.signature!=descriptor.signature or resource.quarter!=quarter or resource.hz!=descriptor.hz or resource.ticks.size()!=resource.textures.size() or resource.sizes.size()!=resource.ticks.size() or resource.ticks.size()>CHUNK_FRAMES:
            issues[path]="Invalid native preview Resource";misses+=1;return null
        retained[path]=resource;retained_bytes+=resource.texture_bytes
        while retained_bytes>MEMORY_LIMIT and not retained.is_empty():
            var first:String=retained.keys()[0]
            retained_bytes-=retained[first].texture_bytes;retained.erase(first)
    if resource==null:misses+=1;return null
    var at:int=resource.ticks.bsearch(tick)
    if at>=resource.ticks.size() or resource.ticks[at]!=tick:misses+=1;return null
    hits+=1
    last_texture_bytes=resource.sizes[at]
    return resource.textures[at]

static func image(source:Image)->Image:
    var output:Image=source.duplicate()
    var used:Rect2i=output.get_used_rect()
    if used.has_area():output=output.get_region(used.grow(3).intersection(Rect2i(Vector2i.ZERO,output.get_size())))
    var factor:float=minf(1.0,128.0/maxi(output.get_width(),output.get_height()))
    if factor<1:output.resize(maxi(1,roundi(output.get_width()*factor)),maxi(1,roundi(output.get_height()*factor)),Image.INTERPOLATE_NEAREST)
    return output

func reset()->void:
    specifications.clear();file_digests.clear();dependency_closures.clear();retained.clear();retained_bytes=0;issues.clear()
