extends RefCounted
## Passive activity selection. The caller supplies the displayed owner's age;
## this helper owns neither a condition lifetime nor a second animation clock.
const Tracks=preload("res://presentation/tracks.gd")
const Placement=preload("res://placement.gd")
const Catalog = preload("res://source_catalog.gd")
const RECIPES = "catalog/condition_recipes.json"

## A source lease confirms an already captured logical pose. It never samples
## a later body or stores/restores an outfit/material snapshot.
class Binding extends RefCounted:
    var actor_uuid:String
    var condition_uuid:String
    var capture:Dictionary={}
    var owners:Dictionary={}
    func acquire_condition_pose(owner_id:int,packet:Dictionary)->bool:
        if packet.get("actor_uuid")!=actor_uuid or packet.get("owner_uuid")!=condition_uuid or capture.is_empty():return false
        owners[owner_id]=true
        return true
    func release_condition_pose(owner_id:int)->void:
        owners.erase(owner_id)

static func select(actor: Dictionary, rig_id: String, activity: String, cache: Dictionary, owners:Dictionary={}) -> Dictionary:
    if actor.get("life_state", "alive") != "alive": return {}
    var selected = {}; var priority = -1
    var recipes = Catalog.read_file(RECIPES, cache)
    for condition in actor.get("conditions", []):
        var state: Variant = condition.get("state")
        if state != null and not state.get("suppression_provider_uuids", []).is_empty(): continue
        var id: String = str(condition.behavior_id) if condition.get("behavior_id")!=null else ""
        var config: Dictionary = recipes.get(id, {})
        if config.get("disposition") == "state_only": continue
        var persistent: Dictionary = config.get("persistent", {})
        var rank = int(config.get("composition", {}).get("priority", 0))
        if rank < priority: continue
        var candidate = {}; var field = ""
        var poses: Array = persistent.get("activityPoses", [])
        for i in poses.size():
            var pose: Dictionary = poses[i]
            if pose.rigId != rig_id or pose.activity != activity: continue
            candidate = {"clip":pose.clip, "sampling":pose.get("sampling", "loop"),
                "frame":pose.get("frame", 0), "playback_speed":pose.get("playbackSpeed", 1.0)}
            field = "activityPoses/" + str(i)
            break
        # Preserve existing frozen/terminal resting poses. They do not replace
        # an action track or introduce a locomotion clip for another rig.
        if candidate.is_empty() and activity == "idle":
            if persistent.has("frozenPose"):
                var frozen: Dictionary = persistent.frozenPose
                if frozen.get("captureCurrent",false):
                    var capture:Dictionary=owners.get(condition.condition_uuid,{}).get("logical_pose",{})
                    if capture.is_empty() or capture.rig!=rig_id:continue
                    candidate={"clip":capture.clip,"sampling":"hold","frame":capture.frame,"source_seconds":capture.source_seconds,
                        "world_facing":capture.world_facing,"hidden_slots":capture.hidden_slots,"captured":true,"playback_speed":1.0}
                else:
                    candidate = {"clip":frozen.clip, "sampling":"hold",
                        "frame":frozen.get("framesByRig", {}).get(rig_id, frozen.get("frame", 0)), "playback_speed":1.0}
                field = "frozenPose"
            elif persistent.has("bodyPose"):
                candidate = {"clip":persistent.bodyPose, "sampling":"hold", "terminal":true, "frame":0, "playback_speed":1.0}
                field = "bodyPose"
        if candidate.is_empty(): continue
        var pointer = id + "/persistent/" + field
        candidate.condition_uuid = condition.condition_uuid
        candidate.source = Catalog.source_pointer(RECIPES, pointer, cache)
        candidate.legacy_source = RECIPES + ":/" + pointer
        selected = candidate; priority = rank
    return selected

static func source_seconds(pose: Dictionary, clip: Dictionary, owner_age_ms: float) -> float:
    if pose.get("captured",false):return float(pose.source_seconds)
    var fps = float(clip.fps)
    if pose.get("terminal", false): return float(clip.frames) / fps
    if pose.get("sampling", "hold") == "hold": return float(pose.get("frame", 0)) / fps
    var elapsed = maxf(0, owner_age_ms) / 1000.0 * float(pose.get("playback_speed", 1.0))
    return fposmod(elapsed, float(clip.frames) / fps)

## Shared body arbitration. Motion remains a separate sample so frozen bodies
## retain actual displacement, support and elevation while their clip holds.
static func body_sample(rest:Dictionary,life:String,rig:Dictionary,pose:Dictionary,active:Dictionary,at_ms:float,owner_age_ms:float=0.0)->Dictionary:
    var result:Dictionary={"clip":rest.clip,"source_seconds":rest.source_seconds if life in ["dead","dying","stable"] else at_ms/1000.0}
    if not active.is_empty():result={"clip":active.clip,"source_seconds":active.source_seconds}
    if not pose.is_empty() and rig.clips.has(pose.clip) and (active.is_empty() or pose.get("captured",false)) and life=="alive":
        result={"clip":pose.clip,"source_seconds":source_seconds(pose,rig.clips[pose.clip],owner_age_ms),"condition_uuid":pose.condition_uuid}
        if pose.get("captured",false):result.merge({"world_facing":pose.world_facing,"hidden_slots":pose.hidden_slots,"captured":true})
    return result

static func departure_requested(condition:Dictionary,cache:Dictionary)->bool:
    return Catalog.read_file(RECIPES,cache).get(condition.get("behavior_id",""),{}).get("persistent",{}).get("actorHistory",{}).get("captureDeparture",false)

static func capture_requested(condition:Dictionary,cache:Dictionary)->bool:
    var persistent:Dictionary=Catalog.read_file(RECIPES,cache).get(condition.get("behavior_id",""),{}).get("persistent",{})
    return persistent.get("frozenPose",{}).get("captureCurrent",false) or persistent.get("actorHistory",{}).get("captureDeparture",false)

## Called only at actual ordered admission, before the canonical after-value.
## Current actor materials, camera quarter and later bind time are not inputs.
static func admissions(rows:Array,actors:Dictionary,owners:Dictionary,group:Dictionary,start_ms:float,local_ms:float,previous_directions:Dictionary,cache:Dictionary,departures:Dictionary={})->Dictionary:
    var result:Dictionary={};var before:Dictionary={};var prior_owners:Dictionary=owners.duplicate()
    var active:Dictionary={};var directions:Dictionary={};var rigs:Dictionary={};var cycle:Array=[]
    for change in rows:
        var actor_id:String=change.actor_uuid
        var actor:Dictionary=before.get(actor_id,actors.get(actor_id,{}))
        var after:Variant=change.after
        if change.before==null and after!=null and capture_requested(after,cache) and not actor.is_empty() and (not departure_requested(after,cache) or departures.has(after.condition_uuid)):
            if rigs.is_empty():
                rigs=Catalog.read_file("catalog/rigs.json",cache)
                cycle=Catalog.read_file(Catalog.read_file("catalog-index.json",cache).rig,cache).FACING_CYCLE
                active=Tracks.samples(group.get("actor_tracks",[]),local_ms)
                directions=previous_directions.duplicate()
                var ordered:Array=group.get("actor_tracks",[]).duplicate()
                ordered.sort_custom(func(a,b):return a.start_ms<b.start_ms)
                for track in ordered:
                    if track.start_ms>local_ms:continue
                    var origin:Variant=track.get("from_position");var target:Variant=track.get("target_position",track.get("to_position"))
                    if origin!=null and target!=null and origin!=target:directions[track.actor_uuid]=[origin,target]
            # Rigs are already assigned by the authored appearance. The caller
            # supplies these small existing facts; no source/media is loaded.
            var rig_id:String=actor.get("presentation_rig","")
            if not rig_id.is_empty() and rigs.has(rig_id):
                var rig:Dictionary=rigs[rig_id]
                var rest:Dictionary=actor.get("presentation_rest",{})
                if not rest.is_empty():
                    var pose:Dictionary=select(actor,rig_id,"idle",cache,prior_owners)
                    var age:float=start_ms+local_ms-float(prior_owners.get(pose.get("condition_uuid",""),{}).get("start_ms",start_ms+local_ms))
                    var source:Dictionary=body_sample(rest,actor.life_state,rig,pose,active.get(actor_id,{}),start_ms+local_ms,age)
                    var clip:Dictionary=rig.clips[source.clip]
                    var seconds:float=Tracks.sample_seconds(source.source_seconds,maxf(float(clip.frames)/float(clip.fps),.001),Tracks.character_loops(rig,source.clip))
                    var facing:String=source.get("world_facing","SW")
                    var path:Array=directions.get(actor_id,[])
                    if not source.get("captured",false) and path.size()==2:facing=Placement.facing(Vector2(path[1][0]-path[0][0],path[1][1]-path[0][1]),cycle)
                    var capture:Dictionary={"actor_uuid":actor_id,"condition_uuid":after.condition_uuid,"rig":rig_id,"clip":source.clip,
                        "source_seconds":source.source_seconds,"frame":mini(int(seconds*clip.fps),int(clip.frames)-1),"world_facing":facing,
                        "hidden_slots":source.get("hidden_slots",active.get(actor_id,{}).get("hidden_slots",[])).duplicate(),"admitted_at_ms":start_ms+local_ms}
                    if departure_requested(after,cache) and departures.has(after.condition_uuid):
                        var departure:Dictionary=departures[after.condition_uuid].duplicate(false)
                        var row:Dictionary=departure.row.duplicate(false)
                        var motion:Dictionary=active.get(actor_id,{})
                        if motion.has("position"):row.position=motion.position;row.base_height_steps=motion.base_height_steps
                        row.visual_height=float(motion.get("lift_pixels",0))*(128.0/float(departure.tile_width))/64.0
                        row.facing=facing
                        row.make_read_only();departure.row=row;departure.motion=motion.duplicate(true)
                        departure.make_read_only();capture.departure=departure
                    capture.make_read_only();result[after.condition_uuid]=capture
                    prior_owners[after.condition_uuid]={"logical_pose":capture,"start_ms":start_ms+local_ms}
        if actor.is_empty():continue
        var next:Dictionary=actor.duplicate()
        next.conditions=actor.get("conditions",[]).filter(func(member):return member.condition_uuid!=change.row.condition_uuid)
        if after!=null:next.conditions.append(after)
        before[actor_id]=next
    return result

static func project(samples:Dictionary,actors:Dictionary,owners:Dictionary,cache:Dictionary,rig_ids:Dictionary={})->Dictionary:
    var result:Dictionary=samples
    for owner in owners.values():
        if not owner.has("logical_pose") or not actors.has(owner.actor_uuid):continue
        var actor:Dictionary=actors[owner.actor_uuid]
        var pose:Dictionary=select(actor,str(rig_ids.get(owner.actor_uuid,owner.logical_pose.rig)),"idle",cache,owners)
        if not pose.get("captured",false):continue
        if is_same(result,samples):result=samples.duplicate()
        var sample:Dictionary=samples.get(owner.actor_uuid,{}).duplicate()
        sample.merge({"clip":pose.clip,"source_seconds":pose.source_seconds,"world_facing":pose.world_facing,"hidden_slots":pose.hidden_slots,
            "captured":true,"occurrence":"condition_pose:"+pose.condition_uuid+":"+pose.clip},true)
        result[owner.actor_uuid]=sample
    return result
