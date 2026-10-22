extends RefCounted
# Read the existing authoring owners; adapters return transient draw records.
const Placement = preload("res://placement.gd")
const NativeAuthoring = preload("res://presentation/native_authoring.gd")
const NativePresentationSources = preload("res://presentation/native_presentation_sources.gd")
const BodySources = preload("res://presentation/body_sources.gd")
const CharacterGeometry = preload("res://presentation/character_geometry.gd")
const Metadata = preload("res://presentation/source_metadata.gd")
const AbilityDocuments = preload("res://presentation/ability_documents.gd")
## Environment runtime documents written by tools/build_presentation.gd from
## authoring/environment.tres. Each is cached in a catalog cache under its
## res:// path, so source_snapshot publishes it with the admitted documents.
const ENVIRONMENT := "res://build/presentation/environment/"
# Parsed authoring documents, shared by every catalog cache in the process
# (documents are immutable after admission; see source_snapshot). A document
# is reused only while its file holds the same bytes it was parsed from.
static var _documents:Dictionary={}
static var _documents_mutex:=Mutex.new()

## Exact authoring key only. Canonical membership and lifetime remain the
## disclosed condition UUID. Unknown non-null behaviors never fall through.
static func condition_key(condition:Dictionary)->String:
    var behavior:Variant=condition.get("behavior_id")
    if behavior!=null:return str(behavior)
    var state:Variant=condition.get("state")
    return str(state.get("semantic_key","")) if state!=null else ""

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

static func environment_file(path: String, cache: Dictionary) -> Dictionary:
    if not cache.has(path):
        var record: Resource = Metadata.read(path,ResourceLoader.CACHE_MODE_REUSE)
        if record == null: push_error("Missing environment build output (run tools/build_presentation.gd): " + path)
        cache[path] = record.value if record != null else {}
    return cache[path]

## Terrain views, wall and cliff pieces, fixtures and directional light.
static func environment_world(cache: Dictionary) -> Dictionary:
    return environment_file(ENVIRONMENT + "world.res", cache)

## Every single image the world draws by id, the flame animation and the water look.
static func environment_resources(cache: Dictionary) -> Dictionary:
    return environment_file(ENVIRONMENT + "resources.res", cache)

## Door, prop and trap owners, bank and library paths, wall destructions, chest rests.
static func environment_index(cache: Dictionary) -> Dictionary:
    return environment_file(ENVIRONMENT + "index.res", cache)

## Torch colour and item ids, optical lifts and the fallback cookie (no catalog cache: immutable).
static func environment_lighting() -> Dictionary:
    var record: Resource = Metadata.read(ENVIRONMENT + "lighting.res",ResourceLoader.CACHE_MODE_REUSE)
    if record == null: push_error("Missing environment build output (run tools/build_presentation.gd): lighting.res")
    return record.value if record != null else {}

static func light_ranges() -> Resource:
    var ranges: Resource = Metadata.read(ENVIRONMENT + "light_ranges.res",ResourceLoader.CACHE_MODE_REUSE)
    if ranges == null: push_error("Missing environment build output (run tools/build_presentation.gd): light_ranges.res")
    return ranges

## Measured energy and emission centre per flame frame, keyed by its image path.
static func fixture_optics() -> Dictionary:
    var facts: Resource = Metadata.read(ENVIRONMENT + "fixture_optics.res",ResourceLoader.CACHE_MODE_REUSE)
    if facts == null: push_error("Missing environment build output (run tools/build_presentation.gd): fixture_optics.res")
    return facts.frames if facts != null else {}

## Prepared region artwork is selected by the actual authored residue id.
## Default blood preserves existing callers; unknown sources never alias it.
static func residue_asset(cache: Dictionary,residue_id:String="residue.blood") -> Dictionary:
    var path:String=ENVIRONMENT+"residues/"+residue_id.trim_prefix("residue.")+".res"
    if not cache.has(path):
        var asset: Resource = Metadata.read(path,ResourceLoader.CACHE_MODE_REUSE)
        if asset == null: push_error("Missing environment build output (run tools/build_presentation.gd): " + path); return {}
        cache[path] = asset.value
    return cache[path]

static func prepared_residue_asset(cache: Dictionary,residue_id:String="residue.blood") -> Dictionary:
    return cache.get(ENVIRONMENT+"residues/"+residue_id.trim_prefix("residue.")+".res", {})

static func read_file(relative_path: String, cache: Dictionary) -> Variant:
    if not cache.has(relative_path):
        # Spells, conditions, actions, attacks and their contexts come from the
        # abilities build under the same document names.
        if AbilityDocuments.owns(relative_path):
            var owned: Variant = AbilityDocuments.read(relative_path)
            if owned == null:
                NativeAuthoring._error(cache, "Abilities build has no record table: " + AbilityDocuments.file(relative_path))
                owned = {}
            cache[relative_path] = owned
        else:
            var root: String = ProjectSettings.get_setting("source_data/authoring_root")
            cache[relative_path] = NativeAuthoring.overlay(relative_path, _document(root.path_join(relative_path)), cache)
    return cache[relative_path]

## Explicit project metadata, admitted by a passive source owner. The exact
## JSON path travels in source_snapshot; display queries only borrow it.
static func read_document(path:String,cache:Dictionary)->Dictionary:
    if not path.begins_with("res://") or not path.ends_with(".json"):
        NativeAuthoring._error(cache,"Invalid project metadata path: "+path)
        return {}
    if not cache.has(path):
        var document:Variant=_document(path) if FileAccess.file_exists(path) else null
        if not document is Dictionary:
            NativeAuthoring._error(cache,"Missing or invalid project metadata: "+path)
            document={}
        cache[path]=document
    return cache[path]

static func _document(path:String)->Variant:
    var raw:=FileAccess.get_file_as_bytes(path)
    _documents_mutex.lock();var known:Array=_documents.get(path,[]);_documents_mutex.unlock()
    if not known.is_empty() and known[0]==raw:return known[1]
    var parsed:Variant=JSON.parse_string(raw.get_string_from_utf8())
    _documents_mutex.lock();_documents[path]=[raw,parsed];_documents_mutex.unlock()
    return parsed

static func source_pointer(document: String, pointer: String, cache: Dictionary) -> String:
    # Only these built tables carry field-to-Resource provenance. Other names
    # are labels, not a request to load a retired JSON document from disk.
    if document not in [NativeAuthoring.CONDITION_FILE,NativeAuthoring.ACTION_FILE]:return document+":/"+pointer.trim_prefix("/")
    return NativeAuthoring.source_pointer(document, pointer, read_file(document, cache))

static func source_snapshot(cache: Dictionary) -> Dictionary:
    # Effective source documents are immutable after admission. Give each worker
    # its own cache shell, without reloading selected Resources or sharing derived
    # caches. Qualification belongs to import tools and tests.
    # Pin the source revision before dispatch. A later explicit reload may
    # select another index, while this worker/display keeps these references.
    NativePresentationSources.admission(cache)
    BodySources.admission(cache)
    var snapshot = {}
    for path in cache:
        if path is String and (path.ends_with(".json") or path.begins_with(ENVIRONMENT)) and not path.begins_with("__"):
            snapshot[path] = cache[path]
    if cache.has(NativePresentationSources.CACHE_KEY):
        snapshot[NativePresentationSources.CACHE_KEY]=NativePresentationSources.snapshot(cache[NativePresentationSources.CACHE_KEY])
    if cache.has("__body_source_admission"):
        snapshot.__body_source_admission=cache.__body_source_admission
    if cache.has("native_references_validated"):
        snapshot.native_references_validated = cache.native_references_validated
    if cache.has("native_authoring_errors"):
        snapshot.native_authoring_errors = cache.native_authoring_errors.duplicate()
    return snapshot

static func invalidate_source_indexes()->void:
    NativePresentationSources.invalidate()
    AbilityDocuments.invalidate()
    BodySources.invalidate()
    _documents_mutex.lock();_documents={};_documents_mutex.unlock()

static func adopt_snapshot(cache:Dictionary,offered:Dictionary)->void:
    # Documents belong to the admitted revision. Lazy source references can
    # grow on either worker: merge their immutable shells without discarding
    # already prepared references or allowing a different revision to take over.
    for key in offered:
        if not cache.has(key):cache[key]=offered[key]
    for key in ["__body_source_admission",NativePresentationSources.CACHE_KEY]:
        if not offered.has(key) or not cache.has(key) or is_same(cache[key],offered[key]):continue
        var current:Dictionary=cache[key];var incoming:Dictionary=offered[key]
        if current.index==null or incoming.index==null:continue
        if key==BodySources.KEY:
            if not is_same(current.index,incoming.index):continue
        elif current.index.revision!=incoming.index.revision:continue
        var loaded:Dictionary=current.loaded.duplicate()
        loaded.merge(incoming.loaded,false)
        cache[key]=NativePresentationSources.make_admission(current.index,loaded)

static func validate_native(cache: Dictionary) -> Array:
    # Passive metadata only. No texture decoding, scene creation or shader upload.
    for document in ["catalog/condition_recipes.json", "catalog/body_action_recipes.json", "catalog/resources.json"]:
        read_file(document, cache)
    if not cache.has("native_references_validated"):
        var built:Resource=BodySources.index(cache)
        var rigs:Dictionary={} if built==null else built.rigs
        for recipe in cache["catalog/body_action_recipes.json"].values():
            if not recipe.has("_resource_source"):continue
            # Generic actor actions resolve their real rig at admission. Only
            # a resource's explicit fixed rig is a build-time clip reference.
            if str(recipe.get("rigId","")).is_empty():continue
            var clip:Dictionary=rigs.get(recipe.rigId,{}).get("clips",{}).get(recipe.actor.clip,{})
            if clip.is_empty():NativeAuthoring._error(cache,"Selected action has no source clip: "+recipe._resource_source)
            else:
                for marker in recipe.get("anchors",[]):
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
    var index = environment_index(cache)
    var state: String = row.get("state", "default")
    var source_kind:String=row.get("source_kind",row.kind)
    if source_kind == "wall":
        return index.wall_destructions[row.material] if broken else ""
    if source_kind not in ["prop", "door", "trap"]: return ""
    var group: String = {"prop": "props", "door": "doors", "trap": "traps"}[source_kind]
    var owner = index[group][row.asset]
    if source_kind == "door":
        if broken: return owner.destructions[state + "." + row.get("outcome", "clear")]
        return owner.openings["inward" if state == "open.inward" else "outward"]
    if broken:
        return owner.destructions.get(state, "")
    if source_kind == "trap": return owner.intact
    return owner.intact.get(state, owner.intact.values()[0])

static func bank_data(id: String, cache: Dictionary) -> Dictionary:
    return environment_file(environment_index(cache).banks[id], cache)

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

static func break_duration(row: Dictionary, cache: Dictionary) -> float:
    var bank = bank_for(row,true,cache)
    return duration(bank_data(bank,cache)) if not bank.is_empty() else 0.0

static func owner_for(row: Dictionary, cache: Dictionary) -> Dictionary:
    var source_kind:String=row.get("source_kind",row.kind)
    if source_kind not in ["prop","door","trap"]: return {}
    return environment_index(cache)[{"prop":"props","door":"doors","trap":"traps"}[source_kind]][row.asset]

static func door_frame(row: Dictionary, quarter: int, cache: Dictionary) -> Dictionary:
    var owner = owner_for(row,cache)
    var boundary = Placement.pose(row.orientation,quarter)
    if not owner.frame_resource_by_pose.is_empty():
        return texture_layout(environment_resources(cache).resources[owner.frame_resource_by_pose[boundary]],cache)
    var bank = bank_data(bank_for(row,false,cache),cache)
    var pose = pose_for(bank,row.orientation,quarter)
    if not bank.has("frame_regions_by_pose"): return {}
    var region: Dictionary = bank.frame_regions_by_pose[pose]
    var result: Dictionary = bank.surface_frames_by_pose[pose][0].duplicate(true)
    result.merge({"path":region.path,"rect":region.rect,"native_size":bank.cell,
        "pivot":bank.get("physical_source_contact_by_pose",bank.pivots_by_pose)[pose],"scale":bank.scale})
    return texture_layout(result,cache)

static func receiving_normal(record: Dictionary, cache: Dictionary) -> Dictionary:
    if not record.has("normal"): return record
    # Delivery-selected receiving detail, never depth/support or paint alpha.
    # This raw file key lets media preparation publish the lookup to the scene
    # cache before first use, like the other immutable source documents.
    var normals: Dictionary = environment_file(ENVIRONMENT + "receiving_normals.res", cache).normals
    var original_path: String = record.normal.region.path
    if not normals.has(original_path): return record
    var selected: Dictionary = normals[original_path]
    var result = record.duplicate()
    result.normal = record.normal.duplicate()
    result.normal.region = record.normal.region.duplicate()
    result.normal.region.path = selected.path
    result.normal.receiving_qualification = selected.qualification
    result.normal.original_path = original_path
    return result

static func environment(row: Dictionary, quarter: int, cache: Dictionary, phase: int = 0, time: float = 0.0) -> Dictionary:
    if row.has("floor_motifs"):return floor_residue_record(row,cache)
    # Live destroyed after-values and reconnected snapshots settle on the same
    # authored endpoint as native destruction playback. An explicit active
    # playback phase still selects its own intermediate samples.
    if phase==0 and row.get("destroyed",false): phase=2
    return wall_residue_record(row,quarter,texture_layout(receiving_normal(_environment_source(row,quarter,cache,phase,time),cache),cache),cache)

## Original atlas remains unchanged. The existing environment material samples
## its continuous motif field on one actual supported tile-sized ground quad.
static func floor_residue_record(row:Dictionary,cache:Dictionary)->Dictionary:
    var profile:Dictionary=row.floor_motifs
    var source:Dictionary=environment_resources(cache).get("resources",{}).get(profile.get("art_id",""),{})
    if source.is_empty():return {}
    return {"path":source.path,"native_size":[32.,32.],"pivot":[16.,16.],"scale":1.,
        "flat_ground":true,"floor_motifs":profile}

## Only unchanged original image records carry source_image_id. New banks,
## destruction frames and unrelated objects never borrow those face planes.
static func wall_residue_record(row:Dictionary,quarter:int,record:Dictionary,cache:Dictionary)->Dictionary:
    var image:String=str(record.get("source_image_id",""))
    if image.is_empty() or row.get("kind")!="wall":return record
    var profiles:Dictionary={};var profiles_loaded:bool=false
    var faces:Array=[]
    for member in row.get("wall_members",[row]):
        var residues:Array=member.get("surface_residues",[])
        if residues.is_empty() or member.get("boundaries",[]).size()!=1:continue
        if not profiles_loaded:
            profiles=environment_index(cache).get("wall_residue_sources",{})
            profiles_loaded=true
        var direction:String=str(member.boundaries[0])
        var vertical:bool=direction in ["east","west"]
        var sign:int=1 if direction in ["east","north"] else -1
        var line_twice:int=int(member.position[0] if vertical else member.position[1])*2+sign
        var along:int=int(member.position[1] if vertical else member.position[0])
        var tangent:Vector2=Placement.project(Vector2(0,1) if vertical else Vector2(1,0),0,quarter)
        for residue in residues:
            var profile:Dictionary=profiles.get(residue.residue_id,{})
            var planes:Array=profile.get("images",{}).get(image,{}).get(Placement.pose(direction,quarter),[])
            if planes.is_empty() or not residue.faces.any(func(face):return face in member.get("residue_observed_faces",[]) and Placement.pose(face,quarter) in ["e","s"]):continue
            for plane in planes:
                faces.append({"profile":profile,"plane":plane,"reverse":Vector2(plane.across[0],plane.across[1]).dot(tangent)<0.,
                    "line_twice":line_twice,"along":along,"item_uuid":member.id,"condition_uuid":residue.condition_uuid})
    if faces.is_empty():return record
    var result:Dictionary=record.duplicate(false);result.wall_motif_faces=faces
    return result

static func world_media_frames(program:Dictionary,role:String,quarter:int,orientation:String="east")->Array:
    var source:Dictionary=program.get("roles",{}).get(role,{}) if program.get("kind")=="portal" else program.get("projectile",{}) if role=="projectile" else program
    if source.has("frames_by_quarter"):return source.frames_by_quarter.get(str(quarter),[])
    return source.get("frames_by_pose",{}).get(Placement.POSES[posmod(quarter,4)] if role=="projectile" else Placement.pose(orientation,quarter),[])

static func world_media_record(content:String,role:String,quarter:int,orientation:String,frame:int,cache:Dictionary)->Dictionary:
    var program:Dictionary=environment_index(cache).get("spatial_media",{}).get(content,{})
    var frames:Array=world_media_frames(program,role,quarter,orientation)
    if frames.is_empty() or frame<0 or frame>=frames.size():return {}
    return environment_resources(cache).resources.get(frames[frame],{})

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
    return environment_file(ENVIRONMENT + "texture_layouts.res", cache).layouts

static func texture_layout(record: Dictionary, cache: Dictionary) -> Dictionary:
    if record.is_empty(): return record
    var layouts: Dictionary = texture_layouts(cache)
    var result: Dictionary = record
    # These are physical texture aliases, not a recursive rewrite of metadata.
    # Independent support/mask files and normal.original_path retain their sources.
    for field in ["geometry_region", "hit_mask", "door_partition"]:
        var region: Dictionary = record.get(field,{})
        if not layouts.has(region.get("path","")): continue
        if is_same(result,record): result = record.duplicate()
        result[field] = _layout_region(region,layouts)
        if result[field].is_empty():
            push_error("Invalid environment texture layout region: "+str(region)); return {}
    for field in ["normal", "support"]:
        var value: Dictionary = record.get(field,{})
        var region: Dictionary = value.get("region",{})
        if not layouts.has(region.get("path","")): continue
        if is_same(result,record): result = record.duplicate()
        result[field] = value.duplicate()
        result[field].region = _layout_region(region,layouts)
        if result[field].region.is_empty():
            push_error("Invalid environment texture layout region: "+str(region)); return {}
    var roles: Array = record.get("roles",[])
    for i in roles.size():
        var selection: Dictionary = roles[i].get("selection",{})
        var mask: Dictionary = selection.get("mask",{})
        var region: Dictionary = mask.get("region",{})
        if not layouts.has(region.get("path","")): continue
        if is_same(result,record): result = record.duplicate()
        if is_same(result.get("roles"),roles): result.roles = roles.duplicate()
        result.roles[i] = roles[i].duplicate()
        result.roles[i].selection = selection.duplicate()
        result.roles[i].selection.mask = mask.duplicate()
        result.roles[i].selection.mask.region = _layout_region(region,layouts)
        if result.roles[i].selection.mask.region.is_empty():
            push_error("Invalid environment texture layout region: "+str(region)); return {}
    return result

static func _environment_source(row: Dictionary, quarter: int, cache: Dictionary, phase: int = 0, time: float = 0.0) -> Dictionary:
    if row.has("ground_equipment"):return ground_equipment_record(row.ground_equipment,quarter,cache)
    var world = environment_world(cache)
    var direction: String = row.get("orientation", "east")
    var source_kind:String=row.get("source_kind",row.kind)
    var view = Placement.pose(direction, quarter)
    if row.has("world_media_content"):
        return world_media_record(row.world_media_content,str(row.get("world_media_role","body")),quarter,direction,int(row.get("world_media_frame",0)),cache)
    if row.kind == "resource": return environment_resources(cache).resources[row.asset]
    var bank_id = bank_for(row, phase > 0, cache)
    if not bank_id.is_empty():
        var bank = bank_data(bank_id, cache)
        view = pose_for(bank, direction, quarter)
        var index = environment_index(cache)
        if phase == 0 and source_kind == "prop" and index.rests.has(bank_id):
            # The rest pose shows the registered original art (the source's
            # rest_library); the reconstructed banks still play destruction.
            var library_id: String = index.rests[bank_id]
            var library = environment_file(index.library[library_id],cache)
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
                var water = environment_resources(cache)
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
    return environment_resources(cache).resources[views[view]]

## The authored look is independent of the public object's identity/placement.
static func ground_equipment(item:Dictionary,cache:Dictionary)->Dictionary:
    return BodySources.ground(item,cache)

static func ground_equipment_record(look:Dictionary,quarter:int,cache:Dictionary)->Dictionary:
    if look.is_empty():return {}
    var cell:Array=look.cell;var frame:int=int(look.frame);var row:int=int(look.rows_by_camera[posmod(quarter,4)])
    var value:Dictionary={"path":look.path,"rect":[frame*cell[0],row*cell[1],cell[0],cell[1]],
        "native_size":cell,"pivot":look.pivots_by_camera[posmod(quarter,4)],"scale":look.scale,
        "ground_equipment_source":look.source,"ground_equipment_tint":look.get("tint","#ffffff"),
        "source_pivot":look.source_pivot,"component_profile":"original","optical_status":"colour_shadow_only"}
    # This original source uses affine byte depth + RGB normals. Keep that
    # descriptor distinct from the environment's RG16BE/oct packet.
    var key:Array=[&"__ground_component_binding",look.path,look.slot,look.scale]
    if not cache.has(key):
        BodySources.prepare_descriptor(look.path,look.slot,cache)
        cache[key]=CharacterGeometry.prepare_binding(look.path,look.slot,cache,true,true,"original",float(look.scale),1.)
    var binding:Dictionary=cache[key]
    if binding.parameters.get("has_component_geometry",false):
        value.component_binding=binding
        value.optical_status=binding.status
        var header:Dictionary=BodySources.header(look.path,cache)
        value.component_sheet_size=[header.width,header.height]
    var shadow:Dictionary=look.get("shadow",{})
    if not shadow.is_empty():
        value.ground_shadow={"path":shadow.path,"rect":[frame*shadow.cell[0],row*shadow.cell[1],shadow.cell[0],shadow.cell[1]],
            "native_size":shadow.cell,"pivot":shadow.pivot,"scale":shadow.scale,"ground_equipment_shadow":true}
    return value

static func environment_role(record:Dictionary,source_role:int)->Dictionary:
    # A delivered Shadow sheet is a separate authored source, not a colour
    # selection mask guessed from the equipment's painted pixels.
    if source_role==0 and record.has("ground_equipment_source"):return record.get("ground_shadow",{})
    return record
