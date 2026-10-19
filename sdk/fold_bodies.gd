extends RefCounted
## Body and item records. Every write replaces a leaf, preserving previous presentation cuts.
const BODY_DEFAULTS={"temporary_hp_grant":null,"conditions":[],"controlled_items":null,"occupancy_layer":null,"resolved_size":null,"faction":null,"remains_disposition":"intact","spatial_disposition":"present"}
static func failure(message:String)->Dictionary:return {"ok":false,"error":{"kind":"reducer","message":message}}
static func success(value:Variant)->Dictionary:return {"ok":true,"value":value}

static func enter_item(target:Dictionary,record:Dictionary)->Dictionary:
    var prior:Dictionary=target.items.get(record.item_uuid,{});var look:Variant=record.get("look",prior.get("look"))
    if look==null:return failure("An item's first record requires its look")
    target.items[record.item_uuid]={"look":look,"profile":record.get("profile") if record.get("profile")!=null else prior.get("profile"),"state":record.get("state") if record.get("state")!=null else prior.get("state"),"effects":record.get("effects",[])}
    return success(target)

static func enter_body(target:Dictionary,record:Dictionary)->Dictionary:
    var prior:Dictionary=target.actors.get(record.actor_uuid,{})
    if not prior.get("present",true):return success(target)
    var birth:Variant=record.get("birth",prior if not prior.is_empty() else null)
    if birth==null:return failure("A body's first record requires its birth")
    var body:Dictionary=record.body;var loadouts:Dictionary=target.static.visual_loadouts
    if record.get("loadout")!=null:
        target.static=target.static.duplicate();loadouts=loadouts.duplicate();target.static.visual_loadouts=loadouts
        if loadouts.has(body.visual_loadout_id) and loadouts[body.visual_loadout_id]!=record.loadout:return failure("A visual loadout id names one value")
        loadouts[body.visual_loadout_id]=record.loadout
    if not loadouts.has(body.visual_loadout_id):return failure("A body requires its visual loadout")
    var actor={"uuid":record.actor_uuid,"name":birth.name,"character_body_id":birth.get("character_body_id"),"creature_content_ref":birth.get("creature_content_ref"),"appearance":birth.appearance,"structural_base_size":birth.get("structural_base_size"),"manifestation":birth.get("manifestation"),"visual_loadout":loadouts[body.visual_loadout_id],"last_visual_position":prior.get("last_visual_position"),"present":true}
    for field in ["normal_hp","maximum_hp","temporary_hp","life_state","armor_class"]:actor[field]=body[field]
    for field in BODY_DEFAULTS:actor[field]=body.get(field,BODY_DEFAULTS[field])
    target.actors[record.actor_uuid]=actor
    var recorded={}
    for item in record.get("items",[]):
        var entered=enter_item(target,item)
        if not entered.ok:return entered
        recorded[item.item_uuid]=true
    var shown:Array=actor.controlled_items if actor.controlled_items!=null else []
    if actor.controlled_items==null:
        for layer in actor.visual_loadout.layers:shown.append(layer.item_uuid)
    for identity in shown:
        if not recorded.has(identity) and target.items.has(identity) and not target.items[identity].effects.is_empty():
            var item:Dictionary=target.items[identity].duplicate();item.effects=[];target.items[identity]=item
    return success(target)

static func member(actor:Dictionary,identity:Variant)->Variant:
    for row in actor.conditions:
        if row.condition_uuid==identity:return row
    return null

static func upsert(rows:Array,field:String,value:Variant,key:Variant=null)->Array:
    var result:Array=rows.duplicate();var identity:Variant=value[field] if field!="" else value
    if key!=null:identity=key
    for i in range(rows.size()):
        if (rows[i][field] if field!="" else rows[i])==identity:result[i]=value;return result
    result.append(value);return result

static func remove(rows:Array,field:String,identity:Variant)->Array:
    var result:Array=[]
    for value in rows:
        if (value[field] if field!="" else value)!=identity:result.append(value)
    return result

static func changed_item(target:Dictionary,row:Dictionary)->void:
    var identity:Variant=row.get("item_uuid");var held:Variant=target.items.get(identity)
    if held==null:return
    var next:Dictionary=held.duplicate()
    match row.field:
        "item_effects":next.effects=row.effects
        "item_effect_duration":
            for effect in held.effects:
                if effect.effect_uuid==row.key:
                    var value:Dictionary=effect.duplicate();value.duration=row.duration;next.effects=upsert(held.effects,"effect_uuid",value);break
        "item_state":
            if held.state!=null:next.state=held.state.duplicate();next.state.merge(row.changes,true)
    target.items[identity]=next

static func actor_change(target:Dictionary,fact:Dictionary,condition_rows:Array=[])->Dictionary:
    for record in fact.get("items",[]):
        var entered=enter_item(target,record)
        if not entered.ok:return entered
    for change in fact.get("actors",[]):
        if not target.actors.has(change.actor_uuid):return failure("An actor change requires its held body")
        var actor:Dictionary=target.actors[change.actor_uuid]
        if not actor.present:continue
        for row in change.rows:
            var next:Dictionary=actor.duplicate()
            match row.field:
                "normal_hp","maximum_hp","temporary_hp","temporary_hp_grant","armor_class","resolved_size","spatial_disposition":next[row.field]=row.value
                "active_weapon_set":next.visual_loadout=actor.visual_loadout.duplicate();next.visual_loadout.active_weapon_set=row.value
                "condition":
                    var before:Variant=member(actor,row.condition_uuid);var after:Variant=row.get("member")
                    next.conditions=remove(actor.conditions,"condition_uuid",row.condition_uuid) if after==null else upsert(actor.conditions,"condition_uuid",after)
                    condition_rows.append({"actor_uuid":change.actor_uuid,"row":row,"before":before,"after":after})
                "condition_duration":
                    var prior:Variant=member(actor,row.key)
                    if prior!=null and prior.get("state")!=null:
                        var value:Dictionary=prior.duplicate();value.state=prior.state.duplicate();value.state.duration=row.duration;next.conditions=upsert(actor.conditions,"condition_uuid",value)
                "layer":
                    next.visual_loadout=actor.visual_loadout.duplicate();next.visual_loadout.layers=remove(actor.visual_loadout.layers,"slot",row.slot) if row.get("layer")==null else upsert(actor.visual_loadout.layers,"slot",row.layer)
                "inventory":
                    if actor.controlled_items==null:return failure("inventory rows require the controlled actor's inventory")
                    next.controlled_items=upsert(actor.controlled_items,"",row.item_uuid) if row.held else remove(actor.controlled_items,"",row.item_uuid)
                "item_effects","item_effect_duration","item_state":changed_item(target,row)
            actor=next
        target.actors[change.actor_uuid]=actor
    return success(target)
