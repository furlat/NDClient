extends RefCounted
## Native actor construction shared by displayed and unpublished world owners.
## Source selection is passive; this file owns no timeline or visibility gate.
const SourceMaterial=preload("res://presentation/source_material.gd")
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
    var cell=Vector2(rig.cell_width,rig.cell_height)
    var pivot=Vector2(cell.x*.5,cell.y-rig.origin_y_from_ground)
    owner.set_quad(entry,cell,pivot,128.0/owner.rig_config.TILE_W*row.scale)
    return entry

static func bind_source(owner:Node,entry:Dictionary,rig:Dictionary,path:String,layer_frame:int,layer_facing:String,parameters:Dictionary)->void:
    # One binding implementation for current actors and hidden candidate layers.
    # Pose selection, animation clocks, transforms and visibility remain in Play.
    var layer:Dictionary=entry.actor_layer
    var row:Dictionary=entry.placement
    var sheet: Texture2D = owner.textures[path]
    var palette:Dictionary=layer.get("effect",{}).get("palette",{}) if layer.get("effect",{}).get("palette")!=null else {}
    var frame_key:Array=[sheet,layer_frame,layer_facing,owner.textures.get(owner.resources.get(palette.get("noiseSheet"),""))]
    entry.texture_path = path
    if entry.get("bound_frame_key",[])!=frame_key:
        entry.bound_frame_key=frame_key
        SourceMaterial.set_parameter(entry,"sheet",sheet,true)
        SourceMaterial.set_parameter(entry,"material_cell_size",Vector2(rig.cell_width,rig.cell_height))
        SourceMaterial.set_parameter(entry,"frame_uv",Vector4(layer_frame*rig.cell_width/sheet.get_width(),rig.facing_rows[layer_facing]*rig.cell_height/sheet.get_height(),float(rig.cell_width)/sheet.get_width(),float(rig.cell_height)/sheet.get_height()))
    var palette_parameters=Palette.parameters(layer,layer_facing,layer_frame,owner.textures,owner.resources)
    for name in palette_parameters:
        SourceMaterial.set_parameter(entry,name,palette_parameters[name],name in ["effect_palette_enabled","effect_has_noise","effect_noise"])
    # Play supplies an owned immutable operand value shared by this actor's
    # layers. Fixture/private callers may still supply mutable values.
    if not parameters.is_read_only() or not is_same(entry.get("bound_condition_parameters"),parameters):
        SourceMaterial.apply(entry,parameters)
        entry.bound_condition_parameters=parameters if parameters.is_read_only() else null
    CharacterGeometry.bind(entry,path,owner.catalog_cache,owner.texture,owner.source_depth,owner.source_normals,owner.character_light_profile)
