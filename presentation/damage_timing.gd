extends RefCounted
## Authored response clocks for one actual applied packet and its owned life facts.
## No state mutation, inferred outcomes, or independent playback clock.
const Authoring=preload("res://presentation/authoring.gd")

static func request(node:Dictionary,graph:Dictionary)->Dictionary:
    var current=node
    while not current.is_empty():
        var fact:Variant=current.get("fact")
        if fact!=null and fact.get("kind")=="damage" and fact.get("stage")=="taken":return current
        current=graph.nodes.get(current.get("parent_lineage"),{})
    return node

static func _life(node:Dictionary,graph:Dictionary,target:String)->String:
    var owner=request(node,graph)
    var pending:Array=[owner]
    var result=""
    var last=-1
    while not pending.is_empty():
        var current:Dictionary=pending.pop_back()
        if current.get("canceled",false):continue
        var fact:Variant=current.get("fact")
        if current.uuid!=owner.uuid and fact!=null and fact.get("kind")=="damage" and fact.get("stage")=="taken":continue
        if fact!=null and fact.get("kind")=="life" and fact.get("entity_uuid")==target:
            var order:int=graph.first.get(current.lineage_uuid,-1)
            if order>=last:result=fact.new_state;last=order
        for identity in current.children_lineages:
            if graph.nodes.has(identity):pending.append(graph.nodes[identity])
    return result

static func resolve(node:Dictionary,graph:Dictionary,actor:Dictionary,contact:float,cache:Dictionary)->Dictionary:
    var context:Dictionary=Authoring.load_data("catalog/damage_context.json",cache)
    var override:Dictionary={}
    var parent:Dictionary=graph.nodes.get(node.get("parent_lineage"),{})
    while not parent.is_empty():
        var recipe:Dictionary=graph.recipes.get(parent.uuid,{})
        if recipe.get("damage")!=null:override=recipe.damage;break
        parent=graph.nodes.get(parent.get("parent_lineage"),{})
    var body=Authoring.body("damage",actor,node.fact,cache)
    var clip=Authoring.clip(actor,body.actor.clip,cache)
    var start=contact+float(override.get("impactDelayMs",context.get("impactDelayMs",0)))
    var terminal:bool=actor.get("life_state")=="dead"
    var lethal:bool=_life(node,graph,node.fact.target_entity_uuid)=="dead"
    var enabled:bool=node.fact.applied_damage>0 and not terminal and not lethal
    var hp=start
    var flash=start
    var number:Dictionary=override.get("floatingNumber",{})
    var flash_recipe:Dictionary=override.get("hitFlash",{})
    if enabled and not clip.is_empty():
        var fps:float=float(clip.fps)*float(body.actor.playbackSpeed)
        hp+=float(number.get("frame",context.get("numberFrame",0)))*1000.0/fps
        flash+=float(flash_recipe.get("frame",context.get("flashFrame",0)))*1000.0/fps
    return {"start":start,"hp":hp,"flash":flash,"number":hp,
        "body_enabled":enabled,"terminal":terminal,"lethal":lethal,
        "request_lineage":request(node,graph).lineage_uuid,"actor_uuid":node.fact.target_entity_uuid,
        "body":body,"clip":clip,"recipe":override}

static func life_time(node:Dictionary,graph:Dictionary,fallback:float)->float:
    var owner=request(node,graph)
    if owner.uuid==node.uuid:return fallback
    for timing in graph.damage_timings.values():
        if timing.request_lineage==owner.lineage_uuid and timing.actor_uuid==node.fact.entity_uuid:return timing.hp
    return fallback
