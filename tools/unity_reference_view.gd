extends SceneTree
var data: Dictionary
var textures = {}
var scene: Node2D
var water_shader = Shader.new()
func _initialize() -> void: run.call_deferred()
func texture(path: String) -> Texture2D:
    if not textures.has(path): textures[path]=ImageTexture.create_from_image(Image.load_from_file(path))
    return textures[path]
func colour(c: Dictionary) -> Color: return Color(c.r,c.g,c.b,c.a)
func capture(name: String, centre: Vector2, height: float) -> void:
    if scene:
        root.remove_child(scene)
        scene.queue_free()
    scene=Node2D.new()
    root.add_child(scene)
    var scale=root.size.y/height/128.0
    scene.scale=Vector2.ONE*scale
    scene.position=Vector2(root.size)*0.5-Vector2(centre.x,-centre.y)*128*scale
    var visible_rect=Rect2(Vector2(centre.x,-centre.y)*128-Vector2(root.size)/scale*0.5,Vector2(root.size)/scale).grow(512)
    var layers: Array=data.layers.duplicate()
    layers.sort_custom(func(a,b):return a.order<b.order)
    for layer in layers:
        if layer.name in ["Colliders","Colliders(indestructible)","TileCheck","BuildPreview"]: continue
        var draws: Array=layer.draws.duplicate()
        draws.sort_custom(func(a,b):return a.cell[0]+a.cell[1]>b.cell[0]+b.cell[1])
        for row in draws:
            var origin=Vector2((row.cell[0]-row.cell[1])*64,-(row.cell[0]+row.cell[1]+1)*32)+Vector2(layer.position.x,-layer.position.y)*128
            if not visible_rect.has_point(origin):continue
            var source: Dictionary=data.sprites[row.sprite]
            var sprite=Sprite2D.new()
            sprite.texture=texture(source.path)
            sprite.region_enabled=true
            sprite.region_rect=Rect2(source.rect[0],source.rect[1],source.rect[2],source.rect[3])
            sprite.centered=false
            sprite.offset=-Vector2(source.pivot[0],source.pivot[1])
            sprite.modulate=colour(layer.color)*colour(layer.colors[row.color])
            var m: Dictionary=layer.matrices[row.matrix]
            sprite.transform=Transform2D(Vector2(m.e00,-m.e10)*128/source.ppu,Vector2(-m.e01,m.e11)*128/source.ppu,origin+Vector2(m.e03,-m.e13)*128)
            sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
            if layer.name=="Water":
                var mat=ShaderMaterial.new();mat.shader=water_shader;sprite.material=mat
            scene.add_child(sprite)
    for i in range(3):await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.captures/unity-reference-"+name+".png")
    print("UNITY_REFERENCE ",name)
func run() -> void:
    data=JSON.parse_string(FileAccess.get_file_as_string("res://generated/unity_reference.json"))
    water_shader.code="shader_type canvas_item; void fragment(){ COLOR=vec4(vec3(0.05,0.35,0.46),texture(TEXTURE,UV).a*COLOR.a); }"
    await capture("overview",Vector2(-25,-12),130)
    await capture("start",Vector2(-8.33,1.4),12)
    await capture("stairs",Vector2(-15,-4.75),12)
    await capture("western-fort",Vector2(-30,-11),22)
    await capture("northern-ruins",Vector2(5.5,7.5),22)
    await capture("southern-castle",Vector2(15,-34.25),22)
    await capture("eastern-castle",Vector2(45.5,-23.5),22)
    quit()
