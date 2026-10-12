extends RefCounted
const Placement = preload("res://placement.gd")
# Map records remain data. Catalog entries refer to existing source owners.
static func placement(entry: Dictionary, identity: String, position: Vector2, height: float, orientation: String = "east") -> Dictionary:
    var row = {"id":identity, "catalog_id":entry.id, "kind":entry.kind, "position":[position.x,position.y],
        "base_height_steps":height, "orientation":orientation, "layer":0}
    for field in ["asset", "material", "sample"]:
        if entry.has(field): row[field] = entry[field]
    if entry.has("states"): row.state = entry.states[0]
    if entry.kind in ["wall", "door"]: row.boundaries = [orientation]
    return row

static func assembly(row: Dictionary, catalog: Dictionary) -> Array:
    var rows: Array = [row]
    var entry: Dictionary = catalog.get(row.get("catalog_id",""),{})
    if entry.is_empty(): return rows
    var members: Array = []
    for variant in entry.get("assemblies",{}).values():
        if variant.get("primary",false): members = variant.members; break
    var rotation = ["east","north","west","south"].find(row.orientation)
    for member in members:
        var id: String = "library/"+member.family_id
        if not catalog.has(id) or not catalog[id].placeable: continue
        var offset: Array = member.offset_XHZ
        var p = Placement.rotate_grid(Vector2(offset[0],offset[2]),rotation)
        var child = placement(catalog[id],row.id+"_member_"+str(rows.size()),Vector2(row.position[0],row.position[1])+p,row.base_height_steps+offset[1],row.orientation)
        child.assembly_id = row.id
        child.sort_role = "terrain" if member.role == "supported_floor" else "wall"
        if child.sort_role == "wall": child.boundaries = [row.orientation]
        rows.append(child)
    # Explicit preview composition of the matching authored wall/insert pair.
    if entry.id.begins_with("environment.window.") and entry.id.ends_with(".wall"):
        var insert_id: String = entry.id.trim_suffix(".wall")+".insert"
        if catalog.has(insert_id):
            var insert = placement(catalog[insert_id],row.id+"_insert",Vector2(row.position[0],row.position[1]),row.base_height_steps,row.orientation)
            insert.parent_id = row.id
            insert.assembly_id = row.id
            insert.layer = 1
            rows.append(insert)
    return rows

static func catalog_map(catalog: Array, copies: int = 1) -> Dictionary:
    var rows: Array = []
    var zones: Array = []
    var placeable = catalog.filter(func(entry): return entry.placeable and entry.get("source_role", "environment") == "environment")
    var column_count = 12
    var last_group = ""
    var by_id = {}
    for entry in catalog: by_id[entry.id] = entry
    var plot = 0
    for copy in range(copies):
        for entry in placeable:
            var col = plot % column_count
            var line = plot / column_count
            var centre = Vector2(col * 8, line * 8)
            var h = 2.0 if entry.group == "props" and (plot % 7) == 0 else 0.0
            var material = "wood" if entry.group in ["props", "doors"] else "stone"
            if entry.group != last_group:
                zones.append({"name":entry.group.capitalize(), "position":[centre.x,centre.y]})
                last_group = entry.group
            for x in range(-2, 3):
                for z in range(-2, 3):
                    var id = "floor_%s_%s_%s" % [plot,x,z]
                    rows.append({"id":id,"kind":"terrain","material":material,"position":[centre.x+x,centre.y+z],"base_height_steps":h})
                    if h > 0 and x in [-2,2] and z in [-2,2]:
                        rows.append({"id":id+"_corner","kind":"cliff","orientation":"east","boundaries":["west" if x==-2 else "east","south" if z==-2 else "north"],"position":[centre.x+x,centre.y+z],"base_height_steps":0,"upper_support_id":id})
                    elif h > 0 and x in [-2,2] and not (x == 2 and z == 0):
                        rows.append({"id":id+"_side","kind":"cliff","orientation":"west" if x == -2 else "east", "position":[centre.x+x,centre.y+z],"base_height_steps":0,"upper_support_id":id})
                    if h > 0 and z in [-2,2] and x not in [-2,2]:
                        rows.append({"id":id+"_end","kind":"cliff","orientation":"south" if z == -2 else "north", "position":[centre.x+x,centre.y+z],"base_height_steps":0,"upper_support_id":id})
            # Connected stone paths make the catalog navigable as districts.
            for x in range(-2,6):
                for z in range(-2,6):
                    if x <= 2 and z <= 2: continue
                    rows.append({"id":"road_%s_%s_%s" % [plot,x,z],"kind":"terrain","material":"stone","position":[centre.x+x,centre.y+z],"base_height_steps":0})
            if h > 0:
                rows.append({"id":"stairs_%s" % plot,"kind":"stairs","orientation":"east","position":[centre.x+4,centre.y],"base_height_steps":0})
            rows.append_array(assembly(placement(entry,"asset_%s" % plot,centre,h),by_id))
            plot += 1
    rows.append({"id":"player","kind":"actor","position":[-1,1],"base_height_steps":2,"support_id":"floor_0_-1_1","rig":"neuroclient.modular","facing":"S"})
    return {"id":"catalog","name":"Environment workshop", "camera_size":12.0,"placements":rows,"zones":zones,"asset_count":plot,"copies":copies}
