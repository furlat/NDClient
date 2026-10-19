extends SceneTree
## The built characters source (build/presentation/characters) as the game
## reads it: every server creature id has an entry and a body, gear resolves by
## server item id and the visual variant the server sends, icons and portraits
## resolve from the built maps, measured palette ranges are admitted, and no
## runtime path leaves the project.
##   --headless --script res://tests/characters_source_checks.gd
const BodySources = preload("res://presentation/body_sources.gd")
const Characters = preload("res://presentation/characters.gd")
const Palette = preload("res://presentation/palette.gd")
const UI = preload("res://presentation/ui_catalog.gd")
const Common = preload("res://tools/presentation_build/common.gd")
## Visual loadout rows recorded from the server (item id, visual name, variant, slot).
const RECORDED := [["apparel.cloth_shoes", null, "boots"], ["apparel.cloth_shoes.red", "b0000004", "boots"], ["apparel.costume.pit_fighter_wrap", "85000004", "body_armor"],
    ["apparel.iron_helmet.steel", "h0000008", "helmet"], ["apparel.leather_boots.brown", "b0000009", "boots"], ["apparel.robes.hedge_wizard", "8100000b", "body_armor"],
    ["apparel.roster.bracers_g0000003", "g0000003", "gauntlets"], ["apparel.roster.common_clothes_21ae119f8607", "roster.21ae119f8607", "body_armor"],
    ["armor.chain_mail", null, "body_armor"], ["armor.roster.armor_scraps_d6b6c79a6d59", "roster.d6b6c79a6d59", "body_armor"], ["gear.roster.quiver_6c39094102d0", "roster.6c39094102d0", "backpack"],
    ["shield.shield", null, "weapon_melee_off"], ["weapon.dagger", null, "weapon_melee_main"], ["weapon.handaxe", null, "weapon_melee_off"], ["weapon.longbow", null, "weapon_ranged_main"],
    ["weapon.roster.shortbow_a0000007", "a0000007", "weapon_ranged_main"], ["weapon.shortbow", null, "weapon_ranged_main"]]
var checks := 0
var failures: Array = []

func _initialize() -> void:
    run.call_deferred()

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label);printerr("CHARACTERS_SOURCE_FAIL ", label)

func run() -> void:
    var cache := {}
    var index: Resource = BodySources.index(cache)
    check(index != null, "The built body-source index loads from build/presentation/characters")
    if index == null:return finish()
    check(index.rigs.has(index.root_rig) and index.rigs[index.root_rig].has("slot_order"), "The player body's layered rig is built")
    var source: Resource = load("res://authoring/characters.tres")
    var ids: Dictionary = Common.server_ids().ids
    for id in ids.creature:check(source.sections.characters.has(id), "Every server creature id has a character entry: " + id)
    for id in ids.item:check(source.sections.gear.has(id), "Every server item id has a gear entry: " + id)
    var unbound := []
    for id in ids.creature:
        var entry: Resource = load(source.sections.characters[id]) if source.sections.characters.has(id) else null
        if entry == null or entry.status == "internal":continue
        var actor := {"creature_content_ref": "content.neurodragon:creature:" + id + "@1"}
        if Characters.rig_id(actor, cache).is_empty():unbound.append(id)
    check(unbound.is_empty(), "Every drawn server creature resolves to a built rig: " + str(unbound))
    for row in RECORDED:
        var item := {"item_id": row[0], "visual_variant_id": row[1]}
        var selected: Dictionary = BodySources.equipment(item, row[2], cache)
        check(selected.ok and not selected.value.is_empty(), "Recorded gear resolves by item id and variant: " + str(row))
    for rig_id in index.rigs:
        var rig: Dictionary = index.rigs[rig_id]
        for clip in rig.clips:
            check(int(rig.clips[clip].frames) > 0 and float(rig.clips[clip].fps) > 0.0, "Built clip has frames and a clock: " + rig_id + "/" + clip)
    var outside := []
    for path in index.source_owners:
        if not (str(path).begins_with("res://") or str(path).begins_with("/media/vfx/")):outside.append(path)
        elif str(path).begins_with("res://") and not FileAccess.file_exists(path):outside.append("missing " + str(path))
    check(outside.is_empty(), "Every body source is a project file: " + str(outside.slice(0, 5)))
    var rig: Dictionary = index.rigs[index.root_rig]
    var layer := {"category": "Magic2", "palette": {"colors": [16711680]}, "sourceSheet": "/spritesheets/Magic2/Attack1.png"}
    var prepared: Dictionary = Palette.prepare(layer, rig, "Attack1", cache)
    var measured: Dictionary = index.palette_ranges.get("res://assets/art/media/smallscale/modular/Magic2/Attack1.png", {}).get("128", {})
    check(not measured.is_empty() and is_same(prepared.get("palette_ranges"), measured), "Palette ranges come from the measured data")
    var maps: Dictionary = UI.icon_maps()
    check(maps.icons.has("weapon.longsword") and FileAccess.file_exists(maps.icons["weapon.longsword"].path), "Item icons are bound by server item id")
    check(maps.icons.has("common.end_turn"), "Common HUD icons are built")
    check(maps.creature_portraits.get("creature.goblin", "") == "creature.goblin" and maps.portraits.has("creature.goblin"), "Creature portraits are bound by creature id")
    check(UI.portrait_key({"creature_content_ref": "content.neurodragon:creature:creature.goblin@1"}, {}, {}, cache) == "creature.goblin", "The HUD asks the creature's bound portrait")
    check(UI.item_key({"item_id": "weapon.longsword"}, {}, cache) == "weapon.longsword", "The HUD asks an item icon by its server id")
    finish()

func finish() -> void:
    print("CHARACTERS_SOURCE_CHECKS ", JSON.stringify({"checks": checks, "failures": failures.slice(0, 40)}))
    quit(0 if failures.is_empty() else 1)
