extends RefCounted
## Native item/container admission, from linked event-time after-values.
## This projects a receiving accent; ordinary world/equipment rendering owns
## the real item. No inventory/world diff, fabricated object or birth UUID.
const Actions=preload("res://presentation/native_action_authoring.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Placement=preload("res://placement.gd")

static func release_descriptor(selection:Dictionary)->Dictionary:
    for cue in selection.get("staging",{}).get("cues",[]):
        var descriptor:Dictionary=cue.get("constructor_input",{})
        if descriptor.get("kind")=="payload_release":return descriptor
    return {}

## A finite hand release needs an accepted real cast and its actual destination.
## It consumes no persistent payload state, private power or lifetime identity.
static func payload_release(owner:Dictionary,descriptor:Dictionary,graph:Dictionary,commits:Array)->Dictionary:
    var fact:Variant=owner.get("fact")
    if owner.get("canceled",false) or owner.get("phase")!="completion" or fact==null \
        or fact.kind!="spell" or fact.get("behavior_id")!=descriptor.behavior_id \
        or fact.get("source_entity_uuid")==null:return {"applies":false,"ready":false,"reason":"accepted_payload_cast_not_observed"}
    var position:Variant=null;var admission:Dictionary={};var admission_node:Dictionary={}
    if descriptor.admission=="declared_aim":
        position=fact.get("aoe_position")
        if position==null:return {"applies":false,"ready":false,"reason":"payload_direct_ground_aim_not_disclosed"}
    else:
        var cuts:Dictionary={}
        for commit in commits:
            if commit.has("event_uuid"):cuts[str(commit.event_uuid)]=commit.delta
        var candidates:Array=[]
        for node in graph.get("nodes",{}).values():
            if node.get("canceled",false) or node.get("phase")!="completion" or node.get("fact")==null \
                or node.fact.kind!="spatial" or node.fact.get("change_type")!="object_placed" \
                or not _direct_creation(node,owner,graph):continue
            for placed in _placed(node,descriptor,cuts.get(str(node.id),{})):
                candidates.append({"node":node,"admission":placed})
        if candidates.size()!=1:return {"applies":true,"ready":false,"reason":"payload_exact_placement_not_disclosed" if candidates.is_empty() else "payload_exact_placement_ambiguous"}
        admission=candidates[0].admission;admission_node=candidates[0].node;position=admission.location.position
    var source:String=str(fact.source_entity_uuid)
    var release:Dictionary={"event_uuid":str(owner.id),"acting_holder_uuid":source,"observed":true,"release_accepted":true}
    var evidence:Dictionary={"cast_occurrence":str(owner.id),"cast_lineage":str(owner.lineage_id),"caster_uuid":source,
        "destination":position,"destination_source":str(descriptor.admission)}
    var result:Dictionary={"applies":true,"ready":true,"reason":"","position":position,"release":release,
        "values":{"kind":str(descriptor.payload_kind),"caster_uuid":source,"acting_holder_uuid":source,
            "cast_or_throw_accepted":true,"release_mode":"supplied_cast_snapshot"},"evidence":evidence}
    if not admission.is_empty():
        result.elevation_feet=float(admission.location.base_height_steps)*5.0
        evidence.merge({"placement_occurrence":str(admission_node.id),"placement_lineage":str(admission_node.lineage_id),
            "item_uuid":admission.item_uuid,"item_id":str(descriptor.item_id),"base_height_steps":admission.location.base_height_steps})
    return result

## Finite optical preparation consumes an actual created spatial owner's
## first public anchor. Neither a footprint centre nor a held/private state
## can substitute for that separately disclosed admission.
static func spatial_destinations(owner:Dictionary,descriptor:Dictionary,graph:Dictionary,commits:Array)->Array:
    if owner.get("canceled",false) or owner.get("phase")!="completion" or owner.get("fact")==null \
        or owner.fact.get("kind")!="spell" or owner.get("resolution_record",{}).get("application_id")!=null:return []
    var nodes:Dictionary={}
    for node in graph.get("nodes",{}).values():nodes[str(node.id)]=node
    var result:Array=[]
    for index in commits.size():
        var created:Dictionary=nodes.get(str(commits[index].get("event_uuid","")),{})
        var fact:Variant=created.get("fact")
        if created.get("canceled",false) or created.get("phase")!="completion" or fact==null \
            or fact.get("kind")!="spatial_effect_state" or fact.get("operation")!="created" \
            or fact.get("spatial_effect_uuid")==null or not _direct_creation(created,owner,graph):continue
        var identity:String=str(fact.spatial_effect_uuid)
        for admission_index in commits.size():
            var commit:Dictionary=commits[admission_index]
            var admitted:Dictionary=nodes.get(str(commit.get("event_uuid","")),{})
            if admitted.is_empty() or admitted.get("canceled",false) or admitted.get("phase")!="completion" \
                or not Actions.descendant(admitted,created,graph):continue
            var senses:Variant=commit.delta.get("set",{}).get("senses")
            if senses==null:continue
            var effect:Dictionary=senses.get("spatial_effects",{}).get(identity,{})
            var content:Variant=effect.get("content_ref")
            if not effect.get("apparent_presence",false) or content==null or content.get("content_id")!=descriptor.content_id:continue
            var position:Variant=effect.get("anchor_position")
            var elevation:Variant=effect.get("anchor_elevation_steps")
            if position==null or elevation==null:continue
            # A sensory descendant may precede its mechanical parent's final
            # receipt. Wait for both original admissions, in source row order.
            var publication:Dictionary=created if index>=admission_index else admitted
            result.append({"node":publication,"target_uuid":"","position":position,"elevation_feet":float(elevation)*5.0,
                "evidence":{"spatial_effect_uuid":identity,"content_id":str(descriptor.content_id),
                    "source_occurrence":str(owner.id),"source_lineage":str(owner.lineage_id),
                    "creation_occurrence":str(created.id),"creation_lineage":str(created.lineage_id),
                    "admission_occurrence":str(admitted.id),"admission_lineage":str(admitted.lineage_id),
                    "publication_occurrence":str(publication.id),"publication_lineage":str(publication.lineage_id),
                    "native_parent_occurrence":str(admitted.get("parent_event","")),
                    "position_source":"canonical_created_spatial_anchor","position":position,
                    "anchor_elevation_steps":elevation}})
            break
    return result

static func _direct_creation(candidate:Dictionary,owner:Dictionary,graph:Dictionary)->bool:
    var parent:Variant=candidate.get("parent_lineage")
    while parent!=null:
        if str(parent)==str(owner.lineage_id):return true
        var ancestor:Dictionary=graph.get("nodes",{}).get(str(parent),{})
        if ancestor.is_empty() or ancestor.get("canceled",false):return false
        var fact:Variant=ancestor.get("fact")
        if fact!=null and fact.kind in ["action","spell","attack"]:return false
        parent=ancestor.get("parent_lineage")
    return false

## Optical release uses the existing authored casting-frame registration.
## points.from is the exact release socket; points.hand may still be a moving
## preparation hand. Neither current inventory nor an item proxy supplies it.
static func release_packet(component:Dictionary,points:Dictionary)->Dictionary:
    var actual:Dictionary=component.get("native_accepted_release",{})
    if actual.get("event_uuid")!=str(component.get("source_event_uuid","")) \
        or actual.get("acting_holder_uuid")!=str(component.get("actor_uuid","")) \
        or not actual.get("observed",false) or not actual.get("release_accepted",false):
        return {"ready":false,"reason":"payload_accepted_release_identity_not_observed"}
    return {"ready":true,"reason":"","packet":actual.merged({"point":points.from})}

## One actual source lineage can disclose a lifetime condition and an ordinary
## created item in separate ordered rows. Join only those original admissions;
## a later equipped/cached item or another seat cannot supply missing ancestry.
## The returned metadata publishes on the later admission, never at cast start.
static func lifetime_bindings(events:Array,graph:Dictionary,commits:Array,cache:Dictionary={})->Dictionary:
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
    var payloads:Dictionary=payload_lifetime_bindings(events,graph,commits)
    for at in payloads:
        if not result.has(at):result[at]={}
        result[at].merge(payloads[at])
    for node in events:
        var pair:Dictionary=quarry_binding(node,graph,{},cache)
        if not pair.get("ready",false):continue
        var at:String=str(pair.condition_occurrence)
        # A reapplication observes its retained root at this Action's cut;
        # it does not fabricate an owner application in the current group.
        var owner_at:String=str(pair.get("owner_observation_occurrence",pair.get("owner_occurrence","")))
        if int(order[owner_at])>int(order[at]):at=owner_at
        pair.evidence.publication_occurrence=at
        if not result.has(at):result[at]={}
        result[at][str(pair.identity.recipient_condition_uuid)]=pair
    for bindings in result.values():bindings.make_read_only()
    return result

## The original cast must disclose both actual memberships. A matching name
## on another actor, or a surviving unrelated sustain, cannot join this child.
static func quarry_descriptor(node:Dictionary,cache:Dictionary)->Dictionary:
    var fact:Variant=node.get("fact")
    if fact==null or fact.get("kind") not in ["spell","action"] or fact.get("behavior_id")==null:return {}
    var selection:Dictionary={}
    if fact.kind=="spell":selection=Actions.Phases.selection_for(fact,cache)
    else:
        var binding:Dictionary=Authoring.load_data("catalog/body_action_bindings.json",cache).get(str(fact.behavior_id),{})
        selection={"staging":{"cues":binding.get("effect_cues",[])}}
    var selected:Dictionary={}
    for cue in selection.get("staging",{}).get("cues",[]):
        var descriptor:Dictionary=cue.get("constructor_input",{})
        if descriptor.get("projection")!="quarry_application" or descriptor.get("behavior_id")!=fact.behavior_id:continue
        if selected.is_empty():selected=descriptor
        else:
            for field in ["behavior_id","quarry_kind","owner_condition_id","recipient_condition_id","owner_admission"]:
                if selected.get(field)!=descriptor.get(field):return {}
    return selected

static func quarry_binding(node:Dictionary,graph:Dictionary,descriptor:Dictionary={},cache:Dictionary={})->Dictionary:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or node.get("phase")!="completion" or fact==null or fact.get("kind") not in ["spell","action"] \
        or fact.get("source_entity_uuid")==null or fact.get("target_entity_uuid")==null:return {"ready":false}
    if descriptor.is_empty():descriptor=quarry_descriptor(node,cache)
    if descriptor.is_empty() or fact.get("behavior_id")!=descriptor.get("behavior_id"):return {"ready":false}
    var source:String=str(fact.source_entity_uuid);var target:String=str(fact.target_entity_uuid)
    var owner_id:String=str(descriptor.owner_condition_id);var recipient_id:String=str(descriptor.recipient_condition_id)
    var rows:Array=graph.get("observed_results",{}).get(str(node.id),[]).filter(func(row):return row.kind=="condition_application" and _direct_creation(row.node,node,graph))
    var owners:Array=rows.filter(func(row):return row.target_uuid==source and row.condition.get("behavior_id")==owner_id)
    var children:Array=rows.filter(func(row):return row.target_uuid==target and row.condition.get("behavior_id")==recipient_id)
    if fact.kind=="action":
        if descriptor.get("owner_admission")!="retained" or children.size()!=1 or not owners.is_empty():
            return {"ready":false,"reason":"quarry_reapplication_actual_child_not_disclosed"}
        var actor:Dictionary=graph.get("actor_inputs",{}).get(str(node.id),{}).get(source,{})
        var retained:Array=actor.get("conditions",[]).filter(func(member):return member.get("behavior_id")==owner_id)
        if actor.get("uuid")!=source or retained.size()!=1:
            return {"ready":false,"reason":"quarry_reapplication_retained_owner_ambiguous"}
        var member:Dictionary=retained[0]
        if member.get("condition_uuid")==null:return {"ready":false,"reason":"quarry_reapplication_retained_owner_not_disclosed"}
        return {"ready":true,"reason":"","quarry_kind":str(descriptor.quarry_kind),"owner_id":owner_id,"recipient_id":recipient_id,
            "identity":{"caster_uuid":source,"recipient_uuid":target,"sustain_condition_uuid":str(member.condition_uuid),
                "recipient_condition_uuid":str(children[0].condition.condition_uuid)},
            "retained_owner_member":member,"owner_observation_occurrence":str(node.id),"condition_occurrence":str(children[0].node.id),
            "evidence":{"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),
                "owner_observation_occurrence":str(node.id),"owner_cut":"source_actor_before_row",
                "owner_application_cursor":member.get("state",{}).get("applied_source_event_cursor") if member.get("state") is Dictionary else null,
                "condition_occurrence":str(children[0].node.id),"admission":"actual_reapplication_retained_owner_and_new_member"}}
    if descriptor.get("owner_admission","created")!="created":return {"ready":false}
    if owners.size()!=1 or children.size()!=1:return {"ready":false,"reason":"quarry_exact_sustain_and_recipient_pair_not_disclosed"}
    return {"ready":true,"reason":"","quarry_kind":str(descriptor.quarry_kind),"owner_id":owner_id,"recipient_id":recipient_id,
        "identity":{"caster_uuid":source,"recipient_uuid":target,"sustain_condition_uuid":str(owners[0].condition.condition_uuid),
            "recipient_condition_uuid":str(children[0].condition.condition_uuid)},
        "owner_occurrence":str(owners[0].node.id),"condition_occurrence":str(children[0].node.id),
        "evidence":{"source_occurrence":str(node.id),"source_lineage":str(node.lineage_id),
            "owner_occurrence":str(owners[0].node.id),"condition_occurrence":str(children[0].node.id),"admission":"same_cast_actual_sustain_and_recipient_members"}}

static func quarry_state(binding:Dictionary,state:Dictionary)->Dictionary:
    if not binding.get("ready",false) or not binding.has("quarry_kind"):return {"ready":false,"reason":"quarry_original_membership_pair_not_observed"}
    var id:Dictionary=binding.identity
    var caster:Dictionary=state.get("actors",{}).get(str(id.caster_uuid),{})
    var recipient:Dictionary=state.get("actors",{}).get(str(id.recipient_uuid),{})
    var owners:Array=caster.get("conditions",[]).filter(func(member):return str(member.condition_uuid)==str(id.sustain_condition_uuid) and member.behavior_id==binding.owner_id)
    var children:Array=recipient.get("conditions",[]).filter(func(member):return str(member.condition_uuid)==str(id.recipient_condition_uuid) and member.behavior_id==binding.recipient_id)
    var owner_state:Dictionary=owners[0].state if owners.size()==1 and owners[0].get("state")!=null else {}
    var child_state:Dictionary=children[0].state if children.size()==1 and children[0].get("state")!=null else {}
    var owner_suppressed:bool=not owner_state.get("suppression_provider_uuids",[]).is_empty()
    var child_suppressed:bool=not child_state.get("suppression_provider_uuids",[]).is_empty()
    var owner:Dictionary={"condition_uuid":str(id.sustain_condition_uuid),"condition_id":binding.owner_id,
        "source_actor_uuid":str(id.caster_uuid),"recipient_uuid":str(id.caster_uuid),"present":owners.size()==1,
        "observed":owners.size()==1,"contribution_active":owners.size()==1 and not owner_suppressed,"suppressed":owner_suppressed}
    var child:Dictionary={"condition_uuid":str(id.recipient_condition_uuid),"condition_id":binding.recipient_id,
        "source_actor_uuid":str(id.caster_uuid),"recipient_uuid":str(id.recipient_uuid),"present":children.size()==1,
        "observed":children.size()==1,"contribution_active":children.size()==1 and not child_suppressed,"suppressed":child_suppressed}
    return {"ready":true,"owner":owner,"quarry":{"sustain_uuid":str(id.sustain_condition_uuid),
        "source_actor_uuid":str(id.caster_uuid),"recipient_uuid":str(id.recipient_uuid),"observed":owners.size()==1 and children.size()==1,"condition":child}}

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


## Payload lifetime and item are independently disclosed descendants of one
## accepted cast. Neither the condition name nor an old cached item joins them.
static func payload_lifetime_bindings(events:Array,graph:Dictionary,commits:Array)->Dictionary:
    var result:Dictionary={};var cuts:Dictionary={};var order:Dictionary={}
    for index in events.size():order[str(events[index].id)]=index
    for commit in commits:
        if commit.has("event_uuid"):cuts[str(commit.event_uuid)]=commit.delta
    for node in events:
        for cue in graph.get("condition_cues",{}).get(str(node.id),[]):
            if cue.phase!="application":continue
            var source:Dictionary={};var selected:Dictionary={}
            for effect in cue.get("recipe",{}).get("persistent",{}).get("nativeEffects",[]):
                var descriptor:Dictionary=effect.get("constructor_input",{})
                if descriptor.get("kind")!="retained_payload" or descriptor.get("lifetime_condition_id")!=cue.condition.get("behavior_id"):continue
                var candidate:Dictionary=_lifetime_source(node,str(descriptor.source_behavior_id),graph)
                if candidate.is_empty():continue
                if not source.is_empty():source={};selected={};break
                source=candidate;selected=descriptor
            if source.is_empty() or str(source.fact.source_entity_uuid)!=str(cue.actor_uuid):continue
            var kind:String=str(selected.payload_kind);var item_id:String=str(selected.item_id)
            var admissions:Array=[]
            for event in events:
                if event.get("canceled",false) or event.get("phase")!="completion" or event.get("fact")==null or not _direct_creation(event,source,graph):continue
                var candidates:Array=[]
                if event.fact.get("kind")=="spatial" and event.fact.get("change_type")=="object_placed":candidates=_placed(event,selected,cuts.get(str(event.id),{}))
                elif event.fact.get("kind")=="actor_change":candidates=_inventory(event,selected,graph,cuts.get(str(event.id),{}))
                for admission in candidates:admissions.append({"node":event,"admission":admission})
            var at:String=str(node.id)
            var binding:Dictionary={"ready":false,"reason":"payload_exact_created_item_not_disclosed" if admissions.is_empty() else "payload_created_item_ambiguous"}
            var lifetimes:Array=[]
            for peer in events:
                for member in graph.get("condition_cues",{}).get(str(peer.id),[]):
                    if member.phase!="application" or member.condition.get("behavior_id")!=selected.lifetime_condition_id or str(member.actor_uuid)!=str(cue.actor_uuid):continue
                    var peer_source:Dictionary=_lifetime_source(peer,str(source.fact.behavior_id),graph)
                    if not peer_source.is_empty() and str(peer_source.id)==str(source.id):lifetimes.append(str(member.condition.condition_uuid))
            if lifetimes.size()!=1:binding={"ready":false,"reason":"payload_lifetime_ambiguous_for_created_item"}
            elif admissions.size()==1:
                var actual:Dictionary=admissions[0]
                if int(order[str(actual.node.id)])>int(order[str(node.id)]):at=str(actual.node.id)
                binding={"ready":true,"reason":"","payload_kind":kind,"item_id":item_id,
                    "identity":{"created_item_uuid":str(actual.admission.item_uuid),"lifetime_condition_uuid":str(cue.condition.condition_uuid),"caster_uuid":str(source.fact.source_entity_uuid)},
                    "location":actual.admission.location,"evidence":{"source_occurrence":str(source.id),"source_lineage":str(source.lineage_id),
                        "condition_occurrence":str(node.id),"condition_lineage":str(node.lineage_id),"item_occurrence":str(actual.node.id),
                        "item_lineage":str(actual.node.lineage_id),"publication_occurrence":at,"admission":actual.admission.location.kind}}
            if not result.has(at):result[at]={}
            result[at][str(cue.condition.condition_uuid)]=binding
    return result

## This current location is optical presentation data. Inventory membership
## alone cannot assert an exposed hand, container opening or world position.
static func payload_location(component:Dictionary,state:Dictionary)->Dictionary:
    var binding:Dictionary=component.get("creation_binding",{})
    if not binding.get("ready",false) or not binding.has("payload_kind"):return {"ready":false,"reason":binding.get("reason","payload_identity_not_observed")}
    var identity:Dictionary=binding.identity
    if str(component.get("condition_uuid",""))!=str(identity.lifetime_condition_uuid):return {"ready":false,"reason":"payload_lifetime_identity_mismatch"}
    var actor:Dictionary=state.get("actors",{}).get(str(identity.caster_uuid),{})
    var members:Array=actor.get("conditions",[]).filter(func(member):return str(member.condition_uuid)==str(identity.lifetime_condition_uuid))
    if members.size()!=1:return {"ready":false,"reason":"payload_lifetime_not_currently_disclosed"}
    var item:String=str(identity.created_item_uuid)
    var object:Dictionary=state.get("objects",{}).get(item,{})
    var sight:Dictionary=state.get("senses",{}).get("objects",{}).get(item,{}) if state.get("senses")!=null else {}
    if object.is_empty() or not sight.get("visual",false):return {"ready":false,"reason":"payload_current_exposed_anchor_not_disclosed"}
    if object.get("item",{}).get("item_id")!=binding.item_id:return {"ready":false,"reason":"payload_current_item_kind_mismatch"}
    var placement:Dictionary=object.placement
    if placement.get("position")==null or not placement.has("base_height_steps"):return {"ready":false,"reason":"payload_current_ground_support_not_disclosed"}
    var member_state:Dictionary=members[0].state if members[0].get("state")!=null else {}
    var suppressed:bool=not object.item.get("construction_suppressions",[]).is_empty() or not member_state.get("suppression_provider_uuids",[]).is_empty()
    var packet:Dictionary={"item_uuid":item,"lifetime_uuid":str(identity.lifetime_condition_uuid),"original_caster_uuid":str(identity.caster_uuid),
        "kind":str(binding.payload_kind),"item_id":str(binding.item_id),"present":true,"observed":true,
        "contributions_active":not suppressed,"suppressed":suppressed,"retired":false,"lifetime_present":true,
        "location_kind":"floor","location_owner_uuid":item}
    # Optional source power stays absent unless the actual member discloses it.
    if member_state.has("dice_count") and member_state.dice_count!=null:packet.dice_count=member_state.dice_count
    return {"ready":true,"reason":"","state":packet,"anchor":{"item_uuid":item,"location_owner_uuid":item,"location_kind":"floor","observed":true},
        "point":Placement.contact({"position":placement.position,"base_height_steps":placement.base_height_steps}),
        "position":placement.position,"base_height_steps":placement.base_height_steps,"evidence":binding.evidence}
