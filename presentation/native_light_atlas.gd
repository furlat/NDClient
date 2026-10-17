extends RefCounted
const GroundReceiving = preload("res://presentation/ground_receiving.gd")
const Delta = preload("res://presentation/native_light_delta.gd")
const CanvasDraw = preload("res://presentation/canvas_draw.gd")
const SourceMaterial = preload("res://presentation/source_material.gd")
# Native Canvas lights receive into isolated straight-RGBA cells. Original 3D
# quads, source materials, painter order and picking remain their original owners.
const CappedEnvironment = preload("res://presentation/canvas_capped_environment.gdshader")
const CappedModular = preload("res://presentation/canvas_capped_modular.gdshader")
const CappedWater = preload("res://presentation/canvas_capped_water.gdshader")
const Output = preload("res://presentation/canvas_received.gdshader")
const EnvironmentReceiver = preload("res://presentation/canvas_environment.gdshader")
const ShadowReceiver = preload("res://presentation/canvas_environment_unshaded.gdshader")
const ModularReceiver = preload("res://presentation/canvas_modular.gdshader")
const WaterReceiver = preload("res://presentation/canvas_water.gdshader")
const NonreceivingDebug = preload("res://presentation/canvas_nonreceiving_debug.gdshader")
const FlameReceiver = preload("res://presentation/canvas_fixture_flame.gdshader")
const FlameSource = preload("res://presentation/fixture_flame.gdshader")
const MAX_SIZE = 8192
const AMBIENT_INTENSITY = 0.30
# These parameters have explicit style/output owners below. They do not change
# the generic source uniforms already delivered to a receiving material.
const SAMPLE_PARAMETERS={&"current_visibility":true,&"highlighted":true,&"wall_opacity":true,
    &"wall_mask_enabled":true,&"wall_mask_id":true,&"wall_mask_texture":true}
var light_cap: float = 0.0
var ambient: CanvasModulate
var viewport: SubViewport
var receivers: Array = []
var membership: Array = []
var groups: Dictionary = {}
var crop_cache: Dictionary = {}
var parameter_names: Dictionary = {}
var white: Texture2D
var owner: Node3D
var errors: Array = []
var revision := 0
var repack_count := 0
var canvas_key: Array = []
var packed_pixels := 0
var live_receivers := 0
var last_sync_ms := 0.0
var last_pack_ms := 0.0
var layout_members: Dictionary = {}
var projection_root: Node2D
var plane_basis := Basis.IDENTITY
var plane_to_screen := Transform2D.IDENTITY
var static_receivers: Array = []
var dynamic_receivers: Array = []
var static_live_receivers := 0
var admission_stamp: Array = []
var visibility_stamp: Array = []
var dynamic_members: Array = []
var output_stamp: Array = []
var output_dirty: Dictionary = {}
var output_tracked := false
var output_full := false
var output_admission_failed := false
# Play publishes only complete prepared cuts. Standalone authoring/reference
# callers retain the explicit complete-source planner.
var require_prepared_publication := false
var transport_stamp: Array = []
var known_entry_count := -1
var last_reconcile_ms := 0.0
var last_projection_ms := 0.0
var last_reconcile_phases: Dictionary = {}
var last_delta_fallback := ""
var projection_dirty: Array = []
# Display-owner notifications, accumulated until a successful atlas sync. They
# carry identities only; final admitted values are read after buffer publication.
var style_dirty: Dictionary = {}
var visibility_dirty: Dictionary = {}
var cull_dirty: Dictionary = {}
var receivers_tracked := false
var entry_specs: Dictionary = {}
var published_supports: Dictionary = {}
var shelf_cursor := Vector3i(1,1,0)
var delta_ready := false
var delta_serial := -1
var receiver_index: Dictionary = {}
var support_owners: Dictionary = {}
var source_groups: Dictionary = {}
var material_dirty: Dictionary = {}
var next_source_order := 0
var prepared_receiver_sources: Dictionary = {}
var prepared_source_bindings: Dictionary = {}
var prepared_delta: Dictionary = {}
var prepared_style_receivers: Dictionary = {}
var prepared_cleanup: Dictionary = {}
var sample_serial:int=0

func attach(parent: Node3D) -> void:
    owner = parent
    viewport = SubViewport.new()
    viewport.name = "Native2DReceiving"
    viewport.disable_3d = true
    viewport.transparent_bg = true
    viewport.use_hdr_2d = _uses_hdr()
    viewport.size = Vector2i(MAX_SIZE,1024)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    parent.add_child(viewport)
    projection_root=Node2D.new()
    projection_root.name="ReceivingProjection"
    viewport.add_child(projection_root)
    ambient = CanvasModulate.new()
    ambient.color = Color(AMBIENT_INTENSITY,AMBIENT_INTENSITY,AMBIENT_INTENSITY,1.0).linear_to_srgb() if _uses_hdr() else Color(AMBIENT_INTENSITY,AMBIENT_INTENSITY,AMBIENT_INTENSITY,1.0)
    viewport.add_child(ambient)
    RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
    var pixel = Image.create(1,1,false,Image.FORMAT_RGBA8)
    pixel.fill(Color.WHITE)
    white = ImageTexture.create_from_image(pixel)

func set_light_cap(value: float) -> void:
    var selected = maxf(value,0.0)
    if is_equal_approx(light_cap,selected): return
    light_cap=selected
    if is_instance_valid(viewport):
        viewport.use_hdr_2d=_uses_hdr()
        # Godot4.7.2 converts CanvasModulate for HDR, while native light colour
        # and cookie atlas values are unchanged. Preserve calibrated numeric ambient.
        ambient.color=Color(AMBIENT_INTENSITY,AMBIENT_INTENSITY,AMBIENT_INTENSITY,1.0).linear_to_srgb() if _uses_hdr() else Color(AMBIENT_INTENSITY,AMBIENT_INTENSITY,AMBIENT_INTENSITY,1.0)
    for group in groups.values(): group.version=-1
    membership.clear(); admission_stamp.clear(); output_stamp.clear()
    delta_ready=false
    revision+=1

var normals_visible = false
var normal_shaders: Dictionary = {}

func _uses_hdr() -> bool:
    return light_cap>0.0 and not normals_visible

func set_normals_visible(value: bool) -> void:
    if normals_visible==value: return
    normals_visible=value
    if is_instance_valid(viewport):
        viewport.use_hdr_2d=_uses_hdr()
        ambient.color=Color(AMBIENT_INTENSITY,AMBIENT_INTENSITY,AMBIENT_INTENSITY,1.0).linear_to_srgb() if _uses_hdr() else Color(AMBIENT_INTENSITY,AMBIENT_INTENSITY,AMBIENT_INTENSITY,1.0)
    for group in groups.values(): group.version=-1
    membership.clear(); admission_stamp.clear(); output_stamp.clear()
    delta_ready=false

func _normal_shader(source: Shader) -> Shader:
    if not normal_shaders.has(source):
        var shader=Shader.new()
        var code: String=source.code.replace("blend_disabled;","blend_disabled, unshaded;")
        code=code.replace('#include "','#include "res://presentation/')
        shader.code="#define SHOW_SOURCE_NORMALS\n"+code
        normal_shaders[source]=shader
    return normal_shaders[source]

func _entry_info(entry: Dictionary, target_options: Dictionary = {}) -> Dictionary:
    var selected_normals: bool = target_options.get("normals_visible",normals_visible)
    var selected_cap: float = target_options.get("light_cap",light_cap)
    var source: Shader = entry.material.shader
    var previous: Dictionary = entry.atlas_source_info if entry.has("atlas_source_info") else {}
    if not previous.is_empty() and previous.source==source and previous.role==entry.role and previous.kind==entry.placement.kind and previous.get("normals_visible",false)==selected_normals and previous.get("light_cap",0.0)==selected_cap: return previous
    var path: String = source.resource_path
    var modular: bool = path.ends_with("modular.gdshader")
    var water: bool = path.ends_with("water.gdshader")
    var flame: bool = path.ends_with("fixture_flame.gdshader")
    var shader: Shader = ModularReceiver if modular else WaterReceiver if water else FlameReceiver if flame else ShadowReceiver if entry.role=="shadow" else EnvironmentReceiver
    if selected_normals:
        if entry.role=="shadow" or flame: shader=NonreceivingDebug
        elif shader in [ModularReceiver,WaterReceiver,EnvironmentReceiver]: shader=_normal_shader(shader)
    var capped: bool = selected_cap>0.0 and not selected_normals and entry.role!="shadow" and not flame
    var output: Shader = (CappedModular if modular else CappedWater if water else CappedEnvironment) if capped else Output
    var result={"capped":capped,"light_cap":selected_cap,"normals_visible":selected_normals,"source":source,"role":entry.role,"kind":entry.placement.kind,"shader":shader,"output":output,"water":water,"dynamic":entry.placement.kind=="actor" or flame}
    if target_options.is_empty(): entry.atlas_source_info=result
    return result

func _shader(entry: Dictionary) -> Shader:
    return _entry_info(entry).shader

func _output_shader(entry: Dictionary) -> Shader:
    return _entry_info(entry).output

func _dynamic(entry: Dictionary) -> bool:
    return _entry_info(entry).dynamic

func _issue(message: String) -> void:
    if message not in errors: errors.append(message)

func _crop(entry: Dictionary, world: Node, info: Dictionary = {}) -> Dictionary:
    var cell = Vector2i(entry.cell)
    # Animated sheets retain one stable authored cell throughout frame changes.
    # Static sources use their exact nonzero-alpha bounds, never an alpha cutoff.
    if info.is_empty(): info=_entry_info(entry)
    if info.dynamic or info.water:
        return {"pixels":Rect2i(Vector2i.ZERO,cell),"uv":Vector4(0,0,1,1)}
    var record: Dictionary = entry.get("record",{})
    var path: String = record.get("path","")
    if not world.source_images.has(path):
        _issue("Native light atlas needs prepared original colour image: "+path)
        return {}
    var image: Image = world.source_images[path]
    var r: Array = record.get("rect",[0,0,cell.x,cell.y])
    var region = Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
    var key = [image.get_instance_id(),region,cell]
    if crop_cache.has(key): return crop_cache[key]
    if not Rect2i(Vector2i.ZERO,image.get_size()).encloses(region) or not region.has_area() or cell.x<1 or cell.y<1:
        _issue("Native light atlas original region is outside its prepared image: "+path)
        return {}
    var result:Dictionary=static_crop(image,region,cell)
    crop_cache[key] = result
    return result

static func static_crop(image:Image,region:Rect2i,cell:Vector2i)->Dictionary:
    # The admitted original Image is immutable. Both ordinary source binding
    # and the private environment worker use this exact nonzero-alpha rule.
    var used: Rect2i = image.get_region(region).get_used_rect()
    var pixels = Rect2i(Vector2i.ZERO,Vector2i.ONE)
    if used.has_area():
        var scale = Vector2(cell)/Vector2(region.size)
        var start = (Vector2(used.position)*scale).floor()
        var end = (Vector2(used.end)*scale).ceil()
        pixels = Rect2i(Vector2i(start),Vector2i(end-start))
    var uv = Vector4(float(pixels.position.x)/cell.x,float(pixels.position.y)/cell.y,
        float(pixels.size.x)/cell.x,float(pixels.size.y)/cell.y)
    return {"pixels":pixels,"uv":uv}

static func plan_layout(specs: Array, minimum: Vector2i, limit: int = MAX_SIZE) -> Dictionary:
    # Pure planning: an overflow cannot mutate the last published atlas, nodes,
    # material overrides or floor addresses.
    var positions = {}; var x = 1; var y = 1; var row_height = 0; var pixels = 0
    for spec in specs:
        var size: Vector2i = spec.crop.pixels.size
        if size.x+2>limit or size.y+2>limit:
            return {"ok":false,"error":"Native light atlas source cell exceeds %d: %s" % [limit,size]}
        if x+size.x+1>limit:
            x=1; y+=row_height+2; row_height=0
        positions[spec.id] = Vector2i(x,y)
        x+=size.x+2; row_height=maxi(row_height,size.y); pixels+=size.x*size.y
    var needed = maxi(y+row_height+1,minimum.y)
    if needed>limit or minimum.x>limit:
        return {"ok":false,"error":"Native light atlas exceeds %d pixels: %s" % [limit,Vector2i(minimum.x,needed)]}
    var height = maxi(1,minimum.y)
    while height<needed: height=mini(limit,height*2)
    return {"ok":true,"size":Vector2i(limit,height),"positions":positions,"pixels":pixels,"cursor":Vector3i(x,y,row_height),"full":true}

func _layout_additions(specs: Array, members: Dictionary, minimum: Vector2i) -> Dictionary:
    # Preserve live cells while adding a few disclosed receivers. Removed cells
    # become holes; the existing compact planner remains the bounded fallback.
    if layout_members.is_empty(): return plan_layout(specs,minimum)
    var x=shelf_cursor.x; var y=shelf_cursor.y; var height=shelf_cursor.z
    var positions={}; var pixels=0
    for spec in specs:
        var size: Vector2i=spec.crop.pixels.size
        pixels+=size.x*size.y
        if layout_members.has(spec.id):
            if layout_members[spec.id]!=members[spec.id]: return plan_layout(specs,minimum)
            continue
        if size.x+2>MAX_SIZE or size.y+2>MAX_SIZE: return plan_layout(specs,minimum)
        if x+size.x+1>MAX_SIZE: x=1; y+=height+2; height=0
        if y+size.y+1>MAX_SIZE: return plan_layout(specs,minimum)
        positions[spec.id]=Vector2i(x,y)
        x+=size.x+2; height=maxi(height,size.y)
    var needed=maxi(y+height+1,minimum.y)
    if needed>MAX_SIZE or minimum.x>MAX_SIZE: return plan_layout(specs,minimum)
    var size_y=viewport.size.y
    while size_y<needed: size_y=mini(MAX_SIZE,size_y*2)
    return {"ok":true,"size":Vector2i(MAX_SIZE,size_y),"positions":positions,"pixels":pixels,"cursor":Vector3i(x,y,height),"full":false}

func _candidate_specs(entries: Array, information: Dictionary, geometry: Dictionary, signatures: Dictionary, world: Node) -> Dictionary:
    var phase=Time.get_ticks_usec()
    var supports=GroundReceiving.heights(entries)
    var dirty_cells={}
    for cell in published_supports:
        if not supports.has(cell) or supports[cell]!=published_supports[cell]: dirty_cells[cell]=true
    for cell in supports:
        if not published_supports.has(cell) or supports[cell]!=published_supports[cell]: dirty_cells[cell]=true
    var affected={}
    for cell in dirty_cells:
        affected[cell]=true
        for direction in GroundReceiving.DIRECTIONS: affected[cell+direction]=true
    last_reconcile_phases.supports_ms=(Time.get_ticks_usec()-phase)/1000.0
    phase=Time.get_ticks_usec()
    var specs: Array=[]; var members={}; var caches={}; var indices={}; var reused=0
    var slices=0; var masks=0; var packets_reused=0
    for entry in entries:
        var source_id: int=entry.node.get_instance_id()
        var info: Dictionary=information[source_id]
        var signature: Array=signatures[source_id]
        var previous: Dictionary=entry_specs[source_id] if entry_specs.has(source_id) else {}
        var same: bool=not previous.is_empty() and is_same(previous.entry,entry) and previous.signature==signature
        var topology_changed=false
        if same and not affected.is_empty():
            for cell in previous.cells:
                if affected.has(cell): topology_changed=true; break
        var candidate: Dictionary
        if same and previous.ground_version==entry.get("ground_version",0) and not topology_changed:
            candidate=previous; reused+=previous.specs.size()
        else:
            var crop: Dictionary=previous.crop if same else _crop(entry,world,info)
            if crop.is_empty(): return {"ok":false}
            var batched: bool=entry.has("batch_rows")
            var rows: Array=entry.batch_rows if batched else [entry.placement]
            candidate={"entry":entry,"signature":signature,"ground_version":entry.get("ground_version",0),"crop":crop,"specs":[],"by_row":{},"indices":{},"cells":{},"packets":{}}
            var previous_rows: Dictionary=previous.get("by_row",{}) if same else {}
            var previous_packets: Dictionary=previous.get("packets",{}) if same else {}
            for index in rows.size():
                var row: Dictionary=rows[index]
                var row_id: String=str(row.id) if batched else "source"
                var old: Dictionary=previous_rows[row_id] if previous_rows.has(row_id) else {}
                var eligible=GroundReceiving.eligible(row)
                var cell=Vector2(row.position[0],row.position[1]) if eligible else Vector2.ZERO
                if eligible: candidate.cells[cell]=true
                var packet: Dictionary=previous_packets[row_id] if previous_packets.has(row_id) else {}
                var support=Vector3(cell.x,cell.y,float(row.get("base_height_steps",0.0)))
                var unchanged: bool=batched and not old.is_empty() and not packet.is_empty() and packet.data==entry.ground_packets[row_id].data and packet.eligible==eligible and packet.support==support
                var spec: Dictionary
                if unchanged and not affected.has(cell):
                    # Native packed-array equality checks ALL transform bytes,
                    # including direct packet edits, before reusing a row. The
                    # snapshot is separate from the mutable published packet.
                    spec=old; reused+=1; packets_reused+=1
                else:
                    var source_geometry: Array=[]
                    if not info.dynamic:
                        var transform: PackedFloat32Array=entry.ground_packets[row_id].data.slice(0,12) if batched else PackedFloat32Array()
                        if batched: slices+=1
                        source_geometry=[geometry.get(source_id,[]),crop.uv,transform]
                    var join_mask: int=GroundReceiving.mask(row,supports)
                    masks+=1
                    if not old.is_empty() and old.source_geometry==source_geometry and old.join_mask==join_mask:
                        spec=old; reused+=1
                    else:
                        spec={"join_mask":join_mask,"id":str(source_id)+":"+row_id,"entry":entry,"crop":crop,"source_geometry":source_geometry,"source_id":source_id,"info":info,"material_id":entry.material.get_instance_id()}
                if batched:
                    candidate.packets[row_id]=packet if unchanged else {"data":entry.ground_packets[row_id].data.duplicate(),"eligible":eligible,"support":support}
                candidate.specs.append(spec); candidate.by_row[row_id]=spec
                candidate.indices[spec.id]=index if batched else -1
        caches[source_id]=candidate
        specs.append_array(candidate.specs); indices.merge(candidate.indices)
        for spec in candidate.specs: members[spec.id]=spec.crop
    last_reconcile_phases.candidates_ms=(Time.get_ticks_usec()-phase)/1000.0
    last_reconcile_phases.transform_slices=slices
    last_reconcile_phases.join_masks_evaluated=masks
    last_reconcile_phases.floor_packets_reused=packets_reused
    return {"ok":true,"specs":specs,"members":members,"entries":caches,"indices":indices,"supports":supports,"reused":reused}

func _parameter_changes(entry:Dictionary,previous_version:int)->Variant:
    return SourceMaterial.changes_since(entry,previous_version)

func _output_parameter_names(shader:Shader,target:Shader)->Dictionary:
    var key:Array=[shader.get_instance_id(),target.get_instance_id()]
    if not parameter_names.has(key):
        var accepted:Dictionary={};var names:Dictionary={}
        for row in target.get_shader_uniform_list():accepted[row.name]=true
        for row in shader.get_shader_uniform_list():
            if accepted.has(row.name) and not str(row.name).begins_with("wall_") and row.name not in ["use_instance_visibility","current_visibility","highlighted"]:names[row.name]=true
        parameter_names[key]=names
    return parameter_names[key]

func _copy_output_source(entry: Dictionary,source_shader:Shader=null,sample_base:int=-1) -> void:
    if not entry.has("received_material"): return
    var output: ShaderMaterial=entry.received_material
    var source: ShaderMaterial=entry.material
    var version: int=entry.get("source_version",0)
    var previous: Dictionary=entry.received_source_key if entry.has("received_source_key") else {}
    var same_owner=not previous.is_empty() and previous.output==output and previous.output_shader==output.shader and previous.binding_revision==entry.source_binding_revision
    if same_owner and previous.version==version:return
    var mesh: QuadMesh=entry.node.multimesh.mesh if entry.has("batch_rows") else entry.node.mesh
    if same_owner and sample_base>=0 and previous.version>=sample_base and previous.get("quad_size")==mesh.size:
        var next:Dictionary=previous.duplicate();next.version=version
        entry.received_source_key=next
        return
    var shader:Shader=source.shader if source_shader==null else source_shader
    var names:Dictionary=_output_parameter_names(shader,output.shader)
    var changes:Variant=_parameter_changes(entry,previous.version) if same_owner and previous.get("quad_size")==mesh.size else null
    if changes!=null:
        var copied:int=0
        for name in changes:
            if name in names:output.set_shader_parameter(name,SourceMaterial.value(entry,name));copied+=1
        if changes.size()==1 and changes.has(&"frame_uv"):last_reconcile_phases.material_frame_copies=last_reconcile_phases.get("material_frame_copies",0)+1
        else:last_reconcile_phases.material_parameter_copies=last_reconcile_phases.get("material_parameter_copies",0)+1
        last_reconcile_phases.material_parameter_uniforms=last_reconcile_phases.get("material_parameter_uniforms",0)+copied
    else:
        for name in names: output.set_shader_parameter(name,SourceMaterial.value(entry,name))
        output.set_shader_parameter("use_instance_visibility",entry.has("batch_rows"))
        output.set_shader_parameter("source_quad_size",mesh.size)
        entry.erase("received_style")
        last_reconcile_phases.material_full_copies=last_reconcile_phases.get("material_full_copies",0)+1
        var field:String="material_output_full_dynamic" if _entry_info(entry).dynamic else "material_output_full_static"
        last_reconcile_phases[field]=last_reconcile_phases.get(field,0)+1
    entry.received_source_key={"binding_revision":entry.source_binding_revision,"version":version,"output":output,"output_shader":output.shader,"quad_size":mesh.size}

func _copy_parameters(group: Dictionary,source_shader:Shader=null,binding:Variant=null) -> bool:
    # Return whether shared non-frame uniforms were recopied. Projection/style
    # owners need no redundant writes for an admitted UV-only animation frame.
    var source: ShaderMaterial = group.entry.material
    var shader:Shader=source.shader if source_shader==null else source_shader
    var key = [shader.get_instance_id(),group.material.shader.get_instance_id()]
    if not parameter_names.has(key):
        var accepted = {}
        for row in group.material.shader.get_shader_uniform_list(): accepted[row.name]=true
        var names: Dictionary = {}
        for row in shader.get_shader_uniform_list():
            if accepted.has(row.name) and row.name not in ["current_visibility","highlighted"]: names[row.name]=true
        parameter_names[key]=names
    var same_owner:bool=bool(binding) if binding!=null else group.get("source_material")==source and group.source_shader==shader and group.get("target_material")==group.material and group.get("target_shader")==group.material.shader and group.get("binding_revision",-1)==group.entry.source_binding_revision
    var changes:Variant=_parameter_changes(group.entry,group.version) if same_owner else null
    if changes!=null:
        var copied:int=0
        for name in changes:
            if name in parameter_names[key]:group.material.set_shader_parameter(name,SourceMaterial.value(group.entry,name));copied+=1
        if changes.size()==1 and changes.has(&"frame_uv"):last_reconcile_phases.material_frame_copies=last_reconcile_phases.get("material_frame_copies",0)+1
        else:last_reconcile_phases.material_parameter_copies=last_reconcile_phases.get("material_parameter_copies",0)+1
        last_reconcile_phases.material_parameter_uniforms=last_reconcile_phases.get("material_parameter_uniforms",0)+copied
    else:
        for name in parameter_names[key]: group.material.set_shader_parameter(name,SourceMaterial.value(group.entry,name))
        group.material.set_shader_parameter("use_instance_visibility",false)
        group.material.set_shader_parameter("source_crop",group.crop.uv)
        group.material.set_shader_parameter("atlas_cell_size",Vector2(group.crop.pixels.size))
        group.material.set_shader_parameter("receiver_visibility",group.visibility)
        group.material.set_shader_parameter("ground_join_mask",group.get("join_mask",0))
        group.capped=group.info.capped
        group.material.set_shader_parameter("store_irradiance",group.capped)
        group.seconds=null;group.highlighted=null
        last_reconcile_phases.material_full_copies=last_reconcile_phases.get("material_full_copies",0)+1
        var field:String="material_receiver_full_dynamic" if group.info.dynamic else "material_receiver_full_static"
        last_reconcile_phases[field]=last_reconcile_phases.get(field,0)+1
    group.version = group.entry.get("source_version",0)
    if not same_owner:
        group.source_shader=shader
        group.source_material=source;group.target_material=group.material;group.target_shader=group.material.shader
        group.binding_revision=group.entry.source_binding_revision
    return changes==null

func _group(entry: Dictionary, crop: Dictionary, visibility: float, receiver_id: String, info: Dictionary = {}, join_mask: int = 0) -> Dictionary:
    # GLES3 reserves 16 vec4 slots per instance-uniform CanvasItem and has only
    # 4096 hardware slots here. Native region UV carries packing without that
    # allocation. Binary memory style uses two shared materials per source.
    if info.is_empty(): info=_entry_info(entry)
    var id: Array = [entry.material.get_instance_id(),visibility,receiver_id if info.water else "",join_mask]
    var group: Dictionary = groups.get(id,{})
    var shader: Shader = info.shader
    if group.is_empty():
        var prepared: Dictionary=prepared_source_bindings.get(entry.node.get_instance_id(),{})
        if prepared.get("accepted",false): group=prepared.groups.get(id,{})
        if group.is_empty(): group=_new_group(entry,crop,visibility,id,info,join_mask)
        else: last_reconcile_phases.prepared_receiver_materials=last_reconcile_phases.get("prepared_receiver_materials",0)+1
        group.rank=groups.size()
        groups[id]=group
    elif group.material.shader!=shader or group.crop!=crop:
        group.material.shader=shader; group.crop=crop; group.version=-1
    group.entry=entry
    group.info=info
    group.water=info.water
    var source_id: int=entry.node.get_instance_id()
    group.source_id=source_id
    if not source_groups.has(source_id): source_groups[source_id]={}
    source_groups[source_id][id]=group
    if group.version<0: material_dirty[source_id]=true
    return group

func _new_group(entry:Dictionary,crop:Dictionary,visibility:float,id:Array,info:Dictionary,join_mask:int)->Dictionary:
    return Delta.new_group(entry,crop,visibility,id,info,join_mask)

static func selected_parameters(ledger:Dictionary,names:Dictionary)->Dictionary:
    var selected:Dictionary={}
    for name in names:selected[name]=ledger.get(name)
    return selected

func _receiver_parameter_names(shader:Shader,target:Shader)->Dictionary:
    var key:Array=[shader.get_instance_id(),target.get_instance_id()]
    if not parameter_names.has(key):
        var accepted:Dictionary={};var names:Dictionary={}
        for row in target.get_shader_uniform_list():accepted[row.name]=true
        for row in shader.get_shader_uniform_list():
            if accepted.has(row.name) and row.name not in ["current_visibility","highlighted"]:names[row.name]=true
        parameter_names[key]=names
    return parameter_names[key]

func capture_group_input(entry:Dictionary,info:Dictionary,crop:Dictionary,basis:Basis,screen:Vector2)->Dictionary:
    # Capture only actual source values. The worker never reads the original
    # material, a Node, a texture, or a mutable source-parameter dictionary.
    var shader:Shader=entry.material.shader
    var parameters:Dictionary=selected_parameters(entry.source_parameters,_receiver_parameter_names(shader,info.shader))
    parameters.make_read_only()
    var input:Dictionary={"entry":entry,"info":info,"crop":crop,"parameters":parameters,
        "basis":basis,"screen":screen,"source_shader":shader,"source_material":entry.material,
        "version":entry.source_version,"binding_revision":entry.source_binding_revision,
        "highlighted":SourceMaterial.value(entry,"highlighted")}
    input.make_read_only()
    return input

func static_environment_options(world:Node,packets:Dictionary={},images:Dictionary={})->Dictionary:
    var shader:Shader=preload("res://environment.gdshader")
    var roles:Dictionary={}
    for role in ["body","wall","cliff","terrain","shadow"]:
        var info:Dictionary=_entry_info({"material":{"shader":shader},"role":role,"placement":{"kind":"prop"}})
        roles[role]={"info":info,"receiver_names":_receiver_parameter_names(shader,info.shader),
            "output_names":_output_parameter_names(shader,info.output)}
    var crops:Dictionary={}
    for packet in packets.values():
        for selected in packet.entries:
            var value:Dictionary=selected.descriptor
            if value.get("empty",false):continue
            var record:Dictionary=value.record;var path:String=record.path
            if not images.has(path):continue
            var cell:=Vector2i(value.cell);var r:Array=record.get("rect",[0,0,cell.x,cell.y])
            var key:Array=[images[path].get_instance_id(),Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3])),cell]
            if crop_cache.has(key):crops[key]=crop_cache[key]
    return {"roles":roles,"basis":Basis(world.camera.global_basis.x,-world.camera.global_basis.y,world.camera.global_basis.z).transposed(),
        "screen_size":world.get_viewport().get_visible_rect().size,"parent_transform":world.global_transform,
        "received":viewport.get_texture(),"transport":[viewport.get_instance_id(),_uses_hdr(),light_cap],"cached_crops":crops}

static func _binding_shell(entry:Dictionary,sampled:Dictionary,source:Dictionary,output:Dictionary,group_input:Dictionary,basis:Basis,screen:Vector2)->Dictionary:
    return {"entry":entry,"snapshot":sampled,"source":source,"signature":source.signature,"info":source.info,
        "ground_version":source.ground_version,"version":entry.get("source_version",0),"binding_revision":entry.source_binding_revision,
        "specs":{},"groups":{},"receivers":{},"output":output,"accepted":false,"phase_usec":{},
        "profile_preparation":false,"created_rows":0,"projected_packet_rows":0,"group_input":group_input,"basis":basis,"screen_size":screen}

static func private_environment_binding(entry:Dictionary,value:Dictionary,options:Dictionary,crop:Dictionary,crop_key:Array)->Dictionary:
    var selected:Dictionary=options.roles.get(entry.role,options.roles.body)
    var info:Dictionary=selected.info.duplicate();info.kind=entry.placement.kind;info.role=entry.role
    var geometry:Array=[options.get("source_parent_transform",options.parent_transform)*Transform3D(value.basis,value.position),value.mesh_size,value.mesh_center]
    var signature:Array=[value.cell,value.record.get("path",""),value.record.get("rect",[]),info.shader,entry.material.get_instance_id(),geometry]
    var source:Dictionary={"info":info,"signature":signature,"geometry":geometry,"crop":crop,"same":false,
        "ground_version":0,"row_indices":{},"packets":{},"by_row":{},"receivers":{},"addresses":{}}
    var sampled:Dictionary=entry.duplicate()
    sampled.erase("prepared_source");sampled.erase("mesh")
    sampled.merge({"cell":value.cell,"pivot":value.pivot,"scale":value.scale,"screen_rect":value.screen_rect,
        "record":value.record,"floor_group":value.floor_group,"scenery_value":float(entry.source_parameters.current_visibility) if entry.source_parameters.get("current_visibility")!=null else 1.0})
    var group_input:Dictionary={"parameters":selected_parameters(entry.source_parameters,selected.receiver_names),"info":info,"crop":crop,
        "basis":options.basis,"screen":options.screen_size,"source_shader":options.roles.body.info.source,"source_material":entry.material,
        "version":entry.source_version,"binding_revision":entry.source_binding_revision,"highlighted":entry.source_parameters.get("highlighted")}
    var parameters:Dictionary=selected_parameters(entry.source_parameters,selected.output_names) if info.capped else {}
    if info.capped:
        parameters.use_instance_visibility=false;parameters.source_quad_size=value.mesh_size
        parameters.current_visibility=sampled.scenery_value;parameters.highlighted=group_input.highlighted
    parameters.received=options.received;parameters.received_is_encoded_hdr=options.transport[1]
    parameters.use_instance_atlas=false;parameters.light_cap=info.light_cap
    var sample:Dictionary={"version":entry.source_version,"highlighted":group_input.highlighted,"material":entry.material,
        "shader":entry.material.shader,"binding_revision":entry.source_binding_revision,"seconds":null,"visibility":sampled.scenery_value}
    sample.make_read_only()
    var output:Dictionary={"sample":sample,"input":{"shader":info.output,"parameters":parameters,"binding":options.transport,
        "capped":info.capped,"quad_size":value.mesh_size}}
    var prepared:Dictionary=_binding_shell(entry,sampled,source,output,group_input,options.basis,options.screen_size)
    prepared.erase("entry") # Installed only after removing the owning entry's packet field.
    prepared.private_static=true;prepared.crop_key=crop_key
    group_input.parameters.make_read_only()
    # A non-floor static source has one receiving row whose group key is
    # already final: its material, its seeded visibility and no support mask.
    # Building that material here keeps it off the planner after construction.
    if not info.dynamic and not info.water and not GroundReceiving.eligible(entry.placement):
        var visibility:float=sampled.scenery_value
        var group:Dictionary=Delta.static_group(group_input,[entry.material.get_instance_id(),visibility,"",0],visibility,0)
        group.material.get_rid()
        prepared.static_group=group
    Delta.realize_output(output)
    prepared.capture=Delta.private_source_capture(prepared)
    return prepared

func adopt_private_environment_binding(entry:Dictionary,packet:Dictionary,world:Node)->Dictionary:
    if packet.is_empty():return {}
    entry.erase("static_atlas_packet")
    var sampled:Dictionary=packet.snapshot;sampled.node=entry.node
    entry.scenery_value=sampled.scenery_value
    var source:Dictionary=packet.source;source.entry=entry;source.snapshot=sampled
    # This is the sole actual native identity capture. The descriptor already
    # owns quad, crop, uniforms and geometry; no source readback is required.
    source.geometry[0]=entry.node.global_transform
    packet.entry=entry
    var input:Dictionary=packet.group_input;input.entry=entry
    if packet.has("static_group"):packet.static_group.entry=entry
    var output:Dictionary=packet.output
    input.make_read_only()
    packet.receiver_parent=projection_root;output.private_node=true
    crop_cache[packet.crop_key]=source.crop
    _link_private_source(packet,entry)
    return packet

static func _link_private_source(prepared:Dictionary,entry:Dictionary)->void:
    if not prepared.has("capture"):return
    var source:Dictionary=prepared.capture
    source.entry=entry;source.proof.entry=entry
    # Late actor texture operands change only this private source's delivery
    # version. They have already been written to its receiving/output material.
    source.proof.version=entry.source_version
    source.proof.binding_revision=entry.source_binding_revision

func actor_resource_options(world:Node)->Dictionary:
    # Scene-owner shader/transport capture; the worker receives only selected
    # immutable values and strong resources, never an atlas or live Node.
    var shader:Shader=preload("res://modular.gdshader")
    var roles:Dictionary={}
    for role in ["body","shadow"]:
        var info:Dictionary=_entry_info({"material":{"shader":shader},"role":role,"placement":{"kind":"actor"}})
        roles[role]={"info":info,"receiver_names":_receiver_parameter_names(shader,info.shader),
            "output_names":_output_parameter_names(shader,info.output)}
    return {"roles":roles,"basis":Basis(world.camera.global_basis.x,-world.camera.global_basis.y,world.camera.global_basis.z).transposed(),
        "screen_size":world.get_viewport().get_visible_rect().size,"received":viewport.get_texture(),
        "transport":[viewport.get_instance_id(),_uses_hdr(),light_cap]}

static func private_actor_binding(entry:Dictionary,mesh:QuadMesh,options:Dictionary)->Dictionary:
    # Dynamics prepare material resources only. Actual receiver geometry,
    # projection, layout, actor pose and clocks remain the current sampler's.
    var selected:Dictionary=options.roles[entry.role];var info:Dictionary=selected.info
    var crop:Dictionary={"pixels":Rect2i(Vector2i.ZERO,Vector2i(entry.cell)),"uv":Vector4(0,0,1,1)}
    var signature:Array=[entry.cell,"",[],info.shader,entry.material.get_instance_id(),[]]
    var source:Dictionary={"info":info,"signature":signature,"geometry":[],"crop":crop,"same":false,
        "ground_version":0,"row_indices":{},"packets":{},"by_row":{},"receivers":{},"addresses":{}}
    var sampled:Dictionary=entry.duplicate()
    var output_material:=ShaderMaterial.new();output_material.shader=info.output
    if info.capped:
        for name in selected.output_names:output_material.set_shader_parameter(name,entry.source_parameters.get(name))
        output_material.set_shader_parameter("use_instance_visibility",false)
        output_material.set_shader_parameter("source_quad_size",mesh.size)
        output_material.set_shader_parameter("current_visibility",1.0)
        output_material.set_shader_parameter("highlighted",entry.source_parameters.get("highlighted"))
    output_material.set_shader_parameter("received",options.received)
    output_material.set_shader_parameter("received_is_encoded_hdr",options.transport[1])
    output_material.set_shader_parameter("use_instance_atlas",false)
    output_material.set_shader_parameter("light_cap",info.light_cap)
    output_material.get_rid()
    var output:Dictionary={"received_material":output_material,"binding":options.transport,"private_node":true}
    var prepared:Dictionary=_binding_shell(entry,sampled,source,output,{},options.basis,options.screen_size)
    prepared.erase("entry")
    prepared.material_only=true;prepared.private_actor=true
    prepared.receiver_names=selected.receiver_names;prepared.output_names=selected.output_names
    var key:Array=[entry.material.get_instance_id(),1.0,"",0]
    var group:Dictionary=Delta.new_group({},crop,1.0,key,info,0)
    var material:ShaderMaterial=group.material
    for name in selected.receiver_names:material.set_shader_parameter(name,entry.source_parameters.get(name))
    material.set_shader_parameter("use_instance_visibility",false)
    material.set_shader_parameter("source_crop",crop.uv)
    material.set_shader_parameter("atlas_cell_size",Vector2(crop.pixels.size))
    material.set_shader_parameter("receiver_visibility",1.0)
    material.set_shader_parameter("ground_join_mask",0)
    material.set_shader_parameter("store_irradiance",info.capped)
    material.set_shader_parameter("world_to_canvas",options.basis)
    material.set_shader_parameter("actual_scene_viewport_size",options.screen_size)
    material.set_shader_parameter("highlighted",entry.source_parameters.get("highlighted"))
    material.get_rid()
    group.merge({"version":entry.source_version,"source_shader":info.source,"source_material":entry.material,
        "target_material":material,"target_shader":info.shader,"binding_revision":entry.source_binding_revision,
        "capped":info.capped,"seconds":null,"highlighted":entry.source_parameters.get("highlighted")},true)
    prepared.groups[key]=group
    prepared.capture=Delta.private_source_capture(prepared)
    return prepared

func adopt_private_actor_binding(entry:Dictionary,prepared:Dictionary,world:Node,filled_textures:Array=[])->Dictionary:
    # Only the installed native identities and late-arriving texture operands
    # are adopted. The worker's full material initialization is never replayed.
    prepared.entry=entry;prepared.snapshot.node=entry.node
    prepared.source.entry=entry;prepared.source.snapshot=prepared.snapshot
    prepared.version=entry.source_version;prepared.binding_revision=entry.source_binding_revision
    var highlighted=SourceMaterial.value(entry,"highlighted")
    for group in prepared.groups.values():
        group.entry=entry;group.source_id=entry.node.get_instance_id()
        for name in filled_textures:
            if prepared.receiver_names.has(name):group.material.set_shader_parameter(name,SourceMaterial.value(entry,name))
        group.version=entry.source_version;group.binding_revision=entry.source_binding_revision
    var output:Dictionary=prepared.output;var material:ShaderMaterial=output.received_material
    if prepared.info.capped:
        for name in filled_textures:
            if prepared.output_names.has(name):material.set_shader_parameter(name,SourceMaterial.value(entry,name))
        output.received_source_key={"binding_revision":entry.source_binding_revision,"version":entry.source_version,
            "output":material,"output_shader":material.shader,"quad_size":entry.node.mesh.size}
        output.received_style={"output":material,"visibility":1.0,"highlighted":highlighted,"seconds":null}
    var sample:Dictionary={"version":entry.source_version,"highlighted":highlighted,"material":entry.material,
        "shader":entry.material.shader,"binding_revision":entry.source_binding_revision,"seconds":null,"visibility":1.0}
    sample.make_read_only();output.sample=sample
    prepared.snapshot.source_version=entry.source_version;prepared.snapshot.source_binding_revision=entry.source_binding_revision
    prepared.receiver_parent=projection_root
    prepared.material_proof={"binding_revision":entry.source_binding_revision,
        "quad":[entry.node.mesh,entry.node.mesh.size,entry.node.mesh.center_offset],"output":material,"output_shader":material.shader,
        "transport":output.binding}
    _link_private_source(prepared,entry)
    return prepared

func prepare_source_binding(entry:Dictionary,snapshot:Dictionary,world:Node,dynamic_materials:bool=false,target_options:Dictionary={},profile_preparation:bool=false)->Dictionary:
    # The snapshot has only private future floor arrays. Native materials/nodes
    # are read here; all receiving resources created below remain candidate-owned.
    var setup_started:int=Time.get_ticks_usec() if profile_preparation else 0
    var source:Dictionary=Delta._source(self,entry,world,snapshot,target_options)
    if source.crop.is_empty():return {}
    var actor:bool=entry.placement.kind=="actor" and entry.has("actor_layer")
    var flame:bool=entry.material.shader==FlameSource
    if source.info.dynamic and (not dynamic_materials or not (actor or flame)):return {}
    var sampled:Dictionary=entry.duplicate() if snapshot.is_empty() else snapshot.duplicate()
    sampled.erase("received_source_key");sampled.erase("received_style")
    # Publication consumes the sample that produced these private materials.
    # Actual source/hover/visibility changes after preparation remain distinct
    # and reach receiving materials through the ordinary scalar sync path.
    var highlighted=SourceMaterial.value(entry,"highlighted")
    var seconds=SourceMaterial.value(entry,"displayed_time_seconds") if source.info.water else null
    var visibility:float=sampled.get("scenery_value",1.0)
    var sample={"version":sampled.get("source_version",0),"highlighted":highlighted,
        "material":entry.material,"shader":entry.material.shader,"binding_revision":entry.source_binding_revision,
        "seconds":seconds,"visibility":visibility}
    sample.make_read_only()
    var group_capture_started:int=Time.get_ticks_usec() if profile_preparation else 0
    var group_input:Dictionary={} if source.info.dynamic else capture_group_input(entry,source.info,source.crop,
        Basis(world.camera.global_basis.x,-world.camera.global_basis.y,world.camera.global_basis.z).transposed(),world.get_viewport().get_visible_rect().size)
    var group_capture_usec:int=Time.get_ticks_usec()-group_capture_started if profile_preparation else 0
    var output:Dictionary={"sample":sample}
    var output_started:int=Time.get_ticks_usec() if profile_preparation else 0
    var deferred_output:bool=not source.info.dynamic and target_options.get("defer_static_output",false)
    var encoded:bool=source.info.light_cap>0.0 and not source.info.normals_visible
    var material:ShaderMaterial
    if deferred_output:
        var parameters:Dictionary={}
        var mesh:QuadMesh=entry.node.multimesh.mesh if entry.has("batch_rows") else entry.node.mesh
        if source.info.capped:
            parameters=selected_parameters(entry.source_parameters,_output_parameter_names(entry.material.shader,source.info.output))
            parameters.use_instance_visibility=entry.has("batch_rows");parameters.source_quad_size=mesh.size
            parameters.current_visibility=visibility;parameters.highlighted=highlighted
        parameters.received=viewport.get_texture();parameters.received_is_encoded_hdr=encoded
        parameters.use_instance_atlas=entry.has("batch_rows");parameters.light_cap=source.info.light_cap
        output.input={"shader":source.info.output,"parameters":parameters,"binding":[viewport.get_instance_id(),encoded,source.info.light_cap],
            "capped":source.info.capped,"quad_size":mesh.size}
    else:
        sampled.received_material=ShaderMaterial.new();sampled.received_material.shader=source.info.output
        if source.info.capped:_copy_output_source(sampled)
        output.received_material=sampled.received_material;material=sampled.received_material
        material.set_shader_parameter("received",viewport.get_texture())
        material.set_shader_parameter("received_is_encoded_hdr",encoded)
        material.set_shader_parameter("use_instance_atlas",entry.has("batch_rows"))
        material.set_shader_parameter("light_cap",source.info.light_cap)
        output.binding=[viewport.get_instance_id(),encoded,source.info.light_cap]
        if source.info.capped:
            material.set_shader_parameter("current_visibility",visibility)
            material.set_shader_parameter("highlighted",highlighted)
            if source.info.water:material.set_shader_parameter("displayed_time_seconds",seconds)
            output.received_style={"output":material,"visibility":visibility,"highlighted":highlighted,"seconds":seconds}
        if sampled.has("received_source_key"):output.received_source_key=sampled.received_source_key
    var prepared:Dictionary=_binding_shell(entry,sampled,source,output,group_input,
        Basis(world.camera.global_basis.x,-world.camera.global_basis.y,world.camera.global_basis.z).transposed(),world.get_viewport().get_visible_rect().size)
    prepared.profile_preparation=profile_preparation
    prepared.phase_usec={"source_setup":output_started-setup_started-group_capture_usec,"receiver_capture":group_capture_usec,
        "output_materials":Time.get_ticks_usec()-output_started} if profile_preparation else {}

    if source.info.dynamic:
        # No receiver, geometry, region or address is prepared for dynamics.
        # Only private copies of its exact already-bound material are retained.
        var mesh:QuadMesh=entry.node.mesh
        prepared.material_only=true;prepared.receiver_parent=projection_root
        prepared.material_proof={"binding_revision":entry.source_binding_revision,
            "quad":[mesh,mesh.size,mesh.center_offset],
            "output":material,"output_shader":material.shader,
            "transport":[viewport.get_instance_id(),encoded,source.info.light_cap]}
        _prepare_source_group(prepared,float(entry.get("scenery_value",1.0)),"",0)
    return prepared

func dynamic_prepared_miss(entry:Dictionary,prepared:Dictionary,reason:String)->bool:
    # Current-sync diagnostics only; no readiness/resource ownership changes.
    if not last_reconcile_phases.has("dynamic_prepared_misses"):last_reconcile_phases.dynamic_prepared_misses={}
    var counts:Dictionary=last_reconcile_phases.dynamic_prepared_misses
    counts[reason]=counts.get(reason,0)+1
    if not last_reconcile_phases.has("dynamic_prepared_samples"):last_reconcile_phases.dynamic_prepared_samples=[]
    if last_reconcile_phases.dynamic_prepared_samples.size()<8:
        last_reconcile_phases.dynamic_prepared_samples.append({"id":entry.get("id",entry.placement.get("id","")),
            "reason":reason,"prepared_version":prepared.get("version",-1),"version":entry.get("source_version",-1),
            "binding_revision":entry.get("source_binding_revision",-1),
            "preparation":entry.get("atlas_preparation",{})})
    return false

func prepared_dynamic_materials_match(prepared:Dictionary,entry:Dictionary)->bool:
    var proof:Dictionary=prepared.get("material_proof",{})
    if proof.is_empty() or not prepared.get("material_only",false):return dynamic_prepared_miss(entry,prepared,"no_material_proof")
    var mesh:QuadMesh=entry.node.mesh
    if not is_same(prepared.entry,entry) or proof.binding_revision!=entry.source_binding_revision:return dynamic_prepared_miss(entry,prepared,"source_binding_revision")
    if proof.quad!=[mesh,mesh.size,mesh.center_offset]:return dynamic_prepared_miss(entry,prepared,"quad")
    if proof.output!=prepared.output.received_material or proof.output_shader!=prepared.output.received_material.shader:return dynamic_prepared_miss(entry,prepared,"output_material_or_shader")
    if proof.transport!=[viewport.get_instance_id(),_uses_hdr(),light_cap]:return dynamic_prepared_miss(entry,prepared,"transport")
    for group in prepared.groups.values():
        if group.target_material!=group.material or group.target_shader!=group.material.shader:return dynamic_prepared_miss(entry,prepared,"receiving_group")
    return true

func publish_render_options(options: Dictionary) -> void:
    # The caller has preflighted all replacement bindings against the old mode.
    # Keep that admitted delta owner while changing the existing native target.
    var next_cap: float = options.light_cap
    var next_normals: bool = options.normals_visible
    if light_cap==next_cap and normals_visible==next_normals: return
    light_cap=next_cap; normals_visible=next_normals
    viewport.use_hdr_2d=_uses_hdr()
    ambient.color=Color(AMBIENT_INTENSITY,AMBIENT_INTENSITY,AMBIENT_INTENSITY,1.0).linear_to_srgb() if _uses_hdr() else Color(AMBIENT_INTENSITY,AMBIENT_INTENSITY,AMBIENT_INTENSITY,1.0)
    admission_stamp.clear(); output_stamp.clear(); revision+=1

func _prepare_source_group(prepared:Dictionary,visibility:float,receiver_id:String,join_mask:int)->Dictionary:
    var entry:Dictionary=prepared.entry
    var info:Dictionary=prepared.info
    var key:Array=[entry.material.get_instance_id(),visibility,receiver_id if info.water else "",join_mask]
    if not prepared.groups.has(key):
        var phase_started:int=Time.get_ticks_usec() if prepared.profile_preparation else 0
        var group:Dictionary=_new_group(prepared.snapshot,prepared.source.crop,visibility,key,info,join_mask)
        _copy_parameters(group)
        group.material.set_shader_parameter("world_to_canvas",prepared.basis)
        group.material.set_shader_parameter("actual_scene_viewport_size",prepared.screen_size)
        group.highlighted=SourceMaterial.value(entry,"highlighted")
        group.material.set_shader_parameter("highlighted",group.highlighted)
        group.entry=entry
        prepared.groups[key]=group
        if prepared.profile_preparation:prepared.phase_usec.group_materials=prepared.phase_usec.get("group_materials",0)+Time.get_ticks_usec()-phase_started
    return prepared.groups[key]

func prepare_source_row(prepared:Dictionary,row:Dictionary,parent:Node,supports:Dictionary,visibility:float,final_spec:Dictionary={},projection_packet:Dictionary={},selected_group:Dictionary={},private_draw:CanvasDraw=null)->void:
    var entry:Dictionary=prepared.entry
    var spec:Dictionary=final_spec
    if spec.is_empty():
        spec=Delta._spec(prepared.source,row)
        spec.join_mask=GroundReceiving.mask(row,supports)
    prepared.specs[spec.row_id]=spec
    var info:Dictionary=prepared.info
    var group:Dictionary=selected_group if not selected_group.is_empty() else _prepare_source_group(prepared,visibility,spec.id,spec.join_mask)
    var row_started:int=Time.get_ticks_usec() if prepared.profile_preparation else 0
    # Retained rows also receive private geometry. Publication replaces their
    # record in place; it never constructs or projects a missing receiver.
    if prepared.receivers.has(spec.id):
        dispose_receiver(prepared.receivers[spec.id])
    var index:int=prepared.snapshot.ground_indices[spec.row_id] if entry.has("batch_rows") else -1
    var receiver:Dictionary={"id":spec.id,"entry":entry,"index":index,"group":group,
        "crop":spec.crop,"position":Vector2i.ZERO,"projection":[],"visibility":visibility,"bounds":Rect2(),
        "row_id":spec.row_id,"row":row,"water":info.water,"source_geometry":spec.source_geometry,
        "source_material":spec.material_id,"receiving_shader":info.shader,"join_mask":spec.join_mask,
        "dynamic":info.dynamic,"spec":spec}
    if info.dynamic:
        receiver.node=prepare_receiver_node(parent);receiver.node.material=group.material
    else:
        receiver.draw=private_draw if private_draw!=null else new_static_draw(group.material)
        receiver.draw.attach(projection_root.get_canvas_item())
    if prepared.profile_preparation:prepared.phase_usec.row_creation=prepared.phase_usec.get("row_creation",0)+Time.get_ticks_usec()-row_started
    var projection_started:int=Time.get_ticks_usec() if prepared.profile_preparation else 0
    if not projection_packet.is_empty():
        receiver.projection=projection_packet.identity;set_receiver_transform(receiver,projection_packet.transform)
        receiver.world_origin=projection_packet.world_origin;receiver.bounds=projection_packet.bounds
        if receiver.water and selected_group.is_empty():receiver.group.material.set_shader_parameter("receiver_world_origin",receiver.world_origin)
        prepared.projected_packet_rows+=1
    else:
        # Dynamic/explicit isolated callers retain their current scene sample.
        _project_entry(receiver,prepared.snapshot,prepared.basis)
    if prepared.profile_preparation:prepared.phase_usec.projection_apply=prepared.phase_usec.get("projection_apply",0)+Time.get_ticks_usec()-projection_started
    prepared.created_rows+=1
    prepared.receivers[spec.id]=receiver

func adopt_source_binding(prepared:Dictionary)->bool:
    if prepared.has("receiver_parent"):
        if not is_instance_valid(prepared.receiver_parent) or prepared.receiver_parent!=projection_root:
            return false
    else:
        # Existing callers can still prepare under their own hidden parent.
        for receiver in prepared.receivers.values():
            if receiver.has("draw"):
                if receiver.draw.batch==null:receiver.draw.attach(projection_root.get_canvas_item())
            else:receiver.node.reparent(projection_root,false)
    var entry:Dictionary=prepared.entry
    prepared_source_bindings[entry.node.get_instance_id()]=prepared
    # Direct-parent receivers need no native tree mutation at publication.
    # Only _visibility can show them after their actual entry is admitted.
    return true

func prepare_receiver_node(parent: Node) -> Sprite2D:
    # An invisible, unassigned shell. No atlas address, material, projection or
    # future state enters the displayed atlas during world preparation.
    var node = Sprite2D.new()
    node.texture=white; node.centered=false
    node.region_enabled=true; node.region_filter_clip_enabled=false
    node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; node.visible=false
    parent.add_child(node)
    return node

func new_static_draw(material:ShaderMaterial)->CanvasDraw:
    var draw=CanvasDraw.new()
    draw.initialize(white,white.get_rid(),material,material.get_rid(),Transform2D.IDENTITY,Rect2(),0)
    draw.attach(projection_root.get_canvas_item())
    return draw

func receiver_kind(receiver:Dictionary,dynamic:bool,material:ShaderMaterial)->void:
    # The explicit complete planner can recycle a retired cell for a source of
    # another kind. Recycle its cell, never a static RID as a dynamic Node.
    if dynamic and receiver.has("draw"):
        dispose_receiver(receiver);receiver.erase("draw")
        receiver.node=prepare_receiver_node(projection_root);receiver.node.material=material
    elif not dynamic and receiver.has("node"):
        dispose_receiver(receiver);receiver.erase("node");receiver.draw=new_static_draw(material)

static func receiver_handle(receiver:Dictionary):
    return receiver.draw if receiver.has("draw") else receiver.node

static func receiver_material(receiver:Dictionary)->ShaderMaterial:
    return receiver.draw.material if receiver.has("draw") else receiver.node.material

static func set_receiver_material(receiver:Dictionary,value:ShaderMaterial)->void:
    if receiver.has("draw"):receiver.draw.set_material(value)
    elif receiver.node.material!=value:receiver.node.material=value

static func receiver_transform(receiver:Dictionary)->Transform2D:
    return receiver.draw.transform if receiver.has("draw") else receiver.node.transform

func receiver_global_transform(receiver:Dictionary)->Transform2D:
    return projection_root.global_transform*receiver.draw.transform if receiver.has("draw") else receiver.node.global_transform

static func set_receiver_transform(receiver:Dictionary,value:Transform2D)->void:
    if receiver.has("draw"):receiver.draw.set_transform(value)
    else:receiver.node.transform=value

static func set_receiver_region(receiver:Dictionary,value:Rect2)->void:
    if receiver.has("draw"):receiver.draw.set_region(value)
    else:receiver.node.region_rect=value

static func set_receiver_rank(receiver:Dictionary,value:int)->void:
    if receiver.has("draw"):receiver.draw.set_rank(value)
    else:receiver.node.z_index=value

static func receiver_visible(receiver:Dictionary)->bool:
    return receiver.draw.visible if receiver.has("draw") else receiver.node.visible

static func set_receiver_visible(receiver:Dictionary,value:bool)->void:
    if receiver.has("draw"):receiver.draw.set_visible(value)
    else:receiver.node.visible=value

static func dispose_receiver(receiver:Dictionary,immediate:bool=false)->void:
    if receiver.has("draw"):receiver.draw.dispose()
    elif is_instance_valid(receiver.get("node")):
        if immediate:receiver.node.free()
        else:receiver.node.queue_free()

func adopt_prepared_receivers(entry: Dictionary, nodes: Array, prepared_parent: Node = null) -> bool:
    if not is_instance_valid(entry.node):return false
    if prepared_parent!=null and (not is_instance_valid(prepared_parent) or prepared_parent!=projection_root):return false
    var id: int=entry.node.get_instance_id()
    if prepared_receiver_sources.has(id):return false
    for node in nodes:
        if not is_instance_valid(node) or (prepared_parent!=null and node.get_parent()!=prepared_parent):return false
    for node in nodes:
        if node.get_parent()!=projection_root:node.reparent(projection_root,false)
    entry.atlas_receiver_shells=nodes
    prepared_receiver_sources[id]=entry
    return true

func _release_prepared_receivers() -> void:
    for entry in prepared_receiver_sources.values():
        for node in entry.atlas_receiver_shells:
            if not is_instance_valid(node):continue
            if not prepared_cleanup.is_empty():prepared_cleanup.unused.append({"node":node})
            else:node.queue_free()
        entry.erase("atlas_receiver_shells")
    prepared_receiver_sources.clear()
    if not prepared_cleanup.is_empty():
        Delta.retire_candidate(prepared_cleanup,prepared_delta,prepared_source_bindings,true)
        prepared_cleanup.blocked=false
        prepared_delta={};prepared_source_bindings={};prepared_cleanup={}
    else:
        # Direct atlas fixtures have no WorldPreparation retirement owner.
        prepared_delta={}
        for prepared in prepared_source_bindings.values():
            for receiver in prepared.receivers.values():
                dispose_receiver(receiver)
        prepared_source_bindings.clear()

func _make_receiver(spec: Dictionary, group: Dictionary, index: int) -> Dictionary:
    var prepared:Dictionary=prepared_source_bindings.get(spec.source_id,{})
    if prepared.get("accepted",false) and prepared.receivers.has(spec.id):
        var receiver:Dictionary=prepared.receivers[spec.id]
        prepared.receivers.erase(spec.id)
        receiver.group=group;receiver.index=index
        set_receiver_material(receiver,group.material)
        last_reconcile_phases.prepared_receiver_bindings=last_reconcile_phases.get("prepared_receiver_bindings",0)+1
        return receiver
    var shells: Array=spec.entry.get("atlas_receiver_shells",[])
    var receiver:Dictionary={"id":spec.id,"entry":spec.entry,"index":index,"group":group,
        "crop":spec.crop,"position":Vector2i.ZERO,"projection":[],"visibility":-1.0,"bounds":Rect2()}
    if spec.info.dynamic or not shells.is_empty():
        if shells.is_empty():receiver.node=prepare_receiver_node(projection_root)
        else:
            receiver.node=shells.pop_back()
            last_reconcile_phases.prepared_receiver_nodes=last_reconcile_phases.get("prepared_receiver_nodes",0)+1
        receiver.node.material=group.material
    else:receiver.draw=new_static_draw(group.material)
    # Cells never overlap. This groups canvas calls within the same light range.
    set_receiver_rank(receiver,group.rank%1024)
    return receiver

func floor_address_token(entry: Dictionary) -> Array:
    # Capture on the scene thread only after this exact floor version has been
    # addressed. Worker copies may retain old addresses, never native resources.
    if not delta_ready or not entry.has("batch_rows"): return []
    var id: int=entry.node.get_instance_id()
    var source: Dictionary=entry_specs.get(id,{})
    if source.is_empty() or not is_same(source.entry,entry) or source.ground_version!=entry.get("ground_version",0): return []
    return [get_instance_id(),repack_count,id,source.ground_version]

func _publish_addresses(floor_receivers: Dictionary, changed_outputs: Array) -> void:
    var target=Vector2(viewport.size)
    for receiver in changed_outputs:
        var origin=Vector2(receiver.position)/target
        var size=Vector2(receiver.crop.pixels.size)/target
        var output: ShaderMaterial=receiver.entry.received_material
        output.set_shader_parameter("source_crop",receiver.crop.uv)
        output.set_shader_parameter("atlas_region",Vector4(origin.x,origin.y,size.x,size.y))
    var rewritten=0
    var packet_reads=0; var packet_reads_skipped=0; var rows_checked=0; var rows_preserved=0
    var prepared_compare_usec:int=0;var prepared_upload_usec:int=0;var prepared_uploads:int=0
    for floor in floor_receivers.values():
        var entry: Dictionary=floor.entry
        var output: ShaderMaterial=entry.received_material
        var crop: Dictionary=floor.crop if floor.has("crop") else floor.receivers[0].crop
        if not floor.get("region_prepared",false):
            output.set_shader_parameter("source_crop",crop.uv)
            output.set_shader_parameter("atlas_cell_size",Vector2(crop.pixels.size)/target)
        rows_preserved+=int(floor.get("preserved_rows",0))
        if floor.has("prepared"):
            var prepared:Dictionary=floor.prepared
            entry.ground_packets=prepared.packets
            entry_specs[entry.node.get_instance_id()].packets=prepared.snapshots
            var compare_started:int=Time.get_ticks_usec()
            var changed:bool=entry.ground_buffer!=prepared.buffer
            prepared_compare_usec+=Time.get_ticks_usec()-compare_started
            if changed:
                var upload_started:int=Time.get_ticks_usec()
                entry.ground_buffer=prepared.buffer;entry.node.multimesh.buffer=prepared.buffer
                prepared_upload_usec+=Time.get_ticks_usec()-upload_started;prepared_uploads+=1
            rows_preserved+=prepared.count
            last_reconcile_phases.prepared_address_rows=last_reconcile_phases.get("prepared_address_rows",0)+prepared.count
            continue
        var buffer: PackedFloat32Array=entry.ground_buffer
        var buffer_changed=false
        var source:Dictionary=entry_specs[entry.node.get_instance_id()]
        var snapshots: Dictionary=source.packets
        # Replace the address directory before writing: a pending worker may
        # still borrow the previous immutable directory.
        source.addresses=source.get("addresses",{}).duplicate()
        var repair_indices: bool=floor.get("repair_indices",false)
        # GroundData.prepare appends exactly the same data into its row packet
        # and aggregate buffer. This certifies equality, not freshness: compare
        # against the atlas address before skipping the duplicate packet read.
        var coherent: bool=floor.get("coherent_addresses",false)
        for receiver in floor.receivers:
            rows_checked+=1
            if repair_indices:
                receiver.index=entry.ground_indices[receiver.row_id]
            var pixel: Vector2i=receiver.position
            source.addresses[str(entry.batch_rows[receiver.index].id)]={"position":pixel,"index":receiver.index}
            var x=pixel.x%1024; var y=pixel.y%1024; var high=(pixel.x/1024)+8*(pixel.y/1024)
            var offset: int=receiver.index*20
            var changed: bool=buffer[offset+17]!=x or buffer[offset+18]!=y or buffer[offset+19]!=high
            if changed:
                buffer[offset+17]=x; buffer[offset+18]=y; buffer[offset+19]=high
                buffer_changed=true; rewritten+=1
            elif coherent:
                packet_reads_skipped+=1
                continue
            var row_id: String=receiver.row_id if repair_indices else entry.batch_rows[receiver.index].id
            var packet: Dictionary=entry.ground_packets[row_id]
            var data: PackedFloat32Array=packet.data
            packet_reads+=1
            if coherent or data[17]!=x or data[18]!=y or data[19]!=high:
                data[17]=x; data[18]=y; data[19]=high; packet.data=data
                if not snapshots.has(row_id): snapshots[row_id]={}
                snapshots[row_id].data=data.duplicate()
        if buffer_changed:
            entry.ground_buffer=buffer; entry.node.multimesh.buffer=buffer
    last_reconcile_phases.address_rows_checked=rows_checked
    last_reconcile_phases.address_rows_preserved=rows_preserved
    last_reconcile_phases.address_rows_rewritten=rewritten
    last_reconcile_phases.address_batches=floor_receivers.size()
    last_reconcile_phases.address_packet_reads=packet_reads
    last_reconcile_phases.address_packet_reads_skipped=packet_reads_skipped
    last_reconcile_phases.prepared_address_index_updates=0
    last_reconcile_phases.prepared_address_buffer_compare_ms=prepared_compare_usec/1000.0
    last_reconcile_phases.prepared_address_buffer_upload_ms=prepared_upload_usec/1000.0
    last_reconcile_phases.prepared_address_buffer_uploads=prepared_uploads


func prepare_output_region(output:Dictionary,source:Dictionary,positions:Dictionary,target:Vector2)->void:
    var entry:Dictionary=source.entry
    var floor:bool=entry.has("batch_rows")
    var position:Vector2i=Vector2i.ZERO
    if not floor:
        var id:String=str(entry.node.get_instance_id())+":source"
        position=positions[id] if positions.has(id) else source.receivers["source"].position
    prepare_output_region_values(output,floor,source.crop,position,target)

static func prepare_output_region_values(output:Dictionary,floor:bool,crop:Dictionary,position:Vector2i,target:Vector2)->void:
    # Explicit numeric operands and a private output material only. Integer
    # floor addresses retain their prepared packet; growth changes UVs only.
    var material:ShaderMaterial=output.received_material
    material.set_shader_parameter("source_crop",crop.uv)
    if floor:
        material.set_shader_parameter("atlas_cell_size",Vector2(crop.pixels.size)/target)
    else:
        var origin:Vector2=Vector2(position)/target
        var size:Vector2=Vector2(crop.pixels.size)/target
        material.set_shader_parameter("atlas_region",Vector4(origin.x,origin.y,size.x,size.y))
    output.region_target=target

func _refresh_normalized_addresses(prepared:Dictionary={}) -> void:
    # Append growth preserves all integer pixel addresses and source geometry.
    # The output's normalized region/cell size is the only retained binding
    # dependent on viewport height; do not reread/reupload unchanged floor data.
    var target=Vector2(viewport.size)
    var updated=0
    for source in entry_specs.values():
        var entry: Dictionary=source.entry
        if prepared.has(entry.node.get_instance_id()):continue
        var output: ShaderMaterial=entry.received_material
        if entry.has("batch_rows"):
            output.set_shader_parameter("atlas_cell_size",Vector2(source.crop.pixels.size)/target)
        else:
            var receiver: Dictionary=source.receivers["source"]
            var origin=Vector2(receiver.position)/target
            var size=Vector2(receiver.crop.pixels.size)/target
            output.set_shader_parameter("atlas_region",Vector4(origin.x,origin.y,size.x,size.y))
        updated+=1
    last_reconcile_phases.resize_output_regions=updated

func _reconcile(world: Node) -> bool:
    var phase = Time.get_ticks_usec()
    last_reconcile_phases={}
    var key: Array = []
    var entries: Array = []
    var geometry: Dictionary = {}
    var information: Dictionary = {}
    var signatures: Dictionary = {}
    var entry_changed=false
    for entry in world.entries:
        if not is_instance_valid(entry.node) or entry.node.is_queued_for_deletion() or not entry.has("cell"): continue
        entries.append(entry)
        var info=_entry_info(entry)
        var id: int = entry.node.get_instance_id()
        information[id]=info
        if entry_specs.has(id) and (not is_same(entry_specs[id].entry,entry) or not entry.has("received_material") or entry_specs[id].get("output")!=entry.get("received_material")): entry_changed=true
        if not info.dynamic:
            var mesh: QuadMesh = entry.node.multimesh.mesh if entry.has("batch_rows") else entry.node.mesh
            geometry[id]=[entry.node.global_transform,mesh.size,mesh.center_offset]
        # Animated sources retain a full cell; frame rectangles are copied by
        # source_version in sync(), not a change to receiver membership.
        var record: Dictionary={} if info.dynamic else entry.get("record",{})
        var signature=[entry.cell,record.get("path",""),record.get("rect",[]),info.shader,entry.material.get_instance_id(),geometry.get(id,[])]
        signatures[id]=signature
        key.append([id,entry.get("ground_version",0),signature])
    last_reconcile_phases.members_ms=(Time.get_ticks_usec()-phase)/1000.0
    var screen_size = Vector2i(world.get_viewport().get_visible_rect().size)
    var resize_needed: bool = screen_size.x>viewport.size.x or screen_size.y>viewport.size.y
    if key==membership and not resize_needed and not entry_changed: return true
    phase=Time.get_ticks_usec()
    var candidate=_candidate_specs(entries,information,geometry,signatures,world)
    if not candidate.ok: return false
    var specs: Array=candidate.specs
    var next_members: Dictionary=candidate.members
    var indices: Dictionary=candidate.indices
    last_reconcile_phases.specs_reused=candidate.reused
    last_reconcile_phases.specs_ms=(Time.get_ticks_usec()-phase)/1000.0
    var repack: bool = next_members!=layout_members or resize_needed
    var plan = {}
    if repack:
        var started = Time.get_ticks_usec()
        plan=_layout_additions(specs,next_members,Vector2i(screen_size.x,maxi(viewport.size.y,screen_size.y)))
        last_pack_ms=(Time.get_ticks_usec()-started)/1000.0
        if not plan.ok:
            _issue(plan.error); return false
    phase=Time.get_ticks_usec()
    var dimensions_changed: bool=repack and plan.size!=viewport.size
    var address_floors={}; var changed_outputs: Array=[]
    var dirty_floors={}
    for id in candidate.entries:
        if dimensions_changed or not entry_specs.has(id) or not is_same(entry_specs[id].entry,candidate.entries[id].entry) or not candidate.entries[id].entry.has("received_material") or entry_specs[id].get("output")!=candidate.entries[id].entry.get("received_material") or candidate.entries[id].entry.received_material.shader!=information[id].output or entry_specs[id].ground_version!=candidate.entries[id].ground_version: dirty_floors[id]=true
    var kept = {}; var next: Array = []; var used_groups = {}; var reusable: Array = []
    var entry_groups: Dictionary = {}
    for receiver in receivers:
        kept[receiver.id]=receiver
        if not next_members.has(receiver.id): reusable.append(receiver)
    var binding_reused := 0
    for spec in specs:
        var index: int=indices[spec.id]
        var receiver: Dictionary = kept[spec.id] if kept.has(spec.id) else {}
        var relocated: bool=repack and plan.positions.has(spec.id)
        if not receiver.is_empty() and (receiver.has("spec") and is_same(receiver.spec,spec)) and not relocated:
            kept.erase(spec.id); receiver.index=index
            used_groups[receiver.group.id]=true
            if dirty_floors.has(spec.source_id):
                if index>=0:
                    if not address_floors.has(spec.source_id): address_floors[spec.source_id]={"entry":spec.entry,"receivers":[]}
                    address_floors[spec.source_id].receivers.append(receiver)
                else: changed_outputs.append(receiver)
            next.append(receiver); binding_reused+=1
            continue
        var retained: bool = not receiver.is_empty() and ((receiver.has("spec") and is_same(receiver.spec,spec)) or (is_same(receiver.entry,spec.entry) and receiver.crop==spec.crop and receiver.get("source_material",0)==spec.material_id and receiver.get("receiving_shader")==spec.info.shader and receiver.get("join_mask",0)==spec.join_mask))
        if retained:
            # A prepared floor can change row indices or a few transforms while
            # retaining its original native source/material. No rebind is needed
            # for the other thousands of receiver cells.
            kept.erase(spec.id)
            receiver.index=index
            used_groups[receiver.group.id]=true
            binding_reused+=1
        else:
            var visibility: float = spec.entry.scenery_values[index] if index>=0 else float(spec.entry.get("scenery_value",1.0))
            if not entry_groups.has(spec.source_id): entry_groups[spec.source_id]={}
            var choices: Dictionary = entry_groups[spec.source_id]
            var style_key = [visibility,spec.join_mask,spec.id if spec.info.water else ""]
            var group: Dictionary = choices.get(style_key,{})
            if group.is_empty():
                group=_group(spec.entry,spec.crop,visibility,spec.id,spec.info,spec.join_mask)
                choices[style_key]=group
            used_groups[group.id]=true
            if receiver.is_empty():
                if reusable.is_empty(): receiver=_make_receiver(spec,group,index)
                else:
                    receiver=reusable.pop_back(); kept.erase(receiver.id); receiver.id=spec.id
            else: kept.erase(spec.id)
            receiver.entry=spec.entry; receiver.index=index; receiver.crop=spec.crop; receiver.group=group
            if receiver.get("dynamic",spec.info.dynamic)!=spec.info.dynamic:receiver_kind(receiver,spec.info.dynamic,group.material)
            receiver.dynamic=spec.info.dynamic; receiver.water=spec.info.water
            receiver.source_material=spec.material_id; receiver.receiving_shader=spec.info.shader
            set_receiver_material(receiver,group.material)
            receiver.visibility=visibility
            receiver.join_mask=spec.join_mask
        if receiver.get("source_geometry",[])!=spec.source_geometry or receiver.projection.is_empty():
            receiver.projection=[]
            if not receiver.dynamic: projection_dirty.append(receiver)
        receiver.source_geometry=spec.source_geometry
        if relocated:
            var next_position: Vector2i = plan.positions[spec.id]
            var region=Rect2(Vector2(next_position),Vector2(receiver.crop.pixels.size))
            if receiver.get("region",Rect2())!=region:
                set_receiver_region(receiver,region); receiver.region=region
            receiver.position=next_position
        receiver.spec=spec
        if index>=0:
            if relocated: dirty_floors[spec.source_id]=true
            if dirty_floors.has(spec.source_id):
                if not address_floors.has(spec.source_id): address_floors[spec.source_id]={"entry":spec.entry,"receivers":[]}
                address_floors[spec.source_id].receivers.append(receiver)
        elif relocated or dirty_floors.has(spec.source_id):
            changed_outputs.append(receiver)
        next.append(receiver)
    # All dimensions were validated before any published state changed.
    for receiver in kept.values(): dispose_receiver(receiver)
    for id in groups.keys():
        if not used_groups.has(id): groups.erase(id)
    var rank = 0
    for group in groups.values(): group.rank=rank; rank+=1
    for receiver in next:
        var z: int = receiver.group.rank%1024
        if receiver.get("rank",-1)!=z: set_receiver_rank(receiver,z); receiver.rank=z
    receivers=next; membership=key; layout_members=next_members
    entry_specs=candidate.entries; published_supports=candidate.supports
    static_receivers=[]; dynamic_receivers=[]
    for receiver in receivers:
        (dynamic_receivers if receiver.dynamic else static_receivers).append(receiver)
    if repack:
        viewport.size=plan.size; packed_pixels=plan.pixels; shelf_cursor=plan.cursor; revision+=1; repack_count+=1
        last_reconcile_phases.layout_mode="full" if plan.full else "append"
    last_reconcile_phases.receivers_ms=(Time.get_ticks_usec()-phase)/1000.0
    last_reconcile_phases.bindings_reused=binding_reused
    phase=Time.get_ticks_usec()
    var transport=[viewport.get_texture(),_uses_hdr(),light_cap]
    var transport_changed: bool=transport!=transport_stamp
    var output_updates=0
    for id in candidate.entries:
        if not transport_changed and not dirty_floors.has(id): continue
        var entry: Dictionary=candidate.entries[id].entry
        var output_shader: Shader=information[id].output
        output_updates+=1
        var new_output: bool = not entry.has("received_material")
        if new_output:
            var output = ShaderMaterial.new(); output.shader=output_shader
            entry.received_material=output
        if entry.received_material.shader!=output_shader:
            entry.received_material.shader=output_shader
            entry.erase("received_source_key")
        entry.received_material.set_shader_parameter("received",transport[0])
        entry.received_material.set_shader_parameter("use_instance_atlas",entry.has("batch_rows"))
        entry.received_material.set_shader_parameter("received_is_encoded_hdr",transport[1])
        entry.received_material.set_shader_parameter("light_cap",light_cap)
        if entry.node.material_override!=entry.received_material: entry.node.material_override=entry.received_material
        entry_specs[entry.node.get_instance_id()].output=entry.received_material
        output_changed(entry)
    transport_stamp=transport
    last_reconcile_phases.output_bindings=output_updates
    last_reconcile_phases.output_bind_ms=(Time.get_ticks_usec()-phase)/1000.0
    var address_started=Time.get_ticks_usec()
    # A prepared floor publication can replace its packed buffer while retaining
    # exactly the same tile IDs. Restore addresses even when no repack occurred.
    for id in address_floors.keys():
        if not dirty_floors.has(id): address_floors.erase(id)
    _publish_addresses(address_floors,changed_outputs)
    last_reconcile_phases.floor_address_ms=(Time.get_ticks_usec()-address_started)/1000.0
    last_reconcile_phases.addresses_ms=(Time.get_ticks_usec()-phase)/1000.0
    last_reconcile_phases.projected_receivers=projection_dirty.size()
    return true

func _project(receiver: Dictionary, force: bool) -> void:
    var entry: Dictionary = receiver.entry
    var mesh: QuadMesh = entry.node.multimesh.mesh if receiver.index>=0 else entry.node.mesh
    var identity: Array = [entry.get("ground_version",0),entry.node.global_transform,mesh.size,mesh.center_offset] if receiver.index>=0 else [entry.node.global_transform,mesh.size,mesh.center_offset]
    if not force and identity==receiver.projection: return
    _project_entry(receiver,entry,plane_basis)

func _project_entry(receiver:Dictionary,entry:Dictionary,basis:Basis)->void:
    if receiver.index>=0:receiver.index=entry.ground_indices[receiver.row_id]
    var mesh:QuadMesh=entry.node.multimesh.mesh if receiver.index>=0 else entry.node.mesh
    receiver.projection=[entry.get("ground_version",0),entry.node.global_transform,mesh.size,mesh.center_offset] if receiver.index>=0 else [entry.node.global_transform,mesh.size,mesh.center_offset]
    var transform: Transform3D
    if receiver.index>=0:
        var data: PackedFloat32Array = entry.ground_packets[receiver.row_id].data if entry.get("sparse_ground",false) else entry.ground_buffer
        var i: int = 0 if entry.get("sparse_ground",false) else receiver.index*20
        transform=entry.node.global_transform*Transform3D(Basis(Vector3(data[i],data[i+4],data[i+8]),Vector3(data[i+1],data[i+5],data[i+9]),Vector3(data[i+2],data[i+6],data[i+10])),Vector3(data[i+3],data[i+7],data[i+11]))
    else: transform=entry.node.global_transform
    var local = mesh.center_offset+Vector3(-mesh.size.x*.5,mesh.size.y*.5,0)
    var projected_origin:Vector3=basis*(transform*local)
    var projected_x:Vector3=basis*(transform.basis*Vector3(mesh.size.x,0,0))
    var projected_y:Vector3=basis*(transform.basis*Vector3(0,-mesh.size.y,0))
    var origin=Vector2(projected_origin.x,projected_origin.y)
    var axis_x=Vector2(projected_x.x,projected_x.y)
    var axis_y=Vector2(projected_y.x,projected_y.y)
    var crop: Vector4 = receiver.crop.uv
    origin+=axis_x*crop.x+axis_y*crop.y
    axis_x*=crop.z; axis_y*=crop.w
    set_receiver_transform(receiver,Transform2D(axis_x/receiver.crop.pixels.size.x,axis_y/receiver.crop.pixels.size.y,origin))
    if receiver.water:
        receiver.group.material.set_shader_parameter("receiver_world_origin",transform.origin)
    receiver.world_origin=transform.origin
    receiver.bounds=Rect2(origin,Vector2.ZERO).expand(origin+axis_x).expand(origin+axis_y).expand(origin+axis_x+axis_y)

func style_changed(entry: Dictionary, row_id: String = "source") -> void:
    var source_id: int=entry.node.get_instance_id()
    style_dirty[str(source_id)+":"+row_id]=true
    material_dirty[source_id]=true

func visibility_changed(entry: Dictionary) -> void:
    visibility_dirty[entry.node.get_instance_id()]=true

func capture_projection(world:Node)->Dictionary:
    var camera:Camera3D=world.camera
    var screen:Vector2=world.get_viewport().get_visible_rect().size
    var zero:Vector2=camera.unproject_position(Vector3.ZERO)
    return {"key":[camera.global_transform,camera.size,screen],"screen":Rect2(Vector2.ZERO,screen),
        "transform":Transform2D(camera.unproject_position(camera.global_basis.x)-zero,
            camera.unproject_position(-camera.global_basis.y)-zero,zero)}

func projection_key(world:Node)->Array:
    return [world.camera.global_transform,world.camera.size,world.get_viewport().get_visible_rect().size]

func output_changed(entry: Dictionary) -> void:
    # These final3D fields are owned by wall selection/coverage and output
    # creation, not Canvas receiving. Consume only after painter/mask publication.
    if is_instance_valid(entry.node): output_dirty[entry.node.get_instance_id()]=entry

func _visibility(receiver: Dictionary, screen: Rect2) -> bool:
    if receiver.get("cull_owner",{}).get("frame",-1)==sample_serial:
        # Candidate receivers stayed disabled while private. The source's live
        # visibility and camera were matched once at this publication; known
        # hidden rows need no native getter/intersection or visibility write.
        var prepared_shown:bool=receiver.cull_shown
        if prepared_shown:
            _activate_receiver_batch(receiver)
            set_receiver_visible(receiver,true)
        receiver.view_visible=prepared_shown
        return prepared_shown
    var shown: bool = receiver.entry.node.is_visible_in_tree() and (plane_to_screen*receiver.bounds).intersects(screen)
    if shown:_activate_receiver_batch(receiver)
    if receiver_visible(receiver)!=shown: set_receiver_visible(receiver,shown)
    receiver.view_visible=shown
    return shown

func _activate_receiver_batch(receiver:Dictionary)->void:
    if receiver.has("draw") and receiver.draw.batch!=null and not receiver.draw.batch.adopted:
        # Only the admitted scene sampler can expose a private parent. This
        # also covers the ordinary delta fallback and camera-cull repair.
        receiver.draw.batch.adopt(projection_root.get_canvas_item())

func _style(receiver: Dictionary) -> void:
    var entry: Dictionary = receiver.entry
    if receiver.index>=0: receiver.index=entry.ground_indices[receiver.row_id]
    var visibility: float = entry.scenery_values[receiver.index] if receiver.index>=0 else float(entry.get("scenery_value",1.0))
    if visibility==receiver.visibility: return
    var previous: Dictionary=receiver.group
    receiver.group=_group(entry,receiver.crop,visibility,receiver.id,{},receiver.get("join_mask",0))
    if delta_ready and not is_same(previous,receiver.group):
        if not receiver.group.has("users"): receiver.group.users=0
        receiver.group.users+=1
        Delta.drop_group(self,previous)
    set_receiver_material(receiver,receiver.group.material)
    receiver.rank=receiver.group.rank%1024
    set_receiver_rank(receiver,receiver.rank)
    receiver.visibility=visibility
    if receiver.water:
        receiver.group.material.set_shader_parameter("receiver_world_origin",receiver.get("world_origin",Vector3.ZERO))

func sync(world: Node, published: Array = [], styles: Array = [], changes: Dictionary = {}, tracked_receivers: bool = false) -> void:
    sample_serial+=1
    var started = Time.get_ticks_usec()
    projection_dirty=[]
    last_reconcile_phases={}
    last_delta_fallback=""
    last_pack_ms=0.0
    var screen_size = world.get_viewport().get_visible_rect().size
    # Published scene stamps are not received SDK revisions: queued preparation
    # never enters this atlas. Exact dynamic native IDs catch same-count outfits.
    var moving: Array = []
    if not published.is_empty():
        for entry in world.actor_entries:
            if entry.has("cell") and is_instance_valid(entry.node) and not entry.node.is_queued_for_deletion(): moving.append([entry.node.get_instance_id(),entry.cell])
        for entry in world.fixture_entries:
            if entry.has("cell") and is_instance_valid(entry.node) and not entry.node.is_queued_for_deletion(): moving.append([entry.node.get_instance_id(),entry.cell])
    var reconcile: bool = published.is_empty() or published!=admission_stamp or moving!=dynamic_members or world.entries.size()!=known_entry_count or screen_size.x>viewport.size.x or screen_size.y>viewport.size.y
    var phase = Time.get_ticks_usec()
    var full_reconcile=false
    if reconcile:
        var applied: bool=not changes.is_empty() and Delta.reconcile(self,world,changes)
        if not applied and require_prepared_publication:
            # A production cut cannot discover a replacement scene, including
            # initial/full, dynamic membership and viewport growth changes.
            # The owning world reports the invariant fault and halts its clock.
            output_admission_failed=true
            errors=["Prepared lighting publication failed: "+last_delta_fallback]
            _release_prepared_receivers()
            last_sync_ms=(Time.get_ticks_usec()-started)/1000.0
            return
        if not applied:
            # Explicit initial/global rebuilds retain their complete planner.
            # Full admission/mode/packing fallback derives them from sources.
            var previous_specs=entry_specs
            var previous_membership=membership
            entry_specs={}; membership=[]; delta_ready=false
            applied=_reconcile(world)
            if applied:
                Delta.rebuild(self,int(changes.get("serial",-1)))
                full_reconcile=true
                output_full=true
            else:
                entry_specs=previous_specs; membership=previous_membership
        if not last_delta_fallback.is_empty(): last_reconcile_phases.delta_fallback=last_delta_fallback
        if not applied:
            _release_prepared_receivers()
            output_admission_failed=true
            for issue in errors:
                if issue not in world.presentation_errors: world.presentation_errors.append(issue)
            last_sync_ms=(Time.get_ticks_usec()-started)/1000.0
            return
        output_admission_failed=false
        admission_stamp=published.duplicate(); dynamic_members=moving; known_entry_count=world.entries.size()
    var release_started:int=Time.get_ticks_usec()
    _release_prepared_receivers()
    last_reconcile_phases.prepared_release_ms=(Time.get_ticks_usec()-release_started)/1000.0
    last_reconcile_ms=(Time.get_ticks_usec()-phase)/1000.0
    var camera: Camera3D = world.camera
    var key = [camera.global_transform,camera.size,screen_size]
    var camera_changed: bool = key!=canvas_key
    var screen_size_changed: bool = canvas_key.size()<3 or canvas_key[2]!=screen_size
    canvas_key=key
    var basis = Basis(camera.global_basis.x,-camera.global_basis.y,camera.global_basis.z).transposed()
    var basis_changed: bool = basis!=plane_basis
    plane_basis=basis
    if camera_changed:
        # One affine native parent handles all orthographic pan/zoom. The
        # shader reads MODEL_MATRIX for receiving, then bypasses it for storage.
        var zero = camera.unproject_position(Vector3.ZERO)
        plane_to_screen=Transform2D(camera.unproject_position(camera.global_basis.x)-zero,camera.unproject_position(-camera.global_basis.y)-zero,zero)
        projection_root.transform=plane_to_screen
    phase=Time.get_ticks_usec()
    var restyle: bool = reconcile or styles.is_empty() or styles!=visibility_stamp
    # The producer stamp is [world generation, quarter, sight revision, wall
    # mode]. Modes/views keep the complete path; a sight-only revision can use
    # exact per-row notifications even when geometry did not change.
    var mode_changed: bool=styles.size()<4 or visibility_stamp.size()<4
    if not mode_changed: mode_changed=styles[1]!=visibility_stamp[1] or styles[3]!=visibility_stamp[3]
    var full_receivers: bool=not tracked_receivers or not receivers_tracked or full_reconcile or mode_changed
    var style_checks=0
    if restyle or not style_dirty.is_empty():
        if full_receivers:
            for receiver in static_receivers:
                if not is_same(prepared_style_receivers.get(receiver.id,{}),receiver):_style(receiver); style_checks+=1
        else:
            for id in style_dirty:
                if not receiver_index.has(id): continue
                var receiver: Dictionary=receiver_index[id]
                if receiver.dynamic: continue
                if not is_same(prepared_style_receivers.get(receiver.id,{}),receiver):_style(receiver); style_checks+=1
        visibility_stamp=styles.duplicate()
    for receiver in dynamic_receivers: _style(receiver)
    last_reconcile_phases.prepared_style_receivers=prepared_style_receivers.size()
    last_reconcile_phases.style_receivers_checked=style_checks
    last_reconcile_phases.style_ms=(Time.get_ticks_usec()-phase)/1000.0
    phase=Time.get_ticks_usec()
    # Tracked static owners notify exact source changes. Dynamic actor/flame
    # clocks still poll each frame. Pan/zoom belongs to projection_root; only a
    # changed screen size or basis changes these source-material uniforms.
    # New groups and admitted patches mark themselves.
    var material_sources: Dictionary=material_dirty.duplicate()
    if full_receivers or screen_size_changed or basis_changed:
        for id in source_groups: material_sources[id]=true
    else:
        for receiver in dynamic_receivers: material_sources[receiver.spec.source_id]=true
    var material_sources_updated=0
    var material_sources_unchanged=0
    var material_sample_versions=0
    for id in material_sources:
        if not entry_specs.has(id) or source_groups[id].is_empty(): continue
        var source: Dictionary=entry_specs[id]
        var entry: Dictionary=source.entry
        var material: ShaderMaterial=entry.material
        var version: int=entry.get("source_version",0)
        var highlighted=SourceMaterial.value(entry,"highlighted")
        var seconds=SourceMaterial.value(entry,"displayed_time_seconds") if source.info.water else null
        var visibility: float=entry.get("scenery_value",1.0)
        # Source versions own animation/tint changes; highlight and water time
        # have independent owners. A new visibility/join variant still needs its
        # first copy even if the source itself has not changed. Admission owns
        # material/output replacement and gives that source a fresh sync record;
        # unstamped callers use the complete planner. Avoid native resource
        # identity/shader queries for every unchanged source on every frame.
        if (not screen_size_changed and not basis_changed and not material_dirty.has(id) and source.get("synced",false)
            and source.sync_version==version and source.sync_highlighted==highlighted
            and source.sync_seconds==seconds and source.sync_visibility==visibility):
            material_sources_unchanged+=1
            continue
        material_sources_updated+=1
        var shader:Shader=material.shader
        # One source interval owns all receiving/output consumers. Sight/hover
        # and wall output changes are already delivered by their explicit
        # owners; advance that interval without reconstructing empty generic
        # parameter copies for every material group and the capped output.
        var sample_only:bool=false
        if source.get("synced",false) and source.get("sync_material")==material \
                and source.get("sync_shader")==shader and source.get("sync_binding_revision",-1)==entry.source_binding_revision:
            var sample_changes:Variant=SourceMaterial.changes_since(entry,source.sync_version)
            if sample_changes!=null:
                sample_only=true
                for name in sample_changes:
                    if not SAMPLE_PARAMETERS.has(name):sample_only=false;break
        for group in source_groups[id].values():
            group.info=source.info
            var binding_matches:bool=group.get("binding_revision",-1)==entry.source_binding_revision \
                and group.source_shader==shader and group.get("source_material")==material \
                and group.get("target_material")==group.material and group.get("target_shader")==group.material.shader
            var full_copy:bool=false
            if sample_only and binding_matches and group.version>=source.sync_version:
                group.version=version;material_sample_versions+=1
            elif group.version!=version or not binding_matches:
                full_copy=_copy_parameters(group,shader,binding_matches)
            if highlighted!=group.highlighted:
                group.material.set_shader_parameter("highlighted",highlighted); group.highlighted=highlighted
            if basis_changed or full_copy: group.material.set_shader_parameter("world_to_canvas",basis)
            if screen_size_changed or full_copy: group.material.set_shader_parameter("actual_scene_viewport_size",screen_size)
            if group.water and group.seconds!=seconds:
                group.material.set_shader_parameter("displayed_time_seconds",seconds); group.seconds=seconds
        var output: ShaderMaterial=entry.get("received_material") if source.info.capped else null
        if output!=null:
            _copy_output_source(entry,shader,int(source.sync_version) if sample_only else -1)
            var style: Dictionary=entry.received_style if entry.has("received_style") else {}
            if style.is_empty() or style.output!=output or style.visibility!=visibility or style.highlighted!=highlighted or style.seconds!=seconds:
                output.set_shader_parameter("current_visibility",visibility)
                output.set_shader_parameter("highlighted",highlighted)
                if source.info.water: output.set_shader_parameter("displayed_time_seconds",seconds)
                entry.received_style={"output":output,"visibility":visibility,"highlighted":highlighted,"seconds":seconds}
        source.synced=true
        source.sync_version=version; source.sync_highlighted=highlighted; source.sync_seconds=seconds
        source.sync_visibility=visibility
        source.sync_material=material;source.sync_shader=shader;source.sync_binding_revision=entry.source_binding_revision
        SourceMaterial.acknowledge(entry)
    material_dirty.clear()
    last_reconcile_phases.material_sources_checked=material_sources_updated+material_sources_unchanged
    last_reconcile_phases.material_sources_updated=material_sources_updated
    last_reconcile_phases.material_sources_unchanged=material_sources_unchanged
    last_reconcile_phases.material_sample_versions=material_sample_versions
    last_reconcile_phases.material_sync_ms=(Time.get_ticks_usec()-phase)/1000.0
    phase=Time.get_ticks_usec()
    var screen=Rect2(Vector2.ZERO,screen_size)
    if basis_changed:
        for receiver in static_receivers: _project(receiver,true)
    else:
        for receiver in projection_dirty: _project(receiver,true)
    var cull_checks=0
    if camera_changed or (full_receivers and (reconcile or restyle or not visibility_dirty.is_empty())):
        static_live_receivers=0
        for receiver in static_receivers:
            if _visibility(receiver,screen): static_live_receivers+=1
            cull_checks+=1
    else:
        for receiver in projection_dirty: cull_dirty[receiver.id]=true
        for source_id in visibility_dirty:
            if not entry_specs.has(source_id): continue
            for receiver in entry_specs[source_id].receivers.values(): cull_dirty[receiver.id]=true
        for id in cull_dirty:
            if not receiver_index.has(id): continue
            var receiver: Dictionary=receiver_index[id]
            if receiver.dynamic: continue
            var was_visible: bool=receiver.get("view_visible",false)
            var shown: bool=_visibility(receiver,screen)
            static_live_receivers+=int(shown)-int(was_visible)
            cull_checks+=1
    live_receivers=static_live_receivers
    for receiver in dynamic_receivers:
        _project(receiver,basis_changed)
        if _visibility(receiver,screen): live_receivers+=1
    last_reconcile_phases.cull_receivers_checked=cull_checks
    last_projection_ms=(Time.get_ticks_usec()-phase)/1000.0
    style_dirty.clear(); visibility_dirty.clear(); cull_dirty.clear(); prepared_style_receivers.clear()
    receivers_tracked=tracked_receivers
    last_sync_ms=(Time.get_ticks_usec()-started)/1000.0

func sync_output(world: Node, published: Array = [], tracked: bool = false) -> void:
    # Only after painter/mask publication. The original texture RID remains live
    # across mask redraws; source/material admissions invalidate this stamp.
    last_reconcile_phases.output_entries_checked=0
    if tracked and output_admission_failed: return
    var full: bool=not tracked or not output_tracked or output_full or published.is_empty() or output_stamp.is_empty()
    if not full and (published.size()<4 or output_stamp.size()<4 or published[1]!=output_stamp[1] or published[3]!=output_stamp[3]): full=true
    if not full and published==output_stamp and output_dirty.is_empty(): return
    # Legacy/manual callers retain the original stamp shortcut. Explicit dirty
    # notifications always win, including late mask writes in the same stamp.
    if not tracked and not published.is_empty() and published==output_stamp and output_dirty.is_empty(): return
    var pending: Dictionary=output_dirty
    output_dirty={}
    if output_full:
        # Successful complete admission also retires the preceding view's
        # queued owners. Failed admission never sets this flag.
        for id in pending.keys():
            if not entry_specs.has(id): pending.erase(id)
    if full:
        for entry in world.entries:
            if entry.has("received_material") and is_instance_valid(entry.node): pending[entry.node.get_instance_id()]=entry
    output_stamp=published.duplicate()
    output_tracked=tracked
    output_full=false
    for id in pending:
        var entry: Dictionary=pending[id]
        if not is_instance_valid(entry.node) or entry.node.is_queued_for_deletion(): continue
        if tracked:
            var admitted: Dictionary=entry_specs.get(id,{})
            if admitted.is_empty() or not is_same(admitted.entry,entry) or not entry.has("received_material") or admitted.get("output")!=entry.received_material:
                # A failed/rejected admission must not consume its pending
                # source writes. Successful binding replaces this exact owner.
                output_dirty[id]=entry
                continue
        if not entry.has("received_material"): continue
        last_reconcile_phases.output_entries_checked+=1
        var output: ShaderMaterial = entry.received_material
        output.render_priority=entry.material.render_priority
        if entry.has("wall_source"):
            for name in ["wall_opacity","wall_mask_enabled","wall_mask_id","wall_mask_texture"]:
                var value = SourceMaterial.value(entry,name)
                if output.get_shader_parameter(name)!=value: output.set_shader_parameter(name,value)

func close() -> void:
    _release_prepared_receivers()
    output_dirty.clear(); output_tracked=false; output_full=false; output_admission_failed=false
    var restored = {}
    for receiver in receivers:
        dispose_receiver(receiver)
        var entry: Dictionary = receiver.entry
        if not is_instance_valid(entry.node): continue
        var id: int = entry.node.get_instance_id()
        if restored.has(id): continue
        restored[id]=true
        entry.node.material_override=entry.material
        if entry.has("batch_rows"):
            var buffer: PackedFloat32Array = entry.ground_buffer
            for index in entry.batch_rows.size():
                buffer[index*20+17]=0; buffer[index*20+18]=0; buffer[index*20+19]=0
                var packet: Dictionary = entry.ground_packets[entry.batch_rows[index].id]
                var data: PackedFloat32Array = packet.data
                data[17]=0; data[18]=0; data[19]=0; packet.data=data
            entry.ground_buffer=buffer; entry.node.multimesh.buffer=buffer
    receivers.clear(); static_receivers.clear(); dynamic_receivers.clear(); groups.clear(); membership.clear(); layout_members.clear(); crop_cache.clear()
    entry_specs.clear(); published_supports.clear(); shelf_cursor=Vector3i(1,1,0)
    receiver_index.clear(); support_owners.clear(); source_groups.clear(); material_dirty.clear(); delta_ready=false; delta_serial=-1
    style_dirty.clear(); visibility_dirty.clear(); cull_dirty.clear(); prepared_style_receivers.clear(); receivers_tracked=false
    static_live_receivers=0; live_receivers=0
    admission_stamp.clear(); visibility_stamp.clear(); dynamic_members.clear(); output_stamp.clear(); transport_stamp.clear(); canvas_key.clear(); known_entry_count=-1
    if is_instance_valid(viewport): viewport.queue_free()
    viewport=null
