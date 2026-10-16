extends RefCounted
## One static receiving draw, owned by the existing atlas candidate or atlas.
## Creation is private, hidden and unparented; SceneTree Nodes are never lent
## to its worker. Texture/material references outlive their opaque native RIDs.
var rid:RID
var texture:Texture2D
var material:ShaderMaterial
var transform:Transform2D
var region:Rect2
var rank:int=0
var visible:bool=false
var parent:RID
var batch:RefCounted

func initialize(source:Texture2D,source_rid:RID,shader_material:ShaderMaterial,material_rid:RID,
        value:Transform2D,rect:Rect2,z:int)->void:
    texture=source;material=shader_material;transform=value;region=rect;rank=z
    rid=RenderingServer.canvas_item_create()
    RenderingServer.canvas_item_set_visible(rid,false)
    RenderingServer.canvas_item_set_default_texture_filter(rid,RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
    RenderingServer.canvas_item_set_transform(rid,value)
    RenderingServer.canvas_item_set_material(rid,material_rid)
    RenderingServer.canvas_item_set_z_index(rid,z)
    # Exact Sprite2D(centered=false,region_enabled=true,filter_clip=false)
    # command. Its UV region intentionally addresses the atlas, not white 1x1.
    if rect.has_area():RenderingServer.canvas_item_add_texture_rect_region(rid,Rect2(Vector2.ZERO,rect.size),source_rid,rect,Color.WHITE,false,false)

func attach(value:RID)->void:
    if parent==value:return
    parent=value;RenderingServer.canvas_item_set_parent(rid,value)

func attach_private(value:RefCounted)->void:
    batch=value;batch.retain_draw();attach(value.rid)

func set_material(value:ShaderMaterial)->void:
    if material==value:return
    material=value;RenderingServer.canvas_item_set_material(rid,value.get_rid())

func set_transform(value:Transform2D)->void:
    if transform==value:return
    transform=value;RenderingServer.canvas_item_set_transform(rid,value)

func set_region(value:Rect2)->void:
    if region==value:return
    region=value;RenderingServer.canvas_item_clear(rid)
    RenderingServer.canvas_item_add_texture_rect_region(rid,Rect2(Vector2.ZERO,value.size),texture.get_rid(),value,Color.WHITE,false,false)

func set_rank(value:int)->void:
    if rank==value:return
    rank=value;RenderingServer.canvas_item_set_z_index(rid,value)

func set_visible(value:bool)->void:
    if visible==value:return
    visible=value;RenderingServer.canvas_item_set_visible(rid,value)

func dispose()->int:
    if not rid.is_valid():return 0
    RenderingServer.free_rid(rid);rid=RID();parent=RID();visible=false
    var released:int=1
    if batch!=null:released+=batch.release_draw()
    texture=null;material=null;batch=null
    return released

func _notification(what:int)->void:
    # RefCounted reaches this callback after its last reference is gone; call
    # the server directly rather than dispatching another method on self.
    if what==NOTIFICATION_PREDELETE and rid.is_valid():
        RenderingServer.free_rid(rid)
        if batch!=null:batch.release_draw()
