extends RefCounted
## Small, baked optical samples for authored attachment points. GPU receivers
## still use the original textures; only the CPU attachment queries use these.
const ROOT = "res://.derived/surface-sockets/"
const MANIFEST = ROOT + "manifest.json"

static func file_for(path: String, source: Dictionary) -> String:
    var identity: String = source.get("media",path)
    if not identity.begins_with("/media/"): return ""
    return ROOT + identity.trim_prefix("/media/").get_basename() + ".json"

static func _current(input: Dictionary) -> bool:
    var path: String = input.get("path","")
    if path.is_empty() or not FileAccess.file_exists(path): return false
    if FileAccess.get_modified_time(path)!=int(input.get("mtime",-1)): return false
    var file = FileAccess.open(path,FileAccess.READ)
    return file!=null and file.get_length()==int(input.get("size",-1))

static func _manifest(cache: Dictionary) -> bool:
    if cache.has(MANIFEST): return cache[MANIFEST].get("valid",false)
    var valid: bool = false
    if FileAccess.file_exists(MANIFEST):
        var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
        if document is Dictionary and document.get("schema")==1 and not document.get("authoring_inputs",{}).is_empty():
            valid=true
            for path in document.authoring_inputs:
                var input: Dictionary=document.authoring_inputs[path].duplicate()
                input.path=path
                if not _current(input): valid=false; break
    var result={"valid":valid}
    result.make_read_only()
    cache[MANIFEST]=result
    return valid

static func prepare(path: String, source: Dictionary, geometry_root: String, cache: Dictionary) -> bool:
    # Metadata workers call this before publication. Render-time lookup below
    # never reads disk, synchronizes the GPU or decodes an image.
    var file=file_for(path,source)
    if file.is_empty(): return false
    if cache.has(file): return cache[file].get("valid",false)
    var result={"valid":false}
    if _manifest(cache) and FileAccess.file_exists(file):
        var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
        if parsed is Dictionary and parsed.get("schema")==1 and parsed.get("source")==source.get("media",path) \
                and parsed.get("samples") is Dictionary and parsed.get("size",[]).size()==2:
            var expected={"depth":geometry_root.path_join(source.files.depth),
                "support":geometry_root.path_join(source.files.support),
                "solid":geometry_root.path_join(source.reference).get_base_dir().path_join("solid-valid.png")}
            var valid=true
            for channel in expected:
                var input: Dictionary=parsed.get("optical",{}).get(channel,{})
                if input.get("path")!=expected[channel] or not _current(input): valid=false; break
            if valid:
                result={"valid":true,"size":parsed.size,"samples":parsed.samples}
                result.size.make_read_only()
                for value in result.samples.values():value.make_read_only()
                result.samples.make_read_only()
    result.make_read_only()
    cache[file]=result
    return result.valid

static func ready(path: String, source: Dictionary, cache: Dictionary) -> bool:
    return cache.get(file_for(path,source),{}).get("valid",false)

static func sample(path: String, source: Dictionary, pixel: Vector2i, cache: Dictionary) -> Array:
    var baked: Dictionary=cache.get(file_for(path,source),{})
    if not baked.get("valid",false): return []
    if pixel.x<0 or pixel.y<0 or pixel.x>=baked.size[0] or pixel.y>=baked.size[1]: return []
    return baked.samples.get("%d,%d"%[pixel.x,pixel.y],[])
