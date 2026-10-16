extends RefCounted
const SourceMaterial=preload("res://presentation/source_material.gd")
## One assembled-alpha contour, shared by all physical outfit layers.
const ShaderSource=preload("res://presentation/condition_outline.gdshader")
const Characters=preload("res://presentation/characters.gd")
var owners: Dictionary={}
var pulse_masks: Dictionary={}

func pulse_mask(size: Vector2i) -> Texture2D:
    if pulse_masks.has(size):return pulse_masks[size]
    var mask=Image.create_empty(size.x,size.y,false,Image.FORMAT_R8)
    for k in 5:
        var y=size.y*(.29+k*.085)
        var points=[Vector2i(size.x*.30,y),Vector2i(size.x*.44,y-3),Vector2i(size.x*.49,y+2),Vector2i(size.x*.56,y-3),Vector2i(size.x*.70,y)]
        for i in range(1,points.size()):
            var p: Vector2i=points[i-1];var end: Vector2i=points[i]
            var dx=absi(end.x-p.x);var dy=absi(end.y-p.y)
            var sx=1 if p.x<end.x else -1;var sy=1 if p.y<end.y else -1
            var error=int((dx if dx>dy else -dy)/2)
            while true:
                if p.x>=0 and p.x<size.x and p.y>=0 and p.y<size.y:mask.set_pixelv(p,Color.WHITE)
                if p==end:break
                var twice=error
                if twice>-dx:error-=dy;p.x+=sx
                if twice<dy:error+=dx;p.y+=sy
    pulse_masks[size]=ImageTexture.create_from_image(mask)
    return pulse_masks[size]

func sample(world: Node,actor_id: String,material: Dictionary) -> bool:
    if material.outline.is_empty():erase(world,actor_id);return true
    var actor: Dictionary=world.visual_actors.get(actor_id,{})
    if actor.is_empty():erase(world,actor_id);return true
    var parts: Array=actor.entries.filter(func(entry):return entry.node.visible and entry.role!="shadow" and entry.actor_layer.slot not in Characters.EFFECT_SLOTS)
    if parts.is_empty():erase(world,actor_id);return true
    var rig: Dictionary=world.rigs[actor.row.rig]
    if not owners.has(actor_id):
        var view=SubViewport.new();view.disable_3d=true;view.transparent_bg=true;view.size=Vector2i(rig.cell_width,rig.cell_height);view.render_target_update_mode=SubViewport.UPDATE_DISABLED;world.add_child(view)
        var node=MeshInstance3D.new();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.mesh=parts[0].node.mesh;world.add_child(node)
        var shader=ShaderMaterial.new();shader.shader=ShaderSource;node.material_override=shader
        shader.set_shader_parameter("assembled",view.get_texture())
        shader.set_shader_parameter("pulse_mask",pulse_mask(view.size))
        var entry={"id":actor_id+":condition_outline","node":node,"material":shader,"placement":actor.row,"role":"native_effect","layer":100}
        world.actor_entries.append(entry);world.draw_order_dirty=true
        owners[actor_id]={"view":view,"entry":entry,"key":[],"drawn":false}
    var owner: Dictionary=owners[actor_id]
    var key: Array=parts.map(func(entry):return [entry.texture_path,SourceMaterial.value(entry,"frame_uv"),entry.actor_layer.alpha])
    if owner.key!=key:
        owner.key=key;owner.drawn=false
        for child in owner.view.get_children():child.free()
        for part in parts:
            var sprite=Sprite2D.new();sprite.centered=false;sprite.texture=SourceMaterial.value(part,"sheet")
            var uv: Vector4=SourceMaterial.value(part,"frame_uv")
            sprite.region_enabled=true;sprite.region_rect=Rect2(uv.x*sprite.texture.get_width(),uv.y*sprite.texture.get_height(),uv.z*sprite.texture.get_width(),uv.w*sprite.texture.get_height())
            sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;sprite.modulate.a=part.actor_layer.alpha;owner.view.add_child(sprite)
        owner.view.render_target_update_mode=SubViewport.UPDATE_ONCE
        RenderingServer.frame_post_draw.connect(func():if is_same(owners.get(actor_id),owner):owner.drawn=true,CONNECT_ONE_SHOT)
    var entry: Dictionary=owner.entry
    entry.node.transform=parts[0].node.transform;entry.placement=actor.row
    bind(entry.material,material)
    entry.node.visible=owner.drawn
    return owner.drawn

func erase(world: Node,actor_id: String) -> void:
    if not owners.has(actor_id):return
    var owner: Dictionary=owners[actor_id]
    world.actor_entries.erase(owner.entry);owner.entry.node.queue_free();owner.view.queue_free();owners.erase(actor_id);world.draw_order_dirty=true

func close(world: Node) -> void:
    for id in owners.keys():erase(world,id)
    pulse_masks.clear()

static func bind(shader: ShaderMaterial,material: Dictionary) -> void:
    var recipe: Dictionary=material.outline
    shader.set_shader_parameter("contour_colour",Color.hex(int(recipe.color)*256+255));shader.set_shader_parameter("pulse_colour",Color.hex(int(recipe.pulseColor)*256+255))
    shader.set_shader_parameter("alpha_threshold",float(recipe.get("alphaThreshold",100))/255.0)
    shader.set_shader_parameter("opacity",recipe.get("opacity",.55));shader.set_shader_parameter("pulse_opacity",recipe.get("pulseOpacity",.75))
    shader.set_shader_parameter("period_ms",recipe.get("periodMs",1400));shader.set_shader_parameter("onset_ms",recipe.get("onsetMs",300))
    shader.set_shader_parameter("age_ms",material.outline_age_ms);shader.set_shader_parameter("initialized",material.outline_initial)
    shader.set_shader_parameter("fade_alpha",material.outline_alpha)
