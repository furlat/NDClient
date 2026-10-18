extends RefCounted
# Read the existing authoring owners; adapters return transient draw records.
const Placement = preload("res://placement.gd")
const NativeAuthoring = preload("res://presentation/native_authoring.gd")
const NativePresentationSources = preload("res://presentation/native_presentation_sources.gd")
const BodySources = preload("res://presentation/body_sources.gd")
const UNITY_SOURCES="res://generated/unity_sources.json"
const LIBRARY_SEQUENCES="res://generated/library_sequences.json"
const IMPORTED_RECORDS="__imported_source_records"
# Client original-rest selection policy, reusing the explicit chest pairs in
# tools/build_unity_map.py. Source owner JSON binds reconstructed destruction
# rests; retain those banks for destruction, and use the registered originals
# for intact display. This is not a new source-authoring binding.
const ORIGINAL_CHEST_RESTS = {
    "prop.chest-a1.intact":"fantasy.chest.a1", "prop.chest-a2.intact":"fantasy.chest.a2",
    "prop.chest-a3.intact":"fantasy.chest.a3", "prop.chest-a4.intact":"fantasy.chest.a4",
    "prop.chest-b1.intact":"fantasy.chest.b1", "prop.chest-b2.intact":"fantasy.chest.b2",
}
# Parsed authoring documents, shared by every catalog cache in the process
# (documents are immutable after admission; see source_snapshot). A document
# is reused only while its file holds the same bytes it was parsed from.
static var _documents:Dictionary={}
static var _documents_mutex:=Mutex.new()

static func media_path(path: String) -> String:
    # Project assets (res://assets/art/...) load by their res:// path.
    if path.begins_with("res://"): return path
    if path.begins_with("C:/"): return path
    var root: String = ProjectSettings.get_setting("source_data/media_root")
    var absolute = root.path_join(path.trim_prefix("/media/"))
    # Extended UNC keeps the original deep asset paths readable on Windows.
    if OS.get_name()=="Windows" and absolute.begins_with("//") and not absolute.begins_with("//?/"):
        return "//?/UNC/"+absolute.trim_prefix("//")
    return absolute

static func read_file(relative_path: String, cache: Dictionary) -> Variant:
    if not cache.has(relative_path):
        var root: String = ProjectSettings.get_setting("source_data/authoring_root")
        cache[relative_path] = NativeAuthoring.overlay(relative_path, _document(root.path_join(relative_path)), cache)
    return cache[relative_path]

static func _document(path:String)->Variant:
    var raw:=FileAccess.get_file_as_bytes(path)
    _documents_mutex.lock();var known:Array=_documents.get(path,[]);_documents_mutex.unlock()
    if not known.is_empty() and known[0]==raw:return known[1]
    var parsed:Variant=JSON.parse_string(raw.get_string_from_utf8())
    _documents_mutex.lock();_documents[path]=[raw,parsed];_documents_mutex.unlock()
    return parsed

static func asset(asset_id:String,cache:Dictionary)->Dictionary:
    var selected:Resource=NativePresentationSources.asset(asset_id,cache)
    return {} if selected==null else selected.value

static func prepared_asset(asset_id:String,cache:Dictionary)->Dictionary:
    var selected:Resource=NativePresentationSources.prepared_asset(asset_id,cache)
    return {} if selected==null else selected.value

static func source_pointer(document: String, pointer: String, cache: Dictionary) -> String:
    return NativeAuthoring.source_pointer(document, pointer, read_file(document, cache))

static func _generated_table(path:String,cache:Dictionary)->Dictionary:
    if not cache.has(path):
        var measured:bool=cache.has("__actor_source_profile")
        var started:int=Time.get_ticks_usec() if measured else 0
        var text:String=FileAccess.get_file_as_string(path)
        cache[path]=JSON.parse_string(text)
        if measured:
            var elapsed:int=Time.get_ticks_usec()-started
            var metrics:Dictionary=cache.__actor_source_profile
            metrics.generated_table_load_calls=int(metrics.get("generated_table_load_calls",0))+1
            metrics.generated_table_load_usec=int(metrics.get("generated_table_load_usec",0))+elapsed
            metrics.generated_table_load_characters=int(metrics.get("generated_table_load_characters",0))+text.length()
            if not metrics.has("generated_table_load_paths"):metrics.generated_table_load_paths={}
            var row:Dictionary=metrics.generated_table_load_paths.get(path,{"calls":0,"usec":0,"characters":0})
            row.calls+=1;row.usec+=elapsed;row.characters+=text.length()
            metrics.generated_table_load_paths[path]=row
    return cache[path]

static func seal_environment_sources(cache:Dictionary)->void:
    # Only this explicitly admitted source owner is shared. Other mutable
    # selector/consumer caches keep their existing private ownership rules.
    if not cache.has(IMPORTED_RECORDS):return
    var owner:Dictionary=cache[IMPORTED_RECORDS]
    if not owner.records.is_read_only():owner.records.make_read_only()
    if not owner.is_read_only():owner.make_read_only()

static func _imported_records(cache:Dictionary,table:Dictionary)->Dictionary:
    var owner:Dictionary=cache.get(IMPORTED_RECORDS,{})
    if owner.is_empty() or not is_same(owner.table,table):
        owner={"table":table,"records":{}};cache[IMPORTED_RECORDS]=owner
    return owner

static func _store_imported_record(cache:Dictionary,owner:Dictionary,key:Array,value:Dictionary)->void:
    if owner.records.is_read_only():
        # Fork once on the worker's first new selection. Further additions stay
        # private until source_snapshot seals this completed map for publication.
        owner={"table":owner.table,"records":owner.records.duplicate()};cache[IMPORTED_RECORDS]=owner
    owner.records[key]=value

static func source_snapshot(cache: Dictionary) -> Dictionary:
    # Effective source documents are immutable after admission. Give each worker
    # its own cache shell, without reloading selected Resources or sharing derived
    # caches. Qualification belongs to import tools and tests.
    # Pin the source revision before dispatch. A later explicit reload may
    # select another index, while this worker/display keeps these references.
    NativePresentationSources.admission(cache)
    BodySources.admission(cache)
    seal_environment_sources(cache)
    var snapshot = {}
    for path in cache:
        if path is String and path.ends_with(".json") and not path.begins_with("__"):
            snapshot[path] = cache[path]
    if cache.has(NativePresentationSources.CACHE_KEY):
        snapshot[NativePresentationSources.CACHE_KEY]=NativePresentationSources.snapshot(cache[NativePresentationSources.CACHE_KEY])
    if cache.has("__body_source_admission"):
        snapshot.__body_source_admission=cache.__body_source_admission
    if cache.has("__environment_source_records"):
        snapshot.__environment_source_records=cache.__environment_source_records
    if cache.has(IMPORTED_RECORDS):snapshot[IMPORTED_RECORDS]=cache[IMPORTED_RECORDS]
    if cache.has("native_references_validated"):
        snapshot.native_references_validated = cache.native_references_validated
    if cache.has("native_authoring_errors"):
        snapshot.native_authoring_errors = cache.native_authoring_errors.duplicate()
    return snapshot

static func invalidate_source_indexes()->void:
    NativePresentationSources.invalidate()
    BodySources.invalidate()
    _documents_mutex.lock();_documents={};_documents_mutex.unlock()

static func adopt_snapshot(cache:Dictionary,offered:Dictionary)->void:
    # Documents belong to the admitted revision. Lazy source references can
    # grow on either worker: merge their immutable shells without discarding
    # already prepared references or allowing a different revision to take over.
    for key in offered:
        if key!=IMPORTED_RECORDS and not cache.has(key):cache[key]=offered[key]
    for key in ["__body_source_admission",NativePresentationSources.CACHE_KEY]:
        if not offered.has(key) or not cache.has(key) or is_same(cache[key],offered[key]):continue
        var current:Dictionary=cache[key];var incoming:Dictionary=offered[key]
        if current.index==null or incoming.index==null or current.index.revision!=incoming.index.revision:continue
        var loaded:Dictionary=current.loaded.duplicate()
        loaded.merge(incoming.loaded,false)
        cache[key]=NativePresentationSources.make_admission(current.index,loaded)
    if offered.has("__environment_source_records") and not is_same(cache.__environment_source_records,offered.__environment_source_records):
        var records:Dictionary=cache.__environment_source_records.duplicate()
        records.merge(offered.__environment_source_records,false);records.make_read_only()
        cache.__environment_source_records=records

    if offered.has(IMPORTED_RECORDS):
        var incoming:Dictionary=offered[IMPORTED_RECORDS]
        var admitted:Variant=cache.get(UNITY_SOURCES)
        if is_same(incoming.table,admitted):
            var current:Dictionary=cache.get(IMPORTED_RECORDS,{})
            if current.is_empty() or not is_same(current.table,admitted):cache[IMPORTED_RECORDS]=incoming
            elif not is_same(current,incoming):
                var records:Dictionary=current.records.duplicate();records.merge(incoming.records,false);records.make_read_only()
                var owner:Dictionary={"table":admitted,"records":records};owner.make_read_only();cache[IMPORTED_RECORDS]=owner

static func validate_native(cache: Dictionary) -> Array:
    # Passive metadata only. No texture decoding, scene creation or shader upload.
    for document in ["catalog/condition_recipes.json", "catalog/body_action_recipes.json", "catalog/resources.json"]:
        read_file(document, cache)
    if not cache.has("native_references_validated"):
        var built:Resource=BodySources.index(cache)
        var rigs:Dictionary={} if built==null else built.rigs
        for recipe in cache["catalog/body_action_recipes.json"].values():
            if not recipe.has("_resource_source"):continue
            var clip:Dictionary=rigs.get(recipe.rigId,{}).get("clips",{}).get(recipe.actor.clip,{})
            if clip.is_empty():NativeAuthoring._error(cache,"Selected action has no source clip: "+recipe._resource_source)
            else:
                for marker in recipe.anchors:
                    if marker.frame>clip.frames:NativeAuthoring._error(cache,"Selected action marker exceeds source duration: "+recipe._resource_source)
        for recipe in cache["catalog/condition_recipes.json"].values():
            for pose in recipe.get("persistent",{}).get("activityPoses",[]):
                var clip:Dictionary=rigs.get(pose.rigId,{}).get("clips",{}).get(pose.clip,{})
                if clip.is_empty():
                    NativeAuthoring._error(cache,"Selected activity pose has no source clip: "+pose.rigId+"/"+pose.clip)
                elif pose.sampling=="hold" and pose.frame>=clip.frames:
                    NativeAuthoring._error(cache,"Selected held frame exceeds source clip: "+pose.rigId+"/"+pose.clip)
        cache.native_references_validated=true
    return cache.get("native_authoring_errors", [])

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
    return _generated_table(LIBRARY_SEQUENCES,cache).get(row.asset,[])

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
    var table:Dictionary=_generated_table(UNITY_SOURCES,cache)
    var source: Dictionary = table[row.source_sprite]
    if source.has("records"): return source.records[quarter]
    if phase > 0:
        if row.has("break_owner"):
            var effective: Dictionary = row.duplicate()
            effective.erase("source_sprite")
            effective.merge(row.break_owner,true)
            return environment(effective,quarter,cache,phase,time)
        return library_record(row,quarter,cache,phase,time)
    var key:Array=[row.source_sprite,quarter]
    var records_owner:Dictionary=_imported_records(cache,table)
    if cache.has("__actor_source_profile"):
        var metrics:Dictionary=cache.__actor_source_profile
        var field:String="imported_record_hits" if records_owner.records.has(key) else "imported_record_builds"
        metrics[field]=int(metrics.get(field,0))+1
    if not records_owner.records.has(key):
        var index = read_file("environment/index.json",cache)
        var owner = read_file(index.library[source.asset],cache)
        var sample: Dictionary = owner.samples[int(source.samples[quarter])]
        var result: Dictionary = sample.surface.duplicate(true)
        var rect: Array = sample.colour.rect
        result.merge({"path":sample.colour.path,"rect":rect,"native_size":[rect[2],rect[3]],
            "pivot":source.contact_override[quarter] if source.has("contact_override") else sample.get("physical_source_contact_px",sample.get("pivot",source.pivot)),"scale":source.scale,
            "source_sample":source.samples[quarter],"frame":sample.frame_index})
        _store_imported_record(cache,records_owner,key,result)
        return result
    return records_owner.records[key]

static func receiving_normal(record: Dictionary, cache: Dictionary) -> Dictionary:
    if not record.has("normal"): return record
    # Delivery-selected receiving detail, never depth/support or paint alpha.
    # This raw file key lets media preparation publish the lookup to the scene
    # cache before first use, like the other immutable source documents.
    var key = "res://generated/environment_receiving_normals.json"
    if not cache.has(key):
        cache[key] = JSON.parse_string(FileAccess.get_file_as_string(key))
    var original_path: String = record.normal.region.path
    if not cache[key].normals.has(original_path): return record
    var selected: Dictionary = cache[key].normals[original_path]
    var result = record.duplicate()
    result.normal = record.normal.duplicate()
    result.normal.region = record.normal.region.duplicate()
    result.normal.region.path = selected.path
    result.normal.receiving_qualification = selected.qualification
    result.normal.original_path = original_path
    return result

static func environment(row: Dictionary, quarter: int, cache: Dictionary, phase: int = 0, time: float = 0.0) -> Dictionary:
    # Live destroyed after-values and reconnected snapshots settle on the same
    # authored endpoint as native destruction playback. An explicit active
    # playback phase still selects its own intermediate samples.
    if phase==0 and row.get("destroyed",false): phase=2
    return texture_layout(receiving_normal(_environment_source(row,quarter,cache,phase,time),cache),cache)

static func _layout_region(region: Dictionary, layouts: Dictionary) -> Dictionary:
    if not layouts.has(region.path): return region
    var layout: Dictionary = layouts[region.path]
    var rect: Array = region.rect
    var cell: Array = layout.cell
    var column = floori(float(rect[0])/cell[0])
    var row = floori(float(rect[1])/cell[1])
    var offset = Vector2i(int(rect[0])%int(cell[0]),int(rect[1])%int(cell[1]))
    # A source rectangle must remain entirely inside one unchanged source cell.
    # Reject invalid layouts instead of silently selecting the oversized source.
    if rect[0]<0 or rect[1]<0 or rect[2]<=0 or rect[3]<=0 or \
            offset.x+rect[2]>cell[0] or offset.y+rect[3]>cell[1] or \
            rect[0]+rect[2]>layout.source_size[0] or rect[1]+rect[3]>layout.source_size[1]: return {}
    var index: int = row*int(layout.source_columns)+column
    var result = region.duplicate()
    var local_index = index
    if layout.has("pages"):
        var per_page: int = layout.cells_per_page
        if per_page<=0: return {}
        var page = floori(float(index)/per_page)
        if page>=layout.pages.size(): return {}
        result.path = layout.pages[page]
        local_index = index%per_page
    else:
        # Existing version-one monolithic layouts remain valid until rebaked.
        result.path = layout.path
    result.rect = [(local_index%int(layout.columns))*int(cell[0])+offset.x,
        floori(float(local_index)/layout.columns)*int(cell[1])+offset.y,rect[2],rect[3]]
    return result

static func texture_layouts(cache: Dictionary) -> Dictionary:
    # Immutable source document owned by this catalog cache. A fresh catalog on
    # explicit Reload reads the new manifest; an existing world keeps its own.
    var key = "res://generated/environment_texture_layouts.json"
    if not cache.has(key): cache[key] = JSON.parse_string(FileAccess.get_file_as_string(key))
    return cache[key].layouts

static func texture_layout(record: Dictionary, cache: Dictionary) -> Dictionary:
    if record.is_empty(): return record
    var layouts: Dictionary = texture_layouts(cache)
    var geometry: Dictionary = record.get("geometry_region",{})
    var normal: Dictionary = record.get("normal",{}).get("region",{})
    var remap_geometry = layouts.has(geometry.get("path",""))
    var remap_normal = layouts.has(normal.get("path",""))
    if not remap_geometry and not remap_normal: return record
    var result = record.duplicate()
    if remap_geometry:
        result.geometry_region = _layout_region(geometry,layouts)
        if result.geometry_region.is_empty():
            push_error("Invalid environment texture layout region: "+str(geometry))
            return {}
    if remap_normal:
        result.normal = record.normal.duplicate()
        result.normal.region = _layout_region(normal,layouts)
        if result.normal.region.is_empty():
            push_error("Invalid environment texture layout region: "+str(normal))
            return {}
    return result

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
