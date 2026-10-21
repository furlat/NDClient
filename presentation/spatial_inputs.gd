extends RefCounted
const Placement=preload("res://placement.gd")
## Exact disclosed spatial owners. No cast-name matching, area generation,
## future visibility, synthetic condition member or inferred retirement.

static func content_id(effect:Dictionary)->String:
    return str(effect.get("content_ref",{}).get("content_id",""))

static func admitted_cells(effect:Dictionary)->Array:
    var suppressed:Dictionary={}
    for suppression in effect.get("suppressions",[]):
        for position in suppression.get("positions",[]):suppressed[Vector2i(position[0],position[1])]=true
    return effect.get("positions",[]).filter(func(position):return not suppressed.has(Vector2i(position[0],position[1])))

## A native change is a mechanical observation of this exact spatial owner.
## Sensory membership changes alone are not interaction or retirement events.
static func observed_rows(node:Dictionary)->Array:
    var fact:Variant=node.get("fact")
    if node.get("canceled",false) or fact==null or fact.get("kind")!="spatial_effect_state":return []
    return [{"spatial_effect_uuid":str(fact.spatial_effect_uuid),"event_uuid":str(node.id),
        "lineage_uuid":str(node.lineage_id),"operation":fact.get("operation"),
        "interaction_operation":fact.get("interaction_operation"),
        "positions":fact.get("positions",[]),"removed_positions":fact.get("removed_positions",[]),
        "previous_state":fact.get("previous_state"),"state":fact.get("state"),
        "previous_pressed":fact.get("previous_pressed"),"pressed":fact.get("pressed")}]

## The source keeps its original constructed cells. Only a recorded permanent
## removal supplies a cell's private source age; sight loss and suppression do
## not manufacture entries in this list.
static func removal(owner:Dictionary,row:Dictionary)->Dictionary:
    var anchor:Variant=owner.source_effect.get("anchor_position")
    if anchor==null:anchor=owner.source_effect.positions[0]
    return {"cells":row.removed_positions.map(func(position):return [position[0]-anchor[0],position[1]-anchor[1]]),
        "positions":row.removed_positions,
        "source_seconds":maxf(0.0,float(row.at_ms)-float(owner.start_ms))/1000.0,
        "at_ms":row.at_ms,
        "event_uuid":row.event_uuid,"lineage_uuid":row.lineage_uuid,
        "operation":row.operation,"interaction_operation":row.interaction_operation}

## A finite retirement source receives only this actual transition's removed
## cells. The still-present owner and other spatial UUIDs are separate draws.
static func removal_construction(identity:String,source_effect:Dictionary,row:Dictionary,cue:Dictionary)->Dictionary:
    var subset:Dictionary=source_effect.duplicate()
    subset.positions=row.positions
    subset.suppressions=[]
    var result:Dictionary=construction(identity,subset,cue,subset)
    if result.ready:
        result.evidence=result.evidence.merged({"event_uuid":row.event_uuid,"lineage_uuid":row.lineage_uuid,
            "operation":row.operation,"interaction_operation":row.interaction_operation,"removed_positions":row.positions,"at_ms":row.at_ms})
    return result

## Only recorded retired cells may outlive current sensory membership, for
## the source's authored removal interval. Unseen cells gain no such lease.
static func presentation_cells(owner:Dictionary,at_ms:float,retention_ms:float)->Array:
    var result:Array=admitted_cells(owner.effect).duplicate() if owner.get("observed",true) else []
    for row in owner.get("spatial_observations",[]):
        if at_ms<float(row.at_ms) or at_ms>=float(row.at_ms)+retention_ms:continue
        for position in row.removed_positions:
            if position not in result:result.append(position)
    return result

## Neutral constructor operands clear only the supplied review topology and
## retirement. Actual membership is supplied through its declared setters;
## unchanged material, mask, noise and artistic birth settings remain sealed.
static func construction(identity:String,effect:Dictionary,cue:Dictionary,source_effect:Dictionary={},observed_removals:Array=[],optical_frame:Dictionary={})->Dictionary:
    var descriptor:Dictionary=cue.get("constructor_input",{})
    if descriptor.is_empty():
        # A source without constructor operands is authored artwork at this
        # actual owner's anchor. It does not reconstruct coverage or inputs.
        return {"ready":true,"reason":"","operands":[],
            "evidence":{"spatial_effect_uuid":identity,"content_id":content_id(effect),"placement":"actual_owner_anchor"}}
    if descriptor.get("kind")!="spatial_owner":
        return {"ready":false,"reason":"spatial_constructor_not_bound"}
    if str(descriptor.get("content_id",""))!=content_id(effect):
        return {"ready":false,"reason":"spatial_source_content_not_bound"}
    if descriptor.get("cell_input")=="wall_assembly":
        var original:Dictionary=source_effect if not source_effect.is_empty() else effect
        var geometry:Variant=original.get("area_geometry")
        var anchor:Variant=original.get("anchor_position")
        if anchor==null or geometry==null or geometry.get("shape")!="wall_assembly":return {"ready":false,"reason":"actual_wall_construction_not_disclosed"}
        if effect.get("area_geometry")!=geometry:return {"ready":false,"reason":"wall_geometry_changed_after_construction"}
        return {"ready":true,"reason":"","operands":[{"component_path":descriptor.component_path,"input_field":"",
            "values":{"wall_uuid":identity,"anchor_position":anchor,"wall_geometry":geometry}}],
            "source_anchor":anchor,"source_elevation_steps":geometry.get("base_height_steps",original.get("anchor_elevation_steps")),
            "source_cells":original.positions,"observed_removals":[],
            "evidence":{"spatial_effect_uuid":identity,"content_id":content_id(effect),"wall_geometry":geometry,"anchor_position":anchor}}
    if descriptor.get("cell_input")=="wall_segment":
        var original:Dictionary=source_effect if not source_effect.is_empty() else effect
        var geometry:Dictionary=original.area_geometry if original.get("area_geometry")!=null else {}
        var path:Dictionary=geometry.get("path",{})
        if geometry.get("shape")!="wall_assembly" or path.get("form")!="segment" or path.get("start")==null or path.get("end")==null \
            or original.get("anchor_position")==null or effect.get("area_geometry")!=geometry:
            return {"ready":false,"reason":"actual_wall_segment_not_disclosed"}
        var length:float=Vector2(path.end[0]-path.start[0],path.end[1]-path.start[1]).length()
        if length<=0.0 or float(geometry.get("width_feet",0.0))!=float(descriptor.width_feet) \
            or float(geometry.get("height_feet",0.0))!=float(descriptor.height_feet):
            return {"ready":false,"reason":"wall_segment_source_dimensions_not_bound"}
        return {"ready":true,"reason":"","operands":[{"component_path":descriptor.component_path,
            "input_field":"","values":{"owner_uuid":identity,"state":{},"review_states":[],"length_cells":length}}],
            "evidence":{"spatial_effect_uuid":identity,"content_id":content_id(effect),
                "wall_geometry":geometry,"length_cells":length,"review_retirement_cleared":true}}
    if descriptor.get("cell_input")=="owner_state":
        # Immutable source identity belongs to this actual public spatial UUID.
        # Clear the source's example admission and timed review retirement;
        # its declared owner_state setter receives the current observation.
        return {"ready":true,"reason":"","operands":[{"component_path":descriptor.component_path,
            "input_field":"","values":{"owner_uuid":identity,"state":{},"review_states":[]}}],
            "evidence":{"spatial_effect_uuid":identity,"content_id":content_id(effect),
                "owner_identity":"actual_spatial_uuid","review_retirement_cleared":true}}
    if descriptor.get("cell_input") in ["owned_field","wall_geometry","partitioned_surface"]:
        # UUID-only fields have no immutable construction anchor. Their actual
        # current public anchor follows moving owners through the same setter.
        var live_anchor:bool=descriptor.get("cell_input")=="owned_field" and not descriptor.get("construct_cells",false)
        var original:Dictionary=effect if live_anchor or source_effect.is_empty() else source_effect
        var anchor:Variant=original.get("anchor_position")
        var elevation:Variant=original.get("anchor_elevation_steps")
        if anchor==null and descriptor.get("anchor_policy")=="disclosed_cell":
            anchor=optical_frame.get("anchor");elevation=optical_frame.get("elevation_steps")
        if anchor==null or elevation==null:return {"ready":false,"reason":"actual_spatial_source_anchor_support_not_disclosed"}
        var fields:Dictionary={"owner_uuid":identity}
        if descriptor.get("cell_input")=="wall_geometry":
            var geometry:Dictionary=original.get("area_geometry",{}) if original.get("area_geometry")!=null else {}
            if geometry.get("shape") not in descriptor.get("geometry_shapes",[]):return {"ready":false,"reason":"actual_wall_geometry_shape_not_bound"}
            fields={"wall_uuid":identity,"anchor_position":anchor,"wall_geometry":geometry}
        elif descriptor.get("cell_input")=="partitioned_surface":fields={"surface_uuid":identity}
        elif descriptor.get("construct_cells",false):
            if original.get("positions",[]).is_empty():return {"ready":false,"reason":"spatial_source_cells_not_observed"}
            fields.cells=original.positions.map(func(position):return [position[0]-anchor[0],position[1]-anchor[1]])
        return {"ready":true,"reason":"","operands":[{"component_path":descriptor.component_path,"input_field":"","values":fields}],
            "source_anchor":anchor,"source_elevation_steps":elevation,"source_cells":original.get("positions",[]),"observed_removals":[],
            "evidence":{"spatial_effect_uuid":identity,"content_id":content_id(effect),"anchor_position":anchor,
                "anchor_elevation_steps":elevation,"anchor_policy":descriptor.get("anchor_policy","disclosed_anchor")}}
    var capacity:int=int(cue.get("cell_capacity",0))
    var positions:Array=admitted_cells(effect)
    if capacity>0 and positions.size()>capacity:
        return {"ready":false,"reason":"spatial_source_cell_capacity_exceeded"}
    if descriptor.get("cell_input")=="zone_geometry":
        var anchor:Variant=effect.get("anchor_position")
        var geometry:Dictionary=effect.area_geometry if effect.get("area_geometry")!=null else {}
        if capacity>0 and effect.get("positions",[]).size()>capacity:
            return {"ready":false,"reason":"spatial_source_raw_cell_capacity_exceeded"}
        if anchor==null or positions.is_empty() or geometry.get("shape")!="wall_assembly" \
            or geometry.get("base_height_steps")==null or geometry.get("height_feet")==null:
            return {"ready":false,"reason":"actual_zone_anchor_or_height_not_disclosed"}
        var span:Array=cue.get("cell_span_capacity",[])
        if span.size()==2:
            var low:Vector2=Vector2(positions[0][0],positions[0][1]);var high:Vector2=low
            for position in positions:
                low=low.min(Vector2(position[0],position[1]));high=high.max(Vector2(position[0],position[1]))
            if high.x-low.x+1.0>float(span[0]) or high.y-low.y+1.0>float(span[1]):
                return {"ready":false,"reason":"spatial_source_cell_span_exceeded"}
        return {"ready":true,"reason":"","operands":[{"component_path":descriptor.component_path,
            "input_field":"","values":{"owner_uuid":identity}}],"source_anchor":anchor,
            "source_elevation_steps":geometry.base_height_steps,"source_cells":positions,"observed_removals":[],
            "evidence":{"spatial_effect_uuid":identity,"content_id":content_id(effect),
                "owner_identity":"actual_spatial_uuid","geometry":"current_disclosed_zone"}}
    if descriptor.get("cell_input")=="owned_cells":
        if positions.is_empty():return {"ready":false,"reason":"spatial_source_cells_not_observed"}
        var original:Dictionary=source_effect if not source_effect.is_empty() else effect
        var anchor:Variant=original.get("anchor_position")
        if anchor==null:anchor=original.positions[0]
        var fields:Dictionary={}
        fields[str(descriptor.cells_field)]=positions.map(func(position):return [position[0]-anchor[0],position[1]-anchor[1]])
        # No future retirement has been observed at construction. The same
        # declared source setter receives this actual owner's bounded end if
        # it is retained; ordinary owner teardown may remove it immediately.
        fields[str(descriptor.retirement_field)]=INF
        return {"ready":true,"reason":"","operands":[{"component_path":descriptor.component_path,
            "input_field":"","values":fields}],"source_anchor":anchor,
            "source_elevation_steps":original.get("anchor_elevation_steps"),
            "source_cells":positions,"observed_removals":[],
            "evidence":{"spatial_effect_uuid":identity,"content_id":content_id(effect),
                "constructed_cells":positions,"review_retirement_cleared":true,"owner_identity":"actual_spatial_uuid"}}
    if descriptor.get("cell_input")=="surface_state":
        var original:Dictionary=source_effect if not source_effect.is_empty() else effect
        var anchor:Variant=original.get("anchor_position")
        if anchor==null:return {"ready":false,"reason":"surface_anchor_not_disclosed"}
        var cells:Array=original.positions.map(func(position):return [position[0]-anchor[0],position[1]-anchor[1]])
        if cells.is_empty() or cells.size()>128:return {"ready":false,"reason":"spatial_source_cell_capacity_exceeded"}
        return {"ready":true,"reason":"","operands":[{"component_path":descriptor.component_path,
            "input_field":"","values":{"surface_uuid":identity,"state":{},"admitted_cells":cells,
                "lifecycle_mode":"native_owner","retire_at_seconds":INF}}],
            "source_anchor":anchor,"source_elevation_steps":original.get("anchor_elevation_steps"),
            "source_cells":original.positions,"observed_removals":[],
            "evidence":{"spatial_effect_uuid":identity,"content_id":content_id(effect),
                "constructed_cells":original.positions,"observed_cell_count":positions.size()}}
    if descriptor.get("cell_input")=="surface_groups":
        # Coverage is immutable source geometry. Admission and visibility use
        # the existing spatial AreaMask, never a second gameplay footprint.
        var original:Array=source_effect.positions
        if positions.any(func(position):return position not in original):
            return {"ready":false,"reason":"spatial_source_topology_extension_not_bound"}
        var origin:Dictionary=surface_origin(source_effect)
        if origin.anchor==null:return {"ready":false,"reason":"spatial_source_cells_not_observed"}
        return surface_construction(identity,content_id(effect),original,origin.anchor,origin.elevation_steps,descriptor)
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
            "source_cells":original,"observed_removals":observed_removals,
            "evidence":{"spatial_effect_uuid":identity,"content_id":content_id(effect),
                "observed_cell_count":positions.size(),"constructed_cells":original,"observed_removals":observed_removals}}
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

## The retained source observes this exact current UUID, independently of
## its offline fixture. Actual owner absence withdraws admission immediately;
## no duration, nearby caster or source inspection end is an owner lifetime.
static func owner_state(component:Dictionary,state:Dictionary,sample_seconds:float=INF)->Dictionary:
    var admitted:Dictionary=presence(component,state)
    if not admitted.ready:return admitted
    var effects:Dictionary=state.get("senses",{}).get("spatial_effects",{}) if state.get("senses")!=null else {}
    var identity:String=str(component.spatial_effect_uuid)
    var present:bool=effects.has(identity)
    return {"ready":true,"reason":"","value":{"owner_uuid":identity,"present":present,
        "observed":present,"suppressed":present and not admitted.value,
        "owner_age_seconds":maxf(0.0,sample_seconds) if is_finite(sample_seconds) else maxf(0.0,float(component.get("age_ms",0.0)))/1000.0}}

## This source's state gate describes the same optical occupancy as presence:
## this exact current public UUID, with only its currently unsuppressed cells.
## It declares no damage, trigger, remaining rounds or retained caster power.
## Full current disclosed zone data, not a reconstructed parent or shell.
static func zone_geometry(component:Dictionary,state:Dictionary)->Dictionary:
    var admitted:Dictionary=presence(component,state)
    if not admitted.ready:return admitted
    var effects:Dictionary=state.get("senses",{}).get("spatial_effects",{}) if state.get("senses")!=null else {}
    var identity:String=str(component.spatial_effect_uuid)
    var effect:Dictionary=effects.get(identity,{})
    if component.get("native_cue",{}).get("constructor_input",{}).get("construct_cells",false) and not effect.is_empty():
        # This is one immutable source draw of the same public owner. Its live
        # cells are an actual subset, not another canonical zone or UUID.
        effect=effect.duplicate(false)
        var constructed:Array=component.get("spatial_source_cells",[])
        effect.positions=effect.get("positions",[]).filter(func(position):return position in constructed)
    return {"ready":true,"reason":"","value":{"spatial_effect_uuid":identity,"effect":effect}}

static func surface_state(component:Dictionary,state:Dictionary)->Dictionary:
    var occupancy:Dictionary=presence(component,state)
    if not occupancy.ready:return occupancy
    var descriptor:Dictionary=component.get("native_cue",{}).get("constructor_input",{})
    var surface_kind:String=str(descriptor.get("surface_kind",""))
    if descriptor.get("cell_input")!="surface_state" or surface_kind.is_empty():
        return {"ready":false,"reason":"surface_state_kind_not_bound"}
    var identity:String=str(component.spatial_effect_uuid)
    var effects:Dictionary=state.get("senses",{}).get("spatial_effects",{}) if state.get("senses")!=null else {}
    var original:Array=component.get("spatial_source_cells",[])
    var current:Array=admitted_cells(effects[identity]) if effects.has(identity) else []
    var positions:Array=current if not current.is_empty() else original
    if positions.is_empty():return {"ready":false,"reason":"surface_state_original_cells_not_disclosed"}
    var anchor:Array=component.from_position
    var cells:Array=positions.map(func(position):return [position[0]-anchor[0],position[1]-anchor[1]])
    return {"ready":true,"reason":"","packet":{"surface_uuid":identity,"surface_kind":surface_kind,
        "admitted_cells":cells,"present":occupancy.value,"observed":occupancy.value,
        "contributions_active":occupancy.value,"suppressed":not occupancy.value}}

## The sealed rain source accepts at most32 exact cells and160 optical points
## per immutable group. These are coverage samples inside disclosed cells,
## not particles, gameplay water cells, or another spatial owner.
static func surface_origin(original:Dictionary,disclosures:Array=[])->Dictionary:
    var anchor:Variant=original.get("anchor_position")
    var positions:Array=original.get("positions",[])
    var elevation:Variant=original.get("anchor_elevation_steps")
    if anchor==null and not positions.is_empty():anchor=positions[0]
    if anchor==null and not disclosures.is_empty():
        anchor=disclosures[0].anchor;elevation=disclosures[0].elevation_steps
    if elevation==null:
        for disclosure in disclosures:
            if disclosure.get("anchor")==anchor and disclosure.get("elevation_steps")!=null:elevation=disclosure.elevation_steps;break
    return {"anchor":anchor,"elevation_steps":elevation}

## Public source helper preserves original neighbor ties and disjoint draw
## assignment. It runs only when the actual admitted footprint changes.
static func surface_partitions(identity:String,cells:Array,anchor:Array,descriptor:Dictionary)->Dictionary:
    var path:String=str(descriptor.get("topology_script",""))
    var topology:Script=load(path)
    var local:Array=cells.map(func(position):return [position[0]-anchor[0],position[1]-anchor[1]])
    var full:Dictionary=topology.owner(identity,local)
    return topology.partition(full,int(descriptor.capacity))

static func surface_construction(identity:String,content:String,positions:Array,anchor:Array,elevation:Variant,descriptor:Dictionary)->Dictionary:
    if str(descriptor.get("content_id",""))!=content:return {"ready":false,"reason":"spatial_source_content_not_bound"}
    if positions.is_empty():return {"ready":false,"reason":"spatial_source_cells_not_observed"}
    var groups:Array=surface_groups(identity,positions,anchor)
    return {"ready":true,"reason":"","operands":[{"component_path":descriptor.component_path,
        "input_field":descriptor.input_field,"values":{"surface_groups":groups}}],
        "source_anchor":anchor,"source_elevation_steps":elevation,
        "source_cells":positions,"observed_removals":[],"surface_records":groups,
        "evidence":{"spatial_effect_uuid":identity,"content_id":content,
            "constructed_cells":positions,"surface_group_count":groups.size(),"points_per_group":160}}

static func surface_groups(identity:String,positions:Array,anchor:Array)->Array:
    var result:Array=[]
    for start in range(0,positions.size(),32):
        var local:Array=[]
        var minimum:Vector2i=Vector2i(positions[start][0]-anchor[0],positions[start][1]-anchor[1])
        var maximum:Vector2i=minimum
        for index in range(start,mini(start+32,positions.size())):
            var point:Vector2i=Vector2i(positions[index][0]-anchor[0],positions[index][1]-anchor[1])
            minimum=minimum.min(point);maximum=maximum.max(point);local.append([point.x,point.y])
        var samples:Array=[]
        for index in 160:
            var cell:Array=local[index%local.size()]
            var x:float=fposmod((float(index)+0.5)*0.6180339887498949,1.0)-0.5
            var z:float=fposmod((float(index)+0.5)*0.7548776662466927,1.0)-0.5
            samples.append([float(cell[0])+x,float(cell[1])+z])
        result.append({"source_uuid":identity,"cells":local,"points":samples,
            "bounds":[float(minimum.x)-0.5,float(minimum.y)-0.5,float(maximum.x-minimum.x+1),float(maximum.y-minimum.y+1)]})
    return result


## Initial wall contacts join the exact creating cast through native ancestry.
## A nearby body or matching damage type cannot activate another wall owner.
static func wall_contact_rows(events:Array,graph:Dictionary,recipes:Dictionary={})->Dictionary:
    var owners:Dictionary={};var result:Dictionary={}
    for event_index in events.size():
        var node:Dictionary=events[event_index]
        var fact:Variant=node.get("fact")
        if node.get("canceled",false) or fact==null or fact.get("kind")!="spatial_effect_state" or fact.get("operation")!="created":continue
        var source:Dictionary=_wall_cast(node,graph)
        if source.is_empty():continue
        var effect:Dictionary=graph.get("spatial_creation_inputs",{}).get(str(node.id),{})
        if effect.is_empty():continue
        var recipe:Dictionary=recipes.get(content_id(effect),{})
        var contact_authored:bool=recipe.get("persistent",{}).get("nativeEffects",[]).any(func(cue):
            var descriptor:Dictionary=cue.get("constructor_input",{})
            return descriptor.get("kind")=="spatial_owner" and descriptor.get("cell_input")=="wall_assembly" \
                and descriptor.get("content_id")==content_id(effect) \
                and descriptor.get("contact_behavior_id")==source.fact.get("behavior_id"))
        if not contact_authored:continue
        if not owners.has(source.id):owners[source.id]=[]
        owners[source.id].append({"identity":str(fact.spatial_effect_uuid),"admission_occurrence":str(node.id),"event_index":event_index})
    for event_index in events.size():
        var node:Dictionary=events[event_index]
        var fact:Variant=node.get("fact")
        if node.get("canceled",false) or fact==null or fact.get("kind")!="damage" or fact.get("stage")!="applied" or int(fact.get("applied_damage",0))<=0:continue
        var source:Dictionary=_wall_cast(node,graph)
        if source.is_empty() or owners.get(source.id,[]).size()!=1:continue
        var contact:Dictionary=graph.get("contact_inputs",{}).get(str(node.id),{})
        if contact.is_empty():continue
        var owner:Dictionary=owners[source.id][0]
        # Initial damage can precede public owner admission in source order
        # while sharing its scheduled contact. Deliver those facts only when
        # that actual owner exists; the compiler preserves their original clock.
        var delivery:String=str(owner.admission_occurrence) if event_index<int(owner.event_index) else str(node.id)
        if not result.has(delivery):result[delivery]=[]
        result[delivery].append({"spatial_effect_uuid":owner.identity,"event_uuid":str(node.id),"lineage_uuid":str(node.lineage_id),
            "operation":"contact","positions":[],"removed_positions":[],"contact":{"kind":"damage","actor_uuid":str(fact.target_entity_uuid),
                "position":contact.position,"elevation_steps":contact.elevation_steps},
            "source_occurrence":str(source.id),"source_lineage":str(source.lineage_id)})
    return result

static func _wall_cast(node:Dictionary,graph:Dictionary)->Dictionary:
    var parent:Variant=node.get("parent_lineage")
    var applications:Array=[]
    while parent!=null:
        var owner:Dictionary=graph.get("nodes",{}).get(str(parent),{})
        if owner.is_empty() or owner.get("canceled",false):return {}
        var fact:Variant=owner.get("fact")
        if fact!=null:
            if fact.get("kind") in ["action","attack"]:return {}
            if fact.get("kind")=="spell":
                if fact.get("behavior_id")!=null:
                    return owner if applications.all(func(lineage):return lineage==str(owner.lineage_id)) else {}
                var resolution:Variant=owner.get("resolution_record",{}).get("lineage")
                if resolution==null:return {}
                applications.append(str(resolution))
        parent=owner.get("parent_lineage")
    return {}

## One owner clock, actual optical occupants and the recorded contact prefix.
## No contacts means no damage pulse; sight loss is distinct from retirement.
static func wall_state(component:Dictionary,state:Dictionary,visual_actors:Dictionary)->Dictionary:
    var identity:String=str(component.get("spatial_effect_uuid",""))
    if identity.is_empty() or not component.get("native_wall",false):return {"ready":false,"reason":"actual_wall_owner_not_bound"}
    var effects:Dictionary=state.get("senses",{}).get("spatial_effects",{}) if state.get("senses")!=null else {}
    var current:Dictionary=effects.get(identity,{})
    if not current.is_empty() and content_id(current)!=str(component.spatial_content_id):return {"ready":false,"reason":"actual_wall_content_mismatch"}
    if not current.get("suppressions",[]).is_empty():return {"ready":false,"reason":"wall_partial_suppression_not_supported"}
    var present:bool=not current.is_empty() and bool(current.get("apparent_presence",false))
    var removal:Variant=component.get("wall_removal_at_seconds")
    var occupants:Array=[]
    if present:
        for id in visual_actors:
            var visual:Dictionary=visual_actors[id]
            if visual.get("row",{}).get("visible",true)==false or not visual.has("row"):continue
            occupants.append({"actor_uuid":str(id),"ground":Placement.contact(visual.row)})
    if occupants.size()>16:return {"ready":false,"reason":"wall_optical_occupant_capacity_exceeded"}
    var contacts:Array=[]
    for observed in component.get("wall_contact_prefix",[]):
        var at:float=(float(observed.at_ms)-float(component.absolute_start_ms))/1000.0
        if at<0.0:return {"ready":false,"reason":"actual_wall_contact_precedes_owner_clock"}
        var contact:Dictionary=observed.contact
        contacts.append({"event_uuid":str(observed.event_uuid),"kind":str(contact.kind),"actor_uuid":str(contact.actor_uuid),
            "at_seconds":at,"ground":Placement.contact({"position":contact.position,"base_height_steps":contact.elevation_steps})})
    if contacts.size()>64:return {"ready":false,"reason":"wall_actual_contact_capacity_exceeded"}
    return {"ready":true,"packet":{"wall_uuid":identity,"present":present,"observed":present or removal!=null,
        "removal_at_seconds":removal,"occupants":occupants,"contacts":contacts}}
