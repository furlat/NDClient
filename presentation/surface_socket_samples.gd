extends RefCounted
## Small, baked optical samples for authored attachment points. GPU receivers
## still use the original textures; only the CPU attachment queries use these.
const BodySources=preload("res://presentation/body_sources.gd")
const ROOT = "res://.derived/surface-sockets/"
const MANIFEST = ROOT + "manifest.json"

static func file_for(path: String, source: Dictionary) -> String:
    var identity: String = source.get("media",path)
    if not identity.begins_with("/media/"): return ""
    return ROOT + identity.trim_prefix("/media/").get_basename() + ".json"

static func _baked(path:String,source:Dictionary,cache:Dictionary)->Dictionary:
    var slots:Array=source.get("slots",[])
    if slots.is_empty():return {}
    return BodySources.descriptor(path,str(slots[0]),cache).get("sockets",{})

static func prepare(path:String,source:Dictionary,_geometry_root:String,cache:Dictionary)->bool:
    # Exact bytes were admitted by the offline importer. There is no action-time
    # manifest, source timestamp/length scan or JSON parse.
    return _baked(path,source,cache).get("valid",false)

static func ready(path:String,source:Dictionary,cache:Dictionary)->bool:
    return _baked(path,source,cache).get("valid",false)

static func sample(path:String,source:Dictionary,pixel:Vector2i,cache:Dictionary)->Array:
    var baked:Dictionary=_baked(path,source,cache)
    if not baked.get("valid",false):return []
    if pixel.x<0 or pixel.y<0 or pixel.x>=baked.size[0] or pixel.y>=baked.size[1]:return []
    return baked.samples.get("%d,%d"%[pixel.x,pixel.y],[])
