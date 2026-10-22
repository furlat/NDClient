extends RefCounted
# Delivered per-source optical receivers, separate from environment encodings.
# This table indexes existing media identities; it never chooses an outfit.
const SourceMaterial=preload("res://presentation/source_material.gd")
const BodySources=preload("res://presentation/body_sources.gd")
const Placement = preload("res://placement.gd")
const PROFILES = ["original","gentle","reference"]
const PARAMETERS = {"depth":"component_depth", "normal":"component_normal",
    "support":"component_support", "normal_valid":"component_normal_valid"}

static func record(path:String,slot:String,cache:Dictionary)->Dictionary:
    return BodySources.descriptor(path,slot,cache).get("geometry",{})

static func _root(source: Dictionary) -> String:
    return source.get("_source_root","res://assets")

static func display_path(path: String, slot: String, cache: Dictionary) -> String:
    var source = record(path,slot,cache)
    # Animals were authored as an explicit visible-body RGBA partition. The
    # delivered colour is that exact partition, at the original native size.
    return _root(source).path_join(source.colour_path) if source.has("colour_path") else path

static func paths(path: String, slot: String, cache: Dictionary, profile: String = "") -> Dictionary:
    var resolved = source_paths(path,slot,cache)
    if not resolved.ok:return {}
    return resolved.value if profile.is_empty() else for_profile(resolved.value,resolved.get("normal_sets",{}),profile,cache,"source:"+path+":"+slot)

static func for_profile(paths: Dictionary, normal_sets: Dictionary, profile: String,
        cache: Dictionary = {}, owner: String = "") -> Dictionary:
    # Source metadata and handoffs remain neutral. This projection changes only
    # which existing normal map is required, never its pixels or shader choice.
    if normal_sets.is_empty() or profile.is_empty():return paths
    var key=[&"__normal_profile_projection",owner,profile]
    var held: Dictionary=cache.get(key,{})
    if is_same(held.get("source"),paths) and is_same(held.get("normal_sets"),normal_sets):return held.paths
    var variants={};var selected={}
    for profiles in normal_sets.values():
        for path in profiles.values():variants[path]=true
        if profiles.has(profile):selected[profiles[profile]]=true
    var result={}
    for path in paths:
        if not variants.has(path) or selected.has(path):result[path]=paths[path]
    result.make_read_only()
    cache[key]={"source":paths,"normal_sets":normal_sets,"paths":result}
    return result

static func profile_normals(paths: Dictionary, normal_sets: Dictionary, profile: String) -> Dictionary:
    var result={}
    for profiles in normal_sets.values():
        var selected: String=profiles.get(profile,"")
        if not selected.is_empty() and paths.has(selected):result[selected]=true
    return result

static func _error(message: String) -> Dictionary:
    return {"ok":false,"error":{"kind":"presentation","message":message}}

static func effective_profile(source:Dictionary,requested:String)->String:
    var declared:String=str(source.get("normal_profile",""))
    return requested if declared.is_empty() else declared

static func normal_paths(path:String,slot:String,cache:Dictionary)->Dictionary:
    return {"ok":true,"value":BodySources.descriptor(path,slot,cache).get("normal_paths",{})}

static func source_paths(path:String,slot:String,cache:Dictionary)->Dictionary:
    var descriptor:Dictionary=BodySources.descriptor(path,slot,cache)
    return {"ok":true,"value":descriptor.get("companions",{}),"normal_sets":descriptor.get("normal_sets",{})}

## A facing selects registration metadata only; the source pixels and clock stay exact.
static func camera_origin(source:Dictionary,facing:String="")->Vector2:
    var optical:Dictionary=source.optical_camera
    var origin:Array=optical.get("origins_by_facing",{}).get(facing,optical.origin)
    return Vector2(origin[0],origin[1])

static func _camera_origins(source:Dictionary)->Dictionary:
    var result:Dictionary={}
    for facing in source.optical_camera.get("origins_by_facing",{}):result[facing]=camera_origin(source,facing)
    result.make_read_only()
    return result

static func _reconstruction_origins(source:Dictionary)->Array:
    var optical:Dictionary=source.optical_camera
    var result:Array=[optical.origin]
    for origin in optical.get("origins_by_facing",{}).values():
        if origin not in result:result.append(origin)
    return result

## Future pose preparation projects a private scalar parameter shell; source maps stay immutable.
static func parameters_for_facing(value:Dictionary,facing:String)->Dictionary:
    var origins:Dictionary=value.get("camera_origins",{})
    if origins.is_empty():return value.parameters
    var parameters:Dictionary=value.parameters.duplicate()
    parameters.component_reconstruction_origin=origins.get(facing,parameters.component_reconstruction_origin)
    return parameters

## The same source sheet may change facing without changing its resource binding key.
static func apply_facing(entry:Dictionary,facing:String="")->void:
    if not entry.has("geometry_camera_origins"):return
    if facing.is_empty():
        var sampled:Array=entry.get("bound_frame_key",[])
        if sampled.size()>2:facing=str(sampled[2])
    SourceMaterial.set_parameter(entry,"component_reconstruction_origin",entry.geometry_camera_origins.get(facing,entry.geometry_camera_origin))

static func prepare_binding(path:String,slot:String,cache:Dictionary,depth:bool,normals:bool,profile:String,scale:float,scale_x:float)->Dictionary:
    # Pure future operands. No displayed entry, native material or clock enters
    # this worker result; actual textures are borrowed by the scene owner later.
    var value:Dictionary={"key":[path,depth,normals,scale,scale_x,profile],"parameters":{},"textures":{},"paths":{},"bounds":PackedVector3Array()}
    var source:Dictionary=record(path,slot,cache)
    var pixel_scale:float=scale
    if source.get("source_scale",1.0)!=1.0:
        value.key.append(source.source_scale)
        pixel_scale*=float(source.source_scale)
    profile=effective_profile(source,profile)
    value.status="unsupported_source" if source.is_empty() else source.status
    if source.is_empty():
        value.parameters.has_component_geometry=false
        for parameter in PARAMETERS.values():value.parameters[parameter]=null
        return value
    var profiles:Dictionary=normal_paths(path,slot,cache).value
    if not profiles.has(profile):
        value.status="incomplete_normal_profile";value.error="Unknown normal profile: "+profile
        value.parameters.has_component_geometry=false
        for parameter in PARAMETERS.values():value.parameters[parameter]=null
        return value
    var root:String=_root(source)
    for field in PARAMETERS:
        var absolute:String=profiles[profile] if field=="normal" else root.path_join(source.files[field])
        value.textures[PARAMETERS[field]]=absolute;value.paths[absolute]=true
    var optical:Dictionary=source.optical_camera
    var normal_receiving:Dictionary=source.get("normal_receiving",{})
    var origins:Dictionary=_camera_origins(source)
    if not origins.is_empty():value.camera_origins=origins
    var cell:Array=source.get("cell_size",[128,128])
    value.cell=Vector2(cell[0],cell[1]);value.ground=source.get("optical_ground_pixels",19.0)
    value.parameters.merge({"component_depth_range":Vector2(source.depth_range[0],source.depth_range[1]),
        "component_units":pixel_scale/Placement.PIXELS_PER_UNIT,"component_scale_x":scale_x,
        "component_reconstruction_origin":Vector2(optical.origin[0],optical.origin[1]),"component_elevation":deg_to_rad(optical.elevation_degrees),
        "component_normal_requires_depth":normal_receiving.get("requires_depth",true),
        "component_normal_alpha_threshold":normal_receiving.get("alpha_threshold",0.5),
        "use_component_depth":depth,"use_component_normals":normals,"has_component_geometry":true})
    var relative:=Basis(Vector3.RIGHT,-(deg_to_rad(optical.elevation_degrees)-PI/6.0))
    var units:float=pixel_scale/Placement.PIXELS_PER_UNIT
    for origin in _reconstruction_origins(source):
        for x in [0.0,float(cell[0])]:
            for y in [0.0,float(cell[1])]:
                for d in source.depth_range:value.bounds.append(relative*Vector3(x-origin[0],origin[1]-y,d)*units)
    return value

static func apply_binding_values(entry:Dictionary,value:Dictionary)->bool:
    # Source values are independent of the current scene/pose. A private
    # resource worker and the ordinary binder share the exact same ledger.
    if entry.get("geometry_binding",[])==value.key:return false
    entry.geometry_binding=value.key;entry.geometry_status=value.status;entry.geometry_paths=value.paths
    entry.erase("geometry_ground_pixels");entry.erase("geometry_error");entry.erase("geometry_cell_size")
    entry.erase("geometry_camera_origins");entry.erase("geometry_camera_origin")
    if value.has("camera_origins"):
        entry.geometry_camera_origins=value.camera_origins
        entry.geometry_camera_origin=value.parameters.component_reconstruction_origin
    if value.has("cell"):entry.geometry_cell_size=value.cell
    if value.get("ground")!=null:entry.geometry_ground_pixels=value.ground
    if value.has("error"):entry.geometry_error=value.error
    SourceMaterial.apply(entry,value.parameters)
    apply_facing(entry)
    return true

static func binding_bounds(bounds:AABB,points:PackedVector3Array)->AABB:
    for point in points:bounds=bounds.expand(point)
    return bounds

static func apply_binding(entry:Dictionary,value:Dictionary)->void:
    if not apply_binding_values(entry,value):return
    entry.node.custom_aabb=binding_bounds(entry.node.mesh.get_aabb(),value.bounds)

static func clear(entry: Dictionary) -> void:
    SourceMaterial.set_parameter(entry,"has_component_geometry",false)
    for parameter in PARAMETERS.values(): SourceMaterial.set_parameter(entry,parameter,null)
    entry.geometry_paths = {}
    entry.erase("geometry_cell_size")
    entry.erase("geometry_ground_pixels")
    entry.erase("geometry_binding")
    entry.erase("geometry_camera_origins");entry.erase("geometry_camera_origin")
    entry.node.custom_aabb = entry.node.mesh.get_aabb()

static func bind(entry: Dictionary, path: String, cache: Dictionary, loader: Callable, depth: bool = true, normals: bool = true, profile: String = "original") -> void:
    var scale_x: float = entry.placement.get("scale_x",1.0)
    var key = [path,depth,normals,entry.scale,scale_x,profile]
    if entry.get("source_scale",1.0)!=1.0:key.append(entry.source_scale)
    if entry.get("geometry_binding",[]) == key: return
    var source = record(path,entry.actor_layer.slot,cache)
    profile=effective_profile(source,profile)
    if source.is_empty():
        clear(entry)
        entry.geometry_binding=key
        entry.geometry_status="unsupported_source"
        entry.erase("geometry_error")
        return
    var profiles = normal_paths(path,entry.actor_layer.slot,cache)
    if not profiles.ok or not profiles.value.has(profile):
        clear(entry)
        entry.geometry_binding=key
        entry.geometry_status = "incomplete_normal_profile"
        entry.geometry_error = profiles.error.message if not profiles.ok else "Unknown normal profile: " + profile
        return
    # A clip/profile selects new operands for the same source shader and quad.
    # Write their final values once; nulling and restoring them invalidates
    # unchanged receivers and prevents the material ledger retaining only deltas.
    entry.geometry_binding=key
    entry.geometry_status=source.status
    entry.geometry_paths={}
    entry.erase("geometry_ground_pixels")
    entry.erase("geometry_error")
    var root: String = _root(source)
    for field in PARAMETERS:
        var absolute: String = profiles.value[profile] if field=="normal" else root.path_join(source.files[field])
        SourceMaterial.set_parameter(entry,PARAMETERS[field],loader.call(absolute))
        entry.geometry_paths[absolute] = true
    SourceMaterial.set_parameter(entry,"component_depth_range",Vector2(source.depth_range[0],source.depth_range[1]))
    # Provisional optical convention: one reconstruction unit is one source
    # pixel at the existing quad scale. This never changes its geometry/Z/order.
    var pixel_scale:float=entry.scale
    if entry.get("source_scale",1.0)!=1.0:pixel_scale*=float(entry.source_scale)
    SourceMaterial.set_parameter(entry,"component_units",pixel_scale/Placement.PIXELS_PER_UNIT)
    SourceMaterial.set_parameter(entry,"component_scale_x",scale_x)
    var optical: Dictionary = source.get("optical_camera",{})
    var origins:Dictionary=_camera_origins(source)
    entry.erase("geometry_camera_origins");entry.erase("geometry_camera_origin")
    if not origins.is_empty():
        entry.geometry_camera_origins=origins
        entry.geometry_camera_origin=camera_origin(source)
    var cell: Array = source.get("cell_size",[128,128])
    entry.geometry_cell_size = Vector2(cell[0],cell[1])
    # Only original registered creatures have an authored ground. Library-only
    # packet availability never invents a gameplay placement.
    var ground: Variant = source.get("optical_ground_pixels",19.0)
    if ground!=null: entry.geometry_ground_pixels = float(ground)
    SourceMaterial.set_parameter(entry,"component_reconstruction_origin",Vector2(optical.origin[0],optical.origin[1]))
    apply_facing(entry)
    SourceMaterial.set_parameter(entry,"component_elevation",deg_to_rad(optical.elevation_degrees))
    SourceMaterial.set_parameter(entry,"use_component_depth",depth)
    SourceMaterial.set_parameter(entry,"use_component_normals",normals)
    var normal_receiving:Dictionary=source.get("normal_receiving",{})
    SourceMaterial.set_parameter(entry,"component_normal_requires_depth",normal_receiving.get("requires_depth",true))
    SourceMaterial.set_parameter(entry,"component_normal_alpha_threshold",normal_receiving.get("alpha_threshold",0.5))
    SourceMaterial.set_parameter(entry,"has_component_geometry",true)

    # Reconstructed points can lie outside the painted quad. Expand the native
    # light-culling box from the packet extrema, preserving the quad/pivot itself.
    # The source and display share azimuth but have 45 and 30 degree elevations.
    var relative := Basis(Vector3.RIGHT,-(deg_to_rad(optical.elevation_degrees)-PI/6.0))
    var bounds: AABB = entry.node.mesh.get_aabb()
    var units: float = pixel_scale/Placement.PIXELS_PER_UNIT
    for origin in _reconstruction_origins(source):
        for x in [0.0,float(cell[0])]:
            for y in [0.0,float(cell[1])]:
                for d in source.depth_range:
                    bounds = bounds.expand(relative*Vector3(x-origin[0],origin[1]-y,d)*units)
    entry.node.custom_aabb = bounds
