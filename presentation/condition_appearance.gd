extends RefCounted
## Outfit membership is prepared from ordered condition owners. Factory leases
## only control opacity on that prepared layer, following the body's own pose.
const Documents=preload("res://presentation/ability_documents.gd")
const Catalog=preload("res://source_catalog.gd")
const Effects=preload("res://presentation/effect_package.gd")
const SourceMaterial=preload("res://presentation/source_material.gd")
const RECIPES="catalog/condition_recipes.json"
var leases:Dictionary={}
var previous_actors:Dictionary={}
var witnesses:Array=[]
var sampled_leases:Dictionary={}

class Binding extends RefCounted:
    var appearances:RefCounted
    var condition_uuid:String
    var actor_uuid:String
    var world:Node
    var owner_ids:Dictionary={}
    func acquire_condition_appearance(owner_id:int,specification:Dictionary)->bool:
        if str(specification.get("actor_uuid",""))!=actor_uuid:return false
        var accepted:bool=appearances.acquire(world,condition_uuid,actor_uuid,owner_id,specification)
        if accepted:owner_ids[owner_id]=true
        return accepted
    func set_condition_appearance_opacity(owner_id:int,value:float)->void:
        appearances.set_opacity(condition_uuid,owner_id,value)
    func release_condition_appearance(owner_id:int)->void:
        appearances.release(condition_uuid,owner_id)
        owner_ids.erase(owner_id)

static func declarations(condition:Dictionary,cache:Dictionary)->Array:
    var state:Dictionary=condition.get("state",{}) if condition.get("state") is Dictionary else {}
    if not state.get("suppression_provider_uuids",[]).is_empty():return []
    if not cache.has(RECIPES):cache[RECIPES]=Documents.read(RECIPES)
    return cache.get(RECIPES,{}).get(Catalog.condition_key(condition),{}).get("persistent",{}).get("appearanceLayers",[])

static func removal_ms(condition:Dictionary)->float:
    var result:float=0.0
    for selection in Effects.conditions(str(condition.get("behavior_id",""))):
        result=maxf(result,float(Effects.clip(selection.condition.phases.removal).get("seconds",0.0))*1000.0)
    return result

static func copy_owners(owners:Dictionary)->Dictionary:
    var result:Dictionary={}
    for id in owners:result[id]=owners[id].duplicate(false)
    return result

static func components(owners:Dictionary,at_ms:float,cache:Dictionary)->Array:
    var physical:Dictionary={}
    for owner in owners.values():
        var layers:Array=declarations(owner.condition,cache)
        if layers.is_empty():continue
        if at_ms<float(owner.start_ms) or (not is_inf(owner.end_ms) and at_ms>=float(owner.end_ms)+removal_ms(owner.condition)):continue
        for authored in layers:
            var key:Array=[owner.actor_uuid,authored]
            if not physical.has(key):
                var layer:Dictionary=authored.duplicate(false)
                layer.kind="condition_appearance";layer.alpha=0.0;layer.condition_uuids=[]
                physical[key]={"id":"appearance:"+str(owner.actor_uuid)+":"+str(authored.slot)+":"+str(authored.category)+":"+str(authored.id),
                    "kind":"appearance_layer","actor_uuid":owner.actor_uuid,"layer":layer}
            physical[key].layer.condition_uuids.append(owner.id)
    var selected:Dictionary={}
    for row in physical.values():
        row.layer.condition_uuids.sort()
        var slot:Array=[row.actor_uuid,row.layer.slot]
        var previous:Dictionary=selected.get(slot,{})
        # Distinct definitions compete explicitly by authored priority; they do
        # not share leases simply because both request the backpack slot.
        if previous.is_empty() or float(row.layer.get("priority",0))>float(previous.layer.get("priority",0)) \
            or (row.layer.get("priority",0)==previous.layer.get("priority",0) and row.id<previous.id):selected[slot]=row
    return selected.values()

static func actor_components(actor:Dictionary,cache:Dictionary)->Array:
    var owners:Dictionary={}
    for condition in actor.get("conditions",[]):
        owners[condition.condition_uuid]={"id":condition.condition_uuid,"actor_uuid":actor.uuid,"condition":condition,"start_ms":0.0,"end_ms":INF}
    return components(owners,0.0,cache)

static func entries(world:Node,actor:String,condition_uuid:String)->Array:
    return world.visual_actors.get(actor,{}).get("entries",[]).filter(func(entry):
        var effect:Dictionary=entry.actor_layer.get("effect",{})
        return effect.get("kind")=="condition_appearance" and condition_uuid in effect.get("condition_uuids",[]))

func acquire(world:Node,condition_uuid:String,actor:String,owner_id:int,specification:Dictionary)->bool:
    if condition_uuid.is_empty() or specification.get("body_animation_override",false) \
        or specification.get("pose_policy")!="current_actor_pose_and_facing":return false
    var layer:Dictionary=specification.layer
    var matching:Array=entries(world,actor,condition_uuid).filter(func(entry):return entry.actor_layer.slot==layer.slot \
        and entry.actor_layer.category==layer.category and entry.actor_layer.effect.id==layer.id)
    if matching.is_empty():return false
    if leases.has(owner_id):return leases[owner_id].condition_uuid==condition_uuid and leases[owner_id].actor==actor
    leases[owner_id]={"condition_uuid":condition_uuid,"actor":actor,"layer":layer,"opacity":clampf(float(layer.get("alpha",0)),0,1)}
    return true

func set_opacity(condition_uuid:String,owner_id:int,value:float)->void:
    if leases.has(owner_id) and leases[owner_id].condition_uuid==condition_uuid:leases[owner_id].opacity=clampf(value,0,1)

func release(condition_uuid:String,owner_id:int)->void:
    if leases.has(owner_id) and leases[owner_id].condition_uuid==condition_uuid:leases.erase(owner_id)

func bind(world:Node,handle:Dictionary,component:Dictionary)->String:
    var actor:String=str(component.get("target_uuid",component.get("actor_uuid","")))
    var condition_uuid:String=str(component.get("condition_uuid",""))
    var selected:Array=entries(world,actor,condition_uuid)
    var key:Array=[world.get_instance_id(),actor,condition_uuid,selected.map(func(entry):return entry.node.get_instance_id())]
    if key==handle.get("appearance_binding_key",[]):return handle.get("appearance_binding_reason","")
    var binding:Binding=Binding.new();binding.appearances=self;binding.world=world
    binding.condition_uuid=condition_uuid;binding.actor_uuid=actor
    var accepted:bool=bool(handle.occurrence.call(handle.clip.input_setters.appearance_provider,{"provider":binding,"actor_uuid":actor}))
    handle.appearance_binding=binding;handle.appearance_binding_key=key
    handle.appearance_binding_reason="" if accepted else "appearance_outfit_not_admitted"
    return handle.appearance_binding_reason

func begin_sample()->void:
    sampled_leases.clear()

func sampled(handle:Dictionary)->void:
    var binding:Binding=handle.get("appearance_binding")
    if binding==null:return
    for id in binding.owner_ids:sampled_leases[id]=true

func sync(world:Node)->void:
    witnesses.clear()
    var actors:Dictionary={}
    for lease in leases.values():actors[lease.actor]=true
    var sampled:Dictionary=previous_actors.duplicate();sampled.merge(actors)
    previous_actors=actors
    for actor in sampled:
        for entry in world.visual_actors.get(actor,{}).get("entries",[]):
            var effect:Dictionary=entry.actor_layer.get("effect",{})
            if effect.get("kind")!="condition_appearance":continue
            var opacity:float=0.0
            for lease_id in leases:
                if not sampled_leases.has(lease_id):continue
                var lease:Dictionary=leases[lease_id]
                if lease.actor==actor and lease.condition_uuid in effect.condition_uuids and lease.layer.id==effect.id \
                    and lease.layer.slot==entry.actor_layer.slot and lease.layer.category==entry.actor_layer.category:opacity=maxf(opacity,lease.opacity)
            SourceMaterial.set_parameter(entry,"layer_alpha",opacity)
            if opacity>1.0/255.0 and entry.node.is_visible_in_tree():
                for lease_id in leases:
                    if not sampled_leases.has(lease_id):continue
                    var lease:Dictionary=leases[lease_id]
                    if lease.actor==actor and lease.condition_uuid in effect.condition_uuids and lease.layer.id==effect.id and lease.opacity>1.0/255.0:
                        witnesses.append({"id":"condition:"+lease.condition_uuid+":appearance:"+str(effect.id),"status":"rendered"})

func clear()->void:
    leases.clear();previous_actors.clear();witnesses.clear();sampled_leases.clear()
