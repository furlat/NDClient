extends RefCounted
# Passive placement records and composition functions. No gameplay objects.

const HEIGHT_UNIT = sqrt(2.0 / 3.0)
const PIXELS_PER_UNIT = 64.0 * sqrt(2.0)
const POSES = ["e", "s", "w", "n"]
const DIRECTIONS = {"east": Vector2(1, 0), "north": Vector2(0, 1), "west": Vector2(-1, 0), "south": Vector2(0, -1)}
const STAGES = {"terrain": 0, "covering": 1, "shadow": 2, "body": 3, "wall": 3, "cliff": 3}

static func facing(direction:Vector2,cycle:Array)->String:
    return cycle[posmod(roundi((atan2(direction.y,direction.x)+PI/4)/(TAU/8))+cycle.find("E"),8)]

static func camera_transform(focus: Vector3, quarter: int) -> Transform3D:
    var offset=Basis(Vector3.UP,quarter*PI*.5)*Vector3(12,12*HEIGHT_UNIT,12)
    # Pan changes only translation. Subtracting a translated target in look_at
    # introduces tiny rotation changes and invalidates every light receiver.
    return Transform3D(Basis.looking_at(-offset),focus+offset)

static func contact(row: Dictionary) -> Vector3:
    return Vector3(row.position[0], row.base_height_steps * HEIGHT_UNIT, row.position[1])

static func rotate_grid(point: Vector2, quarter: int) -> Vector2:
    for i in range(quarter):
        point = Vector2(-point.y, point.x)
    return point

static func project(point: Vector2, height: float, quarter: int) -> Vector2:
    var p = rotate_grid(point, quarter)
    return Vector2(64.0 * (p.x - p.y), 32.0 * (p.x + p.y) - 64.0 * height)

static func pose(direction: String, quarter: int) -> String:
    return POSES[posmod(["east", "north", "west", "south"].find(direction) + quarter, 4)]

static func sort_contact(row: Dictionary, quarter: int) -> Vector2:
    var p = Vector2(row.position[0], row.position[1])
    var result = project(p, 0, quarter)
    var first = true
    for direction in row.get("boundaries", []):
        var edge = project(p + DIRECTIONS[direction] * 0.5, 0, quarter)
        if first or edge.y > result.y or (is_equal_approx(edge.y, result.y) and edge.x > result.x):
            result = edge
        first = false
    return result

static func stage(role: String) -> int:
    return STAGES[role]

static func band(entry: Dictionary) -> int:
    return 1 if entry.get("floor_group", false) else stage(entry.role)

static func before(a: Dictionary, b: Dictionary) -> bool:
    # Relations come from support and authored component membership, not RGB or
    # inferred surface depths. Screen overlap only limits work; it is not a mount.
    if not a.screen_rect.intersects(b.screen_rect):
        return false
    var ar: Dictionary = a.placement
    var br: Dictionary = b.placement
    if br.get("roof",false) and not ar.get("roof",false) and ar.get("building_id","") != "" and ar.get("building_id") == br.get("building_id"):
        return true
    var ah: float = ar.base_height_steps
    var bh: float = br.base_height_steps
    if ar.get("kind", "") == "stairs" and br.get("support_id", "") == ar.id:
        return true
    if ar.id == br.id:
        return a.layer < b.layer
    if is_equal_approx(ah, bh):
        if band(a) < band(b) and band(a) <= 1:
            return true
        if band(a) == 1 and band(b) == 1:
            return a.layer < b.layer
    # An upper support covers lower occupants directly beneath its cell. A
    # lower actor outside that cell keeps its ordinary foreground contact order.
    if b.role == "terrain" and ah < bh and a.role != "terrain":
        if a.role == "cliff" and ar.get("upper_support_id", "") == br.id:
            return false
        var delta = Vector2(ar.position[0] - br.position[0], ar.position[1] - br.position[1])
        return absf(delta.x) <= 0.5 and absf(delta.y) <= 0.5
    # The cliff's registered upper rim belongs over its own supported tile.
    if a.role == "terrain" and b.role == "cliff":
        return ar.id == br.get("upper_support_id", "")
    return false

static func key(entry: Dictionary, quarter: int) -> Array:
    var row: Dictionary = entry.placement
    var p = sort_contact(row, quarter)
    var background = 0 if entry.role == "terrain" and row.base_height_steps == 0 else 1
    return [background, row.get("layer",0) if entry.role == "terrain" and row.has("source_sprite") else 0, p.y, p.x, row.base_height_steps, band(entry), entry.layer, entry.id]

static func key_less(a: Array, b: Array) -> bool:
    for i in range(a.size()):
        if a[i] != b[i]:
            return a[i] < b[i]
    return false

static func compose_local(entries: Array, quarter: int) -> Dictionary:
    # Stable topological ordering of local support/component constraints. The
    # ordinary painter key orders unrelated visible pieces, including heights.
    var successors: Array = []
    var incoming: Array[int] = []
    var keys: Array = []
    for entry in entries:
        successors.append([])
        incoming.append(0)
        keys.append(key(entry, quarter))
    # Only overlapping rectangles can create an edge. A projected spatial grid
    # retains exactly the same relations without a global all-pairs scan.
    var buckets = {}
    var non_terrain_buckets = {}
    var producer_buckets = {}
    var has_edges = false
    var owners = {}
    for i in range(entries.size()):
        var rect: Rect2 = entries[i].screen_rect
        var start = (rect.position / 256.0).floor()
        var end = (rect.end / 256.0).floor()
        var candidates = {}
        var producer = band(entries[i]) <= 1 or entries[i].role == "terrain" or entries[i].placement.get("kind","") == "stairs" or entries[i].placement.get("roof",false)
        var owner: String = entries[i].placement.id
        for j in owners.get(owner,[]): candidates[j] = true
        if not owners.has(owner): owners[owner] = []
        owners[owner].append(i)
        for x in range(int(start.x), int(end.x)+1):
            for y in range(int(start.y), int(end.y)+1):
                var cell = Vector2i(x,y)
                # Terrain-to-terrain pairs never impose a constraint. Keep
                # those thousands of floor quads out of each other's queries.
                var query: Dictionary = non_terrain_buckets if entries[i].role == "terrain" else (buckets if producer else producer_buckets)
                for j in query.get(cell, []): candidates[j] = true
                if not buckets.has(cell): buckets[cell] = []
                buckets[cell].append(i)
                if producer:
                    if not producer_buckets.has(cell): producer_buckets[cell] = []
                    producer_buckets[cell].append(i)
                if entries[i].role != "terrain":
                    if not non_terrain_buckets.has(cell): non_terrain_buckets[cell] = []
                    non_terrain_buckets[cell].append(i)
        for j in candidates:
            if before(entries[i], entries[j]):
                has_edges = true
                successors[i].append(j)
                incoming[j] += 1
            if before(entries[j], entries[i]):
                has_edges = true
                successors[j].append(i)
                incoming[i] += 1
    if not has_edges:
        var ordered: Array[int] = []
        ordered.assign(range(entries.size()))
        ordered.sort_custom(func(a,b):return key_less(keys[a],keys[b]))
        return {"order":ordered,"unresolved":[]}
    var ready: Array[int] = []
    for i in range(entries.size()):
        if incoming[i] == 0: heap_push(ready, i, keys)
    var order: Array[int] = []
    while not ready.is_empty():
        var current = heap_pop(ready, keys)
        order.append(current)
        for next in successors[current]:
            incoming[next] -= 1
            if incoming[next] == 0: heap_push(ready, next, keys)
    var unresolved: Array[String] = []
    for i in range(entries.size()):
        if incoming[i] > 0:
            unresolved.append(entries[i].id)
    return {"order": order, "unresolved": unresolved}

static func heap_push(heap: Array[int], value: int, keys: Array) -> void:
    heap.append(value)
    var i = heap.size()-1
    while i > 0:
        var parent = (i-1)/2
        if not key_less(keys[value], keys[heap[parent]]): break
        heap[i] = heap[parent]
        i = parent
    heap[i] = value

static func heap_pop(heap: Array[int], keys: Array) -> int:
    var result = heap[0]
    var tail = heap.pop_back()
    if heap.is_empty(): return result
    var i = 0
    while i*2+1 < heap.size():
        var child = i*2+1
        if child+1 < heap.size() and key_less(keys[heap[child+1]], keys[heap[child]]): child += 1
        if not key_less(keys[heap[child]], keys[tail]): break
        heap[i] = heap[child]
        i = child
    heap[i] = tail
    return result

static func compose(entries: Array, quarter: int, cache: Dictionary = {}) -> Dictionary:
    # Only extract the lowest terrain band. Supports above a lower occupant
    # must remain in the constraint graph, including underground placements.
    var lowest = 0.0
    for entry in entries: lowest = minf(lowest, entry.placement.base_height_steps)
    if cache.get("lowest") != lowest or cache.get("quarter") != quarter or cache.get("size") != entries.size():
        cache.clear()
    if cache.is_empty():
        var background: Array[int] = []
        var foreground: Array[int] = []
        var background_keys = {}
        for i in range(entries.size()):
            if entries[i].role == "terrain" and entries[i].placement.base_height_steps == lowest:
                background.append(i)
                background_keys[i] = key(entries[i],quarter)
            else: foreground.append(i)
        background.sort_custom(func(a,b): return key_less(background_keys[a],background_keys[b]))
        cache.merge({"lowest":lowest,"quarter":quarter,"size":entries.size(),"background":background,"foreground":foreground})
    var local: Array = []
    var foreground: Array[int] = cache.foreground
    for index in foreground: local.append(entries[index])
    var result = compose_local(local,quarter)
    var order: Array[int] = cache.background.duplicate()
    for index in result.order: order.append(foreground[index])
    return {"order":order,"unresolved":result.unresolved}

static func compose_exploration(entries: Array, quarter: int, cache: Dictionary) -> Dictionary:
    # Build the complete static support constraints once. Moving actor layers
    # query only overlapping static pieces, then merge into that stable order.
    if cache.get("size") != entries.size() or cache.get("quarter") != quarter:
        cache.clear()
    if not cache.has("static_order"):
        var static_indices: Array[int] = []
        var static_entries: Array = []
        var mobile: Array[int] = []
        for i in range(entries.size()):
            if entries[i].placement.kind == "actor" or entries[i].get("mobile",false): mobile.append(i)
            else:
                static_indices.append(i)
                static_entries.append(entries[i])
        var result = compose(static_entries,quarter,{})
        var order: Array[int] = []
        var keys = []
        var buckets = {}
        for rank in range(result.order.size()):
            var i: int = static_indices[result.order[rank]]
            order.append(i)
            keys.append({"key":key(entries[i],quarter),"rank":rank})
            var rect: Rect2 = entries[i].screen_rect
            var start=(rect.position/256).floor();var end=(rect.end/256).floor()
            for x in range(int(start.x),int(end.x)+1):
                for y in range(int(start.y),int(end.y)+1):
                    var cell=Vector2i(x,y)
                    if not buckets.has(cell):buckets[cell]=[]
                    buckets[cell].append(rank)
        keys.sort_custom(func(a,b):return key_less(a.key,b.key))
        var preceding=-1
        for item in keys:
            preceding=maxi(preceding,item.rank)
            item.prefix_rank=preceding
        cache.merge({"static_order":order,"mobile":mobile,"keys":keys,"buckets":buckets,
            "quarter":quarter,"size":entries.size(),"unresolved":result.unresolved})
    var static_order: Array = cache.static_order
    var mobile: Array = cache.mobile.duplicate()
    mobile.sort_custom(func(a,b):return key_less(key(entries[a],quarter),key(entries[b],quarter)))
    var insertions = {}
    var previous_owner = {}
    var actor_bounds = {}
    for i in mobile:
        var entry: Dictionary = entries[i]
        var wanted = key(entry,quarter)
        var lo=0;var hi=cache.keys.size()
        while lo<hi:
            var mid=(lo+hi)/2
            if key_less(cache.keys[mid].key,wanted):lo=mid+1
            else:hi=mid
        var preferred=cache.keys[lo-1].prefix_rank+1 if lo>0 else 0
        var bounds_key = [entry.placement.id,entry.screen_rect,band(entry)]
        if not actor_bounds.has(bounds_key):
            var lower=0;var upper=static_order.size()
            var candidates={}
            var start=(entry.screen_rect.position/256).floor();var end=(entry.screen_rect.end/256).floor()
            for x in range(int(start.x),int(end.x)+1):
                for y in range(int(start.y),int(end.y)+1):
                    for rank in cache.buckets.get(Vector2i(x,y),[]):candidates[rank]=true
            for rank in candidates:
                var other: Dictionary = entries[static_order[rank]]
                if before(other,entry):lower=maxi(lower,rank+1)
                if before(entry,other):upper=mini(upper,rank)
            actor_bounds[bounds_key]=[lower,upper]
        var lower=maxi(actor_bounds[bounds_key][0],previous_owner.get(entry.placement.id,0))
        var upper=actor_bounds[bounds_key][1]
        if lower>upper:
            # The caller applies the full fallback order. The next successful
            # cached insertion must therefore publish its full order as well.
            cache.erase("merged_order")
            cache.erase("mobile_positions")
            return compose(entries,quarter,{})
        var slot=clampi(preferred,lower,upper)
        previous_owner[entry.placement.id]=slot
        if not insertions.has(slot):insertions[slot]=[]
        insertions[slot].append(i)
    var fresh = not cache.has("merged_order")
    if fresh:
        cache.merged_order = static_order.duplicate()
        cache.mobile_positions = {}
    var dirty_start = cache.merged_order.size()
    var dirty_end = 0
    var old_positions: Array = cache.mobile_positions.values()
    old_positions.sort()
    old_positions.reverse()
    for rank in old_positions:
        dirty_start=mini(dirty_start,rank);dirty_end=maxi(dirty_end,rank)
        cache.merged_order.remove_at(rank)
    cache.mobile_positions.clear()
    var slots: Array = insertions.keys()
    slots.sort()
    var added=0
    for slot in slots:
        for i in insertions[slot]:
            var rank=slot+added
            cache.merged_order.insert(rank,i)
            cache.mobile_positions[i]=rank
            dirty_start=mini(dirty_start,rank);dirty_end=maxi(dirty_end,rank)
            added+=1
    var result={"order":cache.merged_order,"unresolved":cache.unresolved}
    if not fresh:
        result.changed_start=dirty_start
        result.changed_end=dirty_end+1
    return result
