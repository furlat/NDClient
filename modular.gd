extends RefCounted
const Catalog = preload("res://source_catalog.gd")

static func rgb(value: int) -> Vector3:
    return Vector3((value >> 16) & 255, (value >> 8) & 255, value & 255) / 255.0

static func layers(row: Dictionary, rig: Dictionary, cache: Dictionary) -> Array:
    var appearance: Dictionary = row.get("appearance", {})
    var selected = {
        "shadow": {"category": "Shadow", "tint": 0xFFFFFF, "alpha": 0.5},
        "body": {"category": appearance.get("body", "NakedBody"), "tint": appearance.get("skin", 0xDDAA88), "alpha": 1.0},
        "head": {"category": appearance.get("head", "Head1"), "tint": appearance.get("hair", 0xFFFFFF), "alpha": 1.0}}
    var inventory = Catalog.read_file("items/visuals.json", cache)
    var hand_overrides = Catalog.read_file("items/appearances.json", cache).hands
    for item in row.get("equipment", ["Leather Armor", "Longsword", "Shield"]):
        for category in inventory.categories:
            if category.base_category != item: continue
            var equipment_layers: Array = category.base_presentation.equipment_layers
            for hand in hand_overrides:
                if hand.category == item and hand.variant == null and hand.slot == category.equipment_slot:
                    equipment_layers = hand.layers
                    break
            for layer in equipment_layers:
                selected[layer.render_layer] = {"category": layer.sprite_key, "tint": int(layer.tint_rgb), "alpha": 1.0, "equipment": true}
    if selected.has("helmet") and selected.helmet.category not in ["Head5", "Head8"]:
        selected.erase("head")
    for slot in row.get("effects", {}):
        selected[slot] = {"category": row.effects[slot], "tint": 0xFFFFFF, "alpha": 1.0}
    var result: Array = []
    for slot in rig.slot_order:
        if selected.has(slot):
            selected[slot].slot = slot
            result.append(selected[slot])
    return result
