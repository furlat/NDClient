extends RefCounted
const Catalog = preload("res://source_catalog.gd")
const Characters = preload("res://presentation/characters.gd")

static func load_data(path: String, cache: Dictionary) -> Dictionary:
    return Catalog.read_file(path, cache)

static func rig_id(actor: Dictionary, cache: Dictionary) -> String:
    return "" if actor.is_empty() else Characters.rig_id(actor,cache)

static func clip(actor: Dictionary, name: String, cache: Dictionary) -> Dictionary:
    var rigs = load_data("catalog/rigs.json", cache)
    return rigs.get(rig_id(actor, cache), {}).get("clips", {}).get(name, {})

static func movement_reference_speed(cache: Dictionary) -> float:
    # The exported catalog relies on this field's supplied schema default.
    return float(load_data("schemas/animation.schema.json",cache).properties.movement_reference_speed_feet.default)

static func playback_rate(actor: Dictionary, cache: Dictionary) -> float:
    var rates = load_data("catalog/action_playback_rates.json", cache)
    var value = 1.0
    for condition in actor.get("conditions", []):
        value *= float(rates.get(condition.get("behavior_id"), 1.0))
    return value

static func attack(fact: Dictionary, actor: Dictionary, cache: Dictionary) -> Dictionary:
    var recipes = load_data("catalog/attack_recipes.json", cache)
    var key: Variant = fact.behavior_id
    if not recipes.has(key): return {}
    var recipe: Dictionary = recipes[key].duplicate(true)
    var delivery = "projectile" if fact.weapon_slot in ["RANGED_MAIN", "RANGED_OFF"] else "melee"
    var rig = rig_id(actor, cache)
    var outcomes = {"Hit":"hit","Miss":"miss","Crit":"critical","Crit Miss":"critical_miss"}
    var selected: Dictionary = {}
    for variant in recipe.get("variants", []):
        var matchers: Dictionary = variant.match
        var matches = matchers.get("kind", "attack") == "attack"
        for pair in [["delivery",delivery], ["weaponSlots",fact.weapon_slot], ["outcomes",outcomes.get(fact.attack_outcome)],
            ["sourceItemIds",fact.source_item_id], ["sourceKinds",fact.attack_source_kind], ["rigIds",rig]]:
            var constraint: Variant = matchers.get(pair[0])
            if constraint == null: continue
            if constraint is Array:
                if pair[1] not in constraint: matches = false
            elif pair[1] != constraint: matches = false
        if matchers.get("sourceItemRefs") != null:
            var found = false
            for reference in matchers.sourceItemRefs:
                if reference.content_id == fact.source_item_id: found = true
            if not found: matches = false
        if matchers.get("elemental") != null:
            var elemental = false
            for damage_type in fact.damage_types:
                if damage_type not in ["Bludgeoning","Piercing","Slashing"]: elemental = true
            if matchers.elemental != elemental: matches = false
        var types: Variant = matchers.get("primaryDamageTypes")
        if types != null and (fact.damage_types.is_empty() or fact.damage_types[0] not in types): matches = false
        if matches and (selected.is_empty() or variant.precedence > selected.precedence): selected = variant
    if not selected.is_empty():
        for field in ["actor", "anchors"]:
            if selected.has(field): recipe[field] = selected[field]
        recipe.selected_variant = selected.id
    return recipe

static func body(role: String, actor: Dictionary, fact: Dictionary, cache: Dictionary) -> Dictionary:
    var result = {}
    if role == "movement":
        var context = load_data("catalog/movement_context.json",cache)
        result = {"actor":{"enabled":true,"clip":context.jumpClip if fact.trajectory == "direct_arc" else context.walkClip,
            "playbackSpeed":1.0 if fact.trajectory == "direct_arc" else context.walkPlaybackSpeed,"hiddenSlots":[]}}
    elif role in ["damage","death"]:
        var context = load_data("catalog/"+role+"_context.json",cache)
        result = {"actor":{"enabled":true,"clip":context.bodyClip,"playbackSpeed":context.bodyPlaybackSpeed,"hiddenSlots":[]}}
    elif role == "life":
        var poses: Dictionary = load_data("catalog/life_state_context.json",cache).bodyPoses
        var reverse: bool = fact.new_state == "alive"
        var pose: Dictionary = poses.get(fact.previous_state if reverse else fact.new_state,{})
        var definition: Dictionary = pose.get("removalBody" if reverse else "applicationBody",{})
        if not definition.is_empty():
            result = {"actor":{"enabled":true,"clip":definition.bodyClip,"playbackSpeed":definition.get("playbackSpeed",1.0),"hiddenSlots":[]},"reversed":definition.get("reversed",false)}
    var rig: Dictionary = load_data("catalog/rigs.json",cache).get(rig_id(actor,cache),{})
    var selected = -1
    for row in rig.get("body_contexts",[]):
        if row.role != role: continue
        var qualifier: Dictionary = row.qualifier
        var score = 0
        var matches: bool = qualifier.kind == "default"
        if qualifier.kind == "movement" and role == "movement":
            matches = true
            for field in ["movement_mode","trajectory","connector_presentation_key"]:
                if qualifier.get(field) != null:
                    score += 1
                    if qualifier[field] != fact.get(field): matches = false
        if matches and score > selected:
            selected = score
            result = row.body.duplicate(true)
    return result
