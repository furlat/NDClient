extends RefCounted
# Optional encounter warmup uses authored families from displayed state and the
# bounded already-received operation window. It never publishes future state.
const Characters = preload("res://presentation/characters.gd")
const Catalog = preload("res://source_catalog.gd")

static func _outfit(actor: Dictionary) -> Array:
    return [actor.get("creature_content_ref"),actor.get("appearance"),actor.get("visual_loadout"),actor.get("life_state")]

static func _include(actors: Dictionary, actor: Dictionary) -> void:
    if actor.get("last_visual_position") == null: return
    var id: String = actor.uuid
    var signature = _outfit(actor)
    if not actors.has(id): actors[id] = []
    for prior in actors[id]:
        if _outfit(prior)==signature: return
    actors[id].append(actor)

static func _priority_paths(actor: Dictionary, rig: Dictionary, index: Dictionary, cache: Dictionary) -> Dictionary:
    # These are authored resting/movement sources for this actual outfit, not
    # predicted actions or a second interpretation of movement events.
    var clips = {}
    var rest = Characters.rest_sample(actor,rig,cache)
    if rest.ok: clips[rest.value.clip] = true
    var movement: Dictionary = Characters._read(index.movement_context,cache)
    for field in ["walkClip","jumpClip"]:
        if movement.has(field): clips[movement[field]] = true
    var flight: Dictionary = movement.get("flight",{}).get("body",{}).get("actor",{})
    if flight.get("enabled",false): clips[flight.clip] = true
    for connector in movement.get("connectorProfiles",{}).values():
        if connector.has("bodyClip"): clips[connector.bodyClip] = true
    for context in rig.get("body_contexts",[]):
        var body: Dictionary = context.get("body",{}).get("actor",{})
        if context.role=="movement" and body.get("enabled",false): clips[body.clip] = true
    var available: Array = clips.keys().filter(func(clip):return rig.clips.has(clip))
    var source = Characters.sheet_paths(actor,available,cache)
    return source.value if source.ok else {}

static func plan(state: Dictionary, environment: Dictionary, fixtures: Dictionary, cache: Dictionary, groups: Array = []) -> Dictionary:
    var paths = environment.duplicate()
    var cpu_required = environment.duplicate()
    var gpu_only = {}
    var priority = {}
    var errors: Array = []
    var actors = {}
    var previous: Dictionary = cache.get("__encounter_outfits",{})
    var witnesses = {}
    for actor in state.get("actors",{}).values(): _include(witnesses,actor)
    # These packets have already been admitted by the SDK. Preparing their
    # source families does not publish their actors or advance a display clock.
    for group in groups:
        for actor in group.get("staged_actors",{}).values(): _include(witnesses,actor)
        for commit in group.get("commits",[]):
            for actor in commit.delta.get("actors",{}).values(): _include(witnesses,actor)
        for track in group.get("actor_tracks",[]):
            if not track.has("visual_loadout"): continue
            for actor in witnesses.get(track.actor_uuid,[]).duplicate():
                var variant: Dictionary = actor.duplicate()
                variant.visual_loadout = track.visual_loadout
                _include(witnesses,variant)
    if not witnesses.is_empty():
        var index: Dictionary = Characters._read("catalog-index.json",cache)
        var rigs: Dictionary = Characters._read(index.rigs,cache)
        for id in witnesses:
            actors[id] = []
            for actor in witnesses[id]:
                var signature = _outfit(actor)
                var packet = {}
                for prior in previous.get(id,[]):
                    if prior.signature==signature: packet = prior; break
                if packet.is_empty():
                    packet = {"signature":signature,"paths":{},"priority":{},"cpu_required":{},"gpu_only":{},"errors":[]}
                    var rig: String = Characters.rig_id(actor,cache)
                    if not rigs.has(rig):
                        packet.errors.append("No authored rig for admitted actor " + str(id))
                    else:
                        packet.priority = _priority_paths(actor,rigs[rig],index,cache)
                        var variants: Array = [actor]
                        if actor.get("visual_loadout") != null:
                            for weapon_set in ["melee","ranged"]:
                                var variant: Dictionary = actor.duplicate()
                                variant.visual_loadout = actor.visual_loadout.duplicate()
                                variant.visual_loadout.active_weapon_set = weapon_set
                                variants.append(variant)
                        for variant in variants:
                            var resolved = Characters.sheet_paths(variant,rigs[rig].clips.keys(),cache)
                            if not resolved.ok:
                                packet.errors.append(resolved.error.message)
                                continue
                            packet.paths.merge(resolved.value)
                            packet.cpu_required.merge(resolved.cpu_required)
                            packet.gpu_only.merge(resolved.gpu_only)
                actors[id].append(packet)
                priority.merge(packet.priority)
                paths.merge(packet.paths)
                cpu_required.merge(packet.cpu_required)
                gpu_only.merge(packet.gpu_only)
                errors.append_array(packet.errors)
    cache.__encounter_outfits = actors
    for path in cpu_required: gpu_only.erase(path)
    # Every witnessed active outfit gets its rest/movement closure before any
    # actor's exhaustive poses and alternate equipment variants consume budget.
    var ordered: Dictionary = priority.duplicate()
    ordered.merge(paths)
    paths = ordered
    var retained: Dictionary = cache.get("__encounter_closure",{})
    if not retained.is_empty() and retained.paths.keys()==paths.keys() and retained.get("priority",{}).keys()==priority.keys() and retained.cpu_required==cpu_required and retained.gpu_only==gpu_only and retained.environment==environment and retained.fixtures==fixtures and retained.errors==errors:
        return retained
    var absolute = {}
    for path in paths: absolute[path] = Catalog.media_path(path)
    var priority_absolute = {}
    for path in priority: priority_absolute[path] = absolute[path]
    var result = {"revision":int(retained.get("revision",0))+1,"paths":absolute,"priority":priority_absolute,"environment":environment,"fixtures":fixtures,
        "cpu_required":cpu_required,"gpu_only":gpu_only,"errors":errors}
    cache.__encounter_closure = result
    return result

static func estimates(paths: Dictionary, cpu_required: Dictionary, gpu_only: Dictionary, cache: Dictionary) -> Dictionary:
    var previous: Dictionary = cache.get("__encounter_headers",{})
    var retained = {}
    var result = {}
    for path in paths:
        var size: Dictionary = previous.get(path,{})
        if size.is_empty(): size = _png_size(Catalog.media_path(path))
        retained[path] = size
        if size.has("error"):
            result[path] = size
            continue
        # Deliberately conservative RGBA8 estimates for both GPU and retained
        # originals. Actual decoded CPU accounting replaces this after upload.
        var gpu_bytes: int = size.width * size.height * 4
        var cpu_bytes: int = gpu_bytes if cpu_required.has(path) or not gpu_only.has(path) else 0
        result[path] = {"bytes":gpu_bytes+cpu_bytes,"gpu_bytes":gpu_bytes,"cpu_bytes":cpu_bytes}
    cache.__encounter_headers = retained
    return result

static func source_sizes(paths: Dictionary, cache: Dictionary) -> Dictionary:
    # Required metadata must carry its sizes before optional family discovery.
    # Keep this small header cache separate: estimating the next action must not
    # replace the optional worker's much larger family header cache.
    var headers: Dictionary = cache.get("__required_headers",{})
    var available: Dictionary = cache.get("__encounter_headers",{})
    var result = {}
    for path in paths:
        if not headers.has(path): headers[path] = available[path] if available.has(path) else _png_size(Catalog.media_path(path))
        var header: Dictionary = headers[path]
        if not header.has("error"): result[path] = int(header.width)*int(header.height)*4
    cache.__required_headers = headers
    return result

static func estimate_bytes(estimates: Dictionary) -> Dictionary:
    # Prepared with accepted header metadata; no scene-thread nested lookups for
    # the capped greedy walk. Missing headers retain resident/unknown fallback.
    var result = {}
    for path in estimates:
        if estimates[path].has("bytes"): result[path] = int(estimates[path].bytes)
    return result

static func selection_index(encounter:Dictionary)->Dictionary:
    # Immutable metadata for the same ordered greedy budget walk. Unknown
    # headers keep the original residency-dependent fallback on the scene.
    var known:Dictionary=encounter.paths
    var bytes:Dictionary=encounter.get("estimate_bytes",{})
    var keys:Array=known.keys()
    var prefix=PackedInt64Array([0])
    var positions:Dictionary={}
    for i in keys.size():
        var path:String=keys[i]
        if not bytes.has(path) or int(bytes[path])<0:return {}
        positions[path]=i
        prefix.append(prefix[-1]+int(bytes[path]))
    return {"known":known,"ordered_paths":keys,"positions":positions,"prefix_bytes":prefix}

static func estimate_summary(encounter: Dictionary) -> Dictionary:
    # Runs with metadata/header preparation, before the scene adopts a family.
    var bytes = 0
    var unknown = 0
    for path in encounter.paths:
        var row: Dictionary = encounter.estimates.get(path,{})
        if row.has("bytes"): bytes += int(row.bytes)
        else: unknown += 1
    return {"bytes":bytes,"unknown":unknown}

static func _png_size(path: String) -> Dictionary:
    var file = FileAccess.open(path,FileAccess.READ)
    if file == null: return {"error":"Cannot inspect authored PNG: " + path}
    var header = file.get_buffer(24)
    if header.size()!=24 or header.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]) or header.slice(12,16).get_string_from_ascii()!="IHDR":
        return {"error":"Authored warmup source is not a PNG: " + path}
    var width: int = (int(header[16])<<24)|(int(header[17])<<16)|(int(header[18])<<8)|int(header[19])
    var height: int = (int(header[20])<<24)|(int(header[21])<<16)|(int(header[22])<<8)|int(header[23])
    if width<=0 or height<=0: return {"error":"Invalid authored PNG dimensions: " + path}
    return {"width":width,"height":height}
