extends RefCounted
## Native item/container admission, from linked event-time after-values.
## This projects a receiving accent; ordinary world/equipment rendering owns
## the real item. No inventory/world diff, fabricated object or birth UUID.
const Actions=preload("res://presentation/native_action_authoring.gd")
const Placement=preload("res://placement.gd")

static func observed(owner:Dictionary,descriptor:Dictionary,graph:Dictionary,events:Array,commits:Array)->Array:
    var cuts:Dictionary={}
    for commit in commits:
        if commit.has("event_uuid"):cuts[str(commit.event_uuid)]=commit.delta
    var result:Array=[]
    for node in events:
        if node.get("canceled",false) or node.get("fact")==null or not Actions.descendant(node,owner,graph):continue
        var cut:Dictionary=cuts.get(str(node.id),{})
        if cut.is_empty():continue
        var rows:Array=[]
        if descriptor.admission=="inventory" and node.fact.kind=="actor_change":
            rows=_inventory(node,descriptor,graph,cut)
        elif descriptor.admission=="placed_object" and node.fact.kind=="spatial" and node.fact.change_type=="object_placed":
            rows=_placed(node,descriptor,cut)
        for admission in rows:
            var source:String=str(owner.fact.source_entity_uuid)
            # These self-ability studies use the invoking character's receiving
            # frame. The created item/container is never an actor or surface.
            var recipient:String=source
            var roles={"caster":source,"target":recipient}
            var values={"source_entity_uuid":source,"recipient_entity_uuid":recipient,
                "owner_uuid":str(owner.id),"event_uuid":str(node.id),"actor_roles":roles,
                "geometry_actor":roles[str(descriptor.geometry_actor)],"lease":{},"event":{},"plan_only":false,
                "native_behavior_id":str(owner.fact.behavior_id)}
            var event={"uuid":str(node.id),"source_entity_uuid":source,"target_entity_uuid":recipient,
                "canceled":false,"effect_admitted":true,"ordinary_item_admitted":true,"item_uuid":admission.item_uuid}
            var location:Dictionary=admission.location
            if location.kind=="placed_object":
                event.creation_position_cells=[location.position[0],float(location.base_height_steps)*Placement.HEIGHT_UNIT,location.position[1]]
            var evidence={"source_occurrence":str(owner.id),"source_lineage":str(owner.lineage_id),
                "result_occurrence":str(node.id),"result_lineage":str(node.lineage_id),
                "native_parent_occurrence":str(node.parent_event),"item_uuid":admission.item_uuid,
                "item_id":str(descriptor.item_id),"admission":str(descriptor.admission),
                "holder_uuid":location.get("holder_uuid"),
                "position_source":"canonical_object_placement" if location.kind=="placed_object" else "renderer_socket:"+str(descriptor.presentation_position_socket)}
            if location.kind=="inventory":location=location.merged({"presentation_position_socket":descriptor.presentation_position_socket})
            result.append({"node":node,"target_uuid":recipient,"values":values,"event":event,
                "evidence":evidence,"location":location})
    return result

static func _inventory(node:Dictionary,descriptor:Dictionary,graph:Dictionary,cut:Dictionary)->Array:
    var result:Array=[]
    var records:Dictionary={}
    for item in node.fact.get("items",[]):records[str(item.item_uuid)]=item
    for change in node.fact.get("actors",[]):
        var actor:String=str(change.actor_uuid)
        var before:Dictionary=graph.get("actor_inputs",{}).get(str(node.id),{}).get(actor,{})
        var after:Dictionary=cut.get("actors",{}).get(actor,{})
        # Inventory facts are controlled-seat data. A visible weapon layer or
        # an old cached ItemRecord cannot manufacture a holdings transition.
        if before.get("controlled_items")==null or after.get("controlled_items")==null:continue
        for row in change.rows:
            if row.get("field")!="inventory" or not row.held:continue
            var identity:String=str(row.item_uuid)
            if identity in before.controlled_items or identity not in after.controlled_items or not records.has(identity):continue
            var item:Dictionary=cut.get("items",{}).get(identity,{})
            if item.get("look",{}).get("item_id")!=descriptor.item_id:continue
            result.append({"item_uuid":identity,"location":{"kind":"inventory","holder_uuid":actor,"item_uuid":identity}})
    return result

static func _placed(node:Dictionary,descriptor:Dictionary,cut:Dictionary)->Array:
    var identity:Variant=node.fact.get("object_uuid")
    if identity==null:return []
    var object:Dictionary=cut.get("objects",{}).get(str(identity),{})
    if object.is_empty() or object.item.get("item_id")!=descriptor.item_id:return []
    var placement:Dictionary=object.placement
    if placement.position!=node.fact.position:return []
    return [{"item_uuid":str(identity),"location":{"kind":"placed_object","item_uuid":str(identity),
        "position":placement.position,"base_height_steps":placement.base_height_steps}}]

## The inventory packet has no asserted world item position. Its explicit
## authored socket is resolved by the renderer's actual endpoint packet.
static func event_packet(component:Dictionary,state:Dictionary,endpoints:Array)->Dictionary:
    var location:Dictionary=component.native_creation
    var event:Dictionary=component.native_inputs.event_input
    if location.kind=="placed_object":return {"ready":true,"event":event,"reason":""}
    var holder:String=str(location.holder_uuid)
    var actor:Dictionary=state.get("actors",{}).get(holder,{})
    if actor.get("controlled_items")==null:return {"ready":false,"reason":"creation_holder_inventory_not_disclosed"}
    if location.item_uuid not in actor.controlled_items:return {"ready":false,"reason":"creation_item_no_longer_held"}
    var socket:String=str(location.presentation_position_socket)
    for endpoint in endpoints:
        if endpoint.get("actor_uuid")!=holder or endpoint.get("socket")!=socket:continue
        var point:Vector3=endpoint.point
        return {"ready":true,"event":event.merged({"creation_position_cells":[point.x,point.y,point.z]}),"reason":""}
    return {"ready":false,"reason":"creation_holder_socket_not_bound"}
