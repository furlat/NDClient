extends RefCounted
## Optional offline pose inspection. Authored spells remain the source of defaults.
const DATA = "res://authoring/sandbox/casting.json"

static func variants() -> Array:
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
    return data.profiles.duplicate(true)

static func apply(recipe: Dictionary, rig: Dictionary, profile_id: String = "authored") -> Dictionary:
    var result = recipe.duplicate(true)
    if profile_id == "authored": return result
    var profile: Dictionary = {}
    for candidate in variants():
        if candidate.id == profile_id:
            profile = candidate
            break
    if profile.is_empty() or profile.get("status") != "available":
        push_error("Unknown or unavailable sandbox casting profile: " + profile_id)
        return result
    var clip: String = profile.clip
    var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile.source_recipe))
    var cast: Dictionary = source.cast.duplicate(true)
    var sockets: Dictionary = cast.sourceSockets.duplicate(true)
    if profile.has("socket"):
        sockets.sources = profile.socket.sources.duplicate()
        sockets.forwardPixels = float(profile.socket.get("forwardPixels", 0.0))
        for facing in sockets.preparation:
            var points: Array = sockets.preparation[facing]
            for frame in points.size():
                if sockets.sources.any(func(name):return rig.pose_sockets[name][clip][facing][frame] == null):
                    points[frame] = null
                    continue
                var point := Vector2.ZERO
                for name in sockets.sources:
                    var hand_point: Dictionary = rig.pose_sockets[name][clip][facing][frame]
                    point += Vector2(hand_point.x, hand_point.y)
                point /= sockets.sources.size()
                points[frame] = {"x":point.x,"y":point.y}
            sockets.release[facing] = points[int(profile.release)].duplicate()
    var hand: Dictionary = cast.weaponGlow.duplicate(true)
    var original: Dictionary = recipe.cast
    var material: Dictionary = {}
    var candidates: Array = [original.get("weaponGlow"), original.get("aura")]
    candidates.append_array(original.get("effects", []))
    for layer in candidates:
        if layer != null and layer.get("category", "") in ["Magic1", "Magic2", "Magic3"]:
            material = layer
            break
    # Geometry/timing come from the selected pose; colour and noise stay with this spell.
    if material.is_empty():
        var colors: Dictionary = recipe.elementColors
        hand.colors = {"primary": colors.primary, "mode": "paletteSwap"}
        hand.palette.colors = [colors.tertiary, colors.primary, colors.secondary]
    else:
        for field in ["colors", "palette"]:
            if material.has(field): hand[field] = material[field].duplicate(true)
            else: hand.erase(field)
    hand.sourceSheet = rig.clips[clip].sheets[hand.category]
    # No old clip crops, keyed frames, body aura, or recovery animation survive the selection.
    cast.enabled = true
    cast.actionClip = clip
    cast.bodyPlaybackSpeed = profile.speed
    cast.prepareFrame = profile.prepare
    cast.releaseFrame = profile.release
    cast.recoverFrame = profile.recover
    cast.sourceSockets = sockets
    cast.weaponGlow = hand
    cast.effects = []
    for field in ["aura", "slash", "weaponOverride"]: cast.erase(field)
    result.cast = cast
    if result.get("projectile") != null:
        result.projectile.sourceSockets = sockets.duplicate(true)
        if result.projectile.get("prepare") != null:
            result.projectile.prepare.startFrame = profile.prepare
    return result
