extends RefCounted
## Inspection channels owned by an existing component. They create no effects
## and inherit the same event, recipient and presentation interval.
const Playback=preload("res://presentation/native_spell_playback.gd")

static func light_id(component_id:String,path:String)->String:
    return component_id+":light:"+path

static func channels(component:Dictionary)->Array:
    var result:Array=[]
    for authored_light in component.get("native_lights",[]):
        var light:Dictionary=authored_light.duplicate(false)
        light.tracks=_executing_tracks(authored_light.get("tracks",[]),component.get("native_clip",{}))
        var channel=component.duplicate(false)
        channel.merge({"id":light_id(component.id,light.path),"kind":"native_light","parent_id":component.id,
            "label":"Light · "+str(light.path).get_slice("/",0),"native_light":light,
            "render_method":{"node":"PointLight2D","surface":"native receiving light atlas","renderer":"res://presentation/native_source_lights.gd"}},true)
        result.append(channel)
    if component.has("native_hit"):
        var channel=component.duplicate(false)
        channel.merge({"id":component.id+":native_material","kind":"native_material","parent_id":component.id,
            "label":"Spell material · body","source":"sandbox/body_materials.json:/spells/"+str(component.native_hit.spell_id),
            "render_method":{"node":"ShaderMaterial","surface":"assembled recipient body","renderer":"res://presentation/native_spell_hits.gd","shader":"res://presentation/native_body_material.gdshaderinc"},
            "preview_scope":"live_composed_actor","preview_status":"missing","preview_reason":"Dedicated composed-body source thumbnail is not implemented; inspect the actual recipient in the replay.",
            "mode":"Full spell material; Colour treatment is selectable in Settings / Studio Inspect"},true)
        var definition:Dictionary=component.native_hit.get("definition",{})
        if definition.get("status")!="available":channel.status="missing";channel.reason=definition.get("reason","native_body_material_unassigned")
        result.append(channel)
    return result

static func _executing_tracks(tracks:Array,clip:Dictionary)->Array:
    var result:Array=[]
    for original in tracks:
        if not original.get("enabled",true):continue
        var starts:Array=[]
        if original.get("active_animation",true):starts.append(null)
        for cue in clip.get("animation_cues",[]):
            if cue.node==original.player and cue.animation==original.animation:starts.append(float(cue.at_seconds))
        for start in starts:
            var track:Dictionary=original.duplicate(false)
            if start!=null:track.source_cue_seconds=start
            var stop:float=INF
            for cue in clip.get("animation_cues",[]):
                if cue.node==original.player and float(cue.at_seconds)>float(start if start!=null else 0.0):stop=minf(stop,float(cue.at_seconds))
            track.source_stop_seconds=stop
            result.append(track)
    return result

static func markers(component:Dictionary,offset:float)->Array:
    var result:Array=[]
    if component.get("kind")!="native_light":return result
    var light:Dictionary=component.native_light
    for track in light.tracks:
        var binding:Dictionary={}
        for candidate in light.bindings:
            if str(track.player).begins_with(str(candidate.component)+"/"):binding=candidate;break
        if binding.is_empty() or float(binding.rate)<=0:continue
        for key in track.keys:
            var source:float=float(track.source_cue_seconds)+float(key.time) if track.has("source_cue_seconds") else (float(key.time)-float(binding.offset_seconds))/float(binding.rate)
            if source>=float(track.get("source_stop_seconds",INF)):continue
            var cue:Dictionary=component.native_cue
            if cue.has("lifecycle"):
                for time in _held_key_times(cue,source):
                    result.append({"kind":str(track.path).get_slice(":",1)+"="+str(key.value),
                        "at_ms":offset+component.start_ms+time*1000.0,
                        "source":str(track.player)+":"+str(track.animation)+"/"+str(track.path),"source_seconds":key.time})
                continue
            var first:float=Playback.source_time(cue,0)
            var last:float=Playback.source_time(cue,cue.end)
            # Animation keys are float32; retain an authored terminal switch
            # when JSON's decimal duration differs only by that precision.
            if source<first-.000001 or source>last+.000001:continue
            source=clampf(source,first,last)
            var lo:=0.0;var hi:float=cue.end
            for iteration in 24:
                var mid:float=(lo+hi)*.5
                if Playback.source_time(cue,mid)<source:lo=mid
                else:hi=mid
            result.append({"kind":str(track.path).get_slice(":",1)+"="+str(key.value),
                "at_ms":offset+component.start_ms+hi*1000.0,
                "source":str(track.player)+":"+str(track.animation)+"/"+str(track.path),"source_seconds":key.time})
    return result

static func _held_key_times(cue:Dictionary,source:float)->Array:
    var window:Dictionary=cue.lifecycle
    # Repeated source loops require a bounded inspection interval. Current
    # owner descriptors explicitly hold a measured native pose instead.
    if window.get("hold_mode","hold")!="hold":return []
    var result:Array=[]
    var enter:float=window.get("enter_end_seconds",0.0)
    var owner_end:float=cue.get("owner_end_seconds",INF)
    if not cue.get("initial",false) and source>=-.000001 and source<=enter+.000001 and source<owner_end:
        result.append(clampf(source,0.0,enter))
    var close_start:float=window.get("exit_start_seconds",enter)
    var close_end:float=window.get("exit_end_seconds",close_start)
    if is_finite(owner_end) and source>=close_start-.000001 and source<=close_end+.000001:
        result.append(owner_end+clampf(source,close_start,close_end)-close_start)
    return result
