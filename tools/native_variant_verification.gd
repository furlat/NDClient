extends RefCounted
## Explicit offline freshness verification. Never a runtime preparation gate.
const Variants=preload("res://presentation/native_source_variants.gd")
const DIRECTORY=Variants.DIRECTORY
static func stamp(path:String)->Dictionary:return Variants.stamp(path)
static func _verify_metadata(job:Dictionary)->void:
    # Only passive paths/stat data live here: no ResourceLoader, Shader, mesh,
    # Node or native renderer calls can overlap the source compiler admission.
    var started:int=Time.get_ticks_usec();var stat_count:int=0
    var state:Dictionary=job.state
    if not state.read:
        state.read=true
        if FileAccess.file_exists(DIRECTORY.path_join("index.json")):
            var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY.path_join("index.json")))
            if data is Dictionary:state.manifest=data
    for identity in job.requests:
        var request:Dictionary=job.requests[identity]
        var result:Dictionary={"supported":true,"pending":false,"path":request.path,"error":""}
        if not state.manifest.has(identity) or not FileAccess.file_exists(request.path):
            result.error="Prepared native source missing; run tools/bake_native_source_variants.gd: "+request.label
        else:
            for dependency in state.manifest[identity].dependencies:
                if not state.stamps.has(dependency):state.stamps[dependency]=stamp(dependency);stat_count+=1
                if state.stamps[dependency]!=state.manifest[identity].dependencies[dependency]:
                    result.error="Prepared native source stale: "+dependency
                    break
        job.results[identity]=result
    job.profile={"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"new_dependency_stats":stat_count,"cached_dependency_stats":state.stamps.size(),"variants":job.requests.size()}


static func verify(spec:Dictionary)->Dictionary:
    var identity:String=Variants.key(spec)
    var job={"state":{"manifest":{},"read":false,"stamps":{}},"requests":{identity:{"path":Variants.path_for(spec),"label":str(spec.get("id",""))}},"results":{},"profile":{}}
    _verify_metadata(job)
    return job.results[identity]
