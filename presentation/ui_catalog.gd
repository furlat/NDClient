extends RefCounted
# Presentation only: exact native rows, admitted descriptors and authored UI roles.
const Catalog = preload("res://source_catalog.gd")
const Choices = preload("res://sdk/choices.gd")
const Interaction = preload("res://presentation/interaction.gd")
const GROUPS = ["Base", "Class", "Spells", "Items"]
const SLOTS = ["Head", "Amulet", "Cloak", "Body", "Hands", "Legs", "Left Ring", "Right Ring", "Backpack", "Feet", "MELEE_MAIN", "MELEE_OFF", "RANGED_MAIN", "RANGED_OFF"]

static func authored(cache: Dictionary) -> Dictionary:
    if not cache.has("player_ui"):
        var index = Catalog.read_file("ui/index.json", cache)
        cache.player_ui = {"presentation":Catalog.read_file(index.ui_presentation,cache), "resources":Catalog.read_file(index.ui_resources,cache),
            "choices":JSON.parse_string(FileAccess.get_file_as_string(str(ProjectSettings.get_setting("source_data/authoring_root")).path_join(index.ui_choices)))}
    return cache.player_ui

static func descriptor(state: Dictionary, id: String, exact = null) -> Dictionary:
    # Full ContentRef identities always contain their @version suffix. Most HUD
    # requests use the short content_id; do not format every unrelated identity.
    var identity_lookup = "@" in id
    for row in state.get("content", []):
        if exact != null:
            if Interaction.same_content_ref(row.ref,exact): return row
        elif row.ref.content_id == id or (identity_lookup and "%s:%s:%s@%d" % [row.ref.pack_id,row.ref.definition_kind,row.ref.content_id,row.ref.content_version] == id):
            return row
    return {}

static func action_key(row: Dictionary, state: Dictionary, cache: Dictionary, variant: bool = false) -> String:
    # Weapon buttons and carried-item actions retain their admitted item identity.
    var actor: Dictionary = state.get("actors",{}).get(state.get("current_actor_uuid"),{})
    if row.get("source_item_uuid") != null:
        for item in inventory(actor):
            if item.item_uuid == row.source_item_uuid: return item_key(item,state,cache)
        for item in equipped(actor).values():
            if item.item_uuid == row.source_item_uuid: return item_key(item,state,cache)
    if row.get("action_category") == "attack" and row.get("weapon_slot") != null:
        var weapon: Dictionary = equipped(actor).get(row.weapon_slot,{})
        if not weapon.is_empty(): return item_key(weapon,state,cache)
    var configured = row.get("configured_action_ref")
    var entry = descriptor(state,str(row.get("behavior_id","")),configured)
    var owner = entry.get("ref") if configured == null else configured
    if variant and owner != null:
        var facets = {}
        for facet in row.get("variant_facets",[]): facets[facet.key] = facet.value
        for choice in authored(cache).choices:
            if not Interaction.same_content_ref(choice.owner,owner) or not facets.has(choice.facet) or facets[choice.facet] != choice.value: continue
            var matches = true
            for requirement in choice.requirements:
                if facets.get(requirement) != choice.requirements[requirement]: matches = false
            if matches: return str(choice.icon_key)
    if entry.is_empty() and configured == null:
        entry = authored(cache).presentation.direct_features.get(row.get("provided_by_id",row.get("behavior_id","")),{})
    return str(entry.get("presentation",{}).get("icon_key","") if entry.get("presentation",{}).get("icon_key") != null else "")

static func item_key(item: Dictionary, state: Dictionary, cache: Dictionary) -> String:
    var entry = descriptor(state,str(item.get("item_id","")))
    if entry.is_empty(): entry = authored(cache).presentation.direct_items.get(item.get("item_id",""),{})
    var key = entry.get("presentation",{}).get("icon_key")
    return "" if key == null else str(key)

static func common_key(id: String, cache: Dictionary) -> String:
    var key = authored(cache).presentation.common.get(id,{}).get("presentation",{}).get("icon_key")
    return "" if key == null else str(key)

static func portrait_key(actor: Dictionary, sheet: Dictionary, state: Dictionary) -> String:
    var key = actor.get("appearance",{}).get("portrait_key",sheet.get("portrait_key"))
    if key == null and actor.get("creature_content_ref") != null:
        # PlayerActor carries ContentRef.identity_key, unlike configured actions'
        # full ContentRef. Resolve that key through the admitted descriptors.
        key = descriptor(state,actor.creature_content_ref).get("presentation",{}).get("portrait_key")
    return "" if key == null else str(key)

static func texture(key: String, cache: Dictionary, portrait: bool = false) -> Texture2D:
    if key.is_empty(): return null
    var resource_key = ("portrait:" if portrait else "icon:") + key
    var texture_key = "ui_texture:" + resource_key
    if not cache.has(texture_key):
        var resource = authored(cache).resources.get(resource_key,{})
        if resource.is_empty():
            push_warning("Missing authored UI resource: " + resource_key)
            cache[texture_key] = null
        else:
            if not cache.has("ui_media"):
                cache.ui_media = {"sources":{},"pending":[],"task":-1,"result":{},"failed":[],"completed":0}
            var media: Dictionary = cache.ui_media
            if not media.sources.has(resource.path):
                # Stable native resource: existing controls refresh when its
                # original pixels arrive; no button rebuilding or input hold.
                var blank = Image.create(1,1,false,Image.FORMAT_RGBA8)
                media.sources[resource.path] = ImageTexture.create_from_image(blank)
                media.pending.append(resource.path)
            var source: ImageTexture = media.sources[resource.path]
            if resource.has("rect"):
                var atlas = AtlasTexture.new()
                atlas.atlas = source
                atlas.region = Rect2(resource.rect[0],resource.rect[1],resource.rect[2],resource.rect[3])
                cache[texture_key] = atlas
            else: cache[texture_key] = source
    return cache[texture_key]

static func _decode_icon(path: String, result: Dictionary) -> void:
    result.path = path
    var image = Image.new()
    var error = image.load(Catalog.media_path(path))
    if error != OK or image.is_empty(): result.error = "Could not load authored UI image: "+path
    else: result.image = image

static func poll_images(cache: Dictionary) -> void:
    if not cache.has("ui_media"): return
    var media: Dictionary = cache.ui_media
    if media.task >= 0:
        if not WorkerThreadPool.is_task_completed(media.task): return
        WorkerThreadPool.wait_for_task_completion(media.task)
        if media.result.has("error"):
            media.failed.append(media.result.error)
            push_error(media.result.error)
        else:
            media.sources[media.result.path].set_image(media.result.image)
            media.completed += 1
        media.result = {}
        media.task = -1
    if not media.pending.is_empty():
        var path: String = media.pending.pop_front()
        media.task = WorkerThreadPool.add_task(_decode_icon.bind(path,media.result),false,"Authored HUD image")

static func images_pending(cache: Dictionary) -> bool:
    return cache.has("ui_media") and (cache.ui_media.task >= 0 or not cache.ui_media.pending.is_empty())

static func close_images(cache: Dictionary) -> void:
    if cache.has("ui_media") and cache.ui_media.task >= 0:
        WorkerThreadPool.wait_for_task_completion(cache.ui_media.task)
        cache.ui_media.task = -1

static func rows(discovery: Dictionary) -> Array:
    return Choices.all_actions(discovery)

static func available(row: Dictionary) -> bool:
    return row.get("availability_status","") == "available" and row.get("can_afford",false)

static func family_key(row: Dictionary) -> String:
    return JSON.stringify([row.get("behavior_id"),row.get("configured_action_ref"),row.get("source_item_uuid"),row.get("weapon_slot")])

static func families(discovery: Dictionary, actor: Dictionary) -> Dictionary:
    var groups = {"Base":[],"Class":[],"Spells":[],"Items":[]}
    var indexed = {}
    var owned = {}
    for item in actor.get("controlled_items",[]) if actor.get("controlled_items") != null else []: owned[item.item_uuid] = true
    for row in rows(discovery):
        if row.get("interaction_affordance",{}).get("surface","action_bar") != "action_bar": continue
        if row.get("behavior_id") in ["action.move","action.swim","action.core.drop","action.pick_up"]: continue
        var group = "Base"
        if row.get("source_item_uuid") != null and row.get("action_category") != "attack":
            if not owned.has(row.source_item_uuid): continue
            group = "Items"
        elif row.get("action_category") == "spell": group = "Spells"
        elif str(row.get("provided_by_id","")).begins_with("class_feature.") or str(row.get("provided_by_id","")).begins_with("metamagic.") or str(row.get("provided_by_id","")).begins_with("feat.") or str(row.get("behavior_id","")).begins_with("action.class.") or str(row.get("origin_root_id","")).begins_with("class_feature."): group = "Class"
        var key = family_key(row)
        if not indexed.has(key):
            var family = {"key":key,"rows":[],"label":row.get("display_name","Action"),"group":group}
            indexed[key] = family
            groups[group].append(family)
        indexed[key].rows.append(row)
    var base_order = ["action.attack","action.feature.extra_attack","action.dash","action.dodge","action.disengage","action.jump","action.hide","action.shove"]
    groups.Base.sort_custom(func(a,b):
        var ai = base_order.find(a.rows[0].behavior_id)
        var bi = base_order.find(b.rows[0].behavior_id)
        ai = ai if ai >= 0 else 99
        bi = bi if bi >= 0 else 99
        return int(a.rows[0].get("discovery_index",0)) < int(b.rows[0].get("discovery_index",0)) if ai == bi else ai < bi)
    return groups

static func sheet(state: Dictionary, actor_id: String) -> Dictionary:
    var snapshot = state.get("hud_snapshot")
    if snapshot == null: return {}
    for value in snapshot.get("sheets",[]):
        if value.actor_uuid == actor_id: return value
    return {}

static func compatible_slots(sheet_value: Dictionary, item_uuid: String) -> Array:
    for pair in sheet_value.get("compatible_item_slots",[]):
        if pair[0] == item_uuid: return pair[1]
    return []

static func inventory(actor: Dictionary, query: String = "") -> Array:
    var result: Array = []
    for item in actor.get("controlled_items",[]) if actor.get("controlled_items") != null else []:
        var text = str(item.get("name","")) + " " + str(item.get("description","")) + " " + " ".join(item.get("tags",[]))
        if query.strip_edges().is_empty() or query.to_lower() in text.to_lower(): result.append(item)
    return result

static func equipped(actor: Dictionary) -> Dictionary:
    var result = {}
    for layer in actor.get("visual_loadout",{}).get("layers",[]): result[layer.slot] = layer
    return result

static func item_name(item: Dictionary, state: Dictionary, cache: Dictionary) -> String:
    if item.has("name"): return str(item.name)
    var entry = descriptor(state,str(item.get("item_id","")))
    if not entry.is_empty(): return str(entry.display_name)
    return str(authored(cache).presentation.direct_items.get(item.get("item_id",""),{}).get("label","Undisclosed item"))

static func slot_label(slot: String) -> String:
    return {"MELEE_MAIN":"Melee · main","MELEE_OFF":"Melee · off","RANGED_MAIN":"Ranged · main","RANGED_OFF":"Ranged · off"}.get(slot,slot)

static func cost_text(row: Dictionary) -> String:
    var labels: Array[String] = []
    for cost in row.get("costs",[]):
        var amount = int(cost.get("cost",0))
        if amount > 0: labels.append("%d %s" % [amount,str(cost.get("cost_type","")).replace("_"," ")])
        if cost.get("resource_name") != null and int(cost.get("resource_cost",0)) > 0:
            labels.append("%d %s" % [int(cost.resource_cost),str(cost.resource_name).replace("_"," ")])
    return " · ".join(labels)

static func action_text(row: Dictionary) -> String:
    var parts: Array[String] = [str(row.get("display_name","Action"))]
    if row.get("weapon_slot") != null: parts.append(slot_label(row.weapon_slot) + (" · " + str(row.weapon_name) if row.get("weapon_name") != null else ""))
    if row.get("cast_at_level") != null: parts.append("Level " + str(row.cast_at_level))
    for facet in row.get("variant_facets",[]): parts.append(str(facet.get("label",facet.value)))
    if row.get("restricted_action_budget") != null: parts.append(str(row.restricted_action_budget))
    var cost = cost_text(row)
    if not cost.is_empty(): parts.append(cost)
    if not available(row): parts.append(str(row.get("availability_status","Unavailable")).replace("_"," ").capitalize())
    if not str(row.get("description","")).is_empty(): parts.append(str(row.description))
    return "\n".join(parts)

static func equip_intent(item_uuid: String, slot: String) -> Dictionary:
    return {"kind":"equip","item":{"item_uuid":item_uuid,"slot":slot}}

static func unequip_intent(slot: String) -> Dictionary:
    return {"kind":"unequip","item":{"slot":slot}}
