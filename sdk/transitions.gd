extends RefCounted
const ReducerCells=preload("res://sdk/fold_cells.gd")
## Immutable event-time captures emitted by the SDK fold; no authoring or scene resources.
static func empty_delta()->Dictionary:
    return {"set":{},"actors":{},"items":{},"tiles":{},"tiles_removed":[],"objects":{},"objects_removed":[],"spatial_commit_cursors":{}}
static func snapshot_senses(senses:Variant)->Variant:return senses
static func snapshot_actor(actor:Dictionary)->Dictionary:return actor

static func actor_inputs(target:Dictionary,node:Dictionary,_snapshots:Dictionary={},_retained:bool=false)->Dictionary:
    var result={};var fact:Variant=node.get("fact")
    if fact==null:return result
    for field in ["entity_uuid","source_entity_uuid","target_entity_uuid","observer_uuid"]:
        var identity:Variant=fact.get(field)
        if identity!=null and target.actors.has(identity):result[identity]=target.actors[identity]
    if fact.kind=="actor_change":
        for change in fact.get("actors",[]):
            if target.actors.has(change.actor_uuid):result[change.actor_uuid]=target.actors[change.actor_uuid]
    return result

static func item_inputs(target:Dictionary,actors:Dictionary)->Dictionary:
    var result:Dictionary={}
    for actor in actors.values():
        for layer in actor.get("visual_loadout",{}).get("layers",[]):
            if target.items.has(layer.item_uuid):result[layer.item_uuid]=target.items[layer.item_uuid]
    return result

## Actual Life/unique immediate-parent entry cut, never a canonical position.
static func terminal_input(target:Dictionary,node:Dictionary,lineage:int,source_index:int,entry:Dictionary={})->Dictionary:
    var fact:Variant=node.get("fact")
    if fact==null or fact.get("kind")!="life" or fact.get("new_state")!="dead" \
        or node.get("phase")!="completion" or node.get("canceled",false):return {}
    var identity:String=str(fact.entity_uuid)
    var actor:Dictionary=target.actors.get(identity,{})
    var senses:Variant=target.get("senses")
    if actor.is_empty() or senses==null or not actor.get("present",false) \
        or actor.get("life_state")!=fact.previous_state or actor.get("spatial_disposition","present")!="present" \
        or actor.get("remains_disposition","intact")!="intact":return {}
    var position:Variant=actor.get("last_visual_position")
    var contact:Dictionary=senses.entities.get(identity,{})
    if position==null or not contact.get("visual",false) or contact.get("position")!=position \
        or not ReducerCells.contains(senses.visible,position):return {}
    var key:String=ReducerCells.key(position)
    var support:Dictionary=target.tiles.get(key,{})
    if not support.has("elevation_steps"):return {}
    return {"actor":actor,"contact":contact,"support":support,"position":position,
        "generation":target.generation,"observer_uuid":target.observer_uuid,
        "life_event_uuid":str(node.occurrence),"life_lineage":str(lineage),"source_index":source_index,
        "source_lineage":str(entry.get("lineage",lineage)),"source_event_uuid":str(entry.get("occurrence",node.occurrence)),
        "new_state":fact.new_state,"source_cut":"first_real_life_version" if entry.is_empty() else "immediate_parent_entry"}

static func capture_delta(target:Dictionary,node:Dictionary,bodies:Array,update:Variant,_snapshots:Dictionary={},_retained:bool=false,disclosed:Dictionary={},changed_actors:Dictionary={},changed_items:Dictionary={})->Dictionary:
    var delta=empty_delta();var identities=changed_actors.duplicate();var fact:Variant=node.get("fact")
    for record in bodies:identities[record.actor_uuid]=true
    if fact!=null and not node.get("canceled",false):
        for field in ["entity_uuid","source_entity_uuid","target_entity_uuid","observer_uuid"]:
            if fact.get(field)!=null:identities[fact[field]]=true
        if fact.kind=="actor_change":
            for change in fact.get("actors",[]):identities[change.actor_uuid]=true
        if fact.kind in ["sensory","spatial"] or (fact.kind=="audience" and fact.get("sensory")!=null):
            delta.set.senses=target.senses
            for field in ["entity_members","object_contact_members","effect_members","light_sources","remembered_effects","spatial_content"]:delta.set[field]=target[field].duplicate()
        if fact.kind=="audience":
            delta.set.audience=target.audience;delta.set.hud_snapshot=target.hud_snapshot
            for field in ["entity_members","object_contact_members","effect_members","object_members"]:delta.set[field]=target[field].duplicate()
        if fact.kind=="turn":delta.set.current_actor_uuid=target.current_actor_uuid;delta.set.round_number=target.round_number
        if fact.kind=="spatial" and fact.get("entity_uuid")!=null and target.spatial_commit_cursors.has(fact.entity_uuid):delta.spatial_commit_cursors[fact.entity_uuid]=target.spatial_commit_cursors[fact.entity_uuid]
    for identity in identities:
        if target.actors.has(identity):delta.actors[identity]=target.actors[identity]
    for identity in changed_items:delta.items[identity]=target.items[identity]
    if not bodies.is_empty():delta.set.static=target.static.duplicate()
    if update!=null:
        delta.world_order=disclosed.get("order",[])
        delta.tiles=disclosed.get("tiles",{});delta.tiles_removed=disclosed.get("tiles_removed",[]);delta.objects=disclosed.get("objects",{});delta.objects_removed=disclosed.get("objects_removed",[])
        delta.set.connectors=target.connectors.duplicate();delta.set.object_members=target.object_members.duplicate()
        delta.set.static=target.static.duplicate()
    return delta
