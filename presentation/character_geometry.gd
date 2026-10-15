extends RefCounted
# Delivered per-source optical receivers, separate from environment encodings.
# This table indexes existing media identities; it never chooses an outfit.
const Placement = preload("res://placement.gd")
const TABLE = "res://generated/character_geometry.json"
const PROFILE_TABLE = "res://generated/normal_profiles.json"
const CREATURE_TABLE = "res://generated/creature_geometry.json"
const PROFILES = ["original","gentle","reference"]
const PARAMETERS = {"depth":"component_depth", "normal":"component_normal",
    "support":"component_support", "normal_valid":"component_normal_valid"}

static func record(path: String, slot: String, cache: Dictionary) -> Dictionary:
    if slot == "shadow": return {}
    var table = TABLE if path.begins_with("/media/smallscale/modular/") else CREATURE_TABLE
    if table==CREATURE_TABLE and slot!="body": return {}
    if not cache.has(table): cache[table] = JSON.parse_string(FileAccess.get_file_as_string(table))
    var identity = path
    if table==CREATURE_TABLE and not path.begins_with("/media/"):
        var root: String = ProjectSettings.get_setting("source_data/creature_geometry_root")
        if not path.begins_with(root+"/"): return {}
        identity = cache[table].colour_sources.get(path.trim_prefix(root+"/"),"")
    var source: Dictionary = cache[table].records.get(identity,{})
    if not source.has("files") or slot not in source.slots: return {}
    return source

static func _root(source: Dictionary) -> String:
    return ProjectSettings.get_setting("source_data/creature_geometry_root" if source.has("normal_profiles") else "source_data/character_geometry_root")

static func display_path(path: String, slot: String, cache: Dictionary) -> String:
    var source = record(path,slot,cache)
    # Animals were authored as an explicit visible-body RGBA partition. The
    # delivered colour is that exact partition, at the original native size.
    return _root(source).path_join(source.colour_path) if source.has("colour_path") else path

static func paths(path: String, slot: String, cache: Dictionary, profile: String = "") -> Dictionary:
    var resolved = source_paths(path,slot,cache)
    if not resolved.ok:return {}
    return resolved.value if profile.is_empty() else for_profile(resolved.value,resolved.get("normal_sets",{}),profile,cache,"source:"+path+":"+slot)

static func for_profile(paths: Dictionary, normal_sets: Dictionary, profile: String,
        cache: Dictionary = {}, owner: String = "") -> Dictionary:
    # Source metadata and handoffs remain neutral. This projection changes only
    # which existing normal map is required, never its pixels or shader choice.
    if normal_sets.is_empty() or profile.is_empty():return paths
    var key=[&"__normal_profile_projection",owner,profile]
    var held: Dictionary=cache.get(key,{})
    if is_same(held.get("source"),paths) and is_same(held.get("normal_sets"),normal_sets):return held.paths
    var variants={};var selected={}
    for profiles in normal_sets.values():
        for path in profiles.values():variants[path]=true
        if profiles.has(profile):selected[profiles[profile]]=true
    var result={}
    for path in paths:
        if not variants.has(path) or selected.has(path):result[path]=paths[path]
    result.make_read_only()
    cache[key]={"source":paths,"normal_sets":normal_sets,"paths":result}
    return result

static func profile_normals(paths: Dictionary, normal_sets: Dictionary, profile: String) -> Dictionary:
    var result={}
    for profiles in normal_sets.values():
        var selected: String=profiles.get(profile,"")
        if not selected.is_empty() and paths.has(selected):result[selected]=true
    return result

static func _error(message: String) -> Dictionary:
    return {"ok":false,"error":{"kind":"presentation","message":message}}

static func normal_paths(path: String, slot: String, cache: Dictionary) -> Dictionary:
    var source = record(path,slot,cache)
    if source.is_empty(): return {"ok":true,"value":{}}
    if source.has("normal_profiles"):
        var result = {}
        for profile in PROFILES:
            if not source.normal_profiles.has(profile): return _error("Missing creature normal profile: "+path+"/"+profile)
            result[profile] = _root(source).path_join(source.normal_profiles[profile])
        return {"ok":true,"value":result}
    if not cache.has(PROFILE_TABLE):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_TABLE))
        if not parsed is Dictionary: return _error("Missing or invalid normal profile index: " + PROFILE_TABLE)
        cache[PROFILE_TABLE] = parsed
    var profiles: Dictionary = cache[PROFILE_TABLE].records.get(path,{})
    if profiles.get("original","")!=source.files.normal: return _error("Missing or mismatched original normal profile registration: " + path)
    var root: String = _root(source)
    var derived_root: String = ProjectSettings.get_setting("source_data/normal_profiles_root",ProjectSettings.globalize_path("res://").path_join("../NDCharacterLight/.derived/normals").simplify_path())
    var result = {"original":root.path_join(source.files.normal)}
    for profile in ["gentle","reference"]:
        if not profiles.has(profile) or str(profiles[profile]).is_empty(): return _error("Missing delivered " + profile + " normal profile: " + path)
        result[profile] = derived_root.path_join(profiles[profile])
    return {"ok":true,"value":result}

static func source_paths(path: String, slot: String, cache: Dictionary) -> Dictionary:
    # The catalog shell belongs to its reader. Store immutable results directly
    # in that shell so a worker's shallow copy never fills a shared directory.
    var key: Array = [&"__geometry_companions",path,slot]
    var table: String = TABLE if path.begins_with("/media/smallscale/modular/") else CREATURE_TABLE
    var retained: Dictionary = cache.get(key,{})
    if not retained.is_empty() and is_same(retained.source,cache.get(table)) \
        and is_same(retained.profiles,cache.get(PROFILE_TABLE)) \
        and retained.character_root==ProjectSettings.get_setting("source_data/character_geometry_root") \
        and retained.creature_root==ProjectSettings.get_setting("source_data/creature_geometry_root") \
        and retained.normal_root==ProjectSettings.get_setting("source_data/normal_profiles_root"):
        return retained.result
    var result = _source_paths(path,slot,cache)
    if result.ok:
        result.value.make_read_only()
        if result.has("normal_sets"):
            for profiles in result.normal_sets.values():profiles.make_read_only()
            result.normal_sets.make_read_only()
        result.make_read_only()
        var memo = {"source":cache.get(table),"profiles":cache.get(PROFILE_TABLE),
            "character_root":ProjectSettings.get_setting("source_data/character_geometry_root"),
            "creature_root":ProjectSettings.get_setting("source_data/creature_geometry_root"),
            "normal_root":ProjectSettings.get_setting("source_data/normal_profiles_root"),"result":result}
        memo.make_read_only()
        cache[key] = memo
    return result

static func _source_paths(path: String, slot: String, cache: Dictionary) -> Dictionary:
    var source = record(path,slot,cache)
    if source.is_empty(): return {"ok":true,"value":{}}
    var profiles = normal_paths(path,slot,cache)
    if not profiles.ok: return profiles
    var root: String = _root(source)
    var result = {}
    for relative in source.files.values(): result[root.path_join(relative)] = true
    for absolute in profiles.value.values(): result[absolute] = true
    return {"ok":true,"value":result,"normal_sets":{path:profiles.value}}

static func clear(entry: Dictionary) -> void:
    entry.material.set_shader_parameter("has_component_geometry",false)
    for parameter in PARAMETERS.values(): entry.material.set_shader_parameter(parameter,null)
    entry.geometry_paths = {}
    entry.erase("geometry_cell_size")
    entry.erase("geometry_ground_pixels")
    entry.erase("geometry_binding")
    entry.node.custom_aabb = entry.node.mesh.get_aabb()

static func bind(entry: Dictionary, path: String, cache: Dictionary, loader: Callable, depth: bool = true, normals: bool = true, profile: String = "original") -> void:
    var scale_x: float = entry.placement.get("scale_x",1.0)
    var key = [path,depth,normals,entry.scale,scale_x,profile]
    if entry.get("geometry_binding",[]) == key: return
    clear(entry)
    entry.geometry_binding = key
    var source = record(path,entry.actor_layer.slot,cache)
    entry.geometry_status = "unsupported_source" if source.is_empty() else source.status
    if source.is_empty(): return
    var profiles = normal_paths(path,entry.actor_layer.slot,cache)
    if not profiles.ok or not profiles.value.has(profile):
        entry.geometry_status = "incomplete_normal_profile"
        entry.geometry_error = profiles.error.message if not profiles.ok else "Unknown normal profile: " + profile
        return
    entry.erase("geometry_error")
    var root: String = _root(source)
    for field in PARAMETERS:
        var absolute: String = profiles.value[profile] if field=="normal" else root.path_join(source.files[field])
        entry.material.set_shader_parameter(PARAMETERS[field],loader.call(absolute))
        entry.geometry_paths[absolute] = true
    entry.material.set_shader_parameter("component_depth_range",Vector2(source.depth_range[0],source.depth_range[1]))
    # Provisional optical convention: one reconstruction unit is one source
    # pixel at the existing quad scale. This never changes its geometry/Z/order.
    entry.material.set_shader_parameter("component_units",entry.scale/Placement.PIXELS_PER_UNIT)
    entry.material.set_shader_parameter("component_scale_x",scale_x)
    var optical: Dictionary = source.optical_camera if source.has("optical_camera") else cache[TABLE].optical_camera
    var cell: Array = source.get("cell_size",[128,128])
    entry.geometry_cell_size = Vector2(cell[0],cell[1])
    # Only original registered creatures have an authored ground. Library-only
    # packet availability never invents a gameplay placement.
    var ground: Variant = source.get("optical_ground_pixels",19.0)
    if ground!=null: entry.geometry_ground_pixels = float(ground)
    entry.material.set_shader_parameter("component_reconstruction_origin",Vector2(optical.origin[0],optical.origin[1]))
    entry.material.set_shader_parameter("component_elevation",deg_to_rad(optical.elevation_degrees))
    entry.material.set_shader_parameter("use_component_depth",depth)
    entry.material.set_shader_parameter("use_component_normals",normals)
    entry.material.set_shader_parameter("has_component_geometry",true)

    # Reconstructed points can lie outside the painted quad. Expand the native
    # light-culling box from the packet extrema, preserving the quad/pivot itself.
    # The source and display share azimuth but have 45 and 30 degree elevations.
    var relative := Basis(Vector3.RIGHT,-(deg_to_rad(optical.elevation_degrees)-PI/6.0))
    var bounds: AABB = entry.node.mesh.get_aabb()
    var units: float = entry.scale/Placement.PIXELS_PER_UNIT
    for x in [0.0,float(cell[0])]:
        for y in [0.0,float(cell[1])]:
            for d in source.depth_range:
                bounds = bounds.expand(relative*Vector3(x-optical.origin[0],optical.origin[1]-y,d)*units)
    entry.node.custom_aabb = bounds
