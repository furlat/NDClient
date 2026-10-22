extends RefCounted
## Native world memory: static definitions, authoritative entered supports, and keyed after-values.
const Cells=preload("res://sdk/fold_cells.gd")
const STATE_DEFAULTS={"visual_item_name":null,"boundary_structure":null,"is_open":null,"is_lit":null,"very_bright_radius_feet":null,"bright_radius_feet":null,"dim_radius_feet":null,"stack_count":1,"is_pickable":true,"item_effects":[],"blocks_propagation":false,"is_engaged":null,"surface_residues":[],"current_hit_points":null,"concentration_slots":[],"remnant_state":null,"integrity":"intact","destruction_outcome":null,"construction_geometry":null,"construction_suppressions":[]}
const LOOK_DEFAULTS={"visual_variant_id":null,"contact_passage":"structural","supported_by_uuid":null,"door_mechanism":null,"door_swing":null,"maximum_hit_points":null,"concentration_capacity":0,"construction_owner_uuid":null,"known_to_creator":false}

static func failure(message:String)->Dictionary:return {"ok":false,"error":{"kind":"reducer","message":message}}
static func success(value:Variant)->Dictionary:return {"ok":true,"value":value}

static func static_rows(target:Dictionary,update:Dictionary)->Dictionary:
    target.static=target.static.duplicate()
    for pair in [["tile_looks","look_id","tile_looks"],["residue_materials","residue_id","residues"],["object_looks","item_uuid","object_looks"]]:
        if not update.get(pair[0],[]).is_empty():target.static[pair[2]]=target.static[pair[2]].duplicate()
        for row in update.get(pair[0],[]):
            var store:Dictionary=target.static[pair[2]];var identity=row[pair[1]]
            if store.has(identity) and store[identity]!=row:return failure("A static content id names another value")
            store[identity]=row
    if not update.get("tile_statics",[]).is_empty():target.static.tiles=target.static.tiles.duplicate()
    for row in update.get("tile_statics",[]):target.static.tiles[Cells.key(row.position)]=row
    if not update.get("boundary_structures",[]).is_empty():target.static.boundary_structures=target.static.boundary_structures.duplicate()
    for row in update.get("boundary_structures",[]):
        if target.static.boundary_structures.has(row.structure_id) and target.static.boundary_structures[row.structure_id]!=row.structure:return failure("A boundary structure's content id names another value")
        target.static.boundary_structures[row.structure_id]=row.structure
    return success(target)

static func column(value:Variant,count:int)->Dictionary:
    if value==null:return success({})
    var selected=Cells.row_indices(value.rows,count) if value.get("rows")!=null else success(range(count))
    if not selected.ok:return selected
    if selected.value.size()!=value.values.size() or value.values.is_empty():return failure("A column holds one value per row it selects, and at least one")
    var result={}
    for i in range(selected.value.size()):result[selected.value[i]]=value.values[i]
    return success(result)

static func object_rows(columns:Variant)->Dictionary:
    if columns==null:return success([])
    var count:int=columns.item_uuids.size();var fields={};var placements={}
    if columns.name.size()!=count or columns.map_char.size()!=count:return failure("A dense object column holds one value per row")
    for field in STATE_DEFAULTS.keys()+["members","observed_faces"]:
        var held=column(columns.get(field),count)
        if not held.ok:return held
        fields[field]=held.value
    var at:Variant=columns.get("placements")
    if at!=null:
        var selected=Cells.row_indices(at.rows,count) if at.get("rows")!=null else success(range(count))
        if not selected.ok:return selected
        var indices:Array=selected.value;var defaults={"boundary_direction":null,"tile_uuid":null,"covered_supports":[],"occupies_bands":true,"base_height_steps":0,"orientation":null,"removed_bands":[]};var parts={}
        if at.position.size()!=indices.size() or at.top_height_steps.size()!=indices.size():return failure("A dense placement column holds one value per placed row")
        for field in defaults:
            var held=column(at.get(field),indices.size())
            if not held.ok:return held
            parts[field]=held.value
        for i in range(indices.size()):
            var placement={"position":at.position[i],"top_height_steps":at.top_height_steps[i]}
            for field in defaults:placement[field]=parts[field].get(i,defaults[field])
            placements[indices[i]]=placement
    var result:Array=[]
    for i in range(count):
        var state={"name":columns.name[i],"map_char":columns.map_char[i]}
        for field in STATE_DEFAULTS:state[field]=fields[field].get(i,STATE_DEFAULTS[field])
        result.append({"item_uuid":columns.item_uuids[i],"members":fields.members.get(i),"observed_faces":fields.observed_faces.get(i,[]),"placement":placements.get(i),"state":state})
    return success(result)

static func placement(identity:String,row:Dictionary,statics:Dictionary)->Dictionary:
    var tile:Variant=row.get("tile_uuid")
    if tile==null:
        if not statics.has(Cells.key(row.position)):return failure("A placement without its tile uuid requires the static row of its anchor cell")
        tile=statics[Cells.key(row.position)].tile_uuid
    var result=row.duplicate();result.object_uuid=identity;result.tile_uuid=tile
    result.kind="boundary" if row.get("boundary_direction")!=null else "center"
    if result.get("covered_supports",[]).is_empty():result.covered_supports=[{"position":row.position,"tile_uuid":tile}]
    return success(result)

static func floor_item(look:Dictionary,state:Dictionary,structures:Dictionary)->Dictionary:
    var result=LOOK_DEFAULTS.duplicate();result.merge(look,true);result.merge(STATE_DEFAULTS,true);result.merge(state,true)
    if result.visual_item_name==null:result.visual_item_name=result.name
    var structure:Variant=result.boundary_structure
    if structure!=null:
        if not structures.has(structure):return failure("An object's boundary structure requires its static row")
        result.boundary_structure=structures[structure]
    return success(result)

static func tile_columns(columns:Variant,statics:Dictionary,looks:Dictionary)->Dictionary:
    if columns==null:return success({})
    var points=Cells.mask_points(columns.cells);var data={};var result={}
    for field in ["walking_cost","flying_cost","swimming_cost","burrowing_cost","flags","default_light","resolved_light"]:data[field]=Cells.bytes(columns[field])
    for i in range(points.size()):
        var key=Cells.key(points[i]);var row:Dictionary=statics[key];var look:Dictionary=looks[row.look];var flags=int(data.flags[i])
        var tile={"tile_uuid":row.tile_uuid,"position":points[i],"surface":look.surface,"name":look.name,"blocks_optics":bool(flags&1),"blocks_propagation":bool(flags&2),"surface_kind":["ordinary","stairs","ramp"][(flags>>2)&3],"slope_axis":[null,"north_south","east_west"][(flags>>4)&3],"elevation_steps":columns.elevation_steps[i] if not columns.get("elevation_steps",[]).is_empty() else 0,"condition_names":[],"residues":[]}
        for field in ["walking_cost","flying_cost","swimming_cost","burrowing_cost","default_light","resolved_light"]:tile[field]=int(data[field][i])
        result[key]=tile
    return success(result)

static func support_cells(at:Dictionary)->Dictionary:
    var result={}
    for support in at.covered_supports:
        for height in range(int(at.base_height_steps),int(at.top_height_steps)):
            if not [support.position[0],support.position[1],height] in at.removed_bands:result[Cells.key(support.position)]=support.position;break
    if at.kind=="boundary":
        var delta:Dictionary={"north":[0,1],"south":[0,-1],"east":[1,0],"west":[-1,0]};var offset:Array=delta[at.boundary_direction];var far=[at.position[0]+offset[0],at.position[1]+offset[1]];result[Cells.key(far)]=far
    return result

# Derived query data stays with the exact accepted reducer context, never state.
# A candidate owns only the outer maps/buckets that its actual writes change.
static func fork_context(target:Dictionary,prior:Dictionary={})->Dictionary:
    var reuse:bool=prior.get("initialized",false) and is_same(prior.get("source_objects"),target.objects) and is_same(prior.get("source_connectors"),target.connectors)
    var result:Dictionary=prior.duplicate() if reuse else {"initialized":target.objects.is_empty() and target.connectors.is_empty(),
        "by_support":{},"by_suppression":{},"by_endpoint":{},"object_keys":{},"connector_keys":{},"object_order":{},"next_object_order":0}
    result.source_objects=target.objects;result.source_connectors=target.connectors
    result.owned_maps={};result.owned_buckets={}
    if not reuse:
        for field in ["by_support","by_suppression","by_endpoint","object_keys","connector_keys","object_order"]:result.owned_maps[field]=true
    return result

static func retained_context(context:Dictionary)->Dictionary:
    var result:Dictionary=context.duplicate();result.erase("owned_maps");result.erase("owned_buckets");return result

static func _bind_context(context:Dictionary,target:Dictionary)->void:
    if is_same(context.get("source_objects"),target.objects) and is_same(context.get("source_connectors"),target.connectors):return
    context.clear();context.merge(fork_context(target),true)

static func _own_index(context:Dictionary,field:String)->Dictionary:
    if not context.owned_maps.has(field):context[field]=context[field].duplicate();context.owned_maps[field]=true
    return context[field]

static func _own_bucket(context:Dictionary,field:String,key:String)->Dictionary:
    var table:Dictionary=_own_index(context,field)
    if not context.owned_buckets.has(field):context.owned_buckets[field]={}
    var owned:Dictionary=context.owned_buckets[field]
    if not table.has(key):table[key]={};owned[key]=true
    elif not owned.has(key):table[key]=table[key].duplicate();owned[key]=true
    return table[key]

static func _replace_memberships(context:Dictionary,field:String,identity:String,before:Dictionary,after:Dictionary)->void:
    for key in before:
        if after.has(key):continue
        var bucket:Dictionary=_own_bucket(context,field,key);bucket.erase(identity)
        if bucket.is_empty():context[field].erase(key)
    for key in after:
        if not before.has(key):_own_bucket(context,field,key)[identity]=true

static func _suppression_cells(rows:Array)->Dictionary:
    var result:Dictionary={}
    for row in rows:
        for point in row.positions:result[Cells.key(point)]=true
    return result

static func _index_object(context:Dictionary,identity:String,row:Dictionary,supplied_supports:Variant=null)->void:
    var prior:Dictionary=context.object_keys.get(identity,{})
    var supports:Dictionary
    if supplied_supports!=null:supports=supplied_supports
    elif not prior.is_empty() and prior.placement==row.placement:supports=prior.support_keys
    else:supports=support_cells(row.placement)
    var suppressions:Array=row.item.construction_suppressions
    var cells:Dictionary=prior.suppression_keys if not prior.is_empty() and prior.suppressions==suppressions else _suppression_cells(suppressions)
    _replace_memberships(context,"by_support",identity,prior.get("support_keys",{}),supports)
    _replace_memberships(context,"by_suppression",identity,prior.get("suppression_keys",{}),cells)
    _own_index(context,"object_keys")[identity]={"placement":row.placement,"suppressions":suppressions,"support_keys":supports,"suppression_keys":cells}
    if not context.object_order.has(identity):
        _own_index(context,"object_order")[identity]=int(context.next_object_order);context.next_object_order+=1

static func _forget_object(context:Dictionary,identity:String)->void:
    var prior:Dictionary=context.object_keys.get(identity,{})
    _replace_memberships(context,"by_support",identity,prior.get("support_keys",{}),{})
    _replace_memberships(context,"by_suppression",identity,prior.get("suppression_keys",{}),{})
    _own_index(context,"object_keys").erase(identity);_own_index(context,"object_order").erase(identity)

static func _index_connector(context:Dictionary,identity:String,row:Dictionary)->void:
    var cells:Dictionary=Cells.point_set(row.endpoints)
    _replace_memberships(context,"by_endpoint",identity,context.connector_keys.get(identity,{}),cells)
    _own_index(context,"connector_keys")[identity]=cells

static func _forget_connector(context:Dictionary,identity:String)->void:
    _replace_memberships(context,"by_endpoint",identity,context.connector_keys.get(identity,{}),{})
    _own_index(context,"connector_keys").erase(identity)

static func _query_members(table:Dictionary,entered:Dictionary)->Dictionary:
    var result:Dictionary={}
    for key in entered:
        for identity in table.get(key,{}):result[identity]=true
    return result

static func _entered_candidates(context:Dictionary,target:Dictionary,entered:Dictionary)->Dictionary:
    var support:Dictionary=_query_members(context.by_support,entered)
    var suppression:Dictionary=_query_members(context.by_suppression,entered)
    var objects:Dictionary=support.duplicate();objects.merge(suppression,true)
    var connectors:Dictionary=_query_members(context.by_endpoint,entered)
    # Cheap selected-row consistency only. Completeness is established by the
    # accepted owner and writer closure, not a hidden whole-store validation.
    for identity in objects:
        if not target.objects.has(identity) or not context.object_keys.has(identity) or not context.object_order.has(identity):return {}
    for identity in connectors:
        if not target.connectors.has(identity) or not context.connector_keys.has(identity):return {}
    var ordered:Array=objects.keys();ordered.sort_custom(func(a,b):return int(context.object_order[a])<int(context.object_order[b]))
    return {"objects":ordered,"support":support,"suppression":suppression,"connectors":connectors}

static func _merged_faces(prior:Array,current:Array,faces:Array)->Dictionary:
    var kept={}
    for residue in prior:
        var remaining:Array=[]
        for face in residue.faces:
            if not face in faces:remaining.append(face)
        if not remaining.is_empty():var row=residue.duplicate();row.faces=remaining;kept[row.condition_uuid]=row
    for residue in current:
        for face in residue.faces:
            if not face in faces:return failure("An object row's residues lie on its observed faces")
        if residue.faces.is_empty():continue
        var found:Dictionary={}
        for face in residue.faces:found[face]=true
        for face in kept.get(residue.condition_uuid,{}).get("faces",[]):found[face]=true
        var row=residue.duplicate();row.faces=found.keys();row.faces.sort();kept[row.condition_uuid]=row
    var keys=kept.keys();keys.sort();var result:Array=[]
    for identity in keys:result.append(kept[identity])
    return success(result)

static func _object(target:Dictionary,row:Dictionary,prior_objects:Dictionary,order:Array=[])->Dictionary:
    var identity:String=row.item_uuid;var previous:Variant=target.objects.get(identity);var members:Variant=row.members
    if members==null:
        if target.audience.observers.size()!=1:return failure("A seat with several observers names the members of each object row")
        members=1
    if not target.static.object_looks.has(identity):return failure("An object's first row requires its look")
    var at=placement(identity,row.placement,target.static.tiles) if row.placement!=null else success(previous.placement if previous!=null else null)
    if not at.ok:return at
    if at.value==null:return failure("An object's first row requires its placement")
    var item=floor_item(target.static.object_looks[identity],row.state,target.static.boundary_structures)
    if not item.ok:return item
    var merged=_merged_faces(previous.item.surface_residues if previous!=null else [],item.value.surface_residues,row.observed_faces)
    if not merged.ok:return merged
    item.value.surface_residues=merged.value
    var suppressions:Array=item.value.construction_suppressions.duplicate();var providers={}
    for value in suppressions:providers[value.provider_uuid]=true
    for value in previous.item.construction_suppressions if previous!=null else []:
        if not providers.has(value.provider_uuid):suppressions.append(value)
    item.value.construction_suppressions=suppressions
    if not prior_objects.has(identity):prior_objects[identity]=previous
    if previous==null:order.append({"kind":"objects","id":identity,"remove":false})
    target.objects[identity]={"placement":at.value,"item":item.value,"contained_items":previous.contained_items if previous!=null else null};target.object_members[identity]=members
    return success(target)

static func _contents(target:Dictionary,update:Dictionary,prior_objects:Dictionary)->Dictionary:
    for family in ["contents","contents_changed"]:
        for row in update.get(family,[]):
            var held:Variant=target.objects.get(row.container_uuid)
            if held==null:return failure("Contents require their container")
            var items={}
            if family=="contents_changed":
                if held.contained_items==null:return failure("A contents change requires contents the client holds")
                for value in held.contained_items:items[value.item_uuid]=value
                for identity in row.get("removed",[]):items.erase(identity)
            for value in row.get("items",[]) if family=="contents" else row.get("upserted",[]):
                if not target.static.object_looks.has(value.item_uuid):return failure("A contained item requires its look")
                var joined=floor_item(target.static.object_looks[value.item_uuid],value.state,target.static.boundary_structures)
                if not joined.ok:return joined
                items[value.item_uuid]=joined.value
            var keys=items.keys();keys.sort();var values:Array=[]
            for identity in keys:values.append(items[identity])
            if not prior_objects.has(row.container_uuid):prior_objects[row.container_uuid]=held
            var next:Dictionary=held.duplicate();next.contained_items=values;target.objects[row.container_uuid]=next
    return success(target)

static func _tiles(target:Dictionary,update:Dictionary,prior_tiles:Dictionary)->Dictionary:
    for row in update.get("tile_changes",[]):
        var key=Cells.key(row.position)
        if not target.tiles.has(key):return failure("Tile field update requires an already known tile")
        if not prior_tiles.has(key):prior_tiles[key]=target.tiles[key]
        var tile:Dictionary=target.tiles[key].duplicate();tile.merge(row.changes,true);target.tiles[key]=tile
    var light=Cells.values_map(update.get("resolved_light",{}))
    for key in light:
        if not target.tiles.has(key):return failure("Tile field update requires an already known tile")
        if not prior_tiles.has(key):prior_tiles[key]=target.tiles[key]
        var tile:Dictionary=target.tiles[key].duplicate();tile.resolved_light=light[key];target.tiles[key]=tile
    var own={};var materials={}
    for family in ["tile_conditions","residues","residues_removed"]:
        for row in update.get(family,[]):
            var key=Cells.key(row.position)
            if not target.tiles.has(key):return failure("Tile field update requires an already known tile")
            if not materials.has(key):
                var tile:Dictionary=target.tiles[key];var names:Array=tile.condition_names.slice(0,tile.condition_names.size()-tile.residues.size());own[key]=names;materials[key]={}
                for residue in tile.residues:materials[key][residue.residue_id]=residue
            var rows:Dictionary=materials[key]
            if family=="tile_conditions":own[key]=row.names;continue
            if family=="residues_removed":
                if not rows.erase(row.residue_id):return failure("A residue removal names a residue the client holds")
                continue
            if not target.static.residues.has(row.residue_id):return failure("A residue requires its material's static row")
            var material:Dictionary=target.static.residues[row.residue_id];var existing:Variant=rows.get(row.residue_id)
            if row.get("condition_uuid")!=null:
                if row.get("amount")==null:return failure("A whole residue row carries its amount")
                existing={"condition_uuid":row.condition_uuid,"residue_id":row.residue_id,"description":material.description,"amount":row.amount,"max_amount":material.max_amount,"contributions":[]}
            if existing==null:return failure("A residue the client does not hold arrives whole")
            var contributions:Array=existing.contributions.duplicate()
            for change in row.get("contributions",[]):
                if change.index<contributions.size():contributions[change.index]=change.contribution
                elif change.index==contributions.size():contributions.append(change.contribution)
                else:return failure("A residue contribution is set at an index it holds or appended")
            var next:Dictionary=existing.duplicate();next.contributions=contributions
            if row.get("amount")!=null:next.amount=row.amount
            rows[row.residue_id]=next
    for key in materials:
        var keys=materials[key].keys();keys.sort();var rows:Array=[];var names:Array=own[key].duplicate()
        for identity in keys:rows.append(materials[key][identity]);names.append(target.static.residues[identity].name)
        if not prior_tiles.has(key):prior_tiles[key]=target.tiles[key]
        var tile:Dictionary=target.tiles[key].duplicate();tile.residues=rows;tile.condition_names=names;target.tiles[key]=tile
    return success(target)

static func fold(target:Dictionary,update:Dictionary,disclosed:Dictionary={},world_context:Dictionary={})->Dictionary:
    _bind_context(world_context,target)
    # Keep only the first value of rows this update actually writes or erases.
    # Final comparison handles repeated writes and remove/re-add without
    # copying or diffing the unrelated retained tile/object stores.
    var prior_tiles:Dictionary={};var prior_objects:Dictionary={};var order:Array=[]
    var result=static_rows(target,update)
    if not result.ok:return result
    for identity in update.get("objects_removed",[]):
        if not prior_objects.has(identity):prior_objects[identity]=target.objects.get(identity)
        if not target.objects.erase(identity):return failure("An object removal names an object the client holds")
        target.object_members.erase(identity)
        if world_context.initialized:_forget_object(world_context,identity)
        order.append({"kind":"objects","id":identity,"remove":true})
    for identity in update.get("connectors_removed",[]):
        if not target.connectors.erase(identity):return failure("A connector removal names a connector the client holds")
        if world_context.initialized:_forget_connector(world_context,identity)
    var entered=Cells.point_set(Cells.mask_points(update.get("entered",{})))
    if not entered.is_empty():
        var unchanged=Cells.point_set(Cells.mask_points(update.get("tiles_unchanged",{})));var kept={}
        for key in unchanged:
            if not entered.has(key) or not target.tiles.has(key):return failure("An unchanged tile is an entered cell the client holds")
        for identity in update.get("objects_unchanged",[]):
            if not target.objects.has(identity):return failure("An unchanged object is one the client holds")
            kept[identity]=true
        for key in entered:
            if not unchanged.has(key) and target.tiles.has(key):
                if not prior_tiles.has(key):prior_tiles[key]=target.tiles[key]
                target.tiles.erase(key)
                order.append({"kind":"tiles","id":key,"remove":true})
        var tiles=tile_columns(update.get("tile_columns"),target.static.tiles,target.static.tile_looks)
        if not tiles.ok:return tiles
        for key in tiles.value:
            if not entered.has(key) or unchanged.has(key):return failure("Tile columns describe entered cells only, none of them unchanged")
            if not prior_tiles.has(key):prior_tiles[key]=target.tiles.get(key)
            if not target.tiles.has(key):order.append({"kind":"tiles","id":key,"remove":false})
            target.tiles[key]=tiles.value[key]
        var resent:Dictionary={}
        for identity in (update.objects.item_uuids if update.get("objects")!=null else []):resent[identity]=true
        var candidates:Dictionary={}
        if world_context.initialized:candidates=_entered_candidates(world_context,target,entered)
        var cold:bool=candidates.is_empty()
        if cold:
            # Keep the original complete scan/refusal path for a missing or
            # mismatched owner; seed only this private candidate as it visits.
            world_context.clear();world_context.merge(fork_context(target),true);world_context.initialized=false
        var identities:Array=target.objects.keys() if cold else candidates.objects
        for identity in identities:
            var held:Dictionary=target.objects[identity];var supports:Dictionary={};var touched:bool=false
            if cold:
                supports=support_cells(held.placement)
                for key in supports:
                    if entered.has(key):touched=true;break
            else:touched=candidates.support.has(identity)
            if not resent.has(identity) and not kept.has(identity) and touched:
                if not prior_objects.has(identity):prior_objects[identity]=held
                target.objects.erase(identity);target.object_members.erase(identity)
                if not cold:_forget_object(world_context,identity)
                order.append({"kind":"objects","id":identity,"remove":true});continue
            if cold or candidates.suppression.has(identity):
                var suppressions:Array=[];var changed:bool=false
                for row in held.item.construction_suppressions:
                    var points:Array=[]
                    for point in row.positions:
                        if entered.has(Cells.key(point)):changed=true
                        else:points.append(point)
                    var next:Dictionary=row.duplicate();next.positions=points;suppressions.append(next)
                if changed:
                    if not prior_objects.has(identity):prior_objects[identity]=held
                    var next:Dictionary=held.duplicate();next.item=held.item.duplicate();next.item.construction_suppressions=suppressions;target.objects[identity]=next
                    if not cold:_index_object(world_context,identity,next)
            if cold:_index_object(world_context,identity,target.objects[identity],supports)
        if cold:
            for identity in target.connectors.keys():
                var removed:bool=false
                for point in target.connectors[identity].endpoints:
                    if entered.has(Cells.key(point)):target.connectors.erase(identity);removed=true;break
                if not removed:_index_connector(world_context,identity,target.connectors[identity])
            # Both old scans are complete. Later upserts must maintain this
            # private index even though the operation is not accepted yet.
            world_context.initialized=true
        else:
            for identity in candidates.connectors:
                target.connectors.erase(identity);_forget_connector(world_context,identity)
    var decoded=object_rows(update.get("objects"))
    if not decoded.ok:return decoded
    for row in decoded.value:
        result=_object(target,row,prior_objects,order)
        if not result.ok:return result
        if world_context.initialized:_index_object(world_context,str(row.item_uuid),target.objects[row.item_uuid])
    result=_contents(target,update,prior_objects)
    if not result.ok:return result
    result=_tiles(target,update,prior_tiles)
    if not result.ok:return result
    for row in update.get("connectors",[]):
        target.connectors[row.connector_uuid]=row
        if world_context.initialized:_index_connector(world_context,str(row.connector_uuid),row)
    disclosed.tiles={};disclosed.tiles_removed=[];disclosed.objects={};disclosed.objects_removed=[]
    for key in prior_tiles:
        var current:Variant=target.tiles.get(key)
        if current==null:
            if prior_tiles[key]!=null:disclosed.tiles_removed.append(key)
        elif prior_tiles[key]==null or not is_same(prior_tiles[key],current):disclosed.tiles[key]=current
    for identity in prior_objects:
        var current:Variant=target.objects.get(identity)
        if current==null:
            if prior_objects[identity]!=null:disclosed.objects_removed.append(identity)
        elif prior_objects[identity]==null or not is_same(prior_objects[identity],current):disclosed.objects[identity]=current
    disclosed.changes=disclosed.tiles.keys();disclosed.order=order
    return success(target)
