extends RefCounted
# Read the existing authoring owners; adapters return transient draw records.
const Placement = preload("res://placement.gd")
# Client original-rest selection policy, reusing the explicit chest pairs in
# tools/build_unity_map.py. Source owner JSON binds reconstructed destruction
# rests; retain those banks for destruction, and use the registered originals
# for intact display. This is not a new source-authoring binding.
const ORIGINAL_CHEST_RESTS = {
    "prop.chest-a1.intact":"fantasy.chest.a1", "prop.chest-a2.intact":"fantasy.chest.a2",
    "prop.chest-a3.intact":"fantasy.chest.a3", "prop.chest-a4.intact":"fantasy.chest.a4",
    "prop.chest-b1.intact":"fantasy.chest.b1", "prop.chest-b2.intact":"fantasy.chest.b2",
}

static func media_path(path: String) -> String:
    if path.begins_with("res://"): return ProjectSettings.globalize_path(path)
    if path.begins_with("C:/"): return path
    var root: String = ProjectSettings.get_setting("source_data/media_root")
    var absolute = root.path_join(path.trim_prefix("/media/"))
    # Extended UNC keeps the original deep asset paths readable on Windows.
    if OS.get_name()=="Windows" and absolute.begins_with("//") and not absolute.begins_with("//?/"):
        return "//?/UNC/"+absolute.trim_prefix("//")
    return absolute

static func read_file(relative_path: String, cache: Dictionary) -> Dictionary:
    if not cache.has(relative_path):
        var root: String = ProjectSettings.get_setting("source_data/authoring_root")
        cache[relative_path] = JSON.parse_string(FileAccess.get_file_as_string(root.path_join(relative_path)))
    return cache[relative_path]

static func bank_for(row: Dictionary, broken: bool, cache: Dictionary) -> String:
    var index = read_file("environment/index.json", cache)
    var state: String = row.get("state", "default")
    if row.kind == "wall":
        return read_file(index.wall_destructions, cache)[row.material] if broken else ""
    if row.kind not in ["prop", "door", "trap", "bank"]: return ""
    if row.kind == "bank": return row.asset
    var group: String = {"prop": "props", "door": "doors", "trap": "traps"}[row.kind]
    var owner = read_file(index[group][row.asset], cache)
    if row.kind == "door":
        if broken: return owner.destructions[state + "." + row.get("outcome", "clear")]
        return owner.openings["inward" if state == "open.inward" else "outward"]
    if broken:
        var options: Dictionary = owner.get("destructions_without_attachments", {}) if row.get("attachment_absent", false) else owner.destructions
        if options.is_empty(): options = owner.destructions
        return options.get(state, "")
    if row.kind == "trap": return owner.intact
    return owner.intact.get(state, owner.intact.values()[0])

static func bank_data(id: String, cache: Dictionary) -> Dictionary:
    var index = read_file("environment/index.json", cache)
    return read_file(index.banks[id], cache)

static func frame_at(bank: Dictionary, time: float) -> int:
    if bank.has("sample_times_ms"):
        var result = 0
        for i in range(bank.sample_times_ms.size()):
            if bank.sample_times_ms[i] <= time * 1000 + 0.0001: result = i
        return result
    return clampi(int(floor(time * bank.fps + 0.00001)), 0, int(bank.frame_count) - 1)

static func duration(bank: Dictionary) -> float:
    return float(bank.duration_ms) / 1000.0

static func pose_for(bank: Dictionary, direction: String, quarter: int) -> String:
    var view = Placement.pose(direction, quarter)
    var orientation = ["east", "north", "west", "south"].find(direction)
    if bank.has("camera_quarter_by_pose"):
        var wanted_quarter = posmod(quarter + orientation, 4)
        for candidate in bank.camera_quarter_by_pose:
            if bank.camera_quarter_by_pose[candidate] == wanted_quarter: return candidate
    var surfaces: Dictionary = bank.surface_frames_by_pose
    if surfaces[view][0].geometry.basis == "object_local":
        var object_rotation = Basis(Vector3.UP, -orientation * PI / 2)
        var wanted = (Basis(Vector3.UP, quarter * PI / 2) * Vector3(1, 1, 1)).normalized()
        var best = -2.0
        for candidate in bank.rows:
            var alignment = (object_rotation * local_ray(surfaces[candidate][0].geometry)).normalized().dot(wanted)
            if alignment > best: best = alignment; view = candidate
    return view

static func local_ray(geometry: Dictionary) -> Vector3:
    var rows: Array = geometry.sourceToLocal
    var ray: Array = geometry.rayDirection
    return Vector3(rows[0][0]*ray[0]+rows[0][1]*ray[1]+rows[0][2]*ray[2],
        rows[1][0]*ray[0]+rows[1][1]*ray[1]+rows[1][2]*ray[2], rows[2][0]*ray[0]+rows[2][1]*ray[1]+rows[2][2]*ray[2])

static func sequences(row: Dictionary, cache: Dictionary) -> Array:
    if not cache.has("library_sequences"):
        cache.library_sequences = JSON.parse_string(FileAccess.get_file_as_string("res://generated/library_sequences.json"))
    return cache.library_sequences.get(row.asset,[])

static func library_sequence(row: Dictionary, cache: Dictionary, broken: bool = false) -> int:
    var options = sequences(row,cache)
    var selected = int(row.get("sequence",0))
    if selected<0 or selected>=options.size():return -1
    if not broken or row.get("preview_sequence",false): return selected
    if options[selected].destruction: return selected
    var axes: Dictionary = options[selected].axes
    for i in range(options.size()):
        if not options[i].destruction: continue
        var compatible = true
        for axis in ["pitch_degrees","aim_row"]:
            if options[i].axes.get(axis) != axes.get(axis): compatible = false
        if compatible: return i
    return -1

static func break_duration(row: Dictionary, cache: Dictionary) -> float:
    if row.has("break_owner"):return break_duration(row.break_owner,cache)
    if row.has("source_sprite") and not row.has("asset"): return 0.0
    if row.kind == "library":
        var index = library_sequence(row,cache,true)
        return sequences(row,cache)[index].duration_ms / 1000.0 if index >= 0 else 0.0
    var bank = bank_for(row,true,cache)
    return duration(bank_data(bank,cache)) if not bank.is_empty() else 0.0

static func library_record(row: Dictionary, quarter: int, cache: Dictionary, phase: int, time: float) -> Dictionary:
    var index = read_file("environment/index.json", cache)
    var library = read_file(index.library[row.asset], cache)
    var options = sequences(row,cache)
    var selected_sequence = library_sequence(row,cache,phase > 0)
    if selected_sequence < 0: selected_sequence = int(row.get("sequence",0))
    var sequence: Dictionary = options[selected_sequence]
    if phase == 2 and sequence.axes.get("state","") == "destruction":
        for option in options:
            # Device owner wreck_sheets are independent of firing pitch.
            if option.axes.get("state","") == "wreck" and option.axes.get("aim_row") == sequence.axes.get("aim_row"):
                sequence = option
                break
    elif phase == 2:
        for option in options:
            if option.axes.get("state","") == "settled_state" and option.axes.get("variant_index") == sequence.axes.get("variant_index") and option.axes.get("variant_name") == sequence.axes.get("variant_name"):
                sequence = option
                break
    var direction: String = row.get("orientation", "east")
    var orientation = ["east", "north", "west", "south"].find(direction)
    var wanted = (Basis(Vector3.UP, quarter * PI / 2) * Vector3(1,1,1)).normalized()
    var rotation = Basis(Vector3.UP, -orientation * PI / 2)
    var best = -3.0
    var view_indices: Array = []
    for indices in sequence.views.values():
        var candidate: Dictionary = library.samples[int(indices[0])]
        var score = 0.0
        if candidate.has("camera_quadrant"):
            score = 2.0 if candidate.camera_quadrant == posmod(quarter + orientation, 4) else -2.0
        elif candidate.surface.has("geometry") and candidate.surface.geometry.basis == "object_local":
            score = (rotation * local_ray(candidate.surface.geometry)).normalized().dot(wanted)
        else:
            score = 1.0 if candidate.source_view == Placement.pose(direction, quarter) else -1.0
        if score > best: best = score; view_indices = indices
    var frame = 0
    if phase == 2: frame = view_indices.size()-1
    elif phase == 1:
        for i in range(view_indices.size()):
            var sample: Dictionary = library.samples[int(view_indices[i])]
            var sample_time = sample.get("time_ms", i * 1000.0 / maxf(sequence.fps,1.0))
            if sample_time <= time*1000.0+0.0001: frame = i
    else: frame = mini(int(row.get("frame",0)),view_indices.size()-1)
    var selected: Dictionary = library.samples[int(view_indices[frame])]
    var result: Dictionary = selected.surface.duplicate(true)
    var rect: Array = selected.colour.rect
    result.merge({"path": selected.colour.path, "rect": rect, "native_size": [rect[2],rect[3]],
        "pivot": selected.get("physical_source_contact_px", selected.pivot), "scale": selected.scale,
        "frame": frame,"source_sample":int(view_indices[frame]),"source_frame":selected.frame_index,
        "source_state":selected.state,"source_variant":selected.get("variant_name",""),
        "hidden":phase==2 and sequence.clear_at_end})
    return result

static func owner_for(row: Dictionary, cache: Dictionary) -> Dictionary:
    if row.kind not in ["prop","door","trap"]: return {}
    var index = read_file("environment/index.json",cache)
    return read_file(index[{"prop":"props","door":"doors","trap":"traps"}[row.kind]][row.asset],cache)

static func door_frame(row: Dictionary, quarter: int, cache: Dictionary) -> Dictionary:
    var owner = owner_for(row,cache)
    var boundary = Placement.pose(row.orientation,quarter)
    if not owner.frame_resource_by_pose.is_empty():
        return read_file("assets.json",cache).resources[owner.frame_resource_by_pose[boundary]]
    var bank = bank_data(bank_for(row,false,cache),cache)
    var pose = pose_for(bank,row.orientation,quarter)
    if not bank.has("frame_regions_by_pose"): return {}
    var region: Dictionary = bank.frame_regions_by_pose[pose]
    var result: Dictionary = bank.surface_frames_by_pose[pose][0].duplicate(true)
    result.merge({"path":region.path,"rect":region.rect,"native_size":bank.cell,
        "pivot":bank.get("physical_source_contact_by_pose",bank.pivots_by_pose)[pose],"scale":bank.scale})
    return result

static func imported_record(row: Dictionary, quarter: int, cache: Dictionary, phase: int, time: float) -> Dictionary:
    if not cache.has("unity_sources"):
        cache.unity_sources = JSON.parse_string(FileAccess.get_file_as_string("res://generated/unity_sources.json"))
    var source: Dictionary = cache.unity_sources[row.source_sprite]
    if source.has("records"): return source.records[quarter]
    if phase > 0:
        if row.has("break_owner"):
            var effective: Dictionary = row.duplicate()
            effective.erase("source_sprite")
            effective.merge(row.break_owner,true)
            return environment(effective,quarter,cache,phase,time)
        return library_record(row,quarter,cache,phase,time)
    var key = "unity_record:"+row.source_sprite+":"+str(quarter)
    if not cache.has(key):
        var index = read_file("environment/index.json",cache)
        var owner = read_file(index.library[source.asset],cache)
        var sample: Dictionary = owner.samples[int(source.samples[quarter])]
        var result: Dictionary = sample.surface.duplicate(true)
        var rect: Array = sample.colour.rect
        result.merge({"path":sample.colour.path,"rect":rect,"native_size":[rect[2],rect[3]],
            "pivot":source.contact_override[quarter] if source.has("contact_override") else sample.get("physical_source_contact_px",sample.get("pivot",source.pivot)),"scale":source.scale,
            "source_sample":source.samples[quarter],"frame":sample.frame_index})
        cache[key] = result
    return cache[key]

static func receiving_normal(record: Dictionary, cache: Dictionary) -> Dictionary:
    if not record.has("normal"): return record
    # Small receiving-only derivation from retained source render passes. It is
    # never a replacement for the source depth, support, color or registration.
    var key = "__pixel_integrated_receiving_normals"
    if not cache.has(key):
        cache[key] = JSON.parse_string(FileAccess.get_file_as_string("res://generated/environment_receiving_normals.json")).normals
    var original_path: String = record.normal.region.path
    if not cache[key].has(original_path): return record
    var selected: Dictionary = cache[key][original_path]
    var result = record.duplicate()
    result.normal = record.normal.duplicate()
    result.normal.region = record.normal.region.duplicate()
    result.normal.region.path = selected.path
    result.normal.receiving_qualification = selected.qualification
    result.normal.original_path = original_path
    return result

static func environment(row: Dictionary, quarter: int, cache: Dictionary, phase: int = 0, time: float = 0.0) -> Dictionary:
    return receiving_normal(_environment_source(row,quarter,cache,phase,time),cache)

static func _environment_source(row: Dictionary, quarter: int, cache: Dictionary, phase: int = 0, time: float = 0.0) -> Dictionary:
    if row.has("source_sprite"): return imported_record(row,quarter,cache,phase,time)
    var world = read_file("world.json", cache)
    var direction: String = row.get("orientation", "east")
    var view = Placement.pose(direction, quarter)
    if row.kind == "library": return library_record(row, quarter, cache, phase, time)
    if row.kind == "resource": return read_file("assets.json", cache).resources[row.asset]
    var bank_id = bank_for(row, phase > 0, cache)
    if not bank_id.is_empty():
        var bank = bank_data(bank_id, cache)
        view = pose_for(bank, direction, quarter)
        if phase == 0 and row.kind == "prop" and ORIGINAL_CHEST_RESTS.has(bank_id):
            var library_id: String = ORIGINAL_CHEST_RESTS[bank_id]
            var index = read_file("environment/index.json",cache)
            var library = read_file(index.library[library_id],cache)
            # Original sprite facing follows the existing Unity registration.
            # Reconstructed closed/open bank rays disagree on north/south and
            # must not select the original artwork's viewpoint.
            var original_view = Placement.pose(direction,quarter)
            for sample in library.samples:
                if sample.source_view != original_view: continue
                var original: Dictionary = sample.surface.duplicate(true)
                var rect: Array = sample.colour.rect
                original.merge({"path":sample.colour.path,"rect":rect,"native_size":[rect[2],rect[3]],
                    "pivot":sample.get("physical_source_contact_px",sample.pivot),"scale":sample.scale,
                    "frame":sample.frame_index,"bank":bank_id,"original_library":library_id})
                return original
        var frame = frame_at(bank, time) if phase == 1 else (int(bank.frame_count)-1 if phase == 2 else 0)
        var owner = owner_for(row,cache)
        if phase == 0 and row.kind == "trap": frame = int(owner.state_frames[row.get("state", "ready")])
        if phase == 0 and row.kind == "door" and row.get("state", "closed") != "closed": frame = int(bank.frame_count)-1
        var cell: Array = bank.cell
        var result: Dictionary = bank.surface_frames_by_pose[view][frame].duplicate(true)
        var region: Dictionary = bank.frames_by_pose[view][frame] if bank.has("frames_by_pose") else {"path":bank.path, "rect":[frame*cell[0],bank.rows.find(view)*cell[1],cell[0],cell[1]]}
        if row.kind == "door" and bank.has("leaf_path"):
            region = {"path":bank.leaf_path,"rect":[frame*cell[0],bank.rows.find(view)*cell[1],cell[0],cell[1]]}
        result.merge({"path":region.path, "rect":region.rect, "native_size":cell,
            "pivot":bank.get("physical_source_contact_by_pose", bank.pivots_by_pose)[view], "scale":bank.scale,
            "flat_ground":owner.get("flat_ground", false), "frame":frame, "bank":bank_id,
            "hidden":phase == 2 and bank.get("clear_at_end", false)})
        if phase == 0 and row.kind == "door" and bank.has("actor_depth") and bank.has("depth_frames_by_pose") and bank.has("ground_origins_by_pose"):
            # Legacy actor-depth is a separate RG16 little-endian painter-depth
            # registration, not the lighting packet's RG16BE ray depth. Split
            # this leaf around its own frame only; keep the authored contact.
            var registration: Dictionary = bank.actor_depth
            var depth_region: Dictionary = bank.depth_frames_by_pose[view][frame]
            result.door_partition = {"path":depth_region.path,"rect":depth_region.rect,
                "range":registration.depth_range,"cell":registration.cell,
                "scale":registration.pixels_per_unit_by_pose[view]*bank.scale,
                "offset":(bank.ground_origins_by_pose[view][1]-result.pivot[1])*bank.scale}
        if phase == 0 and owner.has("selection_masks_by_pose"):
            result.hit_mask = owner.selection_masks_by_pose[view]
        return result
    var views: Dictionary
    match row.kind:
        "terrain":
            if row.material == "water":
                var water = read_file("assets.json",cache)
                var result: Dictionary = water.resources[water.water.mask].duplicate(true)
                result.water = water.water
                return result
            views = world.terrain[row.material]
        "wall":
            if row.boundaries.size() == 2:
                for candidate in world.wall_corner_faces:
                    var faces: Array = world.wall_corner_faces[candidate]
                    if row.boundaries.has(faces[0]) and row.boundaries.has(faces[1]):
                        # Source corner n is the right-hand junction, s the left.
                        # Authored face labels run opposite to sprite-view order.
                        view = Placement.POSES[posmod(quarter - Placement.POSES.find(candidate), 4)]
                views = world[row.material + "_wall_corner"]
            else:
                view = Placement.pose(row.boundaries[0], quarter)
                views = world[row.material + "_wall_straight"]
        "cliff":
            views = world.terrain_cliff.straight
            if row.get("boundaries", []).size() == 2:
                for candidate in world.terrain_cliff.corner_faces:
                    var faces: Array = world.terrain_cliff.corner_faces[candidate]
                    if row.boundaries.has(faces[0]) and row.boundaries.has(faces[1]):
                        view = Placement.POSES[posmod(Placement.POSES.find(candidate) + quarter, 4)]
                views = world.terrain_cliff.corner
        "stairs": views = world.terrain_stairs.poses
    var result: Dictionary = read_file("assets.json", cache).resources[views[view]]
    if row.kind == "stairs":
        result = result.duplicate(true)
        result.pivot = world.terrain_stairs.contacts_px[view][0]
    return result
