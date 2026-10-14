extends RefCounted
## Passive authored condition banks. No clock, nodes or canonical writes.
const RegisteredMedia=preload("res://presentation/registered_media.gd")

static func duration_ms(asset_id:String,cache:Dictionary)->float:
    var media=RegisteredMedia.resolve(asset_id,cache)
    if media.status!="available":return 0.0
    var phase:Dictionary=media.definition.phases.get("impact",{})
    return float(phase.get("frames",0))*1000.0/float(phase.get("fps",media.definition.fps))

static func _bank(id:String,asset:String,age:float,alpha:float,cache:Dictionary,sample_fps:float=-1)->Dictionary:
    var media=RegisteredMedia.resolve(asset,cache)
    var source_age=maxf(0,age)
    if sample_fps>0 and media.status=="available":
        var phase:Dictionary=media.definition.phases.impact
        source_age*=sample_fps/float(phase.get("fps",media.definition.fps))
    return {"part_id":id,"media":media,"source_age_ms":source_age,"phase_age_ms":maxf(0,age),"alpha":alpha}

static func _ordinary(row:Dictionary,age:float,alpha:float,cache:Dictionary)->Array:
    var metadata:Dictionary=row.metadata
    var layer:Dictionary=row.layer
    var application:bool=not row.initial
    if application and float(layer.get("fadeInMs",0))>0:
        var fade_age=age
        if row.get("removal_age_ms")!=null:fade_age=minf(age,maxf(0,row.age_ms-row.removal_age_ms-float(layer.get("startOffsetMs",0))))
        alpha*=clampf(fade_age/float(layer.fadeInMs),0,1)
    var fade:Array=metadata.get("application_fade_ms",[1500.0,2000.0])
    var blend=clampf((age-float(fade[0]))/(float(fade[1])-float(fade[0])),0,1) if fade[1]>fade[0] else 1.0
    if not application or metadata.get("application_asset_id")==null:blend=1.0
    var result:Array=[]
    if blend<1 and alpha>0:
        var application_id:String=metadata.application_asset_id
        # Finite entry banks stop at their authored end; never hold a last frame
        # across a missing sustain transition.
        var bank=RegisteredMedia.resolve(application_id,cache)
        var duration=0.0 if bank.status!="available" else float(bank.definition.phases.impact.frames)*1000.0/float(layer.fps)
        if duration<=0 or age<duration:result.append(_bank("application",application_id,age,alpha*(1-blend),cache,float(layer.fps)))
    if blend>0 and alpha>0:
        var local_age=age-float(metadata.get("sustain_start_ms",0)) if application else age
        result.append(_bank("sustain",metadata.get("asset_id",layer.assetId),local_age,alpha*blend,cache,float(layer.fps)))
    return result

static func sample(row:Dictionary,cache:Dictionary)->Array:
    var layer:Dictionary=row.layer
    var metadata:Dictionary=row.metadata
    var age=float(row.age_ms)-(float(layer.get("startOffsetMs",0)) if not row.initial else 0.0)
    if age<0:return []
    var removal:Variant=row.get("removal_age_ms")
    var release:Variant=metadata.get("removal_asset_id")
    var alpha=float(row.get("selection_alpha",row.alpha))
    if removal!=null and release!=null:
        var duration=duration_ms(release,cache)
        if float(removal)<0 or (duration>0 and float(removal)>=duration):return []
        var overlap=float(metadata.get("removal_crossfade_ms",0))
        var blend=minf(1,float(removal)/overlap) if overlap>0 else 1.0
        # The original lifetime freezes outgoing colour at the removal instant.
        # Release coverage comes from the bank, not the generic owner fade.
        var frozen=age-float(removal)+(float(layer.get("phaseOffsetMs",0)) if not row.initial else 0.0)
        alpha=float(layer.get("opacity",1.0))
        var result:Array=_ordinary(row,frozen,alpha,cache) if blend<1 else []
        for part in result:part.alpha*=1-blend
        if blend>0:result.append(_bank("release",release,float(removal),alpha*blend,cache))
        return result
    age+=float(layer.get("phaseOffsetMs",0)) if not row.initial else 0.0
    return _ordinary(row,age,alpha,cache)
