extends RefCounted
## Exact authored source operands. This layer has no scene or texture ownership.
const Placement=preload("res://placement.gd")
const Catalog=preload("res://source_catalog.gd")
const EnvironmentMedia=preload("res://presentation/environment_media.gd")
const Order=preload("res://grid_order.gd")
const GroundReceiving=preload("res://presentation/ground_receiving.gd")

static func v2(value:Array)->Vector2:return Vector2(value[0],value[1])
static func v4(value:Array)->Vector4:return Vector4(value[0],value[1],value[2],value[3])
static func matrix3(rows:Array)->Basis:
    return Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2]))
static func matrix4(rows:Array)->Transform3D:return Transform3D(matrix3(rows),Vector3(rows[0][3],rows[1][3],rows[2][3]))

static func quad(row:Dictionary,record:Dictionary,quarter:int,camera_basis:Basis)->Dictionary:
    var cell:Vector2=v2(record.native_size);var pivot:Vector2=v2(record.pivot);var scale:float=record.scale
    var size:Vector2=cell*scale/Placement.PIXELS_PER_UNIT
    var center:=Vector3((cell.x*0.5-pivot.x)*scale/Placement.PIXELS_PER_UNIT,(pivot.y-cell.y*0.5)*scale/Placement.PIXELS_PER_UNIT,0)
    var origin:Vector2=Placement.project(v2(row.position),row.base_height_steps,quarter)
    var value:Dictionary={"cell":cell,"pivot":pivot,"scale":scale,"mesh_size":size,"mesh_center":center,
        "aabb":AABB(center-Vector3(size.x*0.5,size.y*0.5,0),Vector3(size.x,size.y,0)),
        "position":Placement.contact(row),"basis":camera_basis,"screen_rect":Rect2(origin-pivot*scale,cell*scale)}
    if row.has("affine"):
        var affine:Array=row.affine;var a:=Vector2(affine[0],affine[1]);var b:=Vector2(affine[2],affine[3])
        if row.get("ground_projection",false):
            a=Placement.project(Placement.rotate_grid(Vector2(a.x/128+a.y/64,a.y/64-a.x/128),quarter),0,0)
            b=Placement.project(Placement.rotate_grid(Vector2(b.x/128+b.y/64,b.y/64-b.x/128),quarter),0,0)
        value.basis=camera_basis*Basis(Vector3(a.x,-a.y,0),Vector3(-b.x,b.y,0),Vector3(0,0,1))
        var bounds:=Rect2()
        for corner in [Vector2.ZERO,Vector2(cell.x,0),cell,Vector2(0,cell.y)]:
            var point:Vector2=origin+a*((corner-pivot)*scale).x+b*((corner-pivot)*scale).y
            bounds=Rect2(point,Vector2.ZERO) if corner==Vector2.ZERO else bounds.expand(point)
        value.screen_rect=bounds
    return value

static func describe(row:Dictionary,record:Dictionary,source_role:int,quarter:int,camera_basis:Basis,source_depth:bool,source_normals:bool)->Dictionary:
    if record.is_empty():return {"empty":true,"record":record,"visible":false,"position":Placement.contact(row),"basis":camera_basis}
    var value:Dictionary=quad(row,record,quarter,camera_basis)
    value.record=record;value.visible=not record.get("hidden",false);value.floor_group=record.get("flat_ground",false)
    var p:Dictionary={"source_tint":v4(row.get("tint",[1,1,1,1])),"colour_size":value.cell,
        "colour_rect":v4(record.get("rect",[0,0,value.cell.x,value.cell.y])),"door_leaf_partition":0,
        "has_component_geometry":false,"use_component_depth":false,"use_component_normals":false,
        "native_scene_enabled":false,"native_scene_plane":false,"use_floor_motifs":false,"wall_motif_face_count":0}
    var textures:Dictionary={"colour_texture":record.path}
    if record.has("floor_motifs") and source_role==1:
        p.merge(_floor_motif_parameters(row,record.floor_motifs),true)
    if source_role==1 and not record.get("wall_motif_faces",[]).is_empty():
        var wall:Dictionary=_wall_motif_parameters(record.wall_motif_faces)
        p.merge(wall.parameters,true);textures.merge(wall.textures,true)
        if wall.has("reason"):value.wall_residue_gap=wall.reason
    if source_role==3 or (source_role==1 and row.kind=="door"):
        var partition:Dictionary=record.get("door_partition",{})
        if partition.is_empty():
            if source_role==3:value.visible=false
        else:
            p.door_leaf_partition=-1 if source_role==3 else 1;textures.door_depth_texture=partition.path
            p.door_depth_rect=v4(partition.rect);p.door_depth_cell=v2(partition.cell);p.door_depth_range=v2(partition.range)
            p.door_depth_scale=partition.scale;p.door_depth_offset=partition.offset
            var origin:Vector2=Placement.project(v2(row.position),0,quarter)
            p.door_frame_depth=Placement.sort_contact(row,quarter).y-origin.y
    var selection:Dictionary={}
    for role in record.get("roles",[]):
        if role.role=="ground_shadow":selection=role.selection;break
    var shadow_pass:bool=source_role==0
    if shadow_pass and selection.is_empty() and not record.get("ground_equipment_shadow",false):value.visible=false
    p.source_unlit=shadow_pass or row.get("unlit",false);p.highlighted=false;p.use_selection=not selection.is_empty();p.invert_selection=not shadow_pass
    if not selection.is_empty():
        p.selection_kind=1 if selection.kind=="source_rgba" else 0
        if selection.kind=="source_rgba":
            p.rgba_min=v4(selection.bounds.minimum);p.rgba_max=v4(selection.bounds.maximum)
        elif selection.kind=="mask":
            var mask:Dictionary=selection.mask
            textures.selection_mask=mask.region.path;p.selection_rect=v4(mask.region.rect)
            p.selection_scale=v2(mask.sampling.scale);p.selection_offset=v2(mask.sampling.offset)
            var values:Array=[-1.0,-1.0,-1.0,-1.0]
            for i in range(mini(4,selection.values.size())):values[i]=selection.values[i]
            p.selection_values=v4(values)
    p.ground_receiver=GroundReceiving.eligible(row)
    p.has_geometry=record.has("geometry")
    if p.has_geometry:
        var g:Dictionary=record.geometry;var sampling:Dictionary=record.geometry_sampling
        textures.geometry_texture=record.geometry_region.path;textures.normal_texture=record.normal.region.path
        p.geometry_rect=v4(record.geometry_region.rect);p.normal_rect=v4(record.normal.region.rect)
        p.sample_scale=v2(sampling.scale);p.sample_offset=v2(sampling.offset);p.sample_center=v2(sampling.pixel_center)
        p.normal_scale=v2(record.normal.sampling.scale);p.normal_offset=v2(record.normal.sampling.offset)
        p.pixel_to_ray=matrix3(g.pixelToRayOrigin);p.ray_direction=Vector3(g.rayDirection[0],g.rayDirection[1],g.rayDirection[2])
        p.depth_range=v2(g.depthRange);p.source_to_local=matrix4(g.sourceToLocal);p.normal_to_local=matrix3(record.normal.normalToLocal)
        var world_basis:Basis=Basis(Vector3.UP,quarter*PI*0.5)*Basis.from_scale(Vector3(1,Placement.HEIGHT_UNIT,1))
        if g.basis=="object_local":
            world_basis=Basis(Vector3.UP,-["east","north","west","south"].find(row.get("orientation","east"))*PI/2)*Basis.from_scale(Vector3(1,Placement.HEIGHT_UNIT,1))
        p.local_to_world=Transform3D(world_basis,Placement.contact(row));p.local_normal_to_world=world_basis.inverse().transposed()
        p.use_source_depth=source_depth;p.use_source_normals=source_normals
        var receiver_to_quad:Transform3D=Transform3D(value.basis.inverse()*world_basis,Vector3.ZERO)*p.source_to_local
        var bounds:AABB=value.aabb
        for x in [0.0,float(record.geometry_region.rect[2])]:
            for y in [0.0,float(record.geometry_region.rect[3])]:
                for depth in g.depthRange:
                    var point:Vector3=p.pixel_to_ray*Vector3(x+sampling.pixel_center[0],y+sampling.pixel_center[1],1)+p.ray_direction*float(depth)
                    bounds=bounds.expand(receiver_to_quad*point)
        value.aabb=bounds
    var binding:Dictionary=record.get("component_binding",{})
    if not binding.is_empty():
        p.merge(binding.parameters,true);textures.merge(binding.textures,true)
        p.use_component_depth=source_depth;p.use_component_normals=source_normals
        var sheet:Vector2=v2(record.component_sheet_size);var rect:Vector4=p.colour_rect
        p.material_cell_size=value.cell;p.frame_uv=Vector4(rect.x/sheet.x,rect.y/sheet.y,rect.z/sheet.x,rect.w/sheet.y)
        p.native_scene_pivot=value.pivot;p.native_scene_enabled=source_depth
        # Apply the very same image-plane registration to the original optical
        # surface. Its ray-depth origin/range and encoding remain unchanged.
        var source_pivot:Vector2=v2(record.source_pivot)
        var units:float=binding.parameters.component_units
        p.native_scene_ground_height=float(binding.ground)*units-(value.pivot.y-source_pivot.y)*camera_basis.y.y*units
        var shift:=Vector3(source_pivot.x-value.pivot.x,value.pivot.y-source_pivot.y,0.)*units
        for point in binding.bounds:value.aabb=value.aabb.expand(point+shift)
    if record.has("ground_equipment_tint"):
        var tint:=Color(str(record.ground_equipment_tint))
        p.source_tint*=Vector4(tint.r,tint.g,tint.b,tint.a)
    value.parameters=p;value.texture_parameters=textures
    return value

## Bounded source sampling metadata, not a baked image. Compute the original
## integer hash on the CPU so negative coordinates and 64-bit products are not
## silently replaced by a shader's 32-bit hash. All raster sampling stays on GPU.
static func _motif_variation(x:int,y:int)->int:
    return posmod(((x+37)*73856093)^((y+19)*19349663),997)

static func _motif_floor_div(value:int,divisor:int)->int:
    var quotient:int=value/divisor
    return quotient-1 if value<0 and value%divisor!=0 else quotient

static func _motif_round_even(value:float)->int:
    var low:int=floori(value)
    return low if value-float(low)<.5 or (value-float(low)==.5 and low%2==0) else low+1

static func _floor_motif_parameters(row:Dictionary,profile:Dictionary)->Dictionary:
    var origin_x:int=int(row.position[0])*32-16
    var origin_y:int=int(row.position[1])*32-16
    var placements:=PackedVector4Array();placements.resize(16)
    var count:int=0
    for gx in range(_motif_floor_div(origin_x-55,48),_motif_floor_div(origin_x+32+55,48)+1):
        for gy in range(_motif_floor_div(origin_y-55,48),_motif_floor_div(origin_y+32+55,48)+1):
            var variant:int=_motif_variation(gx,gy)
            var left:int=_motif_round_even(float(gx*48+12-origin_x-35)+(float(variant)/997.-.5)*14.)
            placements[count]=Vector4(left,gy*48+12-origin_y-35,variant%4,0.);count+=1
    var noise:=PackedFloat32Array();noise.resize(144)
    var first_x:int=_motif_floor_div(origin_x,3)
    var first_y:int=_motif_floor_div(origin_y,3)
    for x in range(12):
        for y in range(12):noise[x*12+y]=2.+float(_motif_variation(first_x+x,first_y+y))/997.*4.
    var starts:=Vector4();var widths:=Vector4()
    for column in range(4):
        starts[column]=_motif_round_even(float(column)*float(profile.art_size[0])/4.)
        widths[column]=_motif_round_even(float(column+1)*float(profile.art_size[0])/4.)-starts[column]
    return {"use_floor_motifs":true,"floor_motif_count":count,"floor_motif_placements":placements,
        "floor_motif_noise":noise,"floor_motif_noise_phase":Vector2(posmod(origin_x,3),posmod(origin_y,3)),
        "floor_motif_columns":starts,"floor_motif_widths":widths,"floor_motif_height":_motif_round_even(float(profile.art_size[1])/4.),
        "floor_motif_neighbors":int(row.connected_neighbors),"floor_motif_opacity":float(profile.opacity)}

## Existing wall material receives the original source UV treatment. Bounds
## come from the supplied profile: at most two planes for each of two joined
## original boundaries, and six overlapping motifs in each80px wall field.
static func _wall_motif_parameters(faces:Array)->Dictionary:
    if faces.size()>4:return {"parameters":{},"textures":{},"reason":"wall_motif_source_plane_capacity"}
    var origins:=PackedVector4Array();origins.resize(4)
    var axes:=PackedVector4Array();axes.resize(4)
    var columns:=PackedVector4Array();columns.resize(4)
    var widths:=PackedVector4Array();widths.resize(4)
    var placements:=PackedVector4Array();placements.resize(24)
    var variants:=PackedFloat32Array();variants.resize(24)
    var counts:=Vector4();var heights:=Vector4();var reverse:=Vector4();var opacity:=Vector4()
    var textures:Dictionary={}
    for index in faces.size():
        var face:Dictionary=faces[index];var profile:Dictionary=face.profile;var plane:Dictionary=face.plane
        origins[index]=Vector4(plane.origin[0],plane.origin[1],0.,0.)
        axes[index]=Vector4(plane.across[0],plane.across[1],plane.down[0],plane.down[1])
        var lefts:=Vector4();var spans:=Vector4()
        for column in range(4):
            lefts[column]=_motif_round_even(float(column)*float(profile.art_size[0])/4.)
            spans[column]=_motif_round_even(float(column+1)*float(profile.art_size[0])/4.)-lefts[column]
        columns[index]=lefts;widths[index]=spans
        heights[index]=_motif_round_even(float(profile.art_size[1])/4.)
        reverse[index]=1. if face.reverse else 0.;opacity[index]=float(profile.opacity)
        textures["wall_motif_texture"+str(index)]=profile.path
        var origin:int=int(face.along)*64-40;var count:int=0
        for at in range(_motif_floor_div(origin-80,51),_motif_floor_div(origin+160,51)+1):
            var variant:int=_motif_variation(at,int(face.line_twice))
            var width:int=70+variant%37;var height:int=80+variant%100
            placements[index*6+count]=Vector4(_motif_round_even(float(at*51-origin)-float(width)*.5),192-height,width,height)
            variants[index*6+count]=variant%4;count+=1
        counts[index]=count
    return {"parameters":{"wall_motif_face_count":faces.size(),"wall_motif_origins":origins,"wall_motif_axes":axes,
        "wall_motif_columns":columns,"wall_motif_widths":widths,"wall_motif_heights":heights,
        "wall_motif_reverse":reverse,"wall_motif_opacity":opacity,"wall_motif_counts":counts,
        "wall_motif_placements":placements,"wall_motif_variants":variants},"textures":textures}

static func row_packet(row:Dictionary,quarter:int,camera_basis:Basis,cache:Dictionary,source_depth:bool,source_normals:bool)->Dictionary:
    # Fixture flames stay scene-owned; their static body uses this packet.
    if row.get("water_surface",false):return {"eligible":false}
    var source:Dictionary=row.duplicate()
    if source.has("views"):source.asset=source.views[Placement.pose(source.orientation,quarter)]
    var variants:Array=[source];variants.append_array(source.get("wall_members",[]))
    var records:Array=[];var frames:Array=[];var paths:Dictionary={}
    for variant in variants:
        var record:Dictionary=Catalog.environment(variant,quarter,cache)
        if record.has("water") or variant.get("water_surface",false):return {"eligible":false}
        records.append(record);EnvironmentMedia.record_paths(record,paths,cache)
        if variant.kind=="door":
            var frame:Dictionary=Catalog.door_frame(variant,quarter,cache);frames.append(frame);EnvironmentMedia.record_paths(frame,paths,cache)
        else:frames.append({})
    var entries:Array=[]
    for index in variants.size():
        var variant:Dictionary=variants[index]
        var record:Dictionary=records[index]
        var role:String=variant.get("sort_role",variant.kind if variant.kind in ["terrain","wall","cliff"] else "body")
        var shadow:=true
        var layers:Array=[];var base:int=int(variant.get("layer",0))*10
        if shadow:layers.append(["shadow",base,0])
        if variant.kind=="door":layers.append([role,base,3]);layers.append([role,base+1,2])
        layers.append([role,base+2,1])
        for layer in layers:
            var selected:Dictionary=frames[index] if layer[2]==2 else Catalog.environment_role(record,layer[2])
            var descriptor:Dictionary=describe(variant,selected,layer[2],quarter,camera_basis,source_depth,source_normals)
            var entry:Dictionary={"id":variant.id+":"+str(layer[1])+":"+layer[0],"placement":variant,"role":layer[0],
                "layer":layer[1],"source_role":layer[2],"mobile":false,"descriptor":descriptor}
            if variant.kind in ["wall","cliff"]:
                entry.wall_source=source;entry.wall_variant="joined" if variant.has("wall_members") else variant.id
                entry.wall_source_visible=descriptor.visible;entry.id+=":"+entry.wall_variant
                if not is_same(variant,source):descriptor.visible=false
            if variant.has("wall_members") and layer[0]!="shadow":
                var picks:Array=[]
                for member_index in source.wall_members.size():
                    var member:Dictionary=source.wall_members[member_index]
                    picks.append({"row":member,"record":records[member_index+1],"key":Order.key(member,"wall",layer[1],quarter)})
                picks.sort_custom(func(a,b):return Order.less(a.key,b.key) if a.key!=b.key else a.row.id<b.row.id)
                entry.wall_picks=picks
            entries.append(entry)
    paths.merge(EnvironmentMedia.world_media_paths(row,cache))
    return {"eligible":true,"entries":entries,"paths":paths}
