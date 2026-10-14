extends RefCounted
## Original movement_context selectors, shared by compilation and gap reporting.
const Authoring=preload("res://presentation/authoring.gd")

static func selected(actor:Dictionary,trajectory:String,cache:Dictionary,phase:Dictionary={})->Array:
    if trajectory not in ["path","direct_arc"]:return []
    var conditions={}
    for condition in actor.get("conditions",[]):conditions[condition.behavior_id]=true
    var field="walkMedia" if trajectory=="path" else "jumpMedia"
    var rows:Array=Authoring.load_data("catalog/movement_context.json",cache).get(field,[])
    var selected_rows:Array=[]
    for i in rows.size():
        var row:Dictionary=rows[i]
        if not row.get("whenConditions",[]).all(func(id):return conditions.has(id)):continue
        if row.get("unlessConditions",[]).any(func(id):return conditions.has(id)):continue
        if row.role=="takeoff" and phase.has("from") and float(phase.from)>0.0:continue
        if row.role=="landing" and phase.has("to") and float(phase.to)<1.0:continue
        selected_rows.append({"media":row,"source":"catalog/movement_context.json:/"+field+"/"+str(i)})
    return selected_rows

static func native_source(asset_id:String,cache:Dictionary)->String:
    var sources:Dictionary=Authoring.load_data("native_effects/index.json",cache).sources
    for id in sources:
        if asset_id in sources[id].get("media_ids",[]):return id
    return ""

