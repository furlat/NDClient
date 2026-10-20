extends RefCounted
## Exact disclosed spatial owners. No cast-name matching, area generation,
## future visibility, synthetic condition member or inferred retirement.

static func content_id(effect:Dictionary)->String:
    return str(effect.get("content_ref",{}).get("content_id",""))

static func admitted_cells(effect:Dictionary)->Array:
    var suppressed:Dictionary={}
    for suppression in effect.get("suppressions",[]):
        for position in suppression.get("positions",[]):suppressed[Vector2i(position[0],position[1])]=true
    return effect.get("positions",[]).filter(func(position):return not suppressed.has(Vector2i(position[0],position[1])))

## Neutral constructor operands clear only the supplied review topology and
## retirement. Actual membership is supplied through its declared setters;
## unchanged material, mask, noise and artistic birth settings remain sealed.
static func construction(identity:String,effect:Dictionary,cue:Dictionary,source_effect:Dictionary={})->Dictionary:
    var descriptor:Dictionary=cue.get("constructor_input",{})
    if descriptor.get("kind")!="spatial_owner":
        return {"ready":false,"reason":"spatial_constructor_not_bound"}
    if str(descriptor.get("content_id",""))!=content_id(effect):
        return {"ready":false,"reason":"spatial_source_content_not_bound"}
    var capacity:int=int(cue.get("cell_capacity",0))
    var positions:Array=admitted_cells(effect)
    if capacity>0 and positions.size()>capacity:
        return {"ready":false,"reason":"spatial_source_cell_capacity_exceeded"}
    if descriptor.get("cell_input")=="cells":
        # This source constructs its native vegetation once from disclosed
        # topology. Visibility and temporary suppression remain AreaMask's
        # reversible admission; neither is evidence of permanent burning.
        var original:Array=source_effect.positions
        if positions.any(func(position):return position not in original):
            return {"ready":false,"reason":"spatial_source_topology_extension_not_bound"}
        var anchor:Variant=source_effect.get("anchor_position")
        if anchor==null:anchor=original[0]
        var local:Array=original.map(func(position):return [position[0]-anchor[0],position[1]-anchor[1]])
        return {"ready":true,"reason":"","operands":[{"component_path":descriptor.component_path,
            "input_field":descriptor.input_field,"values":{"cells":local,"observed_removals":[]}}],
            "source_anchor":anchor,"source_elevation_steps":source_effect.get("anchor_elevation_steps"),
            "source_cells":original,"observed_removals":[],
            "evidence":{"spatial_effect_uuid":identity,"content_id":content_id(effect),
                "observed_cell_count":positions.size(),"constructed_cells":original,"observed_removals":[]}}
    return {"ready":true,"reason":"","operands":[{"component_path":descriptor.component_path,
        "input_field":descriptor.input_field,"values":{"surface_admitted":false,"admitted_cells":[],"retire_at_seconds":INF}}],
        "evidence":{"spatial_effect_uuid":identity,"content_id":content_id(effect),"observed_cell_count":positions.size()}}

static func presence(component:Dictionary,state:Dictionary)->Dictionary:
    if not component.get("spatial_owner",false) or str(component.get("spatial_effect_uuid","")).is_empty():
        return {"ready":false,"reason":"surface_spatial_owner_not_bound"}
    var effects:Dictionary=state.get("senses",{}).get("spatial_effects",{}) if state.get("senses")!=null else {}
    var identity:String=str(component.spatial_effect_uuid)
    if not effects.has(identity):return {"ready":true,"value":false,"reason":""}
    var effect:Dictionary=effects[identity]
    if content_id(effect)!=str(component.get("spatial_content_id","")):
        return {"ready":false,"reason":"surface_spatial_content_not_bound"}
    return {"ready":true,"value":not admitted_cells(effect).is_empty(),"reason":""}
