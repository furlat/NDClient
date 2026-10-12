extends SceneTree
const Characters = preload("res://presentation/characters.gd")
const Graphs = preload("res://animation/graphs.gd")
const Catalog = preload("res://source_catalog.gd")
const Protocol = preload("res://sdk/protocol.gd")
const Reducer = preload("res://sdk/reducer.gd")
var failures: Array = []
var checks = 0

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label)

func _initialize() -> void:
    run.call_deferred()

func item(name_: String, slot: String, variant: Variant = null) -> Dictionary:
    return {"item_uuid":name_+slot, "slot":slot, "visual_item_name":name_,
        "visual_variant_id":variant, "equipped_visual_policy":"visible"}

func actor() -> Dictionary:
    return {"uuid":"character", "character_body_id":"creature.player.humanoid_body", "creature_content_ref":null,
        "last_visual_position":[2,3], "present":true, "spatial_disposition":"present", "remains_disposition":"intact",
        "life_state":"alive", "appearance":{"presentation_kind":"layered", "visual_scale":1.5, "visual_scale_x":0.8,
        "body_category":"NakedBody2", "skin_tint":0xDDCCAA, "head_category":null, "hair_tint":0x773311,
        "has_beard":true, "beard_tint":0x553322}, "visual_loadout":{"active_weapon_set":"melee",
        "layers":[item("Longsword", "MELEE_MAIN", "3000000c"), item("Dagger", "MELEE_OFF", "10000003"),
            item("Leather Armor", "Body", "50000004"), item("Shortbow", "RANGED_MAIN")]}}

func slots(row: Dictionary) -> Dictionary:
    var result = {}
    for layer in row.equipment_layers: result[layer.slot] = layer
    return result

func sample_check(host: Node, clip: String, time: float, occurrence: String, expected: float, label: String) -> void:
    var result = Graphs.sample(host, clip, time, occurrence)
    check(result.ok and host.clip == clip and absf(host.sample_seconds - expected) < 0.00001,
        label + " received " + host.clip + " @ " + str(host.sample_seconds))

func check_record(path: String, cache: Dictionary) -> void:
    var protocol = Protocol.new()
    var admitted = protocol.decode("InitializationResponse", FileAccess.get_file_as_bytes(path))
    check(admitted.ok, "Real initialization admitted: " + path)
    if not admitted.ok: return
    var packet: Dictionary = protocol.normalize("InitializationResponse", admitted.value)
    var reduced = Reducer.reduce_initialization(packet.initialization, packet.content_additions)
    check(reduced.ok, "Real initialization reduced: " + path)
    if not reduced.ok: return
    var rigs = Catalog.read_file("catalog/rigs.json", cache)
    var state: Dictionary = reduced.value
    for actual in state.actors.values():
        var resolved = Characters.resolve(actual, state, cache)
        check(resolved.ok, "Real actor authoring: " + actual.name + " " + str(resolved.get("error", "")))
        if not resolved.ok or resolved.value == null: continue
        var row: Dictionary = resolved.value
        var concrete = Characters.layers(row, rigs[row.rig], cache)
        check(not concrete.is_empty() and concrete.all(func(layer):return layer.paths.has("Idle")), "Real actor idle sheets: " + actual.name)
        if actual.creature_content_ref == "content.neurodragon:creature:creature.generic_caster@1":
            check(row.rig == "neuroclient.modular" and concrete.any(func(layer):return layer.get("equipment",false)), "Real caster keeps modular equipment")

func run() -> void:
    var start = Time.get_ticks_msec()
    var cache = {}
    var state = {"tiles":{"2,3":{"elevation_steps":3}}}
    var a = actor()
    var result = Characters.resolve(a, state, cache)
    check(result.ok, "Canonical modular actor resolves")
    if not result.ok:
        print(JSON.stringify({"checks":checks, "failures":failures, "error":result})); quit(1); return
    var row: Dictionary = result.value
    var selected = slots(row)
    check(row.rig == "neuroclient.modular", "Existing root owner selects modular rig")
    check(row.position == [2,3] and row.base_height_steps == 3 and row.visual_height == 0.0, "Disclosed position and elevation used exactly")
    check(row.scale == 1.5 and row.scale_x == 0.8, "Authored appearance scales retained")
    check(selected.body.category == "NakedBody2" and selected.body.tint == 0xDDCCAA, "Body and skin retained")
    check(not selected.has("head") and selected.beard.category == "Head2", "Nullable head and beard preserved")
    check(selected.weapon.category == "Melee2" and selected.weapon.tint == 13412932, "Exact mainhand variant")
    check(selected.offhand.category == "Offhand2" and selected.offhand.tint == 14202888, "Exact offhand variant override beats base equipment")
    check(selected.chest.tint == 4491332 and selected.legs.tint == 6040078, "Multi-layer apparel variant")
    check(not selected.has("shadow"), "Modular body selection omits baked shadow for generated geometry shadow")
    a.visual_loadout.active_weapon_set = "ranged"
    result = Characters.resolve(a, state, cache)
    check(result.ok and slots(result.value).weapon.category == "Ranged1" and not slots(result.value).has("offhand"), "Active weapon set filters equipped weapons")
    a.visual_loadout.layers[3].equipped_visual_policy = "hidden"
    result = Characters.resolve(a, state, cache)
    check(result.ok and not slots(result.value).has("weapon"), "Hidden equipped visuals stay hidden")
    a = actor(); a.visual_loadout.layers[0].visual_variant_id = "unknown"
    check(not Characters.resolve(a, state, cache).ok, "Unknown variant fails explicitly")
    a = actor(); a.creature_content_ref = "content.unknown:creature:missing@1"
    check(not Characters.resolve(a, state, cache).ok, "Unknown creature never becomes demo goblin or modular")
    a = actor(); a.appearance.presentation_kind = "placeholder"
    check(not Characters.resolve(a, state, cache).ok, "Unsupported root placeholder fails explicitly")
    a = actor()
    check(not Characters.resolve(a, {"tiles":{}}, cache).ok, "Missing elevation is not invented")
    for field in ["present", "last_visual_position", "spatial_disposition", "remains_disposition"]:
        var absent = actor()
        absent[field] = {"present":false, "last_visual_position":null, "spatial_disposition":"absent", "remains_disposition":"disintegrated"}[field]
        var hidden = Characters.resolve(absent, state, cache)
        check(hidden.ok and hidden.value == null, "Absent actor omitted: " + field)
    var rigs = Catalog.read_file("catalog/rigs.json", cache)
    var modular: Dictionary = rigs[row.rig]
    var concrete = Characters.layers(row, modular, cache)
    for layer in concrete:
        check(layer.slot not in Characters.EFFECT_SLOTS and layer.paths.has("Attack1"), "Concrete authored body/equipment sheet " + layer.slot)
    # Mutating draw data cannot alter canonical state or the shared authoring.
    concrete[0].alpha = 0.01
    check(row.equipment_layers[0].alpha == 1.0 and actor() == a, "Presentation data is copied")
    a.creature_content_ref = "content.neurodragon:creature:creature.goblin@1"
    result = Characters.resolve(a, state, cache)
    check(result.ok and result.value.rig == "smallscale.goblin01", "Exact fixed creature rig overrides absent body binding")
    var fixed = Characters.layers(result.value, rigs[result.value.rig], cache)
    check(fixed.size() == 1 and fixed[0].slot == "body", "Delivered fixed rig excludes baked shadow and inactive authored clip effects")
    check("/Bodies/" in fixed[0].paths.Attack1, "Fixed body uses original clean body sheet instead of combined effects")
    a.creature_content_ref = "content.neurodragon:creature:creature.skeleton_archer@1"
    result = Characters.resolve(a, state, cache)
    check(result.ok and slots(result.value).body.category == "SkeletonArcher05", "Fixed skeleton archer stays its own asset")
    a.life_state = "dead"
    check(Characters.rest_sample(a, rigs["smallscale.goblin01"], cache).value.clip == "Death", "Goblin death uses authored override, not prone clip")
    check(Characters.rest_sample(a, modular, cache).value.clip == "Die", "Modular death uses root death owner")
    a.life_state = "dying"
    check(Characters.rest_sample(a, rigs["smallscale.goblin01"], cache).value.clip == "Die", "Dying life state uses authored body pose")
    a.life_state = "stable"
    check(Characters.rest_sample(a, modular, cache).value.clip == "Die", "Stable life state holds authored pose")
    a.life_state = "alive"
    check(Characters.rest_sample(a, modular, cache).value.clip == "Idle", "Alive default remains Idle")

    var host = Graphs.character(root, modular)
    check(host.clip == "Idle", "Native character starts Idle")
    sample_check(host, "Attack1", 0.0, "attack-a", 0.0, "First frame")
    sample_check(host, "Attack1", 8.0/12.0, "attack-a", 8.0/12.0, "Authored melee contact")
    sample_check(host, "Attack1", 1.1, "attack-a", 1.1, "Attack recovery")
    sample_check(host, "Attack1", 0.0, "attack-b", 0.0, "New occurrence restarts same clip")
    sample_check(host, "Attack1", 0.7, "attack-b", 0.7, "Second occurrence advances")
    sample_check(host, "Attack1", 0.2, "attack-b", 0.2, "Deterministic backward seek")
    sample_check(host, "Run", 2.0, "move", 0.75, "Authored locomotion looping")
    sample_check(host, "Rolling", 0.75, "jump", 0.75, "Jump clock uses source seconds")
    sample_check(host, "Idle", 0.0, "oa-hold", 0.0, "Explicit idle hold")
    sample_check(host, "Rolling", 0.75, "jump", 0.75, "Interrupted jump resumes original source clock")
    sample_check(host, "Rolling", 0.75, "jump", 0.75, "Repeated camera sampling cannot reset motion")
    sample_check(host, "Die", 50.0, "death", 1.25, "Death holds its final frame")
    sample_check(host, "Die", 60.0, "death", 1.25, "Death stays held")
    check(not Graphs.sample(host, "Death", 0.0, "missing").ok, "No fabricated clip alias")
    check(not Graphs.sample(host, "Die", -1.0, "invalid").ok, "Invalid source time rejected")
    var goblin = Graphs.character(root, rigs["smallscale.goblin01"])
    sample_check(goblin, "Death", 50.0, "goblin-death", 1.25, "Generic authored Death clip is supported and held")
    var automatic = Graphs.character(root, rigs["smallscale.goblin01"])
    Graphs.request(automatic, "Death")
    Graphs.advance(automatic, 2.0)
    Graphs.advance(automatic, 0.1)
    check(automatic.clip == "Death", "Generic authored death does not auto-return to Idle")
    host.free(); goblin.free(); automatic.free()
    var args = OS.get_cmdline_user_args()
    for i in range(args.size()-1):
        if args[i] == "--record": check_record(args[i+1], cache)
    print(JSON.stringify({"checks":checks, "elapsed_ms":Time.get_ticks_msec()-start, "failures":failures}))
    quit(0 if failures.is_empty() else 1)
