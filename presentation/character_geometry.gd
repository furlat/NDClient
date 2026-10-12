extends RefCounted
# Delivered per-source optical receivers, separate from environment encodings.
# This table indexes existing media identities; it never chooses an outfit.
const Placement = preload("res://placement.gd")
const TABLE = "res://generated/character_geometry.json"
const PROFILE_TABLE = "res://generated/normal_profiles.json"
const PROFILES = ["original","gentle","reference"]
const PARAMETERS = {"depth":"component_depth", "normal":"component_normal",
    "support":"component_support", "normal_valid":"component_normal_valid"}

static func record(path: String, slot: String, cache: Dictionary) -> Dictionary:
    if slot == "shadow" or not path.begins_with("/media/smallscale/modular/"): return {}
    if not cache.has(TABLE): cache[TABLE] = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
    var source: Dictionary = cache[TABLE].records.get(path,{})
    if not source.has("files") or slot not in source.slots: return {}
    return source

static func paths(path: String, slot: String, cache: Dictionary) -> Dictionary:
    var resolved = source_paths(path,slot,cache)
    return resolved.value if resolved.ok else {}

static func _error(message: String) -> Dictionary:
    return {"ok":false,"error":{"kind":"presentation","message":message}}

static func normal_paths(path: String, slot: String, cache: Dictionary) -> Dictionary:
    var source = record(path,slot,cache)
    if source.is_empty(): return {"ok":true,"value":{}}
    if not cache.has(PROFILE_TABLE):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_TABLE))
        if not parsed is Dictionary: return _error("Missing or invalid normal profile index: " + PROFILE_TABLE)
        cache[PROFILE_TABLE] = parsed
    var profiles: Dictionary = cache[PROFILE_TABLE].records.get(path,{})
    if profiles.get("original","")!=source.files.normal: return _error("Missing or mismatched original normal profile registration: " + path)
    var root: String = ProjectSettings.get_setting("source_data/character_geometry_root")
    var derived_root: String = ProjectSettings.get_setting("source_data/normal_profiles_root",ProjectSettings.globalize_path("res://").path_join("../NDCharacterLight/.derived/normals").simplify_path())
    var result = {"original":root.path_join(source.files.normal)}
    for profile in ["gentle","reference"]:
        if not profiles.has(profile) or str(profiles[profile]).is_empty(): return _error("Missing delivered " + profile + " normal profile: " + path)
        result[profile] = derived_root.path_join(profiles[profile])
    return {"ok":true,"value":result}

static func source_paths(path: String, slot: String, cache: Dictionary) -> Dictionary:
    var source = record(path,slot,cache)
    if source.is_empty(): return {"ok":true,"value":{}}
    var profiles = normal_paths(path,slot,cache)
    if not profiles.ok: return profiles
    var root: String = ProjectSettings.get_setting("source_data/character_geometry_root")
    var result = {}
    for relative in source.files.values(): result[root.path_join(relative)] = true
    for absolute in profiles.value.values(): result[absolute] = true
    return {"ok":true,"value":result}

static func clear(entry: Dictionary) -> void:
    entry.material.set_shader_parameter("has_component_geometry",false)
    for parameter in PARAMETERS.values(): entry.material.set_shader_parameter(parameter,null)
    entry.geometry_paths = {}
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
    var root: String = ProjectSettings.get_setting("source_data/character_geometry_root")
    for field in PARAMETERS:
        var absolute: String = profiles.value[profile] if field=="normal" else root.path_join(source.files[field])
        entry.material.set_shader_parameter(PARAMETERS[field],loader.call(absolute))
        entry.geometry_paths[absolute] = true
    entry.material.set_shader_parameter("component_depth_range",Vector2(source.depth_range[0],source.depth_range[1]))
    # Provisional optical convention: one reconstruction unit is one source
    # pixel at the existing quad scale. This never changes its geometry/Z/order.
    entry.material.set_shader_parameter("component_units",entry.scale/Placement.PIXELS_PER_UNIT)
    entry.material.set_shader_parameter("component_scale_x",scale_x)
    var optical: Dictionary = cache[TABLE].optical_camera
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
    for x in [0.0,128.0]:
        for y in [0.0,128.0]:
            for d in source.depth_range:
                bounds = bounds.expand(relative*Vector3(x-optical.origin[0],optical.origin[1]-y,d)*units)
    entry.node.custom_aabb = bounds
