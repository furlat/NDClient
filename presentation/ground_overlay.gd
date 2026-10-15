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
var revision: Variant = null
var marks: Dictionary = {}
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
var support_checked_tiles = 0
var support_check_us = 0
var mark_update_us = 0
var support_geometry_revision = 0
var support_contact_updates = 0

func set_preview(value: Dictionary, route: Array = [], colour: Color = Color("70d6be")) -> void:
    # Keys are disclosed tile keys; values {colour:Color,width:float}. The path
    # comes directly from SDK preview.selected_route, never local pathfinding.
    if marks == value and path == route and route_colour == colour: return
    marks = value.duplicate(true)
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
    var dirty = {}
    var dense: Array = entry.positions
    var slots: Dictionary = entry.slots
    for i in range(dense.size()-1,-1,-1):
        if wanted.has(dense[i]): continue
        slots.erase(dense[i])
        var last: Vector3 = dense.pop_back()
        if i < dense.size():
            dense[i] = last; slots[last] = i; dirty[i] = true
    for position in positions:
        if slots.has(position): continue
        var index = dense.size()
        dense.append(position); slots[position] = index; dirty[index] = true
    var multimesh: MultiMesh = entry.node.multimesh
    if multimesh.instance_count < dense.size():
        var capacity = maxi(8,multimesh.instance_count)
        while capacity < dense.size(): capacity *= 2
        multimesh.instance_count = capacity
        buffer_allocations += 1
        for i in range(dense.size()): dirty[i] = true
    for i in dirty:
        if i >= dense.size(): continue
        multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,dense[i]))
        transform_writes += 1
    multimesh.visible_instance_count = dense.size()

static func _row(key: String, tile: Dictionary) -> Dictionary:
    return {"id":"ground-overlay:"+key,"kind":"terrain","position":tile.position,
        "base_height_steps":tile.elevation_steps,"layer":0,"boundaries":[]}

func _update_support(key: String, tile: Dictionary, row: Array) -> void:
    var previous: Array = support_rows.get(key,[])
    if previous == row: return
    if not previous.is_empty():
        support_geometry.erase([key]+previous)
        if previous[2] == 0: background_positions.erase(support_positions[key])
    if row.is_empty():
        support_rows.erase(key); support_positions.erase(key); raised_supports.erase(key)
        return
    support_rows[key] = row
    support_geometry.append([key]+row)
    var position = Placement.contact(_row(key,tile))
    support_contact_updates += 1
    support_positions[key] = position
    if tile.elevation_steps == 0:
        background_positions.append(position)
        raised_supports.erase(key)
    else: raised_supports[key] = true

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
    var geometry_changed = false
    if revision != world_revision or not is_same(support_owner,tiles) or support_scope != proof.get("scope"):
        # Light, fog and sensory commits still reach the world renderer. Only
        # disclosed support membership, position or height changes ground UI.
        var changes: Dictionary = proof.get("changes",{})
        var sparse = not proof.is_empty() and is_same(support_owner,tiles) \
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
            support_rows = {}
            support_positions = {}; raised_supports = {}; background_positions = []
            for key in tiles:
                var tile: Dictionary = tiles[key]
                var row = [tile.position[0],tile.position[1],tile.elevation_steps]
                support_rows[key] = row
                support_geometry.append([key]+row)
                var position = Placement.contact(_row(key,tile))
                support_contact_updates += 1
                support_positions[key] = position
                if tile.elevation_steps == 0: background_positions.append(position)
                else: raised_supports[key] = true
        if geometry_changed: support_geometry_revision += 1
        revision = world_revision
        support_owner = tiles
        support_scope = proof.get("scope")
        support_revision = proof.get("revision",-1)
    support_check_us = Time.get_ticks_usec()-began
    var next_stamp = [grid_visible,quarter,background,preview_revision]
    changed = false
    if not geometry_changed and stamp == next_stamp: return ordered
    var mark_began = Time.get_ticks_usec()
    var order_changed = geometry_changed or stamp.is_empty() or stamp.slice(0,3)!=next_stamp.slice(0,3)
    var wanted = {}
    var ground: Array = background_positions if grid_visible and background else []
    var marked: Dictionary = {}
    var candidates: Dictionary = (raised_supports if background else tiles).duplicate() if grid_visible else {}
    candidates.merge(marks)
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
            _batch_positions(batch,ground)
            grid_geometry_stamp = geometry_stamp
        batch.node.visible = true
    elif not batch.is_empty(): batch.node.visible = false
    order_changed = _routes(tiles,background) or order_changed
    if order_changed:
        ordered = cells.values()+routes.values()+mark_batches.values()
        if not batch.is_empty() and batch.node.visible: ordered.append(batch)
        for entry in ordered: entry.order_key = Order.key(entry.placement,entry.role,entry.layer,quarter,background)
        ordered.sort_custom(func(a,b):return Order.less(a.order_key,b.order_key) if a.order_key!=b.order_key else a.id<b.id)
    changed = order_changed
    stamp = next_stamp
    mark_update_us = Time.get_ticks_usec()-mark_began
    return ordered

func _routes(tiles: Dictionary, background: bool) -> bool:
    var wanted = {}
    var order_changed = false
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
                var material = ShaderMaterial.new()
                material.shader = ROUTE
                routes[id] = _entry(id,row,route_mesh,material)
                order_changed = true
            var entry: Dictionary = routes[id]
            if entry.placement != row: order_changed = true
            entry.placement = row
            entry.layer = 1001
            entry.node.position = Placement.contact(row)
            entry.material.set_shader_parameter("line_colour",route_colour)
            entry.material.set_shader_parameter("line_from",(a if half==0 else middle)-entry.node.position)
            entry.material.set_shader_parameter("line_to",(middle if half==0 else b)-entry.node.position)
            wanted[id] = true
    for id in routes.keys():
        if not wanted.has(id):
            routes[id].node.free(); routes.erase(id)
            order_changed = true
    return order_changed

func merge(fixed: Array) -> Array:
    # Both subsequences already use the production total painter key.
    var result: Array = []
    var cursor = 0
    for entry in ordered:
        while cursor<fixed.size() and (Order.less(fixed[cursor].order_key,entry.order_key) if fixed[cursor].order_key!=entry.order_key else fixed[cursor].id<entry.id):
            result.append(fixed[cursor]); cursor += 1
        result.append(entry)
    result.append_array(fixed.slice(cursor))
    return result

func close() -> void:
    if is_instance_valid(root): root.free()
    root = null
    cells.clear(); routes.clear(); batch.clear(); mark_batches.clear(); ordered.clear(); materials.clear()
    support_geometry.clear(); grid_geometry_stamp.clear(); stamp.clear()
    support_positions.clear(); raised_supports.clear(); background_positions.clear()
    support_rows.clear(); support_owner = {}; support_scope = null; support_revision = -1
    support_geometry_revision = 0
    revision = null
