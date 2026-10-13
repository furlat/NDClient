extends RefCounted
# Passive event-time after-values collected inside an owned reducer transaction.
# No authoring, animation timing or scene resources belong at this boundary.
const Audience = preload("res://sdk/audience.gd")

static func empty_delta() -> Dictionary:
    return {"set":{},"actors":{},"tiles":{},"objects":{},"objects_removed":[],"spatial_commit_cursors":{}}

static func snapshot_senses(senses: Variant) -> Variant:
    if senses == null: return null
    # The reducer owns a detached transaction. Sensory folds replace the whole
    # view; spatial facts/observations only replace shell fields or entity-map
    # entries. Preserve those mutable containers, sharing their private leaves.
    var result: Dictionary = senses.duplicate()
    result.entities = senses.entities.duplicate()
    return result

static func actor_inputs(target: Dictionary, node: Dictionary) -> Dictionary:
    var result = {}
    if node.fact != null:
        for field in ["entity_uuid", "source_entity_uuid", "target_entity_uuid", "observer_uuid"]:
            var identity: Variant = node.fact.get(field)
            if identity != null and target.actors.has(identity):
                result[identity] = target.actors[identity].duplicate(true)
    return result

static func capture_delta(target: Dictionary, node: Dictionary, observations: Array, update: Variant) -> Dictionary:
    var delta = empty_delta()
    var actors = {}
    for observation in observations: actors[observation.actor.uuid] = true
    var fact: Variant = node.fact
    if fact != null and not node.canceled:
        for field in ["entity_uuid","source_entity_uuid","target_entity_uuid","observer_uuid"]:
            if fact.get(field) != null: actors[fact[field]] = true
        if fact.kind == "sensory":
            for identity in fact.entity_contacts_changed: actors[identity] = true
            # Audience folds return a new perception snapshot without changing
            # its predecessor. This private event-time record is already owned.
            delta.set.perception = target.perception
        if fact.kind in ["sensory","spatial"]: delta.set.senses = snapshot_senses(target.senses)
        if fact.kind == "turn":
            delta.set.current_actor_uuid = target.current_actor_uuid
            delta.set.round_number = target.round_number
        if fact.kind == "spatial" and fact.entity_uuid != null and target.spatial_commit_cursors.has(fact.entity_uuid):
            delta.spatial_commit_cursors[fact.entity_uuid] = target.spatial_commit_cursors[fact.entity_uuid]
    for identity in actors:
        if target.actors.has(identity): delta.actors[identity] = target.actors[identity].duplicate(true)
    for observation in observations:
        if observation.contact != null:
            delta.set.senses = snapshot_senses(target.senses)
    if update != null:
        for tile in update.tiles: delta.tiles[Audience.point_key(tile.position)] = target.tiles[Audience.point_key(tile.position)]
        for object in update.objects: delta.objects[object.item.item_uuid] = target.objects[object.item.item_uuid]
        delta.objects_removed = update.objects_removed.duplicate()
        delta.set.connectors = target.connectors
    return delta
