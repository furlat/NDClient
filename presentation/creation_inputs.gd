extends RefCounted
## Native item/container admission, from linked event-time after-values.
## This projects a receiving accent; ordinary world/equipment rendering owns
## the real item. No inventory/world diff, fabricated object or birth UUID.
const Actions=preload("res://presentation/native_action_authoring.gd")
const Placement=preload("res://placement.gd")

## One actual source lineage can disclose a lifetime condition and an ordinary
## created item in separate ordered rows. Join only those original admissions;
## a later equipped/cached item or another seat cannot supply missing ancestry.
## The returned metadata publishes on the later admission, never at cast start.
static func lifetime_bindings(events:Array,graph:Dictionary,commits:Array)->Dictionary:
    var result:Dictionary={}
    var cuts:Dictionary={};var order:Dictionary={};var candidates:Array=[]
    for index in events.size():order[str(events[index].id)]=index
    for commit in commits:
        if commit.has("event_uuid"):cuts[str(commit.event_uuid)]=commit.delta
    for node in events:
        if node.get("canceled",false) or node.get("phase")!="completion":continue
        for cue in graph.get("condition_cues",{}).get(node.id,[]):
            if cue.phase!="application":continue
            var descriptor:Dictionary=cue.get("recipe",{}).get("persistent",{}).get("creationIdentity",{})
            if descriptor.is_empty():continue
            var source:Dictionary=_lifetime_source(node,str(descriptor.source_behavior_id),graph)
            var candidate:Dictionary={"node":node,"cue":cue,"descriptor":descriptor,"source":source}
            candidates.append(candidate)
    for candidate in candidates:
        var node:Dictionary=candidate.node;var cue:Dictionary=candidate.cue
        var condition:String=str(cue.condition.condition_uuid)
        var binding:Dictionary={"ready":false,"reason":"creation_source_ancestry_not_disclosed",
            "evidence":{"condition_uuid":condition,"condition_occurrence":str(node.id),"condition_lineage":str(node.lineage_id)}}
        var at:String=str(node.id)
        if not candidate.source.is_empty():
            var source:Dictionary=candidate.source
            var caster:String=str(source.fact.source_entity_uuid)
            var peers:Array=candidates.filter(func(other):return not other.source.is_empty() and other.source.id==source.id \
                and other.cue.actor_uuid==cue.actor_uuid and other.descriptor.item_id==candidate.descriptor.item_id)
            var admissions:Array=[]
            if caster==str(cue.actor_uuid) and peers.size()==1:
                for event in events:
                    if event.get("canceled",false) or event.get("phase")!="completion" or event.get("fact")==null \
                        or event.fact.kind!="actor_change" or not Actions.descendant(event,source,graph):continue
                    for admission in _inventory(event,candidate.descriptor,graph,cuts.get(str(event.id),{})):
                        if admission.location.holder_uuid!=caster:continue
                        var later:String=str(event.id) if int(order[str(event.id)])>int(order[str(node.id)]) else str(node.id)
                        var actual:Dictionary=cuts.get(later,{}).get("actors",{}).get(caster,{})
                        if not actual.get("conditions",[]).any(func(member):return str(member.condition_uuid)==condition):continue
                        if admission.item_uuid not in actual.get("controlled_items",[]):continue
                        admissions.append({"node":event,"admission":admission})
            binding.reason="creation_condition_recipient_mismatch" if caster!=str(cue.actor_uuid) else "creation_lifetime_ambiguous" if peers.size()!=1 else "creation_item_ancestry_not_disclosed" if admissions.is_empty() else "creation_item_admission_ambiguous"
            if admissions.size()==1:
                var actual:Dictionary=admissions[0]
                if int(order[str(actual.node.id)])>int(order[str(node.id)]):at=str(actual.node.id)
                binding={"ready":true,"reason":"","identity":{"created_item_uuid":actual.admission.item_uuid,
                    "lifetime_condition_uuid":condition,"caster_uuid":caster},"item_id":str(candidate.descriptor.item_id),
                    "evidence":{"condition_uuid":condition,"condition_occurrence":str(node.id),"condition_lineage":str(node.lineage_id),
                        "source_occurrence":str(source.id),"source_lineage":str(source.lineage_id),
                        "item_occurrence":str(actual.node.id),"item_lineage":str(actual.node.lineage_id),
                        "item_native_parent":str(actual.node.parent_event),"admission":"inventory"}}
        if not result.has(at):result[at]={}
        if binding.has("identity"):binding.identity.make_read_only()
        binding.evidence.make_read_only()
        binding.make_read_only();result[at][condition]=binding
    for bindings in result.values():bindings.make_read_only()
    return result

static func _lifetime_source(node:Dictionary,behavior:String,graph:Dictionary)->Dictionary:
    var parent:Variant=node.get("parent_lineage")
    while parent!=null:
        var source:Dictionary=graph.get("nodes",{}).get(str(parent),{})
        if source.is_empty():return {}
        var fact:Dictionary=source.get("fact",{}) if source.get("fact")!=null else {}
        if fact.get("kind") in ["spell","action"] and fact.get("behavior_id")==behavior:
            return source if not source.get("canceled",false) and source.get("phase")=="completion" and fact.get("source_entity_uuid")!=null else {}
        parent=source.get("parent_lineage")
    return {}

## Current optical admission is independent of the retained original identity.
## The equipped item proves current holdings; no private inventory inference,
## contribution flag, native weapon body or replacement item is introduced.
static func lifetime_packet(component:Dictionary,state:Dictionary,weapon:Dictionary)->Dictionary:
    var bound:Dictionary=component.get("creation_binding",{})
    if not bound.get("ready",false):return {"ready":false,"reason":bound.get("reason","creation_lifetime_not_observed")}
    var identity:Dictionary=bound.identity
    if str(component.get("condition_uuid",""))!=str(identity.lifetime_condition_uuid):return {"ready":false,"reason":"creation_lifetime_owner_mismatch"}
    var actor:Dictionary=state.get("actors",{}).get(str(identity.caster_uuid),{})
    if not actor.get("conditions",[]).any(func(member):return str(member.condition_uuid)==str(identity.lifetime_condition_uuid)):
        return {"ready":false,"reason":"creation_lifetime_no_longer_present"}
    if not weapon.get("ready",false):return {"ready":false,"reason":weapon.get("reason","creation_weapon_not_displayed")}
    var receiving:Dictionary=weapon.get("binding",{})
    if receiving.get("item_uuid")!=identity.created_item_uuid or receiving.get("holder_uuid")!=identity.caster_uuid \
        or receiving.get("item_id")!=bound.item_id:return {"ready":false,"reason":"creation_current_item_mismatch"}
    return {"ready":true,"reason":"","identity":identity,"weapon":{"lifetime_condition_uuid":identity.lifetime_condition_uuid,
        "caster_uuid":identity.caster_uuid,"lifetime_present":true,"item_in_caster_holdings":true},"evidence":bound.evidence}

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
