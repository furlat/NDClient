extends SceneTree
## Migration proof for the environment source: every runtime document the
## build writes holds exactly what the game read from the legacy files
## (world.json, assets.json, environment/, the generated tables and the
## .derived copies), with the art paths moved inside the project. Strict:
## value types (int/float, typed collections) and every double must match.
## Fields nothing reads are dropped by name below. Runs only while the legacy
## files exist.
##   --headless --script res://tools/presentation_build/verify_environment_parity.gd
const OUT := "res://build/presentation/environment/"
const QUALITY := "C:/Users/tommaso/Documents/assets/fantasy-unified-catalog/environment-normal-quality-2026-10-12/"
const LAYOUTS := "res://.derived/environment-texture-layouts/"
const LIGHTING_2D = preload("res://presentation/lighting_2d.gd")
const LIGHTING = preload("res://presentation/lighting.gd")
## Read by nothing in the game (environment_inventory.md, DEAD lists).
const DEAD_WORLD := ["schema_version", "treatments", "spatial_effects", "spatial_media", "concentration_media", "construction_media", "deposit_media",
    "residue_wall_faces", "residue_particles", "residue_ground", "residue_surfaces", "liquid_surfaces", "stone_door_frame", "wood_door_closed", "wood_door_open"]
const DEAD_CLIFF := ["role", "rise_steps", "bed_material", "upper_support_offset"]
const DEAD_DOOR := ["pose_offset", "authoring_record", "assembly_variants"]
const DEAD_PROP := ["aperture_masks_by_pose", "occludes_actor_face", "passage_point", "authoring_record"]
const LEGACY_IMAGES := ["support.", "web", "trap-workshop.", "spikes.", "residue."]
var checks := 0
var failures: Array = []

func _initialize() -> void:
    run.call_deferred()

static func legacy_path(path: String) -> String:
    if path.begins_with("/media/"): return "res://assets/art/media/" + path.trim_prefix("/media/")
    if path.begins_with(QUALITY): return "res://assets/art/geometry/environment-quality/" + path.trim_prefix(QUALITY)
    if path.begins_with(LAYOUTS): return OUT + "pages/" + path.trim_prefix(LAYOUTS).replace("/pages/", "/")
    return path

static func moved(value: Variant) -> Variant:
    if value is Dictionary:
        var result := {}
        for key in value: result[moved(key) if key is String else key] = moved(value[key])
        return result
    if value is Array:
        var result: Array = []
        for item in value: result.append(moved(item))
        return result
    if value is String: return legacy_path(value)
    return value

func json(path: String) -> Variant:
    return JSON.parse_string(FileAccess.get_file_as_string(path))

func built(name: String) -> Variant:
    var record: Resource = ResourceLoader.load(OUT + name, "", ResourceLoader.CACHE_MODE_IGNORE)
    return record.value if record != null and "value" in record else null

func compare(label: String, expected: Variant, actual: Variant) -> void:
    checks += 1
    var differences: Array = []
    _same(expected, actual, label, differences)
    if not differences.is_empty():
        failures.append({"label": label, "differences": differences.slice(0, 8), "count": differences.size()})

func _same(a: Variant, b: Variant, where: String, out: Array) -> void:
    if out.size() > 50: return
    if typeof(a) != typeof(b): out.append(where + ": type " + type_string(typeof(a)) + " != " + type_string(typeof(b))); return
    if a is Dictionary:
        if a.is_typed() != b.is_typed(): out.append(where + ": typed dictionary differs")
        for key in a:
            if not b.has(key): out.append(where + ": missing " + str(key))
            else: _same(a[key], b[key], where + "/" + str(key), out)
        for key in b:
            if not a.has(key): out.append(where + ": extra " + str(key))
    elif a is Array:
        if a.is_typed() != b.is_typed(): out.append(where + ": typed array differs")
        if a.size() != b.size(): out.append(where + ": size " + str(a.size()) + " != " + str(b.size())); return
        for i in a.size(): _same(a[i], b[i], where + "/" + str(i), out)
    elif a != b: out.append(where + ": " + str(a) + " != " + str(b))

static func sorted(values: Array) -> Array:
    var result := values.duplicate()
    result.sort()
    return result

static func without(value: Dictionary, keys: Array) -> Dictionary:
    var result := value.duplicate()
    for key in keys: result.erase(key)
    return result

func run() -> void:
    var world: Dictionary = json("res://authoring/world.json")
    var assets: Dictionary = json("res://authoring/assets.json")
    var index: Dictionary = json("res://authoring/environment/index.json")
    # world.res
    var expected_world := without(world, DEAD_WORLD)
    expected_world.terrain = world.terrain.duplicate()
    expected_world.terrain.water = {} # the old value "water.unity" was never read; only has() is
    expected_world.terrain_cliff = without(world.terrain_cliff, DEAD_CLIFF)
    expected_world.terrain_stairs = without(world.terrain_stairs, ["role"])
    expected_world.props = {}
    for id in world.props: expected_world.props[id] = without(world.props[id], ["transition"])
    compare("world", moved(expected_world), built("world.res"))
    # resources.res
    var resources := {}
    for id in assets.resources:
        if not LEGACY_IMAGES.any(func(prefix): return id.begins_with(prefix)): resources[id] = assets.resources[id]
    compare("resources", moved({"resources": resources, "animations": assets.animations, "water": assets.water}), built("resources.res"))
    # index.res and every bank and library family
    var actual_index: Dictionary = built("index.res")
    var doors := {}
    for id in index.doors: doors[id] = without(json("res://authoring/" + index.doors[id]), DEAD_DOOR)
    var props := {}
    for id in index.props: props[id] = without(json("res://authoring/" + index.props[id]), DEAD_PROP)
    var traps := {}
    for id in index.traps: traps[id] = json("res://authoring/" + index.traps[id])
    compare("index/doors", moved(doors), actual_index.doors)
    compare("index/props", moved(props), actual_index.props)
    compare("index/traps", moved(traps), actual_index.traps)
    compare("index/wall_destructions", json("res://authoring/" + index.wall_destructions), actual_index.wall_destructions)
    compare("index/rests", {"prop.chest-a1.intact":"fantasy.chest.a1", "prop.chest-a2.intact":"fantasy.chest.a2",
        "prop.chest-a3.intact":"fantasy.chest.a3", "prop.chest-a4.intact":"fantasy.chest.a4",
        "prop.chest-b1.intact":"fantasy.chest.b1", "prop.chest-b2.intact":"fantasy.chest.b2"}, actual_index.rests)
    compare("index/bank ids", sorted(index.banks.keys()), sorted(actual_index.banks.keys()))
    for id in index.banks:
        var record: Resource = ResourceLoader.load(actual_index.banks.get(id, ""), "", ResourceLoader.CACHE_MODE_IGNORE)
        compare("bank " + id, moved(json("res://authoring/" + index.banks[id])), record.value if record != null else null)
    compare("index/library ids", sorted(index.library.keys()), sorted(actual_index.library.keys()))
    for id in index.library:
        var record: Resource = ResourceLoader.load(actual_index.library.get(id, ""), "", ResourceLoader.CACHE_MODE_IGNORE)
        compare("library " + id, moved(json("res://authoring/" + index.library[id])), record.value if record != null else null)
    # Receiving normals and texture layouts, keyed by their moved paths.
    var normals: Dictionary = json("res://generated/environment_receiving_normals.json").normals
    compare("receiving_normals", moved(normals), built("receiving_normals.res").normals)
    var layouts: Dictionary = json("res://generated/environment_texture_layouts.json").layouts
    compare("texture_layouts", moved(layouts), built("texture_layouts.res").layouts)
    for key in layouts:
        for page in layouts[key].pages:
            var old := Image.load_from_file(ProjectSettings.globalize_path(page))
            var new := Image.load_from_file(ProjectSettings.globalize_path(legacy_path(page)))
            checks += 1
            if old == null or new == null or old.get_format() != new.get_format() or old.get_size() != new.get_size() or old.get_data() != new.get_data():
                failures.append({"label": "page " + page, "differences": ["decoded page differs"]})
    # Fixture optics, blood particles, lighting values.
    var optics: Resource = ResourceLoader.load("res://generated/fixture_optical_facts.res", "", ResourceLoader.CACHE_MODE_IGNORE)
    var built_optics: Resource = ResourceLoader.load(OUT + "fixture_optics.res", "", ResourceLoader.CACHE_MODE_IGNORE)
    compare("fixture_optics", moved(optics.frames), built_optics.frames)
    var current: String = FileAccess.get_file_as_string("res://.derived/native-spells/current").strip_edges()
    var spells: Resource = ResourceLoader.load(current, "", ResourceLoader.CACHE_MODE_IGNORE)
    var blood_old: Resource = ResourceLoader.load(spells.asset_metadata["particles.region.blood"], "", ResourceLoader.CACHE_MODE_IGNORE)
    var blood_new: Resource = ResourceLoader.load(OUT + "residues/blood.res", "", ResourceLoader.CACHE_MODE_IGNORE)
    compare("blood asset id", blood_old.asset_id, blood_new.asset_id)
    compare("blood", blood_old.value, blood_new.value)
    var lighting: Dictionary = built("lighting.res")
    compare("torch colour", LIGHTING_2D.TORCH_COLOUR, lighting.torch_colour)
    compare("torch items", LIGHTING_2D.TORCH_ITEM_IDS, lighting.torch_item_ids)
    compare("carried lift", LIGHTING.CARRIED_OPTICAL_LIFT_STEPS, lighting.carried_lift_steps)
    compare("unregistered lift", LIGHTING.UNREGISTERED_OPTICAL_LIFT_STEPS, lighting.unregistered_lift_steps)
    compare("fallback cookie", "res://assets/art/lighting/" + LIGHTING_2D.DEFAULT_COOKIE.get_file(), lighting.fallback_cookie)
    var ranges_old: Resource = load("res://authoring/presentation/light_ranges.tres")
    var ranges_new: Resource = ResourceLoader.load(OUT + "light_ranges.res", "", ResourceLoader.CACHE_MODE_IGNORE)
    compare("light ranges", [ranges_old.very_bright_edge, ranges_old.bright_edge], [ranges_new.very_bright_edge, ranges_new.bright_edge])
    var report := {"checks": checks, "failures": failures}
    print("ENVIRONMENT_PARITY ", JSON.stringify({"checks": checks, "failures": failures.size()}))
    for failure in failures.slice(0, 30): print("PARITY_FAIL ", JSON.stringify(failure))
    quit(0 if failures.is_empty() else 1)
