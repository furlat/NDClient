extends RefCounted
# Adapter from disclosed SDK geometry into existing authored placement rows.
const Catalog = preload("res://source_catalog.gd")

static func cell_key(position: Array) -> String:
    return "%d,%d" % [position[0],position[1]]

static func rows(state: Dictionary, cache: Dictionary) -> Dictionary:
    var world = Catalog.read_file("world.json",cache)
    var index = Catalog.read_file("environment/index.json",cache)
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
        var direction: String = place.get("boundary_direction") if place.get("boundary_direction") != null else (place.get("orientation") if place.get("orientation") != null else "east")
        var row = {"id":id,"position":place.position,"base_height_steps":place.base_height_steps,
            "orientation":direction,"boundaries":[direction] if place.kind=="boundary" else [],"layer":1,"item_id":item.item_id}
        if index.doors.has(item.item_id):
            row.merge({"kind":"door","asset":item.item_id,"state":"open."+(item.get("door_swing") if item.get("door_swing") != null else "inward") if item.get("is_open",false) else "closed"})
        elif index.props.has(item.item_id):
            var owner = Catalog.read_file(index.props[item.item_id],cache)
            # Prop owners name the backend field and use its JSON value as the
            # bank key (for example is_open -> "false" / "true" for chests).
            var mode := "default"
            if owner.has("state_field"):
                var value = item.get(owner.state_field)
                if value != null: mode = JSON.stringify(value) if value is bool else str(value)
            row.merge({"kind":"prop","asset":item.item_id,"state":mode})
        elif index.traps.has(item.item_id):
            row.merge({"kind":"trap","asset":item.item_id,"state":"active" if item.get("is_engaged",false) else "ready"})
        elif item.get("boundary_structure") != null:
            var structure: Dictionary = item.boundary_structure
            if structure.structure in ["wall","retaining_wall"] and world.has(structure.material+"_wall_straight"):
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
            missing.append("object:"+item.item_id)
            continue
        result.append(row)
    return {"rows":result,"visual_rows":join_walls(result,world),"unresolved":missing}

static func cached_rows(state: Dictionary, cache: Dictionary, retained: Dictionary) -> Dictionary:
    # SDK after-values are immutable. Keep only this world's current records;
    # changes are still resolved through the original source adapter above.
    var senses: Dictionary = state.get("senses",{}) if state.get("senses") != null else {}
    var old: Dictionary = retained.get("records",{})
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
            if record.is_empty() or not is_same(record.source,source) or record.sight!=sight:
                if kind=="objects" and (record.is_empty() or not is_same(record.source,source)): boundary_dirty = true
                var input = {"tiles":{},"objects":{},"senses":senses}
                input[kind][id] = source
                var derived = rows(input,cache)
                var row: Dictionary = derived.rows[0] if not derived.rows.is_empty() else {}
                if record.is_empty() or row!=record.row or derived.unresolved!=record.missing: changed = true
                # Reuse equal projections when HP/resources change without art.
                elif not row.is_empty(): row = record.row
                record = {"source":source,"sight":sight,"row":row,"missing":derived.unresolved}
                resolved += 1
            records[key] = record
            missing.append_array(record.missing)
            if record.row.is_empty(): continue
            result.append(record.row)
            if record.row.kind=="wall": walls.append(record.row)
    retained.records = records
    retained.resolved = resolved
    # Preserve insertion order too: it is the old equal-projection floor tie.
    var ids = records.keys()
    if retained.get("ids",[])!=ids: changed = true
    retained.ids = ids
    if changed or not retained.has("result"):
        if retained.get("walls",[])!=walls:
            var joined = join_walls(walls,Catalog.read_file("world.json",cache))
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

static func update_rows(state: Dictionary, cache: Dictionary, retained: Dictionary, changes: Dictionary) -> Dictionary:
    # Only admitted dirty identities enter source projection. Keep the exhaustive
    # rows() adapter independent so recorded-world parity can check this lifetime.
    var full: bool = changes.get("full",false) or not retained.has("tile_rows")
    if full:
        retained.clear()
        retained.merge({"tile_rows":{},"object_rows":{},"missing":{},"wall_cells":{},"assembly":{},
            "boundaries":{},"boundary_cells":{},"lit_candidates":{},"negative":{},"terrain_materials":{}})
    var tile_keys: Dictionary = changes.get("tiles",{}).duplicate()
    var object_keys: Dictionary = changes.get("objects",{}).duplicate()
    if full:
        for key in state.tiles: tile_keys[key] = true
        for id in state.objects: object_keys[id] = true
    var senses: Dictionary = state.get("senses",{}) if state.get("senses")!=null else {}
    if changes.get("senses",false):
        # Only original fixture resources can change their source row on sight.
        for id in retained.lit_candidates:
            if bool(retained.lit_candidates[id]) != bool(senses.get("objects",{}).get(id,{}).get("visual",false)):
                object_keys[id] = true
    var world = Catalog.read_file("world.json",cache)
    var changed = full
    var affected_walls = {}; var affected_boundaries = {}
    retained.changed_tiles = {}; retained.changed_objects = {}
    retained.resolved = 0
    for key in tile_keys:
        var old: Dictionary = retained.tile_rows.get(key,{})
        var row = {}
        var token: String = "tiles:"+key
        var old_missing: Array = retained.missing.get(token,[])
        if not old.is_empty(): retained.terrain_materials.erase(old.id)
        retained.missing.erase(token); retained.negative.erase(token)
        if state.tiles.has(key):
            var tile: Dictionary = state.tiles[key]
            var material: String = tile.surface.base_material
            if tile.elevation_steps<0: retained.negative[token] = true
            if world.terrain.has(material):
                row = {"id":tile.tile_uuid,"kind":"terrain","material":material,"position":tile.position,
                    "base_height_steps":tile.elevation_steps,"layer":0,"orientation":"east","boundaries":[]}
            else: retained.missing[token] = ["terrain:"+material]
            retained.tile_rows[key] = old if old==row else row
            if not row.is_empty(): retained.terrain_materials[row.id] = material
        else: retained.tile_rows.erase(key)
        if old!=row or old_missing!=retained.missing.get(token,[]):
            changed = true; retained.changed_tiles[key] = true
        retained.resolved += 1
    for id in object_keys:
        var old: Dictionary = retained.object_rows.get(id,{})
        var row = {}
        var token: String = "objects:"+id
        var old_missing: Array = retained.missing.get(token,[])
        retained.missing.erase(token); retained.negative.erase(token)
        retained.lit_candidates.erase(id)
        if state.objects.has(id):
            var object: Dictionary = state.objects[id]
            var derived = rows({"tiles":{},"objects":{id:object},"senses":senses},cache)
            if not derived.rows.is_empty(): row = derived.rows[0]
            if not derived.unresolved.is_empty(): retained.missing[token] = derived.unresolved
            if object.placement.base_height_steps<0: retained.negative[token] = true
            if world.props.has(object.item.item_id) and world.props[object.item.item_id].has("lit_animation"):
                retained.lit_candidates[id] = senses.get("objects",{}).get(id,{}).get("visual",false)
            retained.object_rows[id] = old if old==row else row
        else: retained.object_rows.erase(id)
        if old!=row or old_missing!=retained.missing.get(token,[]):
            changed = true; retained.changed_objects[id] = true
            for value in [old,row]:
                if value.get("kind")!="wall": continue
                var cell = JSON.stringify([value.position,value.material,value.base_height_steps,value.top_height_steps])
                affected_walls[cell] = true
                if not retained.wall_cells.has(cell): retained.wall_cells[cell] = {}
                retained.wall_cells[cell].erase(id)
            if row.get("kind")=="wall":
                var cell = JSON.stringify([row.position,row.material,row.base_height_steps,row.top_height_steps])
                retained.wall_cells[cell][id] = row
            retained.assembly.erase(id)
        # Boundary grants are indexed separately from painted source geometry.
        var cells: Array = _boundary_cells(state.objects[id]) if state.objects.has(id) else []
        var previous: Array = retained.boundary_cells.get(id,[])
        for cell in previous: affected_boundaries[cell] = true
        for cell in cells: affected_boundaries[cell] = true
        if cells!=previous:
            for cell in previous:
                retained.boundaries[cell].erase(id); affected_boundaries[cell] = true
                if retained.boundaries[cell].is_empty(): retained.boundaries.erase(cell)
            for cell in cells:
                if not retained.boundaries.has(cell): retained.boundaries[cell] = []
                retained.boundaries[cell].append(id); affected_boundaries[cell] = true
            if cells.is_empty(): retained.boundary_cells.erase(id)
            else: retained.boundary_cells[id] = cells
        retained.resolved += 1
    # Canonical insertion order remains observable through equal-Y floor ties.
    # In particular remove/re-add in one consumed interval moves that ID last.
    var tile_order: Array = state.tiles.keys(); var object_order: Array = state.objects.keys()
    if retained.get("tile_order",[])!=tile_order:
        if retained.tile_rows.keys()!=tile_order: retained.tile_rows = _ordered_records(retained.tile_rows,tile_order)
        changed = true
    if retained.get("object_order",[])!=object_order:
        if retained.object_rows.keys()!=object_order: retained.object_rows = _ordered_records(retained.object_rows,object_order)
        changed = true
        var ranks = {}
        for i in range(object_order.size()): ranks[object_order[i]] = i
        # Usually one or two IDs share an incident cell. Native order matters
        # to the exhaustive index oracle even when current visibility is a set.
        for cell in affected_boundaries:
            if retained.boundaries.has(cell): retained.boundaries[cell].sort_custom(func(a,b):return ranks[a]<ranks[b])
    retained.tile_order = tile_order; retained.object_order = object_order
    for cell in affected_walls:
        var members: Dictionary = retained.wall_cells[cell]
        if members.is_empty(): retained.wall_cells.erase(cell); continue
        for id in members: retained.assembly[id] = {}
        for row in join_walls(members.values(),world): retained.assembly[row.id] = row
    if changed or not retained.has("result"):
        var result: Array = retained.tile_rows.values(); var visual: Array = result.duplicate()
        if not retained.missing.is_empty():
            result = result.filter(func(row):return not row.is_empty()); visual = result.duplicate()
        for row in retained.object_rows.values():
            if row.is_empty(): continue
            result.append(row)
            var assembled: Dictionary = retained.assembly.get(row.id,row)
            if not assembled.is_empty(): visual.append(assembled)
        var missing: Array = []
        if not retained.missing.is_empty():
            for key in tile_order: missing.append_array(retained.missing.get("tiles:"+key,[]))
            for id in object_order: missing.append_array(retained.missing.get("objects:"+id,[]))
        retained.result = {"rows":result,"visual_rows":visual,"unresolved":missing}
    retained.changed = changed
    return retained.result

static func _ordered_records(records: Dictionary, keys: Array) -> Dictionary:
    var result = {}
    for key in keys: result[key] = records[key]
    return result

static func _boundary_cells(object: Dictionary) -> Array:
    var direction: Variant = object.placement.get("boundary_direction")
    if object.item.get("supported_by_uuid")!=null or object.item.get("boundary_structure")==null or direction==null: return []
    var offset: Array = {"north":[0,-1],"south":[0,1],"east":[1,0],"west":[-1,0]}[direction]
    var position: Array = object.placement.position
    return [cell_key(position),cell_key([position[0]+offset[0],position[1]+offset[1]])]

static func boundary_index(state: Dictionary) -> Dictionary:
    var result = {}
    var directions = {"north":[0,-1],"south":[0,1],"east":[1,0],"west":[-1,0]}
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

static func current_ids(state: Dictionary, boundaries: Dictionary, visible_cells: Dictionary = {}) -> Dictionary:
    # Sparse form of visibility(): only already-disclosed, currently observed
    # identities. Missing IDs mean remembered, never newly invented scenery.
    var senses: Dictionary = state.get("senses",{}) if state.get("senses")!=null else {}
    var result = {}
    visible_cells.clear()
    for position in senses.get("visible",[]):
        var cell = cell_key(position)
        visible_cells[cell] = true
        if state.tiles.has(cell): result[state.tiles[cell].tile_uuid] = true
        for id in boundaries.get(cell,[]):
            if state.objects.has(id): result[id] = true
    for id in senses.get("objects",{}):
        if state.objects.has(id) and senses.objects[id].get("visual",false): result[id] = true
    return result

static func join_walls(rows: Array, world: Dictionary) -> Array:
    # One authored corner can depict two backend edges. Keep the original rows
    # intact for commands; this is only grid-to-art assembly at world revisions.
    var cells = {}
    for row in rows:
        if row.kind != "wall": continue
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
    if not actor.get("present",true) or actor.get("last_visual_position") == null: return false
    var senses: Variant = state.get("senses")
    var contact: Dictionary = senses.entities.get(actor.uuid,{}) if senses != null else {}
    return staged or actor.uuid in state.audience.controlled or contact.get("visual",false)

static func visibility(state: Dictionary) -> Dictionary:
    # Current sight is separate from the last-observed map. Never grow the map
    # from `seen`, a light radius, or an object's remembered activation state.
    var senses: Dictionary = state.get("senses",{}) if state.get("senses") != null else {}
    var visible = {}
    for position in senses.get("visible",[]): visible[cell_key(position)] = true
    var result = {}
    for tile in state.get("tiles",{}).values():
        result[tile.tile_uuid] = visible.has(cell_key(tile.position))
    var directions = {"north":[0,-1],"south":[0,1],"east":[1,0],"west":[-1,0]}
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
