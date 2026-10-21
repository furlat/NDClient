extends RefCounted
## Composed schema-16 perception and memory. Never recompute visibility or gameplay light.
const Cells=preload("res://sdk/fold_cells.gd")
const EFFECT_DEFAULTS={"duration":null,"owner_revision":null,"apparent_presence":false,"trap_state":null,"pressed":null,"direction":null,"anchor_item_uuid":null,"anchor_entity_uuid":null,"energy_type":null,"presence_mode":null,"sustainer_item_uuid":null,"concentration_slot_uuid":null,"anchor_position":null,"anchor_elevation_steps":null,"area_geometry":null,"construction_sections":[],"area_propagation":null,"deposit_source":null,"visible_volume_positions":[],"upper_volume_surfaces":[],"suppressions":[]}
static func success(value:Variant)->Dictionary:return {"ok":true,"value":value}
static func failure(message:String)->Dictionary:return {"ok":false,"error":{"kind":"reducer","message":message}}
static func point_key(point:Array)->String:return Cells.key(point)
static func parse_cell_key(value:String)->Dictionary:return success(Cells.point(value))
static func compare(a:Variant,b:Variant)->int:
    if a is Array and b is Array:
        for i in range(mini(a.size(),b.size())):
            var order=compare(a[i],b[i])
            if order!=0:return order
        return signi(a.size()-b.size())
    return 0 if a==b else (-1 if a<b else 1)
static func points_union(first:Array,second:Array)->Array:
    var all=Cells.point_set(first);all.merge(Cells.point_set(second),true);return Cells.sorted_points(all)
static func modes_key(modes:Array)->Array:
    var result:Array=[]
    for mode in modes:result.append([mode.sense_type,int(mode.get("range_feet",0))])
    result.sort_custom(func(a,b):return compare(a,b)<0);return result
static func modes_signature(modes:Array)->String:return JSON.stringify(modes_key(modes))
static func resolve(observer:String,supplied:Variant)->Dictionary:
    return success({"controlled":[observer],"observers":[observer],"revision":0} if supplied==null else supplied)

static func composed_values(rows:Dictionary)->Dictionary:
    var positions:Array=rows.get("contact_positions",[]);var visual=Cells.row_indices(rows.get("contact_visual",{}),positions.size())
    if not visual.ok:return visual
    var contacts:Array=[];var senses:Array=rows.get("contact_special_senses",[])
    for i in range(positions.size()):contacts.append({"position":positions[i],"visual":i in visual.value,"special_senses":senses[i] if not senses.is_empty() else []})
    return success({"rows":rows,"contacts":contacts,"cells":Cells.mask_points(rows.get("cells",{})),"light_levels":Cells.layered(rows.get("light_levels",[])),"hazards":Cells.layered(rows.get("hazards",[]))})

static func _members(column:Array,index:int,count:int)->Dictionary:
    if not column.is_empty():return success(column[index])
    return success(1) if count==1 else failure("A seat with several observers names the members of each row")

static func _selected_cells(rows:Array,subset:Dictionary)->Dictionary:
    return Cells.selected(rows,subset)

static func _changed_points(prior:Array,added:Dictionary,removed:Dictionary)->Dictionary:
    var result=Cells.point_set(prior)
    for value in Cells.mask_points(removed):
        if not result.erase(Cells.key(value)):return failure("A patch removes only held cells and adds only new ones")
    for value in Cells.mask_points(added):
        if result.has(Cells.key(value)):return failure("A patch removes only held cells and adds only new ones")
        result[Cells.key(value)]=value
    return success(Cells.sorted_points(result))

static func _effect(row:Dictionary,content:Dictionary)->Dictionary:
    var result=EFFECT_DEFAULTS.duplicate();result.merge(content,true);result.merge(row,true)
    result.positions=Cells.mask_points(row.get("positions",{}));result.visible_volume_positions=Cells.mask_points(row.get("visible_volume_positions",{}));return result

static func _patch_effect(prior:Dictionary,patch:Dictionary)->Dictionary:
    var result=prior.duplicate();result.merge(patch.get("changes",{}),true)
    var points=_changed_points(prior.positions,patch.get("positions_added",{}),patch.get("positions_removed",{}))
    if not points.ok:return points
    result.positions=points.value
    points=_changed_points(prior.visible_volume_positions,patch.get("volume_added",{}),patch.get("volume_removed",{}))
    if not points.ok:return points
    result.visible_volume_positions=points.value
    var upper={}
    for row in prior.upper_volume_surfaces:upper[JSON.stringify([row.position,row.lower_height_planes])]=row
    for row in patch.get("upper_removed",[]):
        if not upper.erase(JSON.stringify(row)):return failure("A patch removes only held volume surfaces")
    for row in patch.get("upper_added",[]):upper[JSON.stringify([row.position,row.lower_height_planes])]=row
    result.upper_volume_surfaces=upper.values();result.upper_volume_surfaces.sort_custom(func(a,b):return compare([a.position,a.lower_height_planes],[b.position,b.lower_height_planes])<0)
    return success(result)

static func _light(row:Dictionary,uuids:Array)->Dictionary:
    return {"source_uuid":uuids[row.source],"position":row.position,"base_height_steps":row.get("base_height_steps",0),"very_bright_radius_feet":row.get("very_bright_radius_feet",0),"bright_radius_feet":row.get("bright_radius_feet",0),"dim_radius_feet":row.get("dim_radius_feet",0),"appearance":row.get("appearance","neutral"),"actor_anchored":row.get("actor_anchored",false),"anchor_entity_uuid":uuids[row.anchor_entity] if row.get("anchor_entity")!=null else null,"anchor_item_uuid":uuids[row.anchor_item] if row.get("anchor_item")!=null else null}

static func clear_unseen_positions(target:Dictionary,changed_actors:Dictionary={})->void:
    if target.senses==null:return
    for identity in target.actors:
        var actor:Dictionary=target.actors[identity];var position:Variant=actor.last_visual_position
        if position!=null and actor.present and actor.life_state!="dead" and not identity in target.audience.controlled and not target.senses.entities.has(identity) and Cells.contains(target.senses.visible,position):
            actor=actor.duplicate();actor.last_visual_position=null;target.actors[identity]=actor;changed_actors[identity]=true

static func fold(target:Dictionary,fact:Dictionary,values:Dictionary,changed_actors:Dictionary={},cell_context:Dictionary={})->Dictionary:
    var rows:Dictionary=values.rows;var uuids:Array=rows.get("uuids",[]);var held:Variant=target.senses
    if fact.get("initial",false):
        if held!=null:return failure("A seat's perception enters once")
        held={"position":fact.observer_position,"visible":Cells.EMPTY,"seen":Cells.EMPTY,"entities":{},"objects":{},"effective_light_levels":Cells.values([],{}),"hazardous_cells":Cells.values([],{}),"spatial_effects":{},"paths_dirty":false,"passive_perception":fact.passive_perception,"sense_modes_key":[],"sense_modes":[],"visual_access":fact.visual_access,"light_sources":{},"light_source_removals":{}}
    elif held==null:return failure("A sensory change requires the seat's entered perception")
    var added=_selected_cells(values.cells,fact.get("visible_cells_added",{}));var removed=_selected_cells(values.cells,fact.get("visible_cells_removed",{}))
    if not added.ok:return added
    if not removed.ok:return removed
    # Only a context forked from this exact accepted state's immutable mask
    # may borrow its ordered population and membership table.
    var indexed:bool=is_same(cell_context.get("mask"),held.visible) and cell_context.has("points") and cell_context.has("members")
    var prior_points:Array=cell_context.points if indexed else Cells.mask_points(held.visible)
    var prior_members:Dictionary=cell_context.members if indexed else Cells.point_set(prior_points)
    var topology_changed:bool=not removed.value.is_empty() or not added.value.is_empty()
    var visible:Dictionary=prior_members.duplicate() if topology_changed else prior_members
    for point in removed.value:visible.erase(Cells.key(point))
    for point in added.value:visible[Cells.key(point)]=point
    var points:Array=Cells.sorted_points(visible) if topology_changed else prior_points
    var result:Dictionary=held.duplicate()
    result.visible=Cells.mask(points) if topology_changed else held.visible
    result.seen=Cells.union_points(held.seen,added.value)
    var value_indices:=PackedInt64Array();var values_indexed:bool=false
    for pair in [["effective_light_levels","light_levels","effective_light_levels_changed"],["hazardous_cells","hazards","hazardous_cells_changed"]]:
        var changed=Cells.selected(values[pair[1]],fact.get(pair[2],{}))
        if not changed.ok:return changed
        if held[pair[0]].get("cells",{})==held.visible:
            # This exact accepted mask already owns the aligned immutable bytes.
            # Contact-only changes must not decode/re-encode unchanged columns.
            if indexed and not topology_changed and changed.value.is_empty():
                result[pair[0]]=held[pair[0]];continue
            if not values_indexed:
                value_indices=Cells.value_indices(prior_points,points);values_indexed=true
            result[pair[0]]=Cells.reindexed_values(held[pair[0]],prior_points.size(),points,changed.value,result.visible,value_indices)
        else:
            var prior=Cells.values_map(held[pair[0]])
            for row in changed.value:prior[Cells.key(row.position)]=row.value
            result[pair[0]]=Cells.values(points,prior,result.visible)
    for pair in [["entities","entity_members","entity_contacts_changed","entity_contacts_removed"],["objects","object_contact_members","object_contacts_changed","object_contacts_removed"]]:
        var contacts:Dictionary=held[pair[0]].duplicate();result[pair[0]]=contacts;var members:Dictionary=target[pair[1]];var named={}
        for index in fact.get(pair[3],[]):
            var identity:String=uuids[index]
            if named.has(identity) or not contacts.erase(identity):return failure("A removed contact is one the seat perceives, named once")
            named[identity]=true;members.erase(identity)
        named={}
        for index in fact.get(pair[2],[]):
            var identity:String=uuids[rows.contact_uuid_index[index]]
            if named.has(identity):return failure("A sensory fact names two rows of one identity in one list")
            named[identity]=true;var membership=_members(rows.get("contact_members",[]),index,target.audience.observers.size())
            if not membership.ok:return membership
            contacts[identity]=values.contacts[index];members[identity]=membership.value
    target.spatial_content.merge(fact.get("spatial_effect_content",{}),true)
    var effects:Dictionary=held.spatial_effects.duplicate();var left={};var named={}
    for index in fact.get("spatial_effects_removed",[]):
        var identity:String=uuids[index]
        if named.has(identity) or not effects.has(identity):return failure("A removed effect is one the seat perceives, named once")
        named[identity]=true;left[identity]=[effects[identity],Cells.point_set(effects[identity].positions)];effects.erase(identity);target.effect_members.erase(identity)
    named={}
    for index in fact.get("spatial_effects_patched",[]):
        var identity:String=uuids[rows.patch_uuid_index[index]]
        if named.has(identity) or not effects.has(identity):return failure("A patched effect is one the seat perceives, named once")
        named[identity]=true;var patch:Dictionary=rows.sighting_patches[index];var changed=_patch_effect(effects[identity],patch)
        if not changed.ok:return changed
        effects[identity]=changed.value
        if patch.get("members")!=null:target.effect_members[identity]=patch.members
        left[identity]=[changed.value,Cells.point_set(Cells.mask_points(patch.get("positions_removed",{})))]
    for index in fact.get("spatial_effects_added",[]):
        var identity:String=uuids[rows.sighting_uuid_index[index]]
        if effects.has(identity):return failure("An entering effect is one the seat does not perceive")
        if not target.spatial_content.has(identity):return failure("An entering effect's content was sent before or with it")
        var membership=_members(rows.get("sighting_members",[]),index,target.audience.observers.size())
        if not membership.ok:return membership
        effects[identity]=_effect(rows.sightings[index],target.spatial_content[identity]);target.effect_members[identity]=membership.value
    var retired={}
    for index in fact.get("spatial_effect_cells_retired",[]):
        var identity:String=uuids[rows.retired_uuid_index[index]]
        if retired.has(identity):return failure("A sensory fact names two rows of one identity in one list")
        retired[identity]=Cells.point_set(Cells.mask_points(rows.retired_cells[index]))
    for identity in left:
        var parts:Array=left[identity];var remembered:Variant=target.remembered_effects.get(identity)
        if not parts[1].is_empty() or remembered!=null:
            var cells:Dictionary=parts[1].duplicate()
            if remembered!=null:cells.merge(Cells.point_set(remembered.positions),true)
            var next:Dictionary=parts[0].duplicate();next.positions=Cells.sorted_points(cells);next.visible_volume_positions=[];next.upper_volume_surfaces=[];target.remembered_effects[identity]=next
    for identity in target.remembered_effects.keys():
        var row:Dictionary=target.remembered_effects[identity];var current:Dictionary=effects.get(identity,{});var perceived=Cells.point_set(current.get("positions",[]));var gone:Dictionary=retired.get(identity,{});var kept:Array=[]
        for point in row.positions:
            var key=Cells.key(point)
            if not perceived.has(key) and not gone.has(key) and not (current.get("apparent_presence",row.apparent_presence) and visible.has(key)):kept.append(point)
        if kept.is_empty():target.remembered_effects.erase(identity)
        else:row=row.duplicate();row.positions=kept;target.remembered_effects[identity]=row
    result.spatial_effects=effects
    named={}
    for index in fact.get("light_sources_removed",[]):
        var identity:String=uuids[index]
        if named.has(identity) or not target.light_sources.erase(identity):return failure("A removed light source is one the seat perceives, named once")
        named[identity]=true
    for index in fact.get("light_sources_patched",[]):
        var patch:Dictionary=rows.light_patches[index];var identity:String=uuids[patch.source]
        if not target.light_sources.has(identity):return failure("A patched light source is one the seat perceives")
        var next:Dictionary=target.light_sources[identity].duplicate()
        for field in patch.changes:
            var value:Variant=patch.changes[field]
            if field in ["anchor_entity","anchor_item"]:next[field+"_uuid"]=uuids[value] if value!=null else null
            else:next[field]=value
        target.light_sources[identity]=next
    for index in fact.get("light_sources_added",[]):
        var source:Dictionary=rows.light_sources[index];var identity:String=uuids[source.source]
        if target.light_sources.has(identity):return failure("An entering light source is one the seat does not perceive")
        target.light_sources[identity]=_light(source,uuids)
    if fact.get("observer_position")!=null:result.position=fact.observer_position
    result.paths_dirty=held.paths_dirty or fact.get("paths_dirty",false)
    for field in ["sense_modes","passive_perception","visual_access"]:
        if fact.get(field+"_changed",false) and fact.get(field)!=null:result[field]=fact[field]
    result.sense_modes_key=modes_key(result.sense_modes);target.senses=result
    if fact.get("observer_position")!=null and target.actors.has(target.observer_uuid):
        var actor:Dictionary=target.actors[target.observer_uuid].duplicate();actor.last_visual_position=fact.observer_position;target.actors[target.observer_uuid]=actor;changed_actors[target.observer_uuid]=true
    for index in fact.get("entity_contacts_changed",[]):
        var identity:String=uuids[rows.contact_uuid_index[index]];var contact:Dictionary=values.contacts[index]
        if contact.visual and target.actors.has(identity) and target.actors[identity].present:
            var actor:Dictionary=target.actors[identity].duplicate();actor.last_visual_position=contact.position;target.actors[identity]=actor;changed_actors[identity]=true
    clear_unseen_positions(target,changed_actors)
    cell_context.mask=result.visible;cell_context.points=points;cell_context.members=visible
    return success(target)
