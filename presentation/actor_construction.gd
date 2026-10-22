extends RefCounted
## Native actor construction shared by displayed and unpublished world owners.
## Source selection is passive; this file owns no timeline or visibility gate.
const SourceMaterial=preload("res://presentation/source_material.gd")
const Catalog=preload("res://source_catalog.gd")
const Graphs=preload("res://animation/graphs.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Palette=preload("res://presentation/palette.gd")
const CharacterGeometry=preload("res://presentation/character_geometry.gd")
const Modular=preload("res://modular.gd")
const MODULAR_SHADER=preload("res://modular.gdshader")
const Placement=preload("res://placement.gd")
const QuadShapes=preload("res://presentation/quad_shapes.gd")

static func source_cache(cache:Dictionary)->Dictionary:
    var result:Dictionary=cache.duplicate()
    # Fixed-creature shadow availability is filled lazily by Characters.resolve.
    # Authoring documents and completed selector indexes remain immutable.
    if result.has("__creature_shadow_rigs"):result.__creature_shadow_rigs=result.__creature_shadow_rigs.duplicate()
    return result

static func matches(row:Dictionary,other:Dictionary)->bool:
    return not other.is_empty() and row.rig==other.rig and row.appearance==other.appearance and row.equipment_layers==other.equipment_layers

static func loadouts(samples:Dictionary,components:Array)->Dictionary:
    var result:Dictionary={}
    for id in samples:result[id]={"loadout":samples[id].get("visual_loadout"),"effects":[]}
    for component in components:
        if component.kind not in ["sprite_layer","appearance_layer"]:continue
        var id:String=component.actor_uuid
        if not result.has(id):result[id]={"loadout":null,"effects":[]}
        var effect:Dictionary=component.layer.duplicate();effect.component_id=component.id
        result[id].effects.append(effect)
    return result

static func actor_with_loadout(actor:Dictionary,loadouts:Dictionary)->Dictionary:
    if not loadouts.has(actor.uuid):return actor
    var result:Dictionary=actor.duplicate()
    var selected:Dictionary=loadouts[actor.uuid]
    if selected.loadout!=null:result.visual_loadout=selected.loadout
    result.presentation_layers=selected.effects
    return result

static func prepare_neutral(entry:Dictionary,textures:Dictionary,resources:Dictionary)->void:
    # Only unpublished new layers call this. Current sampling compares the full
    # value and replaces every binding if a condition or hit is active at admission.
    var value:Dictionary=Conditions.material(entry.placement.id,[])
    SourceMaterial.apply(entry,Conditions.parameters(value,textures,resources))

static func graph(owner:Node,rig:Dictionary,templates:Array)->Node:
    return Graphs.character(owner,rig,true,templates)

static func layer(owner:Node,row:Dictionary,rig:Dictionary,source:Dictionary,index:int)->Dictionary:
    owner.add_entry(row,"shadow" if source.slot=="shadow" else "body",index,MODULAR_SHADER)
    var entry:Dictionary=owner.entries.back()
    entry.actor_layer=source
    SourceMaterial.set_parameter(entry,"layer_alpha",source.alpha)
    SourceMaterial.set_parameter(entry,"shadow",source.slot=="shadow")
    owner._light_entry(entry)
    SourceMaterial.set_parameter(entry,"tint",Modular.rgb(source.tint))
    var shape:Dictionary=layer_shape(rig,128.0/owner.rig_config.TILE_W*row.scale)
    entry.node.mesh=QuadShapes.mesh(shape.mesh_size,shape.mesh_center)
    entry.material.set_shader_parameter("source_quad_size",shape.mesh_size)
    entry.node.custom_aabb=entry.node.mesh.get_aabb()
    entry.cell=shape.cell;entry.pivot=shape.pivot;entry.scale=shape.scale
    owner.update_bounds(entry)
    return entry

static func layer_shape(rig:Dictionary,scale:float)->Dictionary:
    var cell:=Vector2(rig.cell_width,rig.cell_height)
    var pivot:=Vector2(cell.x*.5,cell.y-rig.origin_y_from_ground)
    return {"cell":cell,"pivot":pivot,"scale":scale,"mesh_size":cell*scale/Placement.PIXELS_PER_UNIT,
        "mesh_center":Vector3((cell.x*.5-pivot.x)*scale/Placement.PIXELS_PER_UNIT,(pivot.y-cell.y*.5)*scale/Placement.PIXELS_PER_UNIT,0.0)}

static func prepare_binding(rig:Dictionary,layer:Dictionary,path:String,cache:Dictionary,depth:bool,normals:bool,profile:String,scale:float,scale_x:float)->Dictionary:
    CharacterGeometry.BodySources.prepare_descriptor(path,layer.slot,cache)
    var header:Dictionary=CharacterGeometry.BodySources.header(path,cache)
    return {"path":path,"sheet_size":Vector2(header.get("width",0),header.get("height",0)),
        "geometry":CharacterGeometry.prepare_binding(path,layer.slot,cache,depth,normals,profile,scale,scale_x)}

static func realize_binding(owner:Node,value:Dictionary)->Dictionary:
    var result:Dictionary=value.duplicate();result.sheet=owner.textures.get(value.path)
    var geometry:Dictionary=value.geometry.duplicate();geometry.parameters=value.geometry.parameters.duplicate()
    for parameter in geometry.textures:
        var path:String=geometry.textures[parameter]
        if not owner.textures.has(path):return {}
        geometry.parameters[parameter]=owner.textures[path]
    if result.sheet==null:return {}
    result.geometry=geometry
    return result

static func source_parameter_names()->Dictionary:
    # Scene-owner capture only. Workers never mutate the shared shader index.
    if not SourceMaterial.declared_parameters.has(MODULAR_SHADER):
        var names:Dictionary={}
        for row in MODULAR_SHADER.get_shader_uniform_list():names[StringName(row.name)]=null
        SourceMaterial.declared_parameters[MODULAR_SHADER]=names
    return SourceMaterial.declared_parameters[MODULAR_SHADER]

static func bind_source_values(entry:Dictionary,rig:Dictionary,path:String,layer_frame:int,layer_facing:String,
        sheet:Texture2D,sheet_size:Vector2,textures:Dictionary,resources:Dictionary,parameters:Dictionary)->void:
    # This is the one source-uniform algorithm for sampled actors and private
    # resource preparation. It needs no Node, graph, texture getter or clock.
    var layer:Dictionary=entry.actor_layer
    var palette:Dictionary=layer.get("effect",{}).get("palette",{}) if layer.get("effect",{}).get("palette")!=null else {}
    var frame_key:Array=[sheet,layer_frame,layer_facing,textures.get(resources.get(palette.get("noiseSheet"),""))]
    entry.texture_path=path
    if entry.get("bound_frame_key",[])!=frame_key:
        entry.bound_frame_key=frame_key
        SourceMaterial.set_parameter(entry,"sheet",sheet)
        SourceMaterial.set_parameter(entry,"material_cell_size",Vector2(rig.cell_width,rig.cell_height))
        SourceMaterial.set_parameter(entry,"frame_uv",Vector4(layer_frame*rig.cell_width/sheet_size.x,rig.facing_rows[layer_facing]*rig.cell_height/sheet_size.y,float(rig.cell_width)/sheet_size.x,float(rig.cell_height)/sheet_size.y))
    SourceMaterial.apply(entry,Palette.parameters(layer,layer_facing,layer_frame,textures,resources))
    if not parameters.is_read_only() or not is_same(entry.get("bound_condition_parameters"),parameters):
        SourceMaterial.apply(entry,parameters)
        entry.bound_condition_parameters=parameters if parameters.is_read_only() else null
    if entry.has("geometry_camera_origins"):CharacterGeometry.apply_facing(entry,layer_facing)

static func bind_source(owner:Node,entry:Dictionary,rig:Dictionary,path:String,layer_frame:int,layer_facing:String,parameters:Dictionary)->void:
    # Pose selection, animation clocks, transforms and visibility remain in Play.
    var layer:Dictionary=entry.actor_layer
    var row:Dictionary=entry.placement
    var prepared:Dictionary=entry.get("prepared_source_binding",{})
    var prepared_key:Array=[path,owner.source_depth,owner.source_normals,entry.scale,row.get("scale_x",1.0),owner.character_light_profile]
    var source_prepared:bool=not prepared.is_empty() and prepared.geometry.key==prepared_key
    var sheet:Texture2D=prepared.sheet if source_prepared else owner.textures[path]
    var size:Vector2=prepared.sheet_size if source_prepared else Vector2(sheet.get_width(),sheet.get_height())
    bind_source_values(entry,rig,path,layer_frame,layer_facing,sheet,size,owner.textures,owner.resources,parameters)
    if source_prepared:CharacterGeometry.apply_binding(entry,prepared.geometry)
    else:CharacterGeometry.bind(entry,path,owner.catalog_cache,owner.texture,owner.source_depth,owner.source_normals,owner.character_light_profile)

static func realize_private_binding(value:Dictionary,textures:Dictionary)->Dictionary:
    # Missing texture operands stay explicitly named until the scene owner's
    # existing exact-source readiness gate. Metadata/quad work is independent.
    var result:Dictionary=value.duplicate();result.sheet=textures.get(value.path)
    var geometry:Dictionary=value.geometry.duplicate();geometry.parameters=value.geometry.parameters.duplicate()
    for parameter in geometry.textures:geometry.parameters[parameter]=textures.get(geometry.textures[parameter])
    result.geometry=geometry
    return result

static func complete_private_layer(packet:Dictionary,textures:Dictionary)->bool:
    var entry:Dictionary=packet.entry
    for parameter in packet.pending_textures:
        var path:String=packet.pending_textures[parameter]
        if not textures.has(path):return false
    packet.filled_textures=packet.pending_textures.keys()
    if packet.pending_textures.has("effect_noise"):
        SourceMaterial.set_parameter(entry,"effect_has_noise",true)
        packet.filled_textures.append("effect_has_noise")
    for parameter in packet.pending_textures:
        var texture:Texture2D=textures[packet.pending_textures[parameter]]
        SourceMaterial.set_parameter(entry,parameter,texture)
        if parameter=="sheet":entry.prepared_source_binding.sheet=texture
        elif entry.prepared_source_binding.geometry.textures.has(parameter):entry.prepared_source_binding.geometry.parameters[parameter]=texture
    packet.pending_textures={}
    var key:Array=entry.bound_frame_key
    key[0]=entry.prepared_source_binding.sheet
    var noise:String=packet.get("noise_path","")
    key[3]=textures.get(noise) if not noise.is_empty() else null
    return true

static func adopt_private_layer(owner:Node,packet:Dictionary)->Dictionary:
    var entry:Dictionary=packet.entry
    # The worker built the node; completed textures may have widened its bounds.
    var node:MeshInstance3D=entry.node
    node.custom_aabb=packet.aabb
    owner.add_child(node)
    owner.entries.append(entry);owner.actor_entries.append(entry)
    owner._light_entry(entry)
    return entry

static func layer_transform(camera_basis:Basis,row:Dictionary,rig:Dictionary,sample:Dictionary,role:String,clip_name:String,facing:String,frame:int,tile_width:float,body_scale:float)->Transform3D:
    # Shared exact displayed-body math; capture-only layers supply immutable
    # pre-cut operands and never enter published actor membership.
    var basis = camera_basis.scaled_local(Vector3(row.get("scale_x",1.0),1,1))
    var position = Placement.contact(row)
    if sample.has("passage") and role!="shadow":
        var weight: float=sample.passage_weight
        var passage: Dictionary=sample.passage
        var sx=lerpf(1,passage.passageScale[0],weight)
        var sy=lerpf(1,passage.passageScale[1],weight)
        basis=camera_basis.scaled_local(Vector3(row.get("scale_x",1.0)*sx,sy,1))
        var points: Array=rig.get("pose_sockets",{}).get(passage.passageSocket,{}).get(clip_name,{}).get(facing,[])
        var socket: Variant=points[mini(frame,points.size()-1)] if not points.is_empty() else null
        var unit=128.0/float(tile_width)*row.scale/Placement.PIXELS_PER_UNIT
        position+=camera_basis.y*float(passage.passageBodyHeightPx)*(1-sy)*unit
        if socket!=null:
            position+=camera_basis.x*(rig.cell_width*.5-socket.x)*row.get("scale_x",1.0)*sx*weight*unit
            position-=camera_basis.y*(rig.cell_height-rig.origin_y_from_ground-passage.passageBodyHeightPx-socket.y)*sy*weight*unit
    if body_scale!=1.0:
        basis=basis.scaled_local(Vector3.ONE*body_scale)
        position=Placement.contact(row)+(position-Placement.contact(row))*body_scale
    if role != "shadow": position.y += float(sample.get("lift_pixels",0))*(128.0/tile_width)/64.0*Placement.HEIGHT_UNIT
    return Transform3D(basis,position)

## Authored aperture lip in the painted plane, independent of body geometry,
## lighting and the viewport size. Private captures retain these same operands.
static func aperture_parameters(sample:Dictionary,camera_basis:Basis,tile_width:float)->Dictionary:
    var result:Dictionary={"body_aperture_enabled":false}
    var aperture:Dictionary=sample.get("aperture",{})
    if aperture.get("shape") not in ["ellipse","diamond"] or float(sample.get("lift_pixels",0.0))>=0.0:return result
    if sample.get("from_position")==null or not sample.has("from_elevation_feet"):return result
    var scale:float=128.0/tile_width*float(aperture.get("source_scale",1.0))/Placement.PIXELS_PER_UNIT
    var width:float=float(aperture.get("half_width_px",0.0))*scale
    var height:float=float(aperture.get("half_height_px",0.0))*scale
    if width<=0.0 or height<=0.0:return result
    result.merge({"body_aperture_enabled":true,"body_aperture_diamond":aperture.shape=="diamond",
        "body_aperture_center":Vector3(sample.from_position[0],float(sample.from_elevation_feet)/5.0*Placement.HEIGHT_UNIT,sample.from_position[1]),
        "body_aperture_x":camera_basis.x/width,"body_aperture_y":camera_basis.y/height})
    return result
