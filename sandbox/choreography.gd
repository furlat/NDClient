extends RefCounted
const Playback=preload("res://presentation/native_spell_playback.gd")
## Offline visual cue schedule. Time, path and source clocks are distinct data.
## It does not resolve rules, damage or server events.

static func path(a:Vector3,b:Vector3,bend:Vector2,t:float)->Vector3:
    var forward=(b-a).normalized()
    var side=forward.cross(Vector3.UP).normalized()
    if side.is_zero_approx():side=Vector3.RIGHT
    return a.lerp(b,t)+(side*bend.x+Vector3.UP*bend.y)*sin(PI*t)

static func path_length(a:Vector3,b:Vector3,bend:Vector2)->float:
    var length=0.0
    var last=a
    for i in range(1,33):
        var next=path(a,b,bend,float(i)/32.)
        length+=last.distance_to(next);last=next
    return length

static func compile(spec:Dictionary,clips:Array,release:float,cast_start:float,cast_end:float,
        from:Vector3,targets:Array,speed:float,split_targets:bool,preparation_start:float=0.0,actors:Dictionary={})->Dictionary:
    var by_id={}
    for clip in clips:by_id[clip.id]=clip
    var result={"cues":[],"contacts":[],"end":cast_end}
    var deliveries:int=spec.get("deliveries",1)
    for index in deliveries:
        var target:Dictionary=targets[index%targets.size()] if split_targets else targets[0]
        var launch=release+index*float(spec.get("delivery_interval",0.0))
        var bends:Array=spec.get("bends",[[0,0]])
        var bend=Vector2(bends[index%bends.size()][0],bends[index%bends.size()][1])
        var travel=path_length(from,target.body,bend)/maxf(.1,speed)
        var contact=launch+(float(spec.get("contact_after_release",0.04)) if spec.get("target_local",false) else travel)
        result.contacts.append({"time":contact,"target":target.id,"index":index,"position":target.body})
        for choice in spec.cues:
            var role:String=choice.role
            if role=="cast" and index>0:continue
            var clip:Dictionary=by_id[choice.clip].duplicate(true)
            if choice.has("opacity_uniform"):clip.opacity_uniform=choice.opacity_uniform
            var cue_from:Vector3=actors[choice.from_actor].body if choice.has("from_actor") else from
            var cue_target:Dictionary=actors[choice.to_actor] if choice.has("to_actor") else target
            var cue_launch=launch+float(choice.get("launch_delay_seconds",0.0))
            var cue_contact=contact+float(choice.get("launch_delay_seconds",0.0))
            if choice.get("travel_to_target",false):cue_contact=cue_launch+path_length(cue_from,cue_target.body,bend)/maxf(.1,speed)
            var begin=cast_start
            var end=cue_contact
            var source_launch:float=choice.get("source_launch",.2)
            var source_contact:float=choice.get("source_contact",maxf(source_launch+.15,minf(clip.seconds,.8)))
            var native_end:float=choice.get("source_end",clip.seconds)
            if role=="cast":
                begin=maxf(maxf(cast_start,preparation_start),cue_launch-float(choice.get("before_release",.35)))
                end=begin+native_end/float(choice.get("source_rate",1.0))
            elif role=="flight":
                begin=maxf(maxf(cast_start,preparation_start),cue_launch-float(choice.get("charge_seconds",.3)))
                end=cue_contact+maxf(0,native_end-source_contact)
            elif role=="strike":
                begin=cast_start
                end=cue_contact+maxf(0,native_end-source_contact)
            elif role=="spray":
                begin=cue_launch;end=begin+native_end
            elif role in ["impact","area"]:
                begin=cue_contact+float(choice.get("contact_delay",0))
                end=begin+native_end
            elif role=="attached":
                begin={"cast":cast_start,"release":cue_launch,"contact":cue_contact}[choice.get("at","release")]+float(choice.get("delay_seconds",0))
                end=begin+native_end/float(choice.get("source_rate",1.0))
            var cue=choice.duplicate(true)
            cue.merge({"id":"%s:%d"%[choice.get("id",choice.clip),index],"clip":clip,"role":role,
                "begin":begin,"end":end,"launch":cue_launch,"contact":cue_contact,
                "source_launch":source_launch,"source_contact":source_contact,
                "target":cue_target.id,"from":cue_from,"to":cue_target.body,"ground":cue_target.ground,
                "bend":bend,"index":index},true)
            result.cues.append(cue);result.end=maxf(result.end,end)
            if choice.get("reaction_at_start",false):
                result.contacts.append({"time":begin,"target":target.id,"index":100+index,"position":target.body})
    result.contacts.sort_custom(func(a,b):return a.time<b.time if not is_equal_approx(a.time,b.time) else a.index<b.index)
    return result

static func source_time(cue:Dictionary,time:float)->float:
    return Playback.source_time(cue,time)

static func transform(cue:Dictionary,time:float,hand:Vector3,scale_multiplier:float)->Transform3D:
    return Playback.transform(cue,time,hand,scale_multiplier)
