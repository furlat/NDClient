extends RefCounted
## Evaluate the selected native material without translating its shader into a
## palette effect. The player output applies this live surface to its body mask.
const FactorySource=preload("res://sandbox/factory_source.gd")
const Native=preload("res://presentation/native_effects.gd")
const Surface=preload("res://presentation/native_material_surface.gd")
var sources:Dictionary={}
var surfaces:Dictionary={}
var definition:Dictionary={}
var material:Material
var finishing:Dictionary={}
var ramp:Texture2D
var selected_id:=""

func configure(world:Node)->void:
    if selected_id==world.spell.spell_id:return
    close()
    selected_id=world.spell.spell_id
    sources=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/body_materials.json"))
    definition=sources.spells.get(selected_id,{})
    if definition.get("status","")!="available":return
    finishing=world.library.spells[world.selected_spell].get("palette",{})
    if not finishing.get("ramp",[]).is_empty():ramp=Native._palette_texture(finishing.ramp)
    var source_handle:Dictionary={}
    var temporary=false
    for key in world.handles:
        if world.active_clips[key].id==definition.clip:source_handle=world.handles[key];break
    if source_handle.is_empty():
        for clip in world.source_clips:
            if clip.id==definition.clip:
                source_handle=FactorySource.make(world.get_node("Effects"),clip)
                temporary=true;break
    if source_handle.is_empty():
        world.presentation_errors.append("Missing native body material source: "+selected_id);return
    var mesh:MeshInstance3D=source_handle.root.get_node(definition.node)
    var source:Material=mesh.get_active_material(int(definition.surface))
    if source==null:
        world.presentation_errors.append("Missing native body material: "+selected_id)
    else:
        material=source.duplicate(true)
        for property in definition.get("parameter_overrides",{}):
            material.set_shader_parameter(property,definition.parameter_overrides[property])
    if temporary:FactorySource.close(source_handle)

func _make_surface(world:Node)->Dictionary:
    return Surface.make(world,material)

func decorate(world:Node,samples:Array)->void:
    if world.hit_appearance!=1 or material==null:return
    for sample in samples:
        if sample.kind!="material_flash":continue
        var id:String=sample.actor_uuid
        if not surfaces.has(id):surfaces[id]=_make_surface(world)
        var surface:Dictionary=surfaces[id]
        var clock_parameter:String=definition.get("clock_parameter","")
        Surface.sample(surface,sample.age_ms/1000.0,clock_parameter)
        sample.native_surface=surface.viewport.get_texture()
        if world.spell_colours and ramp!=null:
            sample.native_ramp=ramp
            sample.native_finishing=finishing

func close()->void:
    for surface in surfaces.values():Surface.close(surface)
    surfaces.clear();material=null;ramp=null;finishing={};selected_id=""
