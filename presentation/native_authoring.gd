extends RefCounted
## One import boundary: native data Resources become the same passive compiler operands.
const CatalogResource = preload("res://presentation/resources/catalog.gd")
const ConditionResource = preload("res://presentation/resources/condition_presentation.gd")
const ActionResource = preload("res://presentation/resources/body_action.gd")
const CONDITION_FILE = "catalog/condition_recipes.json"
const ACTION_FILE = "catalog/body_action_recipes.json"
const INDEX = "res://authoring/presentation/catalog.tres"

static func _error(cache: Dictionary, message: String) -> void:
    if not cache.has("native_authoring_errors"): cache.native_authoring_errors = []
    if message not in cache.native_authoring_errors: cache.native_authoring_errors.append(message)

static func _load(path: String, cache: Dictionary) -> Resource:
    var key = "native_resource:" + path
    if not cache.has(key):
        if not ResourceLoader.exists(path):
            _error(cache, "Selected presentation Resource is missing: " + path)
            return null
        # Each candidate is independent of the currently displayed authoring.
        # No Resource, including external filter dependencies, holds live state.
        cache[key] = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
        if cache[key] == null: _error(cache, "Cannot load presentation Resource: " + path)
    return cache[key]

static func _catalog(cache: Dictionary) -> CatalogResource:
    var path: String = ProjectSettings.get_setting("source_data/presentation_catalog", INDEX)
    var catalog = _load(path, cache) as CatalogResource
    if catalog == null: _error(cache, "Expected PresentationResourceCatalog: " + path)
    return catalog

static func _range(value: float, low: float, high: float) -> bool:
    return is_finite(value) and value >= low and value <= high

static func overlay(document: String, legacy: Variant, cache: Dictionary) -> Variant:
    if document not in [CONDITION_FILE, ACTION_FILE]: return legacy
    var index = _catalog(cache)
    if index == null: return legacy
    var result = legacy.duplicate()
    if document == ACTION_FILE:
        for id in index.action_recipes:
            var path:String=index.action_recipes[id]
            var selected=_load(path,cache) as ActionResource
            if selected==null or selected.behavior_id!=id or not legacy.has(id):
                _error(cache,"Invalid body action Resource identity: "+path)
                continue
            if selected.rig_id.is_empty() or selected.clip.is_empty() or not _range(selected.playback_speed,.01,8) or selected.effect_frame<0:
                _error(cache,"Invalid body action source/clock: "+path)
                continue
            var recipe:Dictionary=legacy[id].duplicate(true)
            recipe.actor={"enabled":true,"clip":selected.clip,"playbackSpeed":selected.playback_speed,"hiddenSlots":[],"media":[]}
            recipe.anchors=[{"name":"action_start","frame":0},{"name":"effect","frame":selected.effect_frame}]
            recipe.effectAudioCue=selected.effect_audio_cue
            recipe.rigId=selected.rig_id
            recipe._resource_source=path
            recipe._legacy_source=ACTION_FILE+":/"+id
            recipe._source_fields={"actor":path,"actor/clip":path+"::clip","actor/playbackSpeed":path+"::playback_speed",
                "anchors/1/frame":path+"::effect_frame","effectAudioCue":path+"::effect_audio_cue"}
            result[id]=recipe
    elif document == CONDITION_FILE:
        for id in index.condition_recipes:
            var path: String = index.condition_recipes[id]
            var selected = _load(path, cache) as ConditionResource
            if selected == null:
                _error(cache, "Expected ConditionPresentation Resource: " + path)
                continue
            if selected.behavior_id != id or not legacy.has(id):
                _error(cache, "Condition Resource identity has no matching catalog definition: " + path)
                continue
            var recipe: Dictionary = legacy[id].duplicate(true)
            var fields = {}
            if selected.body_outline != null:
                var outline = selected.body_outline
                var valid = _range(outline.opacity,0,1) and _range(outline.pulse_opacity,0,1) \
                    and _range(outline.period_ms,1,10000) and _range(outline.onset_ms,1,10000) \
                    and outline.alpha_threshold >= 1 and outline.alpha_threshold <= 255
                for color in [outline.color,outline.pulse_color]:
                    valid = valid and _range(color.r,0,1) and _range(color.g,0,1) and _range(color.b,0,1)
                if not valid:
                    _error(cache,"Invalid body outline in " + path)
                    continue
                recipe.persistent.bodyOutline = {"color":outline.color.to_rgba32() >> 8,
                    "pulseColor":outline.pulse_color.to_rgba32() >> 8,"alphaThreshold":outline.alpha_threshold,
                    "opacity":outline.opacity,"pulseOpacity":outline.pulse_opacity,
                    "periodMs":outline.period_ms,"onsetMs":outline.onset_ms}
                fields["persistent/bodyOutline"] = path + "::body_outline"
                for pair in [["color","color"],["pulseColor","pulse_color"],["alphaThreshold","alpha_threshold"],
                    ["opacity","opacity"],["pulseOpacity","pulse_opacity"],["periodMs","period_ms"],["onsetMs","onset_ms"]]:
                    fields["persistent/bodyOutline/"+pair[0]] = path + "::body_outline/" + pair[1]
            if selected.body_filter != null:
                var filter = selected.body_filter
                if not _range(filter.opacity,0,1) or not _range(filter.saturation,0,2) or not _range(filter.brightness,0,2) \
                        or not _range(filter.tint.r,0,1) or not _range(filter.tint.g,0,1) or not _range(filter.tint.b,0,1):
                    _error(cache, "Invalid body filter in " + path)
                    continue
                recipe.persistent.alphaMultiplier = filter.opacity
                fields["persistent/alphaMultiplier"] = path + "::body_filter/opacity"
                recipe.persistent.bodyColor = null
                fields["persistent/bodyColor"] = path + "::body_filter"
                if filter.tint != Color.WHITE or filter.saturation != 1 or filter.brightness != 1:
                    recipe.persistent.bodyColor = {"tintRgb":filter.tint.to_rgba32() >> 8,
                        "saturation":filter.saturation, "brightness":filter.brightness}
                    for field in [["tintRgb","tint"],["saturation","saturation"],["brightness","brightness"]]:
                        fields["persistent/bodyColor/"+field[0]]=path+"::body_filter/"+field[1]
            var poses: Array = []
            var selections = {}
            for i in selected.activity_poses.size():
                var pose = selected.activity_poses[i]
                if pose == null or pose.clip.is_empty() or pose.rig_id.is_empty() or not _range(pose.playback_speed,0.01,8) \
                        or pose.activity not in ["idle","move"] or pose.sampling not in ["loop","hold"] or pose.frame < 0:
                    _error(cache, "Incomplete activity pose in " + path)
                    continue
                var selection = pose.rig_id+":"+pose.activity
                if selections.has(selection):
                    _error(cache, "Duplicate activity pose in " + path + ": " + selection)
                    continue
                selections[selection] = true
                poses.append({"rigId":pose.rig_id, "activity":pose.activity, "clip":pose.clip,
                    "sampling":pose.sampling, "frame":pose.frame, "playbackSpeed":pose.playback_speed})
                for field in [["rigId","rig_id"],["activity","activity"],["clip","clip"],["sampling","sampling"],["frame","frame"],["playbackSpeed","playback_speed"]]:
                    fields["persistent/activityPoses/"+str(i)+"/"+field[0]]=path+"::activity_poses/"+str(i)+"/"+field[1]
            if not poses.is_empty():
                recipe.persistent.activityPoses = poses
                fields["persistent/activityPoses"] = path + "::activity_poses"
            for phase in ["application", "removal"]:
                var feedback = selected.application_feedback if phase == "application" else selected.removal_feedback
                if feedback == null: continue
                if not _range(feedback.duration_ms,1,10000):
                    _error(cache, "Invalid feedback duration in " + path)
                    continue
                recipe[phase].feedbackEnabled = feedback.enabled
                recipe[phase].feedbackColor = feedback.color.to_rgba32() >> 8
                recipe[phase].feedbackPrefix = feedback.prefix
                recipe[phase].feedbackDurationMs = feedback.duration_ms
                for pair in [["feedbackEnabled", "enabled"], ["feedbackColor", "color"], ["feedbackPrefix", "prefix"], ["feedbackDurationMs", "duration_ms"]]:
                    fields[phase + "/" + pair[0]] = path + "::" + phase + "_feedback/" + pair[1]
            recipe._source_fields = fields
            recipe._legacy_source = CONDITION_FILE + ":/" + id
            recipe._resource_source = path
            result[id] = recipe
    return result

static func source_pointer(document: String, pointer: String, data: Dictionary) -> String:
    var normalized = pointer.trim_prefix("/")
    if document in [CONDITION_FILE,ACTION_FILE]:
        var id = normalized.get_slice("/", 0)
        var relative = normalized.trim_prefix(id).trim_prefix("/")
        var fields: Dictionary = data.get(id, {}).get("_source_fields", {})
        var matched = ""
        for field in fields:
            if (relative == field or relative.begins_with(field + "/")) and field.length() > matched.length(): matched = field
        if not matched.is_empty(): return fields[matched] + relative.trim_prefix(matched)
    return document + ":/" + normalized
