extends RefCounted
## Composes already-selected visual layers; condition ownership stays in Conditions.
## Capacity is a renderer budget, not a rule limiting active game conditions.
const CAPACITY=8
const FLOAT_FIELDS=["scale","strength","clock","twist","waviness","emission"]
const VECTOR_FIELDS=["noise_scale","scroll"]
const COLOUR_FIELDS=["primary","secondary","tertiary"]

static func compose(actor_id:String,samples:Array)->Dictionary:
    var layers=samples.filter(func(sample):return (sample.get("kind")=="body_surface"
        and sample.get("actor_uuid")==actor_id and float(sample.get("body_surface_strength",0.0))>0.0))
    if layers.is_empty():return {}
    # Higher priority is painted last. Equal priorities are stable across packet
    # arrival order, seeking and removal of another condition instance.
    layers.sort_custom(func(a,b):
        var left=int(a.get("composition",{}).get("priority",0))
        var right=int(b.get("composition",{}).get("priority",0))
        return left<right if left!=right else str(a.id)<str(b.id))
    var missing:Array=[]
    if layers.size()>CAPACITY:
        for sample in layers.slice(0,layers.size()-CAPACITY):
            missing.append({"id":sample.id,"status":"missing","reason":"body_surface_capacity"})
        layers=layers.slice(layers.size()-CAPACITY)
    var parameters={"body_surface_enabled":not layers.is_empty(),"body_surface_count":layers.size()}
    var textures:Array[Texture2D]=[]
    textures.resize(CAPACITY)
    for index in layers.size():textures[index]=layers[index].body_surface_texture
    parameters.body_surface_texture=textures
    for field in FLOAT_FIELDS:
        var values=PackedFloat32Array();values.resize(CAPACITY)
        for index in layers.size():values[index]=float(layers[index]["body_surface_"+field])
        parameters["body_surface_"+field]=values
    for field in VECTOR_FIELDS:
        var values=PackedVector2Array();values.resize(CAPACITY)
        for index in layers.size():values[index]=layers[index]["body_surface_"+field]
        parameters["body_surface_"+field]=values
    for field in COLOUR_FIELDS:
        var values=PackedVector3Array();values.resize(CAPACITY)
        for index in layers.size():
            # The single-surface shader used source_color. Convert explicitly for
            # packed vec3 arrays, which carry numbers rather than Color variants.
            var colour:Color=layers[index]["body_surface_"+field]
            colour=colour.srgb_to_linear()
            values[index]=Vector3(colour.r,colour.g,colour.b)
        parameters["body_surface_"+field]=values
    return {"layers":layers,"parameters":parameters,"missing":missing}

static func bind(material:ShaderMaterial,stack:Dictionary)->void:
    if stack.is_empty():
        material.set_shader_parameter("body_surface_enabled",false)
        material.set_shader_parameter("body_surface_count",0)
        material.set_shader_parameter("body_surface_texture",null)
        return
    for field in stack.parameters:material.set_shader_parameter(field,stack.parameters[field])
