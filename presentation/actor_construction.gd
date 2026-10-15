extends RefCounted
## Native actor construction shared by displayed and unpublished world owners.
## Source selection is passive; this file owns no timeline or visibility gate.
const Graphs=preload("res://animation/graphs.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Palette=preload("res://presentation/palette.gd")
const CharacterGeometry=preload("res://presentation/character_geometry.gd")
const Modular=preload("res://modular.gd")
const MODULAR_SHADER=preload("res://modular.gdshader")

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
        if component.kind!="sprite_layer":continue
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

static func material_key(value:Dictionary,textures:Dictionary,resources:Dictionary)->Array:
    return [Conditions.parameters(value,textures,resources)]

static func prepare_neutral(entry:Dictionary,textures:Dictionary,resources:Dictionary)->void:
    # Only unpublished new layers call this. Current sampling compares the full
    # value and replaces every binding if a condition or hit is active at admission.
    var value:Dictionary=Conditions.material(entry.placement.id,[])
    var key:Array=material_key(value,textures,resources)
    Conditions.bind_parameters(entry.material,key[0])
    entry.bound_condition_key=key.duplicate(true)

static func graph(owner:Node,rig:Dictionary,templates:Array)->Node:
    return Graphs.character(owner,rig,true,templates)

static func layer(owner:Node,row:Dictionary,rig:Dictionary,source:Dictionary,index:int)->Dictionary:
    owner.add_entry(row,"shadow" if source.slot=="shadow" else "body",index,MODULAR_SHADER)
    var entry:Dictionary=owner.entries.back()
    entry.actor_layer=source
    entry.material.set_shader_parameter("layer_alpha",source.alpha)
    entry.material.set_shader_parameter("shadow",source.slot=="shadow")
    owner._light_entry(entry)
    entry.material.set_shader_parameter("tint",Modular.rgb(source.tint))
    var cell=Vector2(rig.cell_width,rig.cell_height)
    var pivot=Vector2(cell.x*.5,cell.y-rig.origin_y_from_ground)
    owner.set_quad(entry,cell,pivot,128.0/owner.rig_config.TILE_W*row.scale)
    return entry

static func bind_source(owner:Node,entry:Dictionary,rig:Dictionary,path:String,layer_frame:int,layer_facing:String,material_state:Dictionary,material_key:Array,material_snapshot:Array)->Array:
    # One binding implementation for current actors and hidden candidate layers.
    # Pose selection, animation clocks, transforms and visibility remain in Play.
    var layer:Dictionary=entry.actor_layer
    var row:Dictionary=entry.placement
    var sheet: Texture2D = owner.textures[path]
    var palette:Dictionary=layer.get("effect",{}).get("palette",{}) if layer.get("effect",{}).get("palette")!=null else {}
    var frame_key:Array=[sheet,layer_frame,layer_facing,owner.textures.get(owner.resources.get(palette.get("noiseSheet"),""))]
    var source_key = [path,frame_key,owner.character_light_profile,owner.source_depth,owner.source_normals,row.get("scale_x",1.0),material_key]
    var previous_source:Array=entry.get("sampled_source_key",[])
    if previous_source != source_key:
        # Same-sheet ordinary layers can change UV and exact condition
        # operands. Palette, sheet or geometry changes still require full copies.
        var previous_condition:Array=entry.get("bound_condition_key",[])
        var partial=palette.is_empty() and entry.get("sampled_source_palette_empty",false) and previous_source.size()==source_key.size()
        if partial:
            partial=previous_source[0]==path and previous_source[1][0]==sheet and previous_source[1][3]==frame_key[3]
            for at in range(2,source_key.size()-1):
                if previous_source[at]!=source_key[at]:partial=false;break
            partial=partial and previous_condition.size()==1 and previous_condition[0].has("condition_alpha") \
                and previous_source[-1]==previous_condition and entry.get("geometry_binding",[])==[path,owner.source_depth,owner.source_normals,entry.scale,entry.placement.get("scale_x",1.0),owner.character_light_profile]
        var base_version:int=entry.get("source_version",0)
        if material_snapshot.is_empty():material_snapshot=material_key.duplicate(true)
        source_key[-1]=material_snapshot
        entry.sampled_source_key = source_key
        entry.sampled_source_palette_empty=palette.is_empty()
        entry.source_version = base_version+1
        if partial:
            var previous_change:Dictionary=entry.get("source_frame_change",{})
            var full_version:int=base_version
            var parameters:Dictionary={}
            # This remains one bounded producer certificate, not a history.
            # Last-change versions let each receiver skip already-copied fields.
            if previous_change.get("version",-1)==base_version and previous_change.get("source")==entry.material \
                    and previous_change.get("shader")==entry.material.shader \
                    and previous_change.get("base_version",-1)==base_version-1:
                full_version=int(previous_change.get("full_version",previous_change.base_version))
                parameters=previous_change.parameters.duplicate() if previous_change.has("parameters") else {&"frame_uv":base_version}
            if entry.get("bound_frame_key",[])!=frame_key:parameters[&"frame_uv"]=base_version+1
            for field in material_key[0]:
                if not previous_condition[0].has(field) or previous_condition[0][field]!=material_key[0][field]:parameters[field]=base_version+1
            entry.source_frame_change={"base_version":base_version,"full_version":full_version,
                "version":base_version+1,"source":entry.material,"shader":entry.material.shader,"parameters":parameters}
        else:entry.erase("source_frame_change")
    entry.texture_path = path
    if entry.get("bound_frame_key",[])!=frame_key:
        entry.bound_frame_key=frame_key
        entry.material.set_shader_parameter("sheet",sheet)
        Palette.bind(entry.material,layer,layer_facing,layer_frame,owner.textures,owner.resources)
        entry.material.set_shader_parameter("material_cell_size",Vector2(rig.cell_width,rig.cell_height))
        entry.material.set_shader_parameter("frame_uv",Vector4(layer_frame*rig.cell_width/sheet.get_width(),rig.facing_rows[layer_facing]*rig.cell_height/sheet.get_height(),float(rig.cell_width)/sheet.get_width(),float(rig.cell_height)/sheet.get_height()))
    if entry.get("bound_condition_key",[])!=material_key:
        if material_snapshot.is_empty():material_snapshot=material_key.duplicate(true)
        entry.bound_condition_key=material_snapshot
        Conditions.bind_parameters(entry.material,material_key[0])
    CharacterGeometry.bind(entry,path,owner.catalog_cache,owner.texture,owner.source_depth,owner.source_normals,owner.character_light_profile)
    return material_snapshot
