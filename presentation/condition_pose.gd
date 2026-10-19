extends RefCounted
## Passive activity selection. The caller supplies the displayed owner's age;
## this helper owns neither a condition lifetime nor a second animation clock.
const Catalog = preload("res://source_catalog.gd")
const RECIPES = "catalog/condition_recipes.json"

static func select(actor: Dictionary, rig_id: String, activity: String, cache: Dictionary) -> Dictionary:
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
    var fps = float(clip.fps)
    if pose.get("terminal", false): return float(clip.frames) / fps
    if pose.get("sampling", "hold") == "hold": return float(pose.get("frame", 0)) / fps
    var elapsed = maxf(0, owner_age_ms) / 1000.0 * float(pose.get("playback_speed", 1.0))
    return fposmod(elapsed, float(clip.frames) / fps)
