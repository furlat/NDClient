extends RefCounted
const SourceMaterial=preload("res://presentation/source_material.gd")
## Optical surface attachment for the offline fixture, with an explicit pose.
## Unresolved samples retain the authored painted point; no nearby-depth search.
const Geometry = preload("res://presentation/character_geometry.gd")
const Characters = preload("res://presentation/characters.gd")
const Placement = preload("res://placement.gd")
const Samples = preload("res://presentation/surface_socket_samples.gd")

## A socket's source pixel uses the very same quad pivot/model as the body.
## A finite event may retain a different contact; translate the model to that
## actual requested contact without borrowing a later live actor position.
static func painted_point(world:Node,row:Dictionary,pixel:Vector2)->Vector3:
    var visual:Dictionary=world.visual_actors.get(row.id,{})
    for entry in visual.get("entries",[]):
        if entry.role=="shadow" or not entry.actor_layer.get("effect",{}).is_empty():continue
        var pivot:Vector2=entry.pivot
        if not entry.get("source_layout",{}).is_empty():
            var native_rig:Dictionary=world.rigs[visual.row.rig]
            pivot=Vector2(native_rig.cell_width*.5,native_rig.cell_height-native_rig.origin_y_from_ground)
        var units:float=float(entry.scale)/Placement.PIXELS_PER_UNIT
        if entry.get("source_scale",1.0)!=1.0:units*=float(entry.source_scale)
        var local:Vector3=Vector3(pixel.x-pivot.x,pivot.y-pixel.y,0.0)*units
        var lift:float=float(row.get("visual_height",0.0))-float(visual.row.get("visual_height",0.0))
        return entry.node.global_transform*local+Placement.contact(row)-Placement.contact(visual.row)+Vector3.UP*lift*Placement.HEIGHT_UNIT
    var rig:Dictionary=world.rigs[row.rig]
    var units:float=128.0/float(world.rig_config.TILE_W)*row.scale/Placement.PIXELS_PER_UNIT
    if rig.get("source_scale",1.0)!=1.0:units*=float(rig.source_scale)
    return Placement.contact(row)+world.camera.basis.x*(pixel.x-rig.cell_width*.5)*units*row.get("scale_x",1.0)+world.camera.basis.y*(rig.cell_height-rig.origin_y_from_ground-pixel.y)*units+Vector3.UP*row.get("visual_height",0.0)*Placement.HEIGHT_UNIT

static func resolve(world: Node, actor_id: String, clip: String, frame: int,
        facing: String, socket_pixel: Vector2, painted_point: Vector3,
        hidden_slots: Array = []) -> Dictionary:
    var result := {"supported":false, "reason":"", "point":painted_point,
        "painted_point":painted_point, "actor_uuid":actor_id, "owner":"",
        "source":"", "clip":clip, "frame":frame, "facing":facing,
        "pixel":socket_pixel}
    if not socket_pixel.is_finite() or not painted_point.is_finite():
        return _missing(result, "nonfinite_socket")
    var visual: Dictionary = world.visual_actors.get(actor_id, {})
    if visual.is_empty() or not visual.get("valid", false):
        return _missing(result, "actor_not_displayed")
    var rig: Dictionary = world.rigs.get(visual.row.rig, {})
    if not rig.get("clips", {}).has(clip) or not rig.get("facing_rows", {}).has(facing):
        return _missing(result, "unknown_source_pose")
    if frame < 0 or frame >= int(rig.clips[clip].frames):
        return _missing(result, "source_frame_out_of_bounds")
    var cell := Vector2i(rig.cell_width, rig.cell_height)
    var pixel := Vector2i(floori(socket_pixel.x), floori(socket_pixel.y))
    if pixel.x < 0 or pixel.y < 0 or pixel.x >= cell.x or pixel.y >= cell.y:
        return _missing(result, "socket_outside_source_cell")
    var sheet_pixel := pixel + Vector2i(frame * cell.x, int(rig.facing_rows[facing]) * cell.y)
    # Entries retain the authoritative source-over order. Choose the painted
    # owner first; unsupported top-layer geometry must not reveal a lower map.
    for i in range(visual.entries.size() - 1, -1, -1):
        var entry: Dictionary = visual.entries[i]
        var layer: Dictionary = entry.actor_layer
        var slot: String = layer.slot
        if slot == "shadow" or slot in Characters.EFFECT_SLOTS or slot in hidden_slots:
            continue
        if not Characters.has_clip(layer,clip) or float(layer.get("alpha", 1.0)) <= 0.0:
            continue
        var source_path:String=Characters.source_path(layer,clip,facing)
        var layout:Dictionary=Geometry.BodySources.descriptor(source_path,slot,world.catalog_cache).get("source_layout",{})
        var sample_pixel:Vector2i=pixel
        var sample_sheet_pixel:Vector2i=sheet_pixel
        if not layout.is_empty():
            var source_pivot:=Vector2(layout.pivot[0],layout.pivot[1])
            var rig_pivot:=Vector2(rig.cell_width*.5,rig.cell_height-rig.origin_y_from_ground)
            var selected_pixel:Vector2=socket_pixel-rig_pivot+source_pivot
            sample_pixel=Vector2i(floori(selected_pixel.x),floori(selected_pixel.y))
            if sample_pixel.x<0 or sample_pixel.y<0 or sample_pixel.x>=layout.cell[0] or sample_pixel.y>=layout.cell[1]:continue
            var rect:Array=layout.frame_rects[frame]
            sample_sheet_pixel=sample_pixel+Vector2i(rect[0],rect[1])
        if not world.source_images.has(source_path):
            return _missing(result, "source_colour_not_prepared")
        var colour: Image = world.source_images[source_path]
        if not _contains(colour, sample_sheet_pixel):
            return _missing(result, "source_colour_layout_mismatch")
        var alpha := colour.get_pixelv(sample_sheet_pixel).a
        if alpha <= 0.0: continue
        result.owner = entry.id
        result.source = source_path
        if not is_equal_approx(alpha, 1.0) or not is_equal_approx(float(layer.get("alpha", 1.0)), 1.0):
            return _missing(result, "translucent_source_owner")
        var condition_alpha: Variant = SourceMaterial.value(entry,"condition_alpha")
        if condition_alpha != null and not is_equal_approx(float(condition_alpha), 1.0):
            return _missing(result, "translucent_display_owner")
        # Geometry.record normally admits metadata lazily. This playback helper
        # may use only the catalog already prepared by the sandbox media pass.
        if not world.catalog_cache.has(Geometry.BodySources.KEY):
            return _missing(result, "source_geometry_catalog_not_prepared")
        var source := Geometry.record(source_path, slot, world.catalog_cache)
        if not layout.is_empty() or source.is_empty() or not source.has("reference"):
            return _missing(result, "source_geometry_not_registered")
        var root := Geometry._root(source)
        var reference := root.path_join(source.reference)
        # The full modular HANDOFF names this file beside each actual completed
        # reference. The discarded initial proposed_output_reference is unused.
        var paths := {"depth":root.path_join(source.files.depth),
            "support":root.path_join(source.files.support),
            "solid":reference.get_base_dir().path_join("solid-valid.png")}
        var compact=Samples.sample(source_path,source,sheet_pixel,world.catalog_cache)
        var depth:Color
        var supported:bool
        var solid:bool
        if compact.size()==4:
            # Construct Color to retain the same float32 normalization as the
            # original Image.get_pixel; geometric placement is unchanged.
            depth=Color(float(compact[0])/255.0,0,0,float(compact[1])/255.0)
            supported=int(compact[2])>127
            solid=int(compact[3])>127
        else:
            # Unbaked/new source authoring and arbitrary offline probes retain
            # the existing exact CPU path. No readback or nearby-pixel guess.
            for channel in paths:
                if not world.source_images.has(paths[channel]):
                    return _missing(result, "source_" + channel + "_not_prepared")
                if not _contains(world.source_images[paths[channel]], sheet_pixel):
                    return _missing(result, "source_" + channel + "_layout_mismatch")
            depth=world.source_images[paths.depth].get_pixelv(sheet_pixel)
            supported=world.source_images[paths.support].get_pixelv(sheet_pixel).r>.5
            solid=world.source_images[paths.solid].get_pixelv(sheet_pixel).r>.5
        if depth.a <= .5 or not supported:
            return _missing(result, "unsupported_source_pixel")
        if not solid:
            return _missing(result, "source_pixel_not_solid")
        var optical: Dictionary = source.get("optical_camera", {})
        if optical.is_empty(): return _missing(result, "source_optical_registration_missing")
        # Modular part packets (no normal profiles of their own) carry no measured ground line.
        var ground: Variant = source.get("optical_ground_pixels", 19.0 if not source.has("normal_profiles") else null)
        if ground == null: return _missing(result, "source_ground_registration_missing")
        var node: Node3D = entry.node
        if not is_instance_valid(node): return _missing(result, "source_model_unavailable")
        var toward: Vector3 = world.camera.global_basis.z
        var model_axis: Vector3 = node.global_basis.z
        if absf(toward.y) < .00001 or model_axis.is_zero_approx() or model_axis.normalized().dot(toward) < .99999:
            return _missing(result, "source_model_not_on_display_ray")
        var units := float(entry.scale) / Placement.PIXELS_PER_UNIT
        if entry.get("source_scale",1.0)!=1.0:units*=float(entry.source_scale)
        var elevation := deg_to_rad(float(optical.elevation_degrees))
        var decoded := float(source.depth_range[0]) + (depth.r * 255.0 - 32.0) * (float(source.depth_range[1]) - float(source.depth_range[0])) / 192.0
        var optical_height := ((Geometry.camera_origin(source,facing).y - float(pixel.y) - .5) * cos(elevation) + decoded * sin(elevation)) * units
        var height := optical_height - float(ground) * units
        var local := Vector3(socket_pixel.x - entry.pivot.x, entry.pivot.y - socket_pixel.y, 0.0) * units
        var painted_height: float = (world.camera.global_basis * local).y
        var view_depth := (height - painted_height) / toward.y
        # The actual model carries mirroring, passage scale and airborne origin.
        # Only its camera-ray displacement is added to the unchanged authored
        # anchor, retaining existing endpoint padding and subpixel placement.
        result.point = painted_point + model_axis * view_depth
        result.supported = true
        result.reason = "supported"
        result.sample_pixel = sheet_pixel
        result.depth = decoded
        result.height_above_optical_ground = height
        result.ray_offset = model_axis.length() * view_depth
        result.solid_source = paths.solid
        return result
    return _missing(result, "no_painted_source_at_socket")

static func _contains(image: Image, pixel: Vector2i) -> bool:
    return image != null and not image.is_empty() and pixel.x >= 0 and pixel.y >= 0 and pixel.x < image.get_width() and pixel.y < image.get_height()

static func _missing(result: Dictionary, reason: String) -> Dictionary:
    result.reason = reason
    return result
