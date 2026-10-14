extends RefCounted
## Read the existing packed media registration, including trimmed part offsets.
const Catalog=preload("res://source_catalog.gd")

static func resolve(asset_id: String, cache: Dictionary) -> Dictionary:
    var key="__registered_media:"+asset_id
    if cache.has(key): return cache[key]
    var root: String=ProjectSettings.get_setting("source_data/authoring_root")
    var files=["media/definitions/"+asset_id+".json","media/storage/"+asset_id+".json"]
    for path in files:
        if not FileAccess.file_exists(root.path_join(path)): return {"status":"missing","reason":"missing_media_registration","asset_id":asset_id}
    var definition: Dictionary=Catalog.read_file(files[0],cache)
    var storage: Dictionary=Catalog.read_file(files[1],cache)
    var paths={}
    for phase in storage.phases.values():
        for layer in phase.layers:
            var collections: Array=layer.get("partsByFacing",{}).values() if layer.has("partsByFacing") else [layer.get("parts",[])]
            for frames in collections:
                for parts in frames:
                    for part in parts: paths[part.file]=true
    var result={"status":"available","asset_id":asset_id,"definition":definition,"storage":storage,"paths":paths}
    cache[key]=result
    return result

static func sample(media: Dictionary, age_ms: float, facing: String, phase_name: String="impact") -> Array:
    if media.status!="available": return []
    var phase: Dictionary=media.definition.phases.get(phase_name,{})
    if phase.is_empty(): return []
    var frame=int(maxf(0,age_ms)/1000.0*phase.fps)
    frame=posmod(frame,int(phase.frames)) if phase.get("loop",false) else mini(frame,int(phase.frames)-1)
    var result: Array=[]
    for layer in media.storage.phases[phase_name].layers:
        var frames: Array=layer.get("partsByFacing",{}).get(facing,[]) if layer.has("partsByFacing") else layer.get("parts",[])
        if frames.is_empty(): continue
        for original in frames[mini(frame,frames.size()-1)]:
            var part: Dictionary=original.duplicate()
            part.blend_mode=layer.get("blendMode","normal")
            part.frame=frame
            result.append(part)
    return result
