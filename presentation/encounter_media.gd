extends RefCounted
# Optional encounter warmup uses authored families from displayed state and the
# bounded already-received operation window. It never publishes future state.
const Characters = preload("res://presentation/characters.gd")
const Catalog = preload("res://source_catalog.gd")

static func _outfit(actor: Dictionary) -> Array:
    return [actor.get("creature_content_ref"),actor.get("appearance"),actor.get("visual_loadout"),actor.get("life_state")]

static func _include(actors: Dictionary, actor: Dictionary, looks:Dictionary) -> void:
    if actor.get("last_visual_position") == null: return
    var id: String = actor.uuid
    var signature = _outfit(actor)
    if not actors.has(id): actors[id] = []
    for prior in actors[id]:
        if _outfit(prior.actor)==signature and prior.looks==looks:return
    actors[id].append({"actor":actor,"looks":looks})

static func _priority_clips(actor:Dictionary,rig:Dictionary,index:Dictionary,cache:Dictionary)->Array:
    var clips:Dictionary={}
    var rest:Dictionary=Characters.rest_sample(actor,rig,cache)
    if rest.ok:clips[rest.value.clip]=true
    var movement:Dictionary=Characters._read(index.movement_context,cache)
    for field in ["walkClip","jumpClip"]:
        if movement.has(field):clips[movement[field]]=true
    var flight:Dictionary=movement.get("flight",{}).get("body",{}).get("actor",{})
    if flight.get("enabled",false):clips[flight.clip]=true
    for connector in movement.get("connectorProfiles",{}).values():
        if connector.has("bodyClip"):clips[connector.bodyClip]=true
    for context in rig.get("body_contexts",[]):
        var body:Dictionary=context.get("body",{}).get("actor",{})
        if context.role=="movement" and body.get("enabled",false):clips[body.clip]=true
    return clips.keys().filter(func(clip):return rig.clips.has(clip))

## Normal maps of the light profiles not in use for this colour sheet (the
## modular parts' profiles, carried by the built layer). A profile switch
## requests its own normals (play.gd media_profile_record).
static func _unselected_normals(descriptor:Dictionary,profile:String)->Dictionary:
    var result:Dictionary={}
    var profiles:Dictionary=descriptor.get("profiles",{})
    if profile.is_empty() or not profiles.has(profile):return result
    for name in profiles:
        if name!=profile:result[profiles[name]]=true
    return result

static func plan(state:Dictionary,environment:Dictionary,fixtures:Dictionary,cache:Dictionary,groups:Array=[],profile:String="")->Dictionary:
    var paths:Dictionary=environment.duplicate();var cpu_required:Dictionary=environment.duplicate()
    var gpu_only:Dictionary={};var priority:Dictionary={};var errors:Array=[];var witnesses:Dictionary={}
    var items:Dictionary=state.get("items",{}).duplicate()
    var actors:Dictionary=state.get("actors",{}).duplicate()
    for actor in actors.values():_include(witnesses,actor,Characters.item_looks(actor,{"items":items}))
    for group in groups:
        var disclosed_items:Dictionary=items.duplicate()
        for commit in group.get("commits",[]):disclosed_items.merge(commit.delta.get("items",{}),false)
        for actor in group.get("staged_actors",{}).values():_include(witnesses,actor,Characters.item_looks(actor,{"items":disclosed_items}))
        for commit in group.get("commits",[]):
            items.merge(commit.delta.get("items",{}),true)
            actors.merge(commit.delta.get("actors",{}),true)
            for actor in commit.delta.get("actors",{}).values():_include(witnesses,actor,Characters.item_looks(actor,{"items":items}))
            if not commit.delta.get("items",{}).is_empty():
                for actor in actors.values():
                    if actor.visual_loadout.layers.any(func(layer):return commit.delta.items.has(layer.item_uuid)):_include(witnesses,actor,Characters.item_looks(actor,{"items":items}))
        for track in group.get("actor_tracks",[]):
            if not track.has("visual_loadout"):continue
            for witness in witnesses.get(track.actor_uuid,[]).duplicate():
                var actor:Dictionary=witness.actor
                var variant:Dictionary=actor.duplicate();variant.visual_loadout=track.visual_loadout
                _include(witnesses,variant,track.get("presentation_item_looks",witness.looks))
    # Compose each actual immutable layer/slot once. Four actors in the same
    # outfit share these entries; neither actor nor equipped-item UUID keys a
    # family, and no actor×all-clips resource/geometry resolution is repeated.
    var selected_sources:Dictionary={}
    var index:Dictionary=Characters._read("catalog-index.json",cache)
    var rigs:Dictionary=Characters.rigs(cache)
    for occurrences in witnesses.values():
        for witness in occurrences:
            var actor:Dictionary=witness.actor
            if Characters.effect_owned(actor,cache):continue
            var id:String=Characters.rig_id(actor,cache)
            if not rigs.has(id):errors.append("No authored rig for admitted actor "+str(actor.uuid));continue
            var priority_clips:Array=_priority_clips(actor,rigs[id],index,cache)
            var variants:Array=[actor]
            if actor.get("visual_loadout")!=null:
                for weapon_set in ["melee","ranged"]:
                    var variant:Dictionary=actor.duplicate();variant.visual_loadout=actor.visual_loadout.duplicate()
                    variant.visual_loadout.active_weapon_set=weapon_set;variants.append(variant)
            for variant in variants:
                var selected:Dictionary=Characters._select_layers(variant,rigs[id],id==Characters.BodySources.index(cache).root_rig,cache,witness.looks)
                if not selected.ok:errors.append(selected.error.message);continue
                for layer in selected.value:
                    var resource=Characters.BodySources.prepare_layer(layer.source_path,cache)
                    if resource==null:errors.append("Cannot admit body category: "+layer.source_path);continue
                    var key:Array=[layer.source_path,layer.slot]
                    if not selected_sources.has(key):selected_sources[key]={"resource":resource,"slot":layer.slot,"priority":{},"worn":false,"rest":{},"rig_clips":rigs[id].clips}
                    if is_same(variant,actor):
                        selected_sources[key].worn=true
                        for clip in priority_clips:selected_sources[key].priority[clip]=true
                    else:
                        # Gear of the inactive weapon set only rests until it is
                        # swapped in; the swap changes the loadout and re-plans.
                        var rest:Dictionary=Characters.rest_sample(variant,rigs[id],cache)
                        if rest.ok:selected_sources[key].rest[rest.value.clip]=true
    for selected in selected_sources.values():
        # Thin source summaries cover the optional library without admitting
        # any clip's geometry, sockets or native optical metadata.
        for clip in selected.resource.clips:
            # A clip outside the rig can never play (the clock has no length for it).
            if not selected.rig_clips.has(clip):continue
            if not selected.worn and not selected.rest.has(clip):continue
            var descriptor:Dictionary=selected.resource.clips[clip].get(selected.slot,{})
            if descriptor.is_empty():continue
            if descriptor.has("banks") and not descriptor.has("bank_summaries"):
                errors.append("Native body bank summaries are missing; rebuild characters: "+str(clip));continue
            var descriptors:Array=descriptor.bank_summaries.values() if descriptor.has("banks") else [descriptor]
            for source in descriptors:
                paths[source.path]=true;cpu_required[source.path]=true
                var unselected:Dictionary=_unselected_normals(source,profile)
                var kept:Dictionary={}
                for companion in source.companions:
                    if not unselected.has(companion):kept[companion]=true
                paths.merge(kept);gpu_only.merge(kept)
                if selected.priority.has(clip):
                    priority[source.path]=true;priority.merge(kept)
    for path in cpu_required:gpu_only.erase(path)
    var ordered:Dictionary=priority.duplicate();ordered.merge(paths);paths=ordered
    var retained:Dictionary=cache.get("__encounter_closure",{})
    if not retained.is_empty() and retained.paths.keys()==paths.keys() and retained.get("priority",{}).keys()==priority.keys() and retained.cpu_required==cpu_required and retained.gpu_only==gpu_only and retained.environment==environment and retained.fixtures==fixtures and retained.errors==errors:return retained
    var absolute:Dictionary={};var priority_absolute:Dictionary={}
    for path in paths:absolute[path]=Catalog.media_path(path)
    for path in priority:priority_absolute[path]=absolute[path]
    var result:Dictionary={"revision":int(retained.get("revision",0))+1,"paths":absolute,"priority":priority_absolute,
        "environment":environment,"fixtures":fixtures,"cpu_required":cpu_required,"gpu_only":gpu_only,"errors":errors,
        "source_layers":selected_sources.size()}
    cache.__encounter_closure=result
    return result

static func estimates(paths: Dictionary, cpu_required: Dictionary, gpu_only: Dictionary, cache: Dictionary) -> Dictionary:
    var previous: Dictionary = cache.get("__encounter_headers",{})
    var retained = {}
    var result = {}
    for path in paths:
        var size: Dictionary = previous.get(path,{})
        if size.is_empty(): size=Characters.BodySources.header(path,cache)
        if size.is_empty():size=_png_size(Catalog.media_path(path))
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
        if not headers.has(path):
            var imported:Dictionary=Characters.BodySources.header(path,cache)
            headers[path]=imported if not imported.is_empty() else (available[path] if available.has(path) else _png_size(Catalog.media_path(path)))
        var header: Dictionary = headers[path]
        if not header.has("error"): result[path] = int(header.width)*int(header.height)*4
    cache.__required_headers = headers
    return result

static func source_headers(paths:Dictionary,cache:Dictionary)->Dictionary:
    # These paths have already crossed source_sizes admission. Publish only
    # their immutable facts, never the optional catalog's whole header table.
    var known:Dictionary=cache.get("__required_headers",{})
    var result:Dictionary={}
    for path in paths:
        if known.has(path):result[path]=known[path]
    result.make_read_only()
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
