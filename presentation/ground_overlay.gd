extends RefCounted
## Passive ground UI in the existing painter merge, outside media/light/picking.
const Placement = preload("res://placement.gd")
const Order = preload("res://grid_order.gd")
const SHADER = preload("res://presentation/ground_overlay.gdshader")
const ROUTE = preload("res://presentation/ground_route.gdshader")
const GRID_COLOUR = Color(0.56,0.70,0.85,0.12)
var cells: Dictionary = {}
var routes: Dictionary = {}
var root: Node3D
var mesh: PlaneMesh
var route_mesh: QuadMesh
var route_material: ShaderMaterial
var revision: Variant = null
var marks: Dictionary = {}
var changed_marks: Dictionary = {}
var mark_order: Array = []
var path: Array = []
var route_colour = Color("70d6be")
var materials: Dictionary = {}
var batch: Dictionary = {}
var mark_batches: Dictionary = {}
var ordered: Array = []
var stamp: Array = []
var grid_geometry_stamp: Array = []
var support_geometry: Array = []
var support_positions: Dictionary = {}
var raised_supports: Dictionary = {}
var background_positions: Array = []
var preview_revision = 0
var changed = false
var transform_writes = 0
var buffer_allocations = 0
var support_owner: Dictionary = {}
var support_scope: Variant = null
var support_revision = -1
var support_rows: Dictionary = {}
var support_slots:Dictionary={}
var background_slots:Dictionary={}
var background_keys:Array=[]
var pending_support_change:bool=false
var pending_grid_changes:bool=false
var pending_grid_removed:Array=[]
var pending_grid_added:Array=[]
var support_checked_tiles = 0
var support_check_us = 0
var mark_update_us = 0
var support_geometry_revision = 0
var support_contact_updates = 0

func set_preview(value: Dictionary, route: Array = [], colour: Color = Color("70d6be")) -> void:
    # Keys are disclosed tile keys; values {colour:Color,width:float}. The path
    # comes directly from SDK preview.selected_route, never local pathfinding.
    var changes = {}
    for key in marks:
        if not value.has(key): changes[key] = {}
    for key in value:
        if marks.get(key,{}) != value[key]: changes[key] = value[key].duplicate(true)
    if changes.is_empty() and path == route and route_colour == colour: return
    # This owner retains only changed cells' previous styles until rendering.
    # Several preview updates before one draw still remove the displayed style.
    for key in changes:
        if not changed_marks.has(key): changed_marks[key] = marks.get(key,{})
        if changes[key].is_empty(): marks.erase(key)
        else: marks[key] = changes[key]
    # First-use material IDs participate in painter ties. Preserve the caller's
    # current order for complete selection without copying every style again.
    mark_order = value.keys()
    path = route.duplicate(true)
    route_colour = colour
    preview_revision += 1

func _material(colour: Color, width: float, fill: Color = Color.TRANSPARENT) -> ShaderMaterial:
    var key = [colour,width,fill]
    if not materials.has(key):
        var value = ShaderMaterial.new()
        value.shader = SHADER
        value.set_shader_parameter("line_colour",colour)
        value.set_shader_parameter("line_width_pixels",width)
        value.set_shader_parameter("fill_colour",fill)
        materials[key] = value
    return materials[key]

func _entry(id: String, row: Dictionary, source: Mesh, material: ShaderMaterial) -> Dictionary:
    var node = MeshInstance3D.new()
    node.mesh = source
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.sorting_use_aabb_center = false
    root.add_child(node)
    return {"id":id,"placement":row,"role":"covering","layer":1000,
        "node":node,"material":material,"ground_overlay":true,"screen_rect":Rect2()}

func _batch(id: String, material: ShaderMaterial, layer: int) -> Dictionary:
    var node = MultiMeshInstance3D.new()
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.sorting_use_aabb_center = false
    node.multimesh = MultiMesh.new()
    node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
    node.multimesh.mesh = mesh
    node.material_override = material
    root.add_child(node)
    var row = _row(id,{"position":[0,0],"elevation_steps":0})
    row.layer = layer
    return {"id":row.id,"placement":row,"role":"covering","layer":1000,
        "node":node,"material":material,"ground_overlay":true,"screen_rect":Rect2(),"positions":[],"slots":{}}

func _batch_positions(entry: Dictionary, positions: Array) -> void:
    if entry.positions == positions: return
    # Background cells never overlap. Preserve their dense native slots rather
    # than resetting the entire buffer when a few cells change style.
    var wanted = {}
    for position in positions: wanted[position] = true
    var removed = []
    for position in entry.positions:
        if not wanted.has(position): removed.append(position)
    removed.reverse()
    _batch_changes(entry,removed,positions)

func _batch_changes(entry: Dictionary, removed: Array, added: Array) -> void:
    var dirty = {}
    var dense: Array = entry.positions
    var slots: Dictionary = entry.slots
    for position in removed:
        if not slots.has(position): continue
        var index: int = slots[position]
        slots.erase(position)
        var last: Vector3 = dense.pop_back()
        if index < dense.size():
            dense[index] = last; slots[last] = index; dirty[index] = true
    for position in added:
        if slots.has(position): continue
        var index = dense.size()
        dense.append(position); slots[position] = index; dirty[index] = true
    var multimesh: MultiMesh = entry.node.multimesh
    # The batch keeps its own copy of the transform buffer and always submits
    # it whole. A single-instance write to a native buffer with no CPU copy
    # first reads the complete buffer back from the GPU, stalling the frame.
    var buffer: PackedFloat32Array = entry.get("buffer",PackedFloat32Array())
    var rebuild: bool = buffer.size() != multimesh.instance_count*12
    if multimesh.instance_count < dense.size():
        var capacity = maxi(8,multimesh.instance_count)
        while capacity < dense.size(): capacity *= 2
        multimesh.instance_count = capacity
        buffer_allocations += 1
        rebuild = true
    if rebuild:
        # Capacity growth replaces every native slot.
        buffer = PackedFloat32Array(); buffer.resize(multimesh.instance_count*12)
        dirty = {}
        for i in range(dense.size()): dirty[i] = true
    for i in dirty:
        if i >= dense.size(): continue
        var position: Vector3 = dense[i]
        var offset: int = i*12
        buffer[offset] = 1; buffer[offset+3] = position.x
        buffer[offset+5] = 1; buffer[offset+7] = position.y
        buffer[offset+10] = 1; buffer[offset+11] = position.z
        transform_writes += 1
    if not dirty.is_empty(): multimesh.buffer = buffer
    entry.buffer = buffer
    multimesh.visible_instance_count = dense.size()

func _change_flat_marks(tiles: Dictionary) -> bool:
    # A style not yet constructed takes the original complete selection path,
    # preserving first-use material identity and painter ordering. Existing
    # flat styles already own native batches; only edited cells move between them.
    # Edited cells usually share the exact style: like the complete path, reuse
    # the previous cell's material when the style is equal.
    var last_style: Dictionary = {}
    for key in changed_marks:
        if not tiles.has(key): continue
        if tiles[key].elevation_steps != 0: return false
        for style in [changed_marks[key],marks.get(key,{})]:
            if style.is_empty() or style == last_style: continue
            if not materials.has([style.colour,style.get("width",2.0),style.get("fill_colour",Color.TRANSPARENT)]): return false
            last_style = style
    var updates = {}
    var last_material: ShaderMaterial = null
    last_style = {}
    for key in changed_marks:
        if not tiles.has(key): continue
        var before: Dictionary = changed_marks[key]
        var after: Dictionary = marks.get(key,{})
        if before == after: continue
        var position: Vector3 = support_positions[key]
        if not before.is_empty():
            if last_material == null or before != last_style:
                last_style = before; last_material = _material(before.colour,before.get("width",2.0),before.get("fill_colour",Color.TRANSPARENT))
            var material = last_material
            if mark_batches.has(material):
                if not updates.has(material): updates[material] = {"removed":[],"added":[]}
                updates[material].removed.append(position)
        if not after.is_empty():
            if last_material == null or after != last_style:
                last_style = after; last_material = _material(after.colour,after.get("width",2.0),after.get("fill_colour",Color.TRANSPARENT))
            var material = last_material
            if not mark_batches.has(material):
                mark_batches[material] = _batch("marks:"+str(material.get_instance_id()),material,2)
                changed = true
            if not updates.has(material): updates[material] = {"removed":[],"added":[]}
            updates[material].added.append(position)
    for material in updates:
        _batch_changes(mark_batches[material],updates[material].removed,updates[material].added)
    if not mark_batches.is_empty() and mark_batches.values().all(func(entry):return entry.positions.is_empty()):
        for entry in mark_batches.values(): entry.node.free()
        mark_batches.clear(); changed = true
    return true

static func _row(key: String, tile: Dictionary) -> Dictionary:
    return {"id":"ground-overlay:"+key,"kind":"terrain","position":tile.position,
        "base_height_steps":tile.elevation_steps,"layer":0,"boundaries":[]}

func capture_support()->Dictionary:
    # Only passive immutable row values cross the existing world worker seam.
    return {"rows":support_rows,"positions":support_positions,"geometry":support_geometry,"raised":raised_supports,
        "background":background_positions,"slots":support_slots,"background_slots":background_slots,"background_keys":background_keys}

static func prepare_support(tiles:Dictionary,changes:Dictionary,previous:Dictionary,rebuild_rows:bool=false)->Dictionary:
    var rows:Dictionary=previous.get("rows",{})
    var full:bool=changes.get("full",false) or rows.is_empty()
    var packet:Dictionary={"full":full,"changes":{},"changed":full and (not rows.is_empty() or not tiles.is_empty())}
    var removed:Array=[];var added:Array=[]
    for key in (changes.get("tiles",{}) if not full else []):
        var tile:Dictionary=tiles.get(key,{})
        var row:Array=[] if tile.is_empty() else [tile.position[0],tile.position[1],tile.elevation_steps]
        var old:Array=rows.get(key,[])
        if row==old:continue
        var position:Vector3=Vector3.ZERO if row.is_empty() else Placement.contact(_row(key,tile))
        packet.changes[key]={"row":row,"position":position}
        if not old.is_empty() and old[2]==0:removed.append(previous.positions[key])
        if not row.is_empty() and row[2]==0:added.append(position)
        packet.changed=true
    packet.grid_removed=removed;packet.grid_added=added
    # A new canonical row-array owner is already an explicit membership
    # preparation. Finish its support directories here too, instead of doing
    # hundreds of dictionary/array mutations at the visible reveal. Ordinary
    # same-membership edits keep their exact sparse operations.
    if full or (rebuild_rows and packet.changed):
        packet.full=true;packet.grid_delta=not full
        # The existing retiring world candidate retains replaced directories;
        # adopting new references must not destroy the old maps on the cue.
        packet.retired=previous
        packet.rows={};packet.geometry=[];packet.positions={};packet.raised={};packet.background=[]
        packet.slots={};packet.background_slots={};packet.background_keys=[]
        for key in tiles:
            var tile:Dictionary=tiles[key]
            var row:Array=[tile.position[0],tile.position[1],tile.elevation_steps]
            var position:Vector3
            if row==rows.get(key,[]):position=previous.positions[key];row=rows[key]
            else:position=Placement.contact(_row(key,tile))
            packet.slots[key]=packet.geometry.size();packet.geometry.append([key]+row)
            packet.rows[key]=row;packet.positions[key]=position
            if row[2]==0:
                packet.background_slots[key]=packet.background.size();packet.background.append(position);packet.background_keys.append(key)
            else:packet.raised[key]=true
    return packet

func publish_support(packet:Dictionary,world_revision:Variant,owner:Dictionary,scope:Variant,owner_revision:int)->void:
    # The candidate already resolved contacts and exact changed support IDs.
    # Publication installs its values; drawing never re-derives this boundary.
    if packet.full:
        support_rows=packet.rows;support_geometry=packet.geometry;support_positions=packet.positions
        raised_supports=packet.raised;background_positions=packet.background
        support_slots=packet.slots;background_slots=packet.background_slots;background_keys=packet.background_keys
        pending_grid_changes=packet.get("grid_delta",false)
        pending_grid_removed=packet.get("grid_removed",[]);pending_grid_added=packet.get("grid_added",[])
    else:
        for key in packet.changes:
            var record:Dictionary=packet.changes[key]
            var old:Array=support_rows.get(key,[])
            if not old.is_empty() and old[2]==0:pending_grid_removed.append(support_positions[key])
            if not record.row.is_empty() and record.row[2]==0:pending_grid_added.append(record.position)
            _update_support(key,{},record.row,record.position)
        pending_grid_changes=pending_grid_changes or not packet.changes.is_empty()
    if packet.changed:support_geometry_revision+=1
    pending_support_change=pending_support_change or packet.changed
    revision=world_revision;support_owner=owner;support_scope=scope;support_revision=owner_revision

func _update_support(key: String, tile: Dictionary, row: Array, prepared_position:Variant=null) -> void:
    var previous: Array = support_rows.get(key,[])
    if previous == row: return
    if not previous.is_empty():
        var slot:int=support_slots[key]
        var tail:Array=support_geometry.pop_back()
        support_slots.erase(key)
        if slot<support_geometry.size():support_geometry[slot]=tail;support_slots[tail[0]]=slot
        if previous[2] == 0:
            slot=background_slots[key]
            var last:Vector3=background_positions.pop_back()
            background_slots.erase(key)
            if slot<background_positions.size():
                background_positions[slot]=last
                # A moved tail has a known support key; no map-wide reverse join.
                var last_key:String=background_keys.pop_back()
                background_keys[slot]=last_key;background_slots[last_key]=slot
            else:background_keys.pop_back()
    if row.is_empty():
        support_rows.erase(key); support_positions.erase(key); raised_supports.erase(key)
        return
    support_rows[key] = row
    support_slots[key]=support_geometry.size()
    support_geometry.append([key]+row)
    var position:Vector3=Placement.contact(_row(key,tile)) if prepared_position==null else prepared_position
    support_contact_updates += 1
    support_positions[key] = position
    if row[2] == 0:
        background_slots[key]=background_positions.size();background_keys.append(key)
        background_positions.append(position)
        raised_supports.erase(key)
    else: raised_supports[key] = true

func current(world_revision: Variant, grid_visible: bool, quarter: int, background: bool, owner: Dictionary, epoch: Variant) -> bool:
    # True exactly when sync would return early: no support, preview, grid or
    # view change. The caller then skips sync and its support snapshot.
    return not pending_support_change and stamp.size()==4 and stamp[0]==grid_visible and stamp[1]==quarter \
        and stamp[2]==background and stamp[3]==preview_revision and revision==world_revision and is_same(support_owner,owner) \
        and support_scope is Array and support_scope.size()==1 and support_scope[0]==epoch

func sync(world: Node, tiles: Dictionary, world_revision: Variant, grid_visible: bool, quarter: int, background: bool, proof: Dictionary = {}) -> Array:
    var began = Time.get_ticks_usec()
    support_checked_tiles = 0
    support_check_us = 0
    mark_update_us = 0
    support_contact_updates = 0
    if root == null:
        root = Node3D.new()
        root.name = "GroundOverlay"
        world.add_child(root)
        mesh = PlaneMesh.new()
        mesh.size = Vector2.ONE
        route_mesh = QuadMesh.new()
    var geometry_changed = pending_support_change
    pending_support_change=false
    # The published row owner survives Timeline's temporary staged tile views.
    # Standalone snapshot callers continue to use their actual tile ownership.
    var source_owner: Dictionary = proof.get("owner",tiles)
    if revision != world_revision or not is_same(support_owner,source_owner) or support_scope != proof.get("scope"):
        # Light, fog and sensory commits still reach the world renderer. Only
        # disclosed support membership, position or height changes ground UI.
        var changes: Dictionary = proof.get("changes",{})
        var sparse = not proof.is_empty() and is_same(support_owner,source_owner) \
            and support_scope == proof.get("scope") and not changes.get("full",true) \
            and changes.get("base_revision",-2) == support_revision \
            and changes.get("revision",-2) == proof.get("revision",-1)
        if sparse:
            for key in changes.get("tiles",{}):
                support_checked_tiles += 1
                var tile: Dictionary = tiles.get(key,{})
                var row: Array = [] if tile.is_empty() else [tile.position[0],tile.position[1],tile.elevation_steps]
                if row != support_rows.get(key,[]):
                    geometry_changed = true
                    _update_support(key,tile,row)
        else:
            var geometry: Array = []
            for key in tiles:
                var tile: Dictionary = tiles[key]
                geometry.append([key,tile.position[0],tile.position[1],tile.elevation_steps])
                support_checked_tiles += 1
            geometry_changed = geometry != support_geometry
        if geometry_changed and not sparse:
            support_geometry = []
            support_rows = {};support_slots={};background_slots={};background_keys=[]
            support_positions = {}; raised_supports = {}; background_positions = []
            for key in tiles:
                var tile: Dictionary = tiles[key]
                var row = [tile.position[0],tile.position[1],tile.elevation_steps]
                support_rows[key] = row
                support_slots[key]=support_geometry.size()
                support_geometry.append([key]+row)
                var position = Placement.contact(_row(key,tile))
                support_contact_updates += 1
                support_positions[key] = position
                if tile.elevation_steps == 0:
                    background_slots[key]=background_positions.size();background_keys.append(key)
                    background_positions.append(position)
                else: raised_supports[key] = true
        if geometry_changed: support_geometry_revision += 1
        revision = world_revision
        support_owner = source_owner
        support_scope = proof.get("scope")
        support_revision = proof.get("revision",-1)
    support_check_us = Time.get_ticks_usec()-began
    var next_stamp = [grid_visible,quarter,background,preview_revision]
    changed = false
    if not geometry_changed and stamp == next_stamp: return ordered
    var mark_began = Time.get_ticks_usec()
    if not geometry_changed and background and not stamp.is_empty() and stamp.slice(0,3)==next_stamp.slice(0,3) and _change_flat_marks(tiles):
        changed = _routes(tiles,background) or changed
        if changed: _order(quarter,background)
        changed_marks.clear(); stamp = next_stamp
        mark_update_us = Time.get_ticks_usec()-mark_began
        return ordered
    # Editing instances in the retained background grid changes its contents,
    # not its one painter entry. Raised cells/routes below report actual order
    # membership or key changes explicitly.
    var order_changed = stamp.is_empty() or stamp.slice(0,3)!=next_stamp.slice(0,3)
    var wanted = {}
    var ground: Array = background_positions if grid_visible and background else []
    var marked: Dictionary = {}
    var candidates: Dictionary = (raised_supports if background else tiles).duplicate() if grid_visible else {}
    for key in mark_order: candidates[key] = true
    var previous_style: Dictionary = {}
    var previous_material: ShaderMaterial
    for key in candidates:
        if not tiles.has(key): continue
        var tile: Dictionary = tiles[key]
        # Ordinary zero-height grid is one native background draw. Marks remain
        # separately ordered ground UI; raised supports keep their own cell key.
        var show_grid = grid_visible and (not background or tile.elevation_steps != 0)
        if not show_grid and not marks.has(key): continue
        var style: Dictionary = marks.get(key,{"colour":GRID_COLOUR,"width":1.0})
        # Adjacent legal cells usually share the exact style. Resolve its native
        # material once per run; the existing interner still owns all materials.
        if previous_material == null or previous_style != style:
            previous_material = _material(style.colour,style.get("width",2.0),style.get("fill_colour",Color.TRANSPARENT))
            previous_style = style
        var material: ShaderMaterial = previous_material
        # The existing background pass places all zero-height marks above its
        # terrain and below every wall/actor. Cells in that pass do not overlap:
        # one MultiMesh per identical style preserves those pixels and ranks.
        # Raised supports still interleave individually with world artwork.
        if background and tile.elevation_steps == 0:
            if not marked.has(material): marked[material] = []
            marked[material].append(support_positions[key])
            continue
        var row = _row(key,tile)
        if not cells.has(key):
            cells[key] = _entry(row.id,row,mesh,material)
            order_changed = true
        var entry: Dictionary = cells[key]
        if entry.placement != row or not entry.has("order_key"):
            entry.placement = row
            entry.node.position = Placement.contact(row)
            order_changed = true
        if entry.material != material:
            entry.material = material
            entry.node.material_override = material
        wanted[key] = true
    for key in cells.keys():
        if not wanted.has(key):
            cells[key].node.free(); cells.erase(key)
            order_changed = true
    for material in marked:
        if not mark_batches.has(material):
            mark_batches[material] = _batch("marks:"+str(material.get_instance_id()),material,2)
            order_changed = true
        _batch_positions(mark_batches[material],marked[material])
    for material in mark_batches.keys():
        if not marked.has(material):
            if not marked.is_empty():
                # Cursor fill membership can temporarily empty a style. Keep its
                # reserved painter entry with zero drawn instances, so restoring
                # that same style does not reorder the complete world.
                _batch_positions(mark_batches[material],[])
            else:
                mark_batches[material].node.free(); mark_batches.erase(material)
                order_changed = true
    if not ground.is_empty():
        if batch.is_empty():
            batch = _batch("background",_material(GRID_COLOUR,1.0),1)
            order_changed = true
        var geometry_stamp = [support_geometry_revision,background]
        if grid_geometry_stamp != geometry_stamp:
            if pending_grid_changes and not grid_geometry_stamp.is_empty() and stamp.slice(0,3)==next_stamp.slice(0,3):
                _batch_changes(batch,pending_grid_removed,pending_grid_added)
            else:_batch_positions(batch,ground)
            grid_geometry_stamp = geometry_stamp
        if not batch.node.visible:order_changed=true
        batch.node.visible = true
    elif not batch.is_empty():
        if batch.node.visible:order_changed=true
        batch.node.visible = false
    order_changed = _routes(tiles,background) or order_changed
    if order_changed:
        _order(quarter,background)
    changed = order_changed
    pending_grid_changes=false;pending_grid_removed=[];pending_grid_added=[]
    changed_marks.clear()
    stamp = next_stamp
    mark_update_us = Time.get_ticks_usec()-mark_began
    return ordered

func _order(quarter: int, background: bool) -> void:
    ordered = cells.values()+routes.values()+mark_batches.values()
    if not batch.is_empty() and batch.node.visible: ordered.append(batch)
    # An entry keeps its key until its placement or the view changes.
    for entry in ordered:
        if not is_same(entry.get("order_placement"),entry.placement) or entry.get("order_quarter",-1)!=quarter or entry.get("order_background")!=background:
            entry.order_key = Order.key(entry.placement,entry.role,entry.layer,quarter,background)
            entry.order_placement = entry.placement; entry.order_quarter = quarter; entry.order_background = background
    ordered.sort_custom(func(a,b):return Order.less(a.order_key,b.order_key) if a.order_key!=b.order_key else a.id<b.id)

func _routes(tiles: Dictionary, background: bool) -> bool:
    var wanted = {}
    var order_changed = false
    # Every route half draws with one material; its segment and colour are
    # instance uniforms. The colour is linearized here exactly as the former
    # source_color material uniform was.
    var linear: Color = route_colour.srgb_to_linear()
    var colour := Vector4(linear.r,linear.g,linear.b,linear.a)
    for i in range(1,path.size()):
        var first_key = "%d,%d" % [path[i-1][0],path[i-1][1]]
        var last_key = "%d,%d" % [path[i][0],path[i][1]]
        if not tiles.has(first_key) or not tiles.has(last_key): continue
        var a = Placement.contact(_row(first_key,tiles[first_key]))
        var b = Placement.contact(_row(last_key,tiles[last_key]))
        if a.is_equal_approx(b): continue
        var middle = (a+b)*.5
        for half in range(2):
            var id = "ground-route:%d:%d" % [i,half]
            var key = first_key if half==0 else last_key
            var row = _row(key,tiles[key])
            row.id = id
            if background and row.base_height_steps == 0: row.layer = 3
            if not routes.has(id):
                if route_material == null:
                    route_material = ShaderMaterial.new()
                    route_material.shader = ROUTE
                routes[id] = _entry(id,row,route_mesh,route_material)
                order_changed = true
            var entry: Dictionary = routes[id]
            if entry.placement != row:
                order_changed = true
                entry.placement = row
            entry.layer = 1001
            var origin: Vector3 = Placement.contact(row)
            var values: Array = [colour,(a if half==0 else middle)-origin,(middle if half==0 else b)-origin,origin]
            if entry.get("route_values") != values:
                entry.node.position = origin
                entry.node.set_instance_shader_parameter("line_colour",values[0])
                entry.node.set_instance_shader_parameter("line_from",values[1])
                entry.node.set_instance_shader_parameter("line_to",values[2])
                entry.route_values = values
            wanted[id] = true
    for id in routes.keys():
        if not wanted.has(id):
            routes[id].node.free(); routes.erase(id)
            order_changed = true
    return order_changed

func close() -> void:
    if is_instance_valid(root): root.free()
    root = null
    cells.clear(); routes.clear(); batch.clear(); mark_batches.clear(); ordered = []; materials.clear(); route_material = null
    changed_marks.clear()
    support_geometry.clear(); grid_geometry_stamp.clear(); stamp.clear()
    support_positions.clear(); raised_supports.clear(); background_positions.clear()
    support_rows.clear();support_slots.clear();background_slots.clear();background_keys.clear()
    pending_support_change=false;pending_grid_changes=false;pending_grid_removed=[];pending_grid_added=[]
    support_owner = {}; support_scope = null; support_revision = -1
    support_geometry_revision = 0
    revision = null
