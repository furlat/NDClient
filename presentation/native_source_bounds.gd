extends RefCounted
## Metadata from the constructed native source, before renderer sampling.
static func emitters(handle:Dictionary)->Array:
    var result:Array=[]
    for emitter in handle.emitters:
        var speed:float=handle.emitter_speeds.get(emitter.get_instance_id(),1.0)
        var trail:bool=emitter.get_script()!=null and emitter.get_script().resource_path.ends_with("GPUTrail3D.gd")
        # GPUTrail stores its number of history samples in GPUParticles.lifetime.
        # Its visible persistence is length_seconds, not that storage count.
        var duration:float=float(emitter.length_seconds) if trail else emitter.lifetime
        result.append({"path":str(handle.root.get_path_to(emitter)),"kind":"gpu_trail" if trail else "particles",
            "lifetime":emitter.lifetime,"length_seconds":float(emitter.length_seconds) if trail else null,
            "source_speed":speed,"tail_seconds":duration/maxf(.001,speed),
            "clock":"motion" if handle.motion_trails.has(emitter.get_instance_id()) else "source",
            "layer_enabled":emitter.layers!=0,"one_shot":emitter.one_shot,"emitting":emitter.emitting})
    return result
