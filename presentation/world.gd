extends RefCounted
# Adapter from disclosed SDK geometry into existing authored placement rows.
const Catalog = preload("res://source_catalog.gd")
const Cells = preload("res://sdk/fold_cells.gd")
const SpatialInputs = preload("res://presentation/spatial_inputs.gd")
const Placement=preload("res://placement.gd")

# The few current immutable sensory masks are shared by world/camera readers.
# This bounded cache is optical derived data, never a second canonical state.
static var _mask_views:Array=[]
static var _mask_mutex:=Mutex.new()
static func visible_positions(state:Dictionary)->Array:
    var senses:Variant=state.get("senses")
    if senses==null:return []
    var mask:Dictionary=senses.get("visible",{})
    _mask_mutex.lock()
    var view:Dictionary={}
    for entry in _mask_views:
        if is_same(entry.mask,mask):view=entry;break
    if view.is_empty():
        view={"mask":mask}
        _mask_views.append(view)
        if _mask_views.size()>4:_mask_views.pop_front()
    if not view.has("points"):
        if not view.has("data"):view.data=Cells.bytes(mask.get("bits",""))
        var data:PackedByteArray=view.data
        var points:Array=[];var height:int=int(mask.get("height",0))
        # Exact Cells.mask_points ordering, borrowing the same decoded bytes
        # already retained for bounded neighbor queries when available.
        for i in range(int(mask.get("width",0))*height):
            if i/8<data.size() and (int(data[i/8])&(1<<(i%8)))!=0:
                points.append([int(mask.get("x0",0))+i/height,int(mask.get("y0",0))+i%height])
        points.make_read_only();view.points=points
    var result:Array=view.points
    _mask_mutex.unlock()
    return result

static func visible_mask_bytes(mask:Dictionary)->PackedByteArray:
    # Extend the existing four-entry immutable-mask owner. Do not create a
    # second population/cache or decode this whole mask for each residue row.
    _mask_mutex.lock()
    var view:Dictionary={}
    for entry in _mask_views:
        if is_same(entry.mask,mask):view=entry;break
    if view.is_empty():
        view={"mask":mask}
        _mask_views.append(view)
        if _mask_views.size()>4:_mask_views.pop_front()
    if not view.has("data"):view.data=Cells.bytes(mask.get("bits",""))
    var result:PackedByteArray=view.data
    _mask_mutex.unlock()
    return result

static func cell_key(position: Array) -> String:
    return "%d,%d" % [position[0],position[1]]

## A body delegation is an exact current public identity join. Content alone,
## proximity and remembered placement cannot suppress an unrelated object.
static func native_object_owner(identity:String,item_id:String,senses:Dictionary,index:Dictionary,placement:Dictionary={})->String:
    var contents:Array=index.get("native_object_owners",{}).get(item_id,[])
    if contents.is_empty():return ""
    var matched:String=""
    for key in senses.get("spatial_effects",{}):
        var effect:Dictionary=senses.spatial_effects[key]
        var content:String=SpatialInputs.content_id(effect)
        # Current sensory membership admits concealed traps too; their
        # apparent_presence controls absence/memory, not this disclosed cut.
        if effect.get("anchor_item_uuid")!=identity or content not in contents \
            or SpatialInputs.admitted_cells(effect).is_empty():continue
        var program:Dictionary=index.get("spatial_media",{}).get(content,{})
        if effect.get("anchor_position")==null and not program.get("native_world_media",false):continue
        if program.get("native_world_media",false) and program.get("requires_object_anchor",false):
            if placement.is_empty() or not senses.get("objects",{}).get(identity,{}).get("visual",false):continue
            var direction:Variant=effect.get("direction")
            var orientation:Variant=placement.get("orientation")
            if orientation==null:orientation=placement.get("boundary_direction")
            if direction==null and not Placement.DIRECTIONS.has(str(orientation)):continue
            if direction==[0,0]:continue
        if not matched.is_empty():return ""
        matched=str(key)
    return matched

## These are visual rows owned by disclosed spatial UUIDs, not SDK objects.
## Source images, state keys and placement policy are declared in GroundSurface.
static func spatial_projection(state:Dictionary,cache:Dictionary)->Dictionary:
    var result:Array=[];var missing:Array=[]
    var senses:Dictionary=state.get("senses",{}) if state.get("senses")!=null else {}
    var sources:Dictionary=Catalog.environment_index(cache).get("spatial_media",{})
    for identity in senses.get("spatial_effects",{}):
        var effect:Dictionary=senses.spatial_effects[identity]
        var content:String=SpatialInputs.content_id(effect)
        var program:Dictionary=sources.get(content,{})
        if not program.get("native_world_media",false):continue
        var cells:Array=SpatialInputs.admitted_cells(effect)
        if cells.is_empty():continue
        var positions:Array=cells
        var support_height:Variant=null
        var subject_uuid:Variant=null
        var object_orientation:Variant=null
        if program.get("requires_object_anchor",false):
            var object_id:Variant=effect.get("anchor_item_uuid")
            var object:Dictionary=state.get("objects",{}).get(object_id,{})
            if object.is_empty() or not senses.get("objects",{}).get(object_id,{}).get("visual",false):
                missing.append("world_media_object_anchor:"+str(identity));continue
            positions=[object.placement.position];support_height=object.placement.base_height_steps;subject_uuid=object_id
            object_orientation=object.placement.get("orientation")
            if object_orientation==null:object_orientation=object.placement.get("boundary_direction")
        elif program.get("placement")=="anchor":
            var anchor:Variant=effect.get("anchor_position")
            if anchor==null:missing.append("world_media_anchor:"+str(identity));continue
            positions=[anchor]
        var direction:Variant=effect.get("direction")
        if direction==null:
            var declared:String=str(object_orientation) if object_orientation!=null else str(program.get("default_orientation",""))
            var vector:Vector2=Placement.DIRECTIONS.get(declared,Vector2.ZERO)
            if vector==Vector2.ZERO:missing.append("world_media_direction:"+str(identity));continue
            direction=[vector.x,vector.y]
        if direction==[0,0]:missing.append("world_media_direction:"+str(identity));continue
        var column:int=posmod(floori(atan2(float(direction[1]),float(direction[0]))/(PI/4.0)+0.5),8)
        var orientation:String=["east","north","west","south"][floori(float(column)/2.0)]
        var raw:Variant=effect.get(str(program.get("state_field","trap_state")))
        var token:String=JSON.stringify(raw) if raw is bool else str(raw)
        var frame:int=int(program.get("state_frames",{}).get(token,0))
        var roles:Array=["entrance","hatch","hatch_front"].filter(func(role):return program.get("roles",{}).has(role)) if program.get("kind")=="portal" else ["body"]
        for position in positions:
            var tile:Dictionary=state.get("tiles",{}).get(cell_key(position),{})
            if tile.is_empty() and support_height==null:missing.append("world_media_support:"+str(identity));continue
            var offset:Array=program.get("origin_offset",[0.0,0.0])
            var point:Array=[position[0]+offset[0]*direction[0]-offset[1]*direction[1],position[1]+offset[0]*direction[1]+offset[1]*direction[0]]
            for role in roles:
                var source:Dictionary=program.get("roles",{}).get(role,{})
                var initial_frame:int=frame
                if program.get("kind")=="portal":
                    initial_frame=int(source.get("opening_frames",0)) if role=="entrance" and token=="activated" else int(source.get("opening_frames",0))+int(source.get("hold_frames",0))+maxi(0,int(source.get("closing_frames",0))-1) if role=="entrance" else int(source.get("opening",[0]).back()) if token=="activated" else 0
                result.append({"id":"spatial:"+str(identity)+":"+cell_key(position)+":"+role,"kind":"resource","position":point,
                    "base_height_steps":float(tile.elevation_steps) if support_height==null else float(support_height),"orientation":orientation,"boundaries":[],"layer":2 if role=="hatch_front" else 1,
                    "spatial_effect_uuid":str(identity),"world_media_content":content,"world_media_role":role,"world_media_frame":initial_frame,
                    "world_media_state":token,"unlit":bool(source.get("unlit",false)),"subject_uuid":subject_uuid,"presentation_only":subject_uuid==null})
    return {"rows":result,"unresolved":missing}

## Continuous floor artwork belongs to actual tile residue identities. Only
## disclosed, currently observed same-height neighbors may join its edge mask.
static func residue_tile_rows(state:Dictionary,key:String,profiles:Dictionary,visible:Dictionary)->Array:
    var tile:Dictionary=state.get("tiles",{}).get(key,{})
    if tile.is_empty():return []
    var rows:Array=[]
    for residue in tile.get("residues",[]):
        var profile:Dictionary=profiles.get(residue.residue_id,{})
        if profile.is_empty() or float(residue.amount)<=0. or residue.get("condition_uuid")==null:continue
        var connected:int=0;var bit:int=0
        for dx in [-1,0,1]:
            for dy in [-1,0,1]:
                if dx==0 and dy==0:continue
                var neighbor_key:String=cell_key([tile.position[0]+dx,tile.position[1]+dy])
                var neighbor:Dictionary=state.tiles.get(neighbor_key,{})
                if visible.has(neighbor_key) and not neighbor.is_empty() and neighbor.elevation_steps==tile.elevation_steps:
                    for other in neighbor.get("residues",[]):
                        if other.residue_id==residue.residue_id and float(other.amount)>0.:connected|=1<<bit;break
                bit+=1
        rows.append({"id":"residue:"+str(tile.tile_uuid)+":"+str(residue.condition_uuid),"kind":"resource",
            "position":tile.position,"base_height_steps":tile.elevation_steps,"orientation":"east","boundaries":[],
            "layer":1,"sort_role":"covering","presentation_only":true,"tile_uuid":tile.tile_uuid,
            "residue_uuid":residue.condition_uuid,"residue_id":residue.residue_id,"floor_motifs":profile,
            "connected_neighbors":connected,"affine":[2.,1.,-2.,1.],"ground_projection":true})
    return rows

static func residue_projection(state:Dictionary,cache:Dictionary)->Array:
    var tiles:Dictionary=state.get("tiles",{})
    if tiles.is_empty():return []
    var profiles:Dictionary=Catalog.environment_index(cache).get("floor_residue_sources",{})
    if profiles.is_empty():return []
    var selected:Array=[]
    for key in tiles:
        for residue in tiles[key].get("residues",[]):
            if profiles.has(residue.residue_id) and float(residue.amount)>0.0 and residue.get("condition_uuid")!=null:
                selected.append(key)
                break
    if selected.is_empty():return []
    var senses:Variant=state.get("senses")
    var mask:Dictionary=senses.get("visible",Cells.EMPTY) if senses!=null else Cells.EMPTY
    # Exact Cells.contains bit addressing. The existing mask-view owner
    # decodes each immutable mask once while it remains in that bounded owner.
    var data:PackedByteArray=visible_mask_bytes(mask)
    var height:int=int(mask.get("height",0));var width:int=int(mask.get("width",0))
    var visible:Dictionary={}
    for key in selected:
        var position:Array=tiles[key].position
        for dx in [-1,0,1]:
            for dy in [-1,0,1]:
                if dx==0 and dy==0:continue
                var point:Array=[position[0]+dx,position[1]+dy]
                var x:int=int(point[0])-int(mask.get("x0",0))
                var y:int=int(point[1])-int(mask.get("y0",0))
                if x<0 or y<0 or x>=width or y>=height:continue
                var index:int=x*height+y
                if index/8<data.size() and (int(data[index/8])&(1<<(index%8)))!=0:
                    visible[cell_key(point)]=point
    var result:Array=[]
    for key in selected:result.append_array(residue_tile_rows(state,key,profiles,visible))
    return result

## Same two disclosed incident supports as native boundary_sides. This is a
## visibility cut only; remembered marked faces remain in the SDK after-value.
static func residue_observed_faces(place:Dictionary,visible:Dictionary)->Array:
    var direction:Variant=place.get("boundary_direction")
    if direction==null:return []
    var delta:Array={"north":[0,1],"south":[0,-1],"east":[1,0],"west":[-1,0]}[direction]
    var opposite:String={"north":"south","south":"north","east":"west","west":"east"}[direction]
    var result:Array=[]
    if Cells.contains(visible,place.position):result.append(opposite)
    if Cells.contains(visible,[place.position[0]+delta[0],place.position[1]+delta[1]]):result.append(direction)
    return result

static func rows(state: Dictionary, cache: Dictionary,include_spatial:bool=true) -> Dictionary:
    var world = Catalog.environment_world(cache)
    var index = Catalog.environment_index(cache)
    var senses: Dictionary = state.get("senses",{}) if state.get("senses") != null else {}
    var result: Array = []
    var missing: Array = []
    for tile in state.tiles.values():
        var material: String = tile.surface.base_material
        if not world.terrain.has(material): missing.append("terrain:"+material); continue
        result.append({"id":tile.tile_uuid,"kind":"terrain","material":material,"position":tile.position,
            "base_height_steps":tile.elevation_steps,"layer":0,"orientation":"east","boundaries":[]})
    for id in state.objects:
        var object: Dictionary = state.objects[id]
        var place: Dictionary = object.placement
        var item: Dictionary = object.item
        if not native_object_owner(str(id),str(item.item_id),senses,index,place).is_empty():continue
        var direction: String = place.get("boundary_direction") if place.get("boundary_direction") != null else (place.get("orientation") if place.get("orientation") != null else "east")
        var row = {"id":id,"position":place.position,"base_height_steps":place.base_height_steps,
            "orientation":direction,"boundaries":[direction] if place.kind=="boundary" else [],"layer":1,"item_id":item.item_id}
        if index.doors.has(item.item_id):
            var opened: bool = item.get("is_open",false)
            var swing: String = item.door_swing if item.get("door_swing") != null else "inward"
            if item.get("integrity")=="destroyed":
                # Destruction clears collision independently of the open flag.
                # The retained pre-destruction pose selects the authored wreck.
                var remnant: Dictionary = item.remnant_state if item.get("remnant_state") != null else {}
                opened = remnant.get("door_open",opened)
                if remnant.get("door_swing") != null: swing = remnant.door_swing
                row.destroyed = true
                row.outcome = item.destruction_outcome
            row.merge({"kind":"door","asset":item.item_id,"state":"open."+swing if opened else "closed"})
        elif index.props.has(item.item_id):
            var owner = index.props[item.item_id]
            # Prop owners name the backend field and use its JSON value as the
            # bank key (for example is_open -> "false" / "true" for chests).
            var mode := "default"
            if owner.has("state_field"):
                var value = item.get(owner.state_field)
                if value != null: mode = JSON.stringify(value) if value is bool else str(value)
            row.merge({"kind":"prop","asset":item.item_id,"state":mode})
        elif index.traps.has(item.item_id):
            row.merge({"kind":"trap","asset":item.item_id,"state":"activated" if item.get("is_engaged",false) else "ready"})
        elif item.get("boundary_structure") != null:
            var structure: Dictionary = item.boundary_structure
            # Doors and fences without art of their own draw the material's wall pieces (environment source stand-ins).
            if structure.structure in ["wall","retaining_wall","door","fence"] and world.has(structure.material+"_wall_straight"):
                row.merge({"kind":"wall","material":structure.material,"top_height_steps":place.top_height_steps})
            elif structure.structure in ["cliff","embankment"]:
                row.merge({"kind":"cliff","material":structure.material,"top_height_steps":place.top_height_steps})
            else: missing.append("structure:"+item.item_id); continue
        elif world.props.has(item.item_id):
            var prop: Dictionary = world.props[item.item_id]
            var views: Dictionary = prop.body_by_pose
            if prop.has("state_field") and item.get(prop.state_field,false): views = prop.get("active_body_by_pose",views)
            row.merge({"kind":"resource","views":views,"asset":views.e})
            if prop.has("lit_animation") and item.get("is_lit") == true and senses.get("objects",{}).get(id,{}).get("visual",false):
                row.lit_animation = prop.lit_animation
        else:
            var ground:Dictionary=Catalog.ground_equipment(item,cache)
            if ground.is_empty():
                missing.append("object:"+item.item_id)
                continue
            row.merge({"kind":"ground_equipment","ground_equipment":ground})
        if item.get("boundary_structure")!=null:
            var structure:Dictionary=item.boundary_structure
            # Source ownership chooses the registered artwork; disclosed
            # structure owns wall eligibility and height independently of it.
            if row.kind=="prop" and structure.structure in ["wall","retaining_wall","door","fence","cliff","embankment"]:
                row.source_kind=row.kind
                row.kind="cliff" if structure.structure in ["cliff","embankment"] else "wall"
                row.material=structure.material
                row.top_height_steps=place.top_height_steps
            if structure.structure in ["cliff","embankment"]:
                # The upper rim sorts at the disclosed top; contact stays at base.
                row.top_height_steps=place.top_height_steps
                row.sort_height_steps=place.top_height_steps
        if item.get("integrity")=="destroyed" and row.kind in ["prop","wall"]:
            row.destroyed = true
            if item.get("destruction_outcome") != null: row.outcome = item.destruction_outcome
        if not item.get("surface_residues",[]).is_empty() and place.get("boundary_direction")!=null:
            row.surface_residues=item.surface_residues
            row.residue_observed_faces=residue_observed_faces(place,senses.get("visible",Cells.EMPTY))
        result.append(row)
    result.append_array(residue_projection(state,cache))
    if include_spatial:
        var spatial:Dictionary=spatial_projection(state,cache)
        result.append_array(spatial.rows);missing.append_array(spatial.unresolved)
    return {"rows":result,"visual_rows":join_walls(result,world),"unresolved":missing}

static func cached_rows(state: Dictionary, cache: Dictionary, retained: Dictionary) -> Dictionary:
    # SDK after-values are immutable. Keep only this world's current records;
    # changes are still resolved through the original source adapter above.
    var senses: Dictionary = state.get("senses",{}) if state.get("senses") != null else {}
    var old: Dictionary = retained.get("records",{})
    var index:Dictionary=Catalog.environment_index(cache)
    var records = {}; var result: Array = []; var walls: Array = []; var missing: Array = []
    var changed = old.size()!=state.tiles.size()+state.objects.size()
    var resolved = 0
    var boundary_dirty = retained.get("object_ids",[])!=state.objects.keys() or not retained.has("boundaries")
    retained.object_ids = state.objects.keys()
    for kind in ["tiles","objects"]:
        for id in state[kind]:
            var source: Dictionary = state[kind][id]
            var key = kind+":"+id
            var sight: bool = kind=="objects" and senses.get("objects",{}).get(id,{}).get("visual",false)
            var record: Dictionary = old.get(key,{})
            var native_owner:String=native_object_owner(str(id),str(source.item.item_id),senses,index,source.placement) if kind=="objects" else ""
            var faces:Array=residue_observed_faces(source.placement,senses.get("visible",Cells.EMPTY)) if kind=="objects" and not source.item.get("surface_residues",[]).is_empty() else []
            if record.is_empty() or not is_same(record.source,source) or record.sight!=sight or record.get("native_owner","")!=native_owner or record.get("residue_faces",[])!=faces:
                if kind=="objects" and (record.is_empty() or not is_same(record.source,source)): boundary_dirty = true
                var input = {"tiles":{},"objects":{},"senses":senses}
                input[kind][id] = source
                var derived = rows(input,cache,false)
                var row: Dictionary = derived.rows[0] if not derived.rows.is_empty() else {}
                if record.is_empty() or row!=record.row or derived.unresolved!=record.missing: changed = true
                # Reuse equal projections when HP/resources change without art.
                elif not row.is_empty(): row = record.row
                record = {"source":source,"sight":sight,"native_owner":native_owner,"residue_faces":faces,"row":row,"missing":derived.unresolved}
                resolved += 1
            records[key] = record
            missing.append_array(record.missing)
            if record.row.is_empty(): continue
            result.append(record.row)
            if record.row.kind=="wall": walls.append(record.row)
    retained.records = records
    var spatial:Dictionary=spatial_projection(state,cache)
    if retained.get("spatial_projection",{})!=spatial:changed=true
    retained.spatial_projection=spatial
    var residues:Array=residue_projection(state,cache)
    if retained.get("residue_projection",[])!=residues:changed=true
    retained.residue_projection=residues;result.append_array(residues)
    result.append_array(spatial.rows);missing.append_array(spatial.unresolved)
    retained.resolved = resolved
    # Preserve insertion order too: it is the old equal-projection floor tie.
    var ids = records.keys()
    if retained.get("ids",[])!=ids: changed = true
    retained.ids = ids
    if changed or not retained.has("result"):
        if retained.get("walls",[])!=walls:
            var joined = join_walls(walls,Catalog.environment_world(cache))
            var assembly = {}
            for row in walls: assembly[row.id] = {}
            for row in joined: assembly[row.id] = row
            retained.assembly = assembly
            retained.walls = walls
        var visual: Array = []
        for row in result:
            var assembled: Dictionary = retained.get("assembly",{}).get(row.id,row)
            if not assembled.is_empty(): visual.append(assembled)
        retained.result = {"rows":result,"visual_rows":visual,"unresolved":missing}
    if boundary_dirty: retained.boundaries = boundary_index(state)
    retained.changed = changed
    return retained.result

# These indexes and result arrays belong to the publication owner. A preparation
# task may borrow them read-only until it finishes, including after cancellation.
# Patches own only changed records/cells. apply_changes is the ownership handoff;
# no presenter may mutate source rows or keep a result array as a private snapshot.
const ROW_INDEXES = ["tile_rows","object_rows","spatial_rows","residue_rows","residue_cells","missing","wall_cells","assembly",
    "boundaries","boundary_cells","lit_candidates","native_candidates","residue_candidates","negative","terrain_materials","object_ranks"]

static func projected_index(base: Dictionary, patch: Dictionary, index: String, key: String, fallback: Variant = null) -> Variant:
    if patch.writes[index].has(key): return patch.writes[index][key]
    if patch.full or patch.removes[index].has(key): return fallback
    return base.get(index,{}).get(key,fallback)

static func projected_row(base: Dictionary, patch: Dictionary, kind: String, id: String) -> Dictionary:
    return projected_index(base,patch,"tile_rows" if kind=="tiles" else "spatial_rows" if kind=="spatial" else "residue_rows" if kind=="residues" else "object_rows",id,{})

static func _write_index(base: Dictionary, patch: Dictionary, index: String, key: String, value: Variant) -> void:
    patch.removes[index].erase(key)
    if not patch.full and base.get(index,{}).has(key) and base[index][key]==value:
        patch.writes[index].erase(key)
    else: patch.writes[index][key] = value

static func _erase_index(base: Dictionary, patch: Dictionary, index: String, key: String) -> void:
    patch.writes[index].erase(key)
    if not patch.full and base.get(index,{}).has(key): patch.removes[index][key] = true

static func _private_cell(base: Dictionary, patch: Dictionary, index: String, key: String, fallback: Variant) -> Variant:
    if not patch.writes[index].has(key):
        patch.writes[index][key] = projected_index(base,patch,index,key,fallback).duplicate()
        patch.removes[index].erase(key)
    return patch.writes[index][key]

static func _wall_cell(row: Dictionary) -> String:
    return JSON.stringify([row.position,row.material,row.base_height_steps,row.top_height_steps])

static func _projected_visual(base: Dictionary, patch: Dictionary, id: String) -> Dictionary:
    var row: Dictionary = projected_index(base,patch,"object_rows",id,{})
    return projected_index(base,patch,"assembly",id,row) if not row.is_empty() else {}

static func prepare_changes(state: Dictionary, cache: Dictionary, base: Dictionary, changes: Dictionary) -> Dictionary:
    # Pure projection against immutable accepted after-values and the borrowed
    # published base. The source cache is owned by this one preparation task.
    var full: bool = changes.get("full",false) or not base.has("row_slots")
    var patch = {"full":full,"writes":{},"removes":{},"order":changes.get("order",[]),
        "canonical_changes":{},"visual_changes":{},"changed_tiles":{},"changed_objects":{},
        "resolved":0,"changed":full,"rebuild_rows":full,"rebuild_visual":full,"missing_changed":full,
        "next_object_rank":0 if full else base.get("next_object_rank",0)}
    for index in ROW_INDEXES: patch.writes[index] = {}; patch.removes[index] = {}
    if full or changes.get("senses",false) or not changes.get("tiles",{}).is_empty() or not changes.get("objects",{}).is_empty() or not changes.get("objects_removed",[]).is_empty():
        var spatial:Dictionary=spatial_projection(state,cache)
        var current:Dictionary={}
        for row in spatial.rows:current[row.id]=row
        var keys:Dictionary=current.duplicate()
        if not full:
            for id in base.get("spatial_rows",{}):keys[id]=true
        for id in keys:
            var old:Dictionary={} if full else base.get("spatial_rows",{}).get(id,{})
            var row:Dictionary=current.get(id,{})
            if row.is_empty():_erase_index(base,patch,"spatial_rows",id)
            else:_write_index(base,patch,"spatial_rows",id,row)
            if old!=row:
                patch.canonical_changes["spatial:"+id]=row;patch.visual_changes[id]=row;patch.changed=true
                if old.is_empty() or row.is_empty():patch.rebuild_rows=true;patch.rebuild_visual=true
        var old_missing:Array=[] if full else base.get("missing",{}).get("spatial",[])
        if spatial.unresolved.is_empty():_erase_index(base,patch,"missing","spatial")
        else:_write_index(base,patch,"missing","spatial",spatial.unresolved)
        if old_missing!=spatial.unresolved:patch.missing_changed=true;patch.changed=true
    var tile_keys: Dictionary = changes.get("tiles",{}).duplicate()
    var object_keys: Dictionary = changes.get("objects",{}).duplicate()
    if full:
        for key in state.tiles: tile_keys[key] = true
        for id in state.objects: object_keys[id] = true
    # Order operations are an accepted mutation log, including remove/re-add
    # with an equal final row. Content equality cannot recover this fact.
    for operation in patch.order:
        if operation.kind=="tiles": tile_keys[operation.id] = true
        else: object_keys[operation.id] = true
    var senses: Dictionary = state.get("senses",{}) if state.get("senses")!=null else {}
    if changes.get("senses",false) and not full:
        for id in base.lit_candidates:
            if bool(base.lit_candidates[id])!=bool(senses.get("objects",{}).get(id,{}).get("visual",false)):
                object_keys[id] = true
        # Only the few explicitly delegated objects depend on spatial-owner
        # membership. Unrelated scenery keeps its existing sparse fast path.
        for id in base.get("native_candidates",{}):object_keys[id]=true
        for id in base.get("residue_candidates",{}):object_keys[id]=true
    var residue_keys:Dictionary=tile_keys.duplicate()
    for key in tile_keys:
        var point:Array=Cells.point(key)
        for dx in [-1,0,1]:
            for dy in [-1,0,1]:residue_keys[cell_key([point[0]+dx,point[1]+dy])]=true
    if changes.get("senses",false) and not full:
        for key in base.get("residue_cells",{}):residue_keys[key]=true
    var profiles:Dictionary=Catalog.environment_index(cache).get("floor_residue_sources",{})
    var observed:Dictionary=Cells.point_set(visible_positions(state)) if not profiles.is_empty() else {}
    for key in residue_keys:
        var old_ids:Array=[] if full else base.get("residue_cells",{}).get(key,[])
        var current:Dictionary={}
        for row in residue_tile_rows(state,key,profiles,observed):current[row.id]=row
        var ids:Dictionary=current.duplicate()
        for id in old_ids:ids[id]=true
        for id in ids:
            var old:Dictionary={} if full else base.get("residue_rows",{}).get(id,{})
            var row:Dictionary=current.get(id,{})
            if row.is_empty():_erase_index(base,patch,"residue_rows",id)
            else:_write_index(base,patch,"residue_rows",id,row)
            if old!=row:
                patch.canonical_changes["residues:"+id]=row;patch.visual_changes[id]=row;patch.changed=true
                if old.is_empty() or row.is_empty():patch.rebuild_rows=true;patch.rebuild_visual=true
        var current_ids:Array=current.keys()
        if old_ids!=current_ids:
            patch.rebuild_rows=true;patch.rebuild_visual=true;patch.changed=true
        if current.is_empty():_erase_index(base,patch,"residue_cells",key)
        else:_write_index(base,patch,"residue_cells",key,current_ids)
    var world: Dictionary = Catalog.environment_world(cache)
    var native_index:Dictionary=Catalog.environment_index(cache)
    var affected_walls = {}; var affected_boundaries = {}; var visual_objects = {}
    for key in tile_keys:
        var old: Dictionary = {} if full else base.tile_rows.get(key,{})
        var row = {}; var token: String = "tiles:"+key
        var old_missing: Array = [] if full else base.missing.get(token,[])
        var missing: Array = []
        _erase_index(base,patch,"missing",token); _erase_index(base,patch,"negative",token)
        if not old.is_empty(): _erase_index(base,patch,"terrain_materials",old.id)
        if state.tiles.has(key):
            var tile: Dictionary = state.tiles[key]
            var material: String = tile.surface.base_material
            if tile.elevation_steps<0: _write_index(base,patch,"negative",token,true)
            if world.terrain.has(material):
                row = {"id":tile.tile_uuid,"kind":"terrain","material":material,"position":tile.position,
                    "base_height_steps":tile.elevation_steps,"layer":0,"orientation":"east","boundaries":[]}
            else: missing = ["terrain:"+material]
            if row==old: row = old
            _write_index(base,patch,"tile_rows",key,row)
            if not row.is_empty(): _write_index(base,patch,"terrain_materials",row.id,material)
        else: _erase_index(base,patch,"tile_rows",key)
        if not missing.is_empty(): _write_index(base,patch,"missing",token,missing)
        if old!=row:
            patch.canonical_changes[token] = row
            if not old.is_empty(): patch.visual_changes[old.id] = {}
            if not row.is_empty(): patch.visual_changes[row.id] = row
            if old.is_empty() or row.is_empty() or old.id!=row.id:
                patch.rebuild_rows = true; patch.rebuild_visual = true
        if old!=row or old_missing!=missing:
            patch.changed = true; patch.changed_tiles[key] = true
        if old_missing!=missing: patch.missing_changed = true
        patch.resolved += 1
    for id in object_keys:
        var old: Dictionary = {} if full else base.object_rows.get(id,{})
        var row = {}; var token: String = "objects:"+id
        var old_missing: Array = [] if full else base.missing.get(token,[])
        var missing: Array = []
        _erase_index(base,patch,"missing",token); _erase_index(base,patch,"negative",token)
        _erase_index(base,patch,"lit_candidates",id)
        _erase_index(base,patch,"native_candidates",id)
        _erase_index(base,patch,"residue_candidates",id)
        if state.objects.has(id):
            var object: Dictionary = state.objects[id]
            var derived = rows({"tiles":{},"objects":{id:object},"senses":senses},cache,false)
            if not derived.rows.is_empty(): row = derived.rows[0]
            missing = derived.unresolved
            if object.placement.base_height_steps<0: _write_index(base,patch,"negative",token,true)
            if not object.item.get("surface_residues",[]).is_empty() and object.placement.get("boundary_direction")!=null:
                _write_index(base,patch,"residue_candidates",id,true)
            if native_index.get("native_object_owners",{}).has(object.item.item_id):
                _write_index(base,patch,"native_candidates",id,object.item.item_id)
            if world.props.has(object.item.item_id) and world.props[object.item.item_id].has("lit_animation"):
                _write_index(base,patch,"lit_candidates",id,senses.get("objects",{}).get(id,{}).get("visual",false))
            if old==row: row = old
            _write_index(base,patch,"object_rows",id,row)
            if full:
                _write_index(base,patch,"object_ranks",id,patch.next_object_rank)
                patch.next_object_rank += 1
        else:
            _erase_index(base,patch,"object_rows",id); _erase_index(base,patch,"object_ranks",id)
        if not missing.is_empty(): _write_index(base,patch,"missing",token,missing)
        if old!=row:
            patch.canonical_changes[token] = row; visual_objects[id] = true
            if old.is_empty() or row.is_empty(): patch.rebuild_rows = true
            for value in [old,row]:
                if value.get("kind")!="wall": continue
                var cell = _wall_cell(value)
                affected_walls[cell] = true
                _private_cell(base,patch,"wall_cells",cell,{}).erase(id)
            if row.get("kind")=="wall":
                _private_cell(base,patch,"wall_cells",_wall_cell(row),{})[id] = row
            _erase_index(base,patch,"assembly",id)
        if old!=row or old_missing!=missing:
            patch.changed = true; patch.changed_objects[id] = true
        if old_missing!=missing: patch.missing_changed = true
        # Incident-cell arrays are copied only when this object's membership or
        # order can affect them. No nested array in the borrowed base is edited.
        var cells: Array = _boundary_cells(state.objects[id]) if state.objects.has(id) else []
        var previous: Array = [] if full else base.boundary_cells.get(id,[])
        for cell in previous: affected_boundaries[cell] = true
        for cell in cells: affected_boundaries[cell] = true
        if cells!=previous:
            for cell in previous: _private_cell(base,patch,"boundaries",cell,[]).erase(id)
            for cell in cells: _private_cell(base,patch,"boundaries",cell,[]).append(id)
            if cells.is_empty(): _erase_index(base,patch,"boundary_cells",id)
            else: _write_index(base,patch,"boundary_cells",id,cells)
        patch.resolved += 1
    if not full:
        for operation in patch.order:
            if operation.kind!="objects": continue
            if operation.remove: _erase_index(base,patch,"object_ranks",operation.id)
            elif state.objects.has(operation.id):
                _write_index(base,patch,"object_ranks",operation.id,patch.next_object_rank)
                patch.next_object_rank += 1
    if changes.has("order_reset"):
        # Exhaustive order discovery is confined to the compatibility wrapper.
        patch.order_reset = changes.order_reset
        patch.next_object_rank = 0
        for id in patch.order_reset.objects:
            _write_index(base,patch,"object_ranks",id,patch.next_object_rank)
            patch.next_object_rank += 1
    if not patch.order.is_empty() or patch.has("order_reset"):
        patch.changed = true; patch.rebuild_rows = true; patch.rebuild_visual = true
        patch.missing_changed = true
    for cell in affected_boundaries:
        var members: Array = _private_cell(base,patch,"boundaries",cell,[])
        members.sort_custom(func(a,b):return projected_index(base,patch,"object_ranks",a,0)<projected_index(base,patch,"object_ranks",b,0))
        if members.is_empty(): _erase_index(base,patch,"boundaries",cell)
    for cell in affected_walls:
        var members: Dictionary = projected_index(base,patch,"wall_cells",cell,{})
        if not full:
            for id in base.wall_cells.get(cell,{}): visual_objects[id] = true
        if members.is_empty(): _erase_index(base,patch,"wall_cells",cell); continue
        for id in members:
            visual_objects[id] = true; _write_index(base,patch,"assembly",id,{})
        for row in join_walls(members.values(),world): _write_index(base,patch,"assembly",row.id,row)
    for id in visual_objects:
        var old: Dictionary = {} if full else base.assembly.get(id,base.object_rows.get(id,{}))
        var row: Dictionary = _projected_visual(base,patch,id)
        if old==row: continue
        patch.visual_changes[id] = row
        if old.is_empty() or row.is_empty(): patch.rebuild_visual = true
    if patch.rebuild_rows or patch.rebuild_visual or patch.missing_changed:
        _prepare_result(base,patch)
    return patch

static func _projected_order(base: Dictionary, patch: Dictionary, kind: String) -> Array:
    if patch.has("order_reset") and patch.order_reset.has(kind): return patch.order_reset[kind]
    var index: String = "tile_rows" if kind=="tiles" else "spatial_rows" if kind=="spatial" else "residue_rows" if kind=="residues" else "object_rows"
    var ordered = {}
    if not patch.full:
        for id in base[index]:
            if not patch.removes[index].has(id): ordered[id] = true
    for id in patch.writes[index]: ordered[id] = true
    for operation in patch.order:
        if operation.kind!=kind: continue
        ordered.erase(operation.id)
        if not operation.remove and projected_index(base,patch,index,operation.id)!=null: ordered[operation.id] = true
    return ordered.keys()

static func _prepare_result(base: Dictionary, patch: Dictionary) -> void:
    # An actual membership/order change has an explicit larger preparation job.
    # Publication only installs these completed arrays and their slot indexes.
    var tile_order: Array = _projected_order(base,patch,"tiles")
    var object_order: Array = _projected_order(base,patch,"objects")
    var spatial_order:Array=_projected_order(base,patch,"spatial")
    var residue_order:Array=[]
    for cell in tile_order:
        residue_order.append_array(projected_index(base,patch,"residue_cells",cell,[]))
    # Keep displaced outer values until the existing candidate retirement.
    # The result shell is separate because publication edits its fields.
    patch.retired=base.duplicate()
    if base.has("result"):patch.retired.result=base.result.duplicate()
    if patch.rebuild_rows:_prepare_indexes(base,patch,tile_order,object_order)
    var result: Array = []
    if patch.rebuild_rows:
        var slots = {}
        for kind in ["tiles","objects","residues","spatial"]:
            for id in (tile_order if kind=="tiles" else spatial_order if kind=="spatial" else residue_order if kind=="residues" else object_order):
                var row: Dictionary = projected_row(base,patch,kind,id)
                if row.is_empty(): continue
                slots[kind+":"+id] = result.size(); result.append(row)
        patch.prepared_rows = result; patch.prepared_row_slots = slots
        patch.tile_order = tile_order; patch.object_order = object_order
    if patch.rebuild_visual:
        var visual: Array = []; var slots = {}
        # Assembly-only membership changes can leave canonical row slots intact.
        for kind in ["tiles","objects","residues","spatial"]:
            for id in (tile_order if kind=="tiles" else spatial_order if kind=="spatial" else residue_order if kind=="residues" else object_order):
                var row: Dictionary = _projected_visual(base,patch,id) if kind=="objects" else projected_row(base,patch,kind,id)
                if row.is_empty(): continue
                slots[row.id] = visual.size(); visual.append(row)
        patch.prepared_visual = visual; patch.prepared_visual_slots = slots
    if patch.missing_changed:
        var missing: Array = []
        var has_missing: bool = not patch.writes.missing.is_empty() or (not patch.full and not base.missing.is_empty())
        if has_missing:
            for key in tile_order: missing.append_array(projected_index(base,patch,"missing","tiles:"+key,[]))
            for id in object_order: missing.append_array(projected_index(base,patch,"missing","objects:"+id,[]))
        patch.prepared_missing = missing
        patch.prepared_missing.append_array(projected_index(base,patch,"missing","spatial",[]))

static func _prepare_indexes(base:Dictionary,patch:Dictionary,tile_order:Array,object_order:Array)->void:
    # Membership/order already requires a new canonical row owner. Complete
    # touched indexes here, beside those arrays, so adoption never replays the
    # accepted mutation log or inserts hundreds of records on the draw frame.
    patch.prepared_indexes={}
    var ordered:Dictionary={}
    for operation in patch.order:ordered[operation.kind]=true
    for index in ROW_INDEXES:
        var kind:String="tiles" if index=="tile_rows" else "objects" if index=="object_rows" else ""
        var reorder:bool=not kind.is_empty() and (ordered.has(kind) or patch.has("order_reset"))
        if not patch.full and patch.writes[index].is_empty() and patch.removes[index].is_empty() and not reorder:continue
        var values:Dictionary
        if not kind.is_empty():
            values={}
            for id in (tile_order if kind=="tiles" else object_order):
                # Empty rows still own canonical insertion positions and
                # missing-art metadata, even though render arrays omit them.
                values[id]=projected_row(base,patch,kind,id)
        else:
            values=patch.writes[index] if patch.full else base[index].duplicate()
            if not patch.full:
                for key in patch.removes[index]:values.erase(key)
                values.merge(patch.writes[index],true)
        patch.prepared_indexes[index]=values

static func apply_changes(base: Dictionary, patch: Dictionary) -> Dictionary:
    # Owner-only, after the borrowing task has completed. The caller validates
    # its displayed revision before this handoff; this function cannot reject.
    if patch.full:
        base.clear()
        base.result = {"rows":[],"visual_rows":[],"unresolved":[]}
        base.row_slots = {}; base.visual_slots = {}
    if patch.rebuild_rows:
        for index in patch.prepared_indexes:base[index]=patch.prepared_indexes[index]
    else:
        for index in ROW_INDEXES:
            for key in patch.removes[index]: base[index].erase(key)
            base[index].merge(patch.writes[index],true)
    if patch.rebuild_rows:
        base.result.rows = patch.prepared_rows; base.row_slots = patch.prepared_row_slots
        base.tile_order = patch.tile_order; base.object_order = patch.object_order
    else:
        for token in patch.canonical_changes: base.result.rows[base.row_slots[token]] = patch.canonical_changes[token]
    if patch.rebuild_visual:
        base.result.visual_rows = patch.prepared_visual; base.visual_slots = patch.prepared_visual_slots
    else:
        for id in patch.visual_changes: base.result.visual_rows[base.visual_slots[id]] = patch.visual_changes[id]
    if patch.missing_changed: base.result.unresolved = patch.prepared_missing
    base.next_object_rank = patch.next_object_rank
    base.changed = patch.changed; base.changed_tiles = patch.changed_tiles; base.changed_objects = patch.changed_objects
    base.resolved = patch.resolved
    return base.result

static func update_rows(state: Dictionary, cache: Dictionary, retained: Dictionary, changes: Dictionary) -> Dictionary:
    # Compatibility/source-oracle entry point. Normal preparation supplies exact
    # order operations and uses prepare_changes/apply_changes at the handoff.
    changes = changes.duplicate()
    if retained.has("tile_rows") and not changes.get("full",false):
        var tile_order: Array = state.tiles.keys(); var object_order: Array = state.objects.keys()
        if retained.get("tile_order",[])!=tile_order or retained.get("object_order",[])!=object_order:
            changes.order_reset = {"tiles":tile_order,"objects":object_order}
    return apply_changes(retained,prepare_changes(state,cache,retained,changes))

static func _boundary_cells(object: Dictionary) -> Array:
    var direction: Variant = object.placement.get("boundary_direction")
    if object.item.get("supported_by_uuid")!=null or object.item.get("boundary_structure")==null or direction==null: return []
    var offset: Array = {"north":[0,1],"south":[0,-1],"east":[1,0],"west":[-1,0]}[direction]
    var position: Array = object.placement.position
    return [cell_key(position),cell_key([position[0]+offset[0],position[1]+offset[1]])]

static func boundary_index(state: Dictionary) -> Dictionary:
    var result = {}
    var directions = {"north":[0,1],"south":[0,-1],"east":[1,0],"west":[-1,0]}
    for id in state.get("objects",{}):
        var object: Dictionary = state.objects[id]
        var direction: Variant = object.placement.get("boundary_direction")
        if object.item.get("supported_by_uuid")!=null or object.item.get("boundary_structure")==null or direction==null: continue
        var position: Array = object.placement.position
        var delta: Array = directions[direction]
        for cell in [cell_key(position),cell_key([position[0]+delta[0],position[1]+delta[1]])]:
            if not result.has(cell): result[cell] = []
            result[cell].append(id)
    return result

static func current_ids(state: Dictionary, boundaries: Dictionary, visible_cells: Dictionary = {}, patch: Dictionary = {}, spatial_rows:Dictionary = {}, residue_rows:Dictionary = {}) -> Dictionary:
    # Sparse form of visibility(): only already-disclosed, currently observed
    # identities. Missing IDs mean remembered, never newly invented scenery.
    var senses: Dictionary = state.get("senses",{}) if state.get("senses")!=null else {}
    var result = {}
    visible_cells.clear()
    for position in visible_positions(state):
        var cell = cell_key(position)
        visible_cells[cell] = true
        if state.tiles.has(cell): result[state.tiles[cell].tile_uuid] = true
        var incident: Array = boundaries.get(cell,[]) if patch.is_empty() else projected_index({"boundaries":boundaries},patch,"boundaries",cell,[])
        for id in incident:
            if state.objects.has(id): result[id] = true
    for id in senses.get("objects",{}):
        if state.objects.has(id) and senses.objects[id].get("visual",false): result[id] = true
    for id in residue_rows:
        var row:Dictionary=residue_rows[id]
        if result.has(row.tile_uuid):result[id]=true
    for id in spatial_rows:
        var row:Dictionary=spatial_rows[id]
        var effect:Dictionary=senses.get("spatial_effects",{}).get(row.spatial_effect_uuid,{})
        if not effect.is_empty() and not SpatialInputs.admitted_cells(effect).is_empty():result[id]=true
    return result

static func join_walls(rows: Array, world: Dictionary) -> Array:
    # One authored corner can depict two backend edges. Keep the original rows
    # intact for commands; this is only grid-to-art assembly at world revisions.
    var cells = {}
    for row in rows:
        # A corner is one intact source. A destroyed edge must retain its own
        # authored endpoint instead of borrowing the other edge's state.
        if row.kind != "wall" or row.get("destroyed",false) or row.has("source_kind"): continue
        var key = JSON.stringify([row.position,row.material,row.base_height_steps,row.top_height_steps])
        if not cells.has(key): cells[key] = []
        cells[key].append(row)
    var corners = {}
    var joined = {}
    for members in cells.values():
        if members.size()!=2: continue
        members.sort_custom(func(a,b):return a.id<b.id)
        var a: Dictionary = members[0]
        var b: Dictionary = members[1]
        if not world.has(a.material+"_wall_corner"): continue
        for faces in world.wall_corner_faces.values():
            if not (a.orientation in faces and b.orientation in faces) or a.orientation==b.orientation: continue
            var corner: Dictionary = a.duplicate(true)
            corner.boundaries = faces.duplicate()
            corner.wall_members = members.duplicate(true)
            corners[a.id] = corner
            joined[b.id] = true
            break
    var visual: Array = []
    for row in rows:
        if not joined.has(row.id): visual.append(corners.get(row.id,row))
    return visual

static func visible_actor(actor: Dictionary, state: Dictionary, staged: bool = false) -> bool:
    if not actor.get("present",true) or actor.get("last_visual_position") == null \
        or actor.get("spatial_disposition","present")!="present" \
        or actor.get("remains_disposition","intact")=="disintegrated": return false
    var senses: Variant = state.get("senses")
    var contact: Dictionary = senses.entities.get(actor.uuid,{}) if senses != null else {}
    # The server retires Dead actors from living-creature sensory contacts.
    # Like the original scene adapter, retain their witnessed corpse pose at
    # the disclosed last position; never retain an unseen living actor.
    return staged or actor.uuid in state.audience.controlled or contact.get("visual",false) or actor.get("life_state")=="dead"

static func visibility(state: Dictionary,cache:Dictionary={}) -> Dictionary:
    # Current sight is separate from the last-observed map. Never grow the map
    # from `seen`, a light radius, or an object's remembered activation state.
    var senses: Dictionary = state.get("senses",{}) if state.get("senses") != null else {}
    var visible = {}
    for position in visible_positions(state): visible[cell_key(position)] = true
    var result = {}
    for tile in state.get("tiles",{}).values():
        result[tile.tile_uuid] = visible.has(cell_key(tile.position))
    var directions = {"north":[0,1],"south":[0,-1],"east":[1,0],"west":[-1,0]}
    for id in state.get("objects",{}):
        var object: Dictionary = state.objects[id]
        var current: bool = senses.get("objects",{}).get(id,{}).get("visual",false)
        var direction: Variant = object.placement.get("boundary_direction")
        # Native boundary disclosure also observes either incident support.
        # An inserted object needs its own sight grant, as in the projector.
        if not current and object.item.get("supported_by_uuid") == null and object.item.get("boundary_structure") != null and direction != null:
            var position: Array = object.placement.position
            var delta: Array = directions[direction]
            current = visible.has(cell_key(position)) or visible.has(cell_key([position[0]+delta[0],position[1]+delta[1]]))
        result[id] = current
    for row in residue_projection(state,cache):result[row.id]=bool(result.get(row.tile_uuid,false))
    for row in spatial_projection(state,cache).rows:result[row.id]=true
    return result

static func ground_background(state: Dictionary, staged: Dictionary = {}) -> bool:
    # A base-zero floor is a single background band only while nothing can be
    # painted below it. Remembered lower supports are still part of the map.
    for tile in state.get("tiles",{}).values():
        if tile.elevation_steps < 0: return false
    for object in state.get("objects",{}).values():
        if object.placement.get("base_height_steps",0) < 0: return false
    var actors: Dictionary = state.get("actors",{}).duplicate()
    actors.merge(staged,true)
    for id in actors:
        var actor: Dictionary = actors[id]
        if not visible_actor(actor,state,staged.has(id)): continue
        var tile: Dictionary = state.get("tiles",{}).get(cell_key(actor.last_visual_position),{})
        if tile.get("elevation_steps",0) < 0: return false
    return true
