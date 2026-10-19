extends RefCounted
## Native item appearance ownership from observed creation and current canonical
## membership. Metadata alone never creates an item or supplies its lifetime.
const Bodies=preload("res://presentation/body_sources.gd")
const World=preload("res://presentation/world.gd")
const Effects=preload("res://presentation/effect_package.gd")
const WEAPON_SETS={"MELEE_MAIN":"melee","MELEE_OFF":"melee","RANGED_MAIN":"ranged","RANGED_OFF":"ranged"}

static func definitions(cache:Dictionary)->Dictionary:
    var index:Resource=Bodies.index(cache)
    return {} if index==null else index.native_item_appearances

static func interested(owners:Dictionary,additions:Array,delta:Dictionary,cache:Dictionary)->bool:
    if not owners.is_empty() or not additions.is_empty():return true
    var entries:Dictionary=definitions(cache)
    for item in delta.get("items",{}).values():
        if entries.has(item.get("look",{}).get("item_id","")):return true
    for actor in delta.get("actors",{}).values():
        for layer in actor.get("visual_loadout",{}).get("layers",[]):
            if entries.has(layer.item_id):return true
    for object in delta.get("objects",{}).values():
        if entries.has(object.get("item",{}).get("item_id","")):return true
    return false

static func active(owner:Dictionary,state:Dictionary)->bool:
    var location:Dictionary=membership(owner.item_uuid,state)
    return not location.is_empty() and location.kind not in ["inventory","ambiguous"] and (not owner.reason.is_empty() or lifetime_present(owner,state))

static func _cast(node:Dictionary,accepted:Array,graph:Dictionary)->Dictionary:
    var cursor:Dictionary=node
    while not cursor.is_empty():
        var fact:Variant=cursor.get("fact")
        if fact!=null and fact.get("behavior_id") in accepted and fact.kind in ["spell","action"]:return cursor
        cursor=graph.nodes.get(cursor.get("parent_lineage"),{})
    return {}

static func origins(events:Array,graph:Dictionary,known_items:Dictionary,cache:Dictionary)->Dictionary:
    var result:Dictionary={};var definitions:Dictionary=definitions(cache)
    for node in events:
        if node.canceled or node.fact==null or node.fact.kind!="actor_change":continue
        for item in node.fact.get("items",[]):
            var id:String=str(item.item_uuid)
            if known_items.has(id):continue
            var definition:Dictionary=definitions.get(item.get("look",{}).get("item_id",""),{})
            if definition.is_empty():continue
            var descriptor:Dictionary=definition.constructor_input
            var cast:Dictionary=_cast(node,descriptor.creation_behaviors,graph)
            if cast.is_empty():continue
            var creator:String=str(cast.fact.source_entity_uuid)
            # Only an actual native creation descendant with an exact holdings
            # admission can establish ownership; another faction's private rows
            # or a matching display name are not evidence.
            var admitted:bool=node.fact.get("actors",[]).any(func(actor):return actor.actor_uuid==creator and actor.rows.any(func(row):return row.field=="inventory" and row.item_uuid==id and row.held))
            if not admitted:continue
            var lifetime:String="";var gap:String=""
            var required:String=str(descriptor.get("lifetime_condition",""))
            if not required.is_empty():
                var owners:Array=[]
                for candidate in events:
                    if candidate.canceled or _cast(candidate,descriptor.creation_behaviors,graph).get("id")!=cast.id:continue
                    for cue in graph.condition_cues.get(candidate.id,[]):
                        if cue.phase=="application" and cue.actor_uuid==creator and cue.condition.behavior_id==required:owners.append(cue.condition.condition_uuid)
                if owners.size()==1:lifetime=str(owners[0])
                else:gap="created_item_lifetime_identity_unavailable"
            var origin={"item_uuid":id,"item_id":item.look.item_id,"creator_uuid":creator,"lifetime_condition_uuid":lifetime,
                "source_occurrence":str(cast.id),"source_lineage":str(cast.lineage_id),"creation_occurrence":str(node.id),
                "creation_lineage":str(node.lineage_id),"reason":gap,"definition":definition}
            if not result.has(node.id):result[node.id]=[]
            result[node.id].append(origin)
    return result

static func membership(item:String,state:Dictionary)->Dictionary:
    var inventory:String=""
    var held:Array=[]
    for actor in state.get("actors",{}).values():
        var loadout:Dictionary=actor.get("visual_loadout",{})
        for layer in loadout.get("layers",[]):
            if layer.item_uuid!=item or WEAPON_SETS.get(str(layer.slot))!=loadout.get("active_weapon_set"):continue
            if World.visible_actor(actor,state):held.append({"kind":"held","holder_uuid":str(actor.uuid),"equipment_slot":str(layer.slot),
                "render_slot":"offhand" if str(layer.slot).ends_with("OFF") else "weapon"})
        var controlled:Variant=actor.get("controlled_items")
        if controlled!=null and item in controlled:inventory=str(actor.uuid)
    if held.size()>1:return {"kind":"ambiguous"}
    if held.size()==1:return held[0]
    if state.get("object_members",{}).has(item) and state.get("objects",{}).has(item):
        var contacts:Dictionary=state.get("senses",{}).get("objects",{}) if state.get("senses")!=null else {}
        if contacts.get(item,{}).get("visual",false):return {"kind":"ground","object":state.objects[item]}
    return {"kind":"inventory","holder_uuid":inventory} if not inventory.is_empty() else {}

static func observe(owners:Dictionary,state:Dictionary,at_ms:float,additions:Array,cache:Dictionary)->bool:
    var changed:bool=false
    for original in additions:
        var origin:Dictionary=original.duplicate(false);origin.start_ms=at_ms
        owners[origin.item_uuid]=origin;changed=true
    # Unknown initial/other-audience provenance is a requirement, never a
    # successful constructor populated with a study identity.
    var candidates:Dictionary={}
    for actor in state.get("actors",{}).values():
        for layer in actor.get("visual_loadout",{}).get("layers",[]):candidates[layer.item_uuid]=layer.item_id
    for id in state.get("object_members",{}):
        candidates[id]=state.get("objects",{}).get(id,{}).get("item",{}).get("item_id","")
    var definitions:Dictionary=definitions(cache)
    for id in candidates:
        if owners.has(id) or not definitions.has(candidates[id]):continue
        owners[id]={"item_uuid":id,"item_id":candidates[id],"creator_uuid":"","lifetime_condition_uuid":"","start_ms":at_ms,
            "reason":"created_item_origin_not_observed","definition":definitions[candidates[id]]}
        changed=true
    # Same-clock creation, equipment and removal rows are distinct ordered
    # cuts. Provenance is retained; only a small membership signature changes.
    for id in owners.keys():
        var owner:Dictionary=owners[id]
        var location:Dictionary=membership(owner.item_uuid,state)
        var signature:Array=[location,lifetime_present(owner,state) if owner.reason.is_empty() else false]
        if owner.get("membership",[])!=signature:
            var after:Dictionary=owner.duplicate(false)
            after.membership=signature;owners[id]=after;changed=true
    return changed

static func lifetime_present(owner:Dictionary,state:Dictionary)->bool:
    if str(owner.definition.constructor_input.get("lifetime_condition","")).is_empty():return true
    var actor:Dictionary=state.get("actors",{}).get(owner.creator_uuid,{})
    return actor.get("conditions",[]).any(func(condition):return condition.condition_uuid==owner.lifetime_condition_uuid)

static func samples(owners:Dictionary,state:Dictionary,at_ms:float)->Array:
    var result:Array=[]
    for owner in owners.values():
        var location:Dictionary=membership(owner.item_uuid,state)
        if location.is_empty() or location.kind=="inventory":continue
        if owner.reason.is_empty() and not lifetime_present(owner,state):continue
        var cue:Dictionary=owner.definition.duplicate(false)
        cue.merge({"begin":0.0,"end":INF,"launch":0.0,"contact":0.0,"source_rate":1.0,"scale":1.0},true)
        var clip:Dictionary=Effects.resolve(str(cue.clip),str(cue.get("selection","")),"attached").duplicate(false)
        clip.requires_constructor_input=true
        var actor:String=str(location.get("holder_uuid",owner.creator_uuid))
        var row={"id":"item:"+owner.item_uuid+":appearance","kind":"native_effect","native_spell":true,"native_item":true,
            "item_owner_uuid":owner.item_uuid,"item_origin":owner,"actor_uuid":actor,"target_uuid":actor,
            "start_ms":owner.start_ms,"absolute_start_ms":owner.start_ms,"duration_ms":INF,"age_ms":maxf(0,at_ms-owner.start_ms),
            "persistent_owner":true,"lifecycle":{},"alpha":1.0,"status":"available","source":cue.source,"source_id":str(cue.clip),
            "native_clip":clip,"native_cue":cue,"cast_recipe":{"enabled":false},"recipe":{},"finish_profile":{},
            "optical":{"energy_multiplier":0.0},"from_position":[0,0],"to_position":[0,0],"from_elevation_feet":0.0,"to_elevation_feet":0.0,
            "trace_keys":["item:"+owner.item_uuid+":appearance"],"source_event_uuid":owner.get("creation_occurrence","")}
        if location.kind=="ambiguous":
            row.status="missing";row.reason="created_item_multiple_observed_holders";row.unbound_constructor_inputs=["created_item_holder"]
        elif not owner.reason.is_empty():
            row.status="missing";row.reason=owner.reason;row.unbound_constructor_inputs=["created_item_origin"]
        else:
            var identity={"created_item_uuid":owner.item_uuid}
            if owner.lifetime_condition_uuid.is_empty():identity.creator_uuid=owner.creator_uuid
            else:identity.merge({"caster_uuid":owner.creator_uuid,"lifetime_condition_uuid":owner.lifetime_condition_uuid})
            row.native_constructor_inputs=[{"component_path":cue.constructor_input.component_path,"input_field":"","values":identity}]
            row.native_constructor_evidence={"item_uuid":owner.item_uuid,"creator_uuid":owner.creator_uuid,"lifetime_condition_uuid":owner.lifetime_condition_uuid,
                "source_occurrence":owner.source_occurrence,"creation_occurrence":owner.creation_occurrence,"creation_lineage":owner.creation_lineage}
        result.append(row)
    return result
