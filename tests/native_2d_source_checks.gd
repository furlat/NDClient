extends SceneTree
# Actual source pixels through the production lit sprite shaders. The oracle is a
# separately placed native Canvas item with CPU-decoded source normals, lit by
# native PointLight2D nodes under a CanvasModulate; it has no light-table code.
# The lit sprite is a 3D quad that reads the same lights from the light table
# (presentation/light_table.gd) and the receiving globals play.gd publishes.
# Its spatial output must equal the independent linear-alpha composite of the
# native Canvas reference within one RGB byte, with exact alpha.
const Catalog = preload("res://source_catalog.gd")
const Geometry = preload("res://presentation/character_geometry.gd")
const Placement = preload("res://placement.gd")
const LightTable = preload("res://presentation/light_table.gd")
const Modular = preload("res://modular.gdshader")
const EnvironmentSource = preload("res://environment.gdshader")
const COOKIE = "C:/Users/tommaso/Documents/Dev/NDCharacterLight/.reference-template/scenes/vfx/textures/T_basic1_vfx.PNG"
# CanvasModulate of the native reference pages (the original demo's ambient).
const AMBIENT = .176419
const PAGE = Vector2i(512,512)
const REFERENCE = '''shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D original : filter_nearest,repeat_disable;
uniform sampler2D decoded_normals : filter_nearest,repeat_disable;
uniform vec2 source_origin;
uniform vec4 source_inverse;
uniform vec4 tint = vec4(1.0);
uniform float visible_now = 1.0;
varying vec2 screen_pixel;
void vertex() { screen_pixel=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
    vec2 uv=mat2(source_inverse.xy,source_inverse.zw)*(screen_pixel-source_origin);
    if(any(lessThan(uv,vec2(0.0))) || any(greaterThanEqual(uv,vec2(1.0)))) discard;
    vec4 colour=texture(original,uv);
    if(colour.a<=0.0) discard;
    colour*=tint;
    float grey=dot(colour.rgb,vec3(.2126,.7152,.0722));
    colour.rgb=mix(mix(vec3(grey),colour.rgb,.35)*.62,colour.rgb,visible_now);
    COLOR=colour;
    NORMAL=texture(decoded_normals,uv).rgb;
}'''
class SourceProbe extends "res://presentation/sprite_sources.gd":
    var images: Dictionary = {}
    func texture(path: String) -> Texture2D:
        if not textures.has(path):
            images[path]=Image.load_from_file(Catalog.media_path(path))
            textures[path]=ImageTexture.create_from_image(images[path])
        return textures[path]
var checks := 0
var failures: Array = []
var comparisons: Array = []
var cache: Dictionary = {}
var images: Dictionary = {}
var textures: Dictionary = {}
var white: Texture2D
var cookie: Texture2D
var reference_shader: Shader
var light_table = LightTable.new()
var cookie_images: Dictionary = {}

func check(value: bool,label: String) -> void:
    checks+=1
    if not value: failures.append(label);print("NATIVE_2D_SOURCE_FAIL ",label)

func texture(path: String) -> Texture2D:
    if not textures.has(path):
        images[path]=Image.load_from_file(Catalog.media_path(path) if path.begins_with("/media/") else path)
        textures[path]=ImageTexture.create_from_image(images[path])
    return textures[path]

func _initialize() -> void: run.call_deferred()

# One native PointLight2D, as the light table row it becomes (see light_table_checks.gd).
func light(position: Vector2,colour: Color,energy: float,height: float,texture_scale: float,source: Texture2D=null) -> Dictionary:
    return {"id":"light-"+str(position),"enabled":true,"texture":source if source!=null else cookie,"screen_position":position,
        "height":height,"energy":energy,"color":colour,"texture_scale":texture_scale,"cookie_scale":Vector2.ONE,"offset":Vector2.ZERO}

func page_lights() -> Array:
    var result: Array=[]
    for i in 2:
        result.append(light([Vector2(95,95),Vector2(285,185)][i],[Color(.809372,.429306,.269121),Color(.35,.55,.85)][i],
            [.9,.55][i],[28,47][i],380.0/cookie.get_width()))
    return result

func native_lights(view: SubViewport,lights: Array) -> void:
    for spec in lights:
        var node=PointLight2D.new();node.texture=spec.texture;node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
        node.position=spec.screen_position;node.color=spec.color;node.energy=spec.energy;node.height=spec.height
        node.texture_scale=spec.texture_scale;node.scale=spec.cookie_scale;node.offset=spec.offset
        view.add_child(node)

# Native Canvas reference page; child 0 is its CanvasModulate.
func page(lit: bool,lights: Variant=null,size: Vector2i=PAGE) -> SubViewport:
    var view=SubViewport.new();view.size=size;view.disable_3d=true;view.transparent_bg=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    view.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    root.add_child(view)
    var ambient=CanvasModulate.new();ambient.color=Color(AMBIENT,AMBIENT,AMBIENT,1) if lit else Color.WHITE;view.add_child(ambient)
    if lit:native_lights(view,page_lights() if lights==null else lights)
    return view

func cookie_image(source: Texture2D) -> Image:
    var id: RID=source.get_rid()
    if not cookie_images.has(id):
        var image: Image=source.get_image().duplicate()
        if image.is_compressed():image.decompress()
        image.convert(Image.FORMAT_RGBA8)
        cookie_images[id]=image
    return cookie_images[id]

# The receiving globals exactly as play.gd _publish_receiving writes them.
func publish_receiving(lights: Array,ambient: float,cap: float=0.0,normals: bool=false) -> void:
    light_table.publish(lights,cookie_image)
    if not light_table.issues.is_empty():check(false,"Light table publishes every test light: "+str(light_table.issues))
    var hdr: bool=cap>0.0 and not normals
    var value:=Color(ambient,ambient,ambient)
    RenderingServer.global_shader_parameter_set(&"light_ambient",value.linear_to_srgb().srgb_to_linear().r if hdr else ambient)
    RenderingServer.global_shader_parameter_set(&"light_cap",cap)
    RenderingServer.global_shader_parameter_set(&"light_normals",normals)

# A spatial page for lit sprites: one world unit is one pixel. The camera has
# the scene camera's basis, so the sprite's world-to-canvas normal transform is
# the one the scene uses; the quad faces the camera as production quads do.
func lit_view(size: Vector2i,basis: Basis=Basis.IDENTITY,background: Color=Color(0,0,0,0)) -> SubViewport:
    var view=SubViewport.new();view.size=size;view.own_world_3d=true;view.transparent_bg=background.a<1.0
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world_environment=WorldEnvironment.new();world_environment.environment=Environment.new()
    world_environment.environment.background_mode=Environment.BG_COLOR;world_environment.environment.background_color=background
    view.add_child(world_environment)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=size.y
    camera.near=.05;camera.far=400.0;camera.basis=basis;view.add_child(camera)
    view.set_meta("camera",camera)
    return view

# The quad sits at the world origin (water/ground read MODEL_MATRIX origin);
# the camera moves so that it covers `rect` in viewport pixels.
func lit_quad(view: SubViewport,material: ShaderMaterial,rect: Rect2,mirror: bool=false) -> MeshInstance3D:
    var camera: Camera3D=view.get_meta("camera")
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=rect.size
    material.set_shader_parameter("source_quad_size",rect.size)
    node.material_override=material
    node.basis=camera.basis*Basis.from_scale(Vector3(-1.0 if mirror else 1.0,1.0,1.0))
    view.add_child(node)
    var centre: Vector2=rect.get_center()
    camera.position=camera.basis*Vector3(view.size.x*.5-centre.x,centre.y-view.size.y*.5,100.0)
    return node

func capture(view: SubViewport) -> Image:
    await process_frame;await RenderingServer.frame_post_draw
    return view.get_texture().get_image()

func sprite(view: SubViewport,material: ShaderMaterial,transform: Transform2D) -> Sprite2D:
    var node=Sprite2D.new();node.texture=white;node.centered=false;node.transform=transform;node.material=material
    view.add_child(node);return node

# Independent native straight-alpha reference over the transparent black target.
# Forward+/Mobile blend in linear space, then encode. Rounded explicitly: an
# RGBA8 Image.set_pixel of a float Color truncates. With `flipped_alpha`, a
# pixel whose stored alpha differs by exactly one byte (a half-byte rounding
# flip of the reference's own RGBA8 target) is composited with that alpha.
func linear_alpha_reference(straight: Image,flipped_alpha: Image=null) -> Image:
    var expected=Image.create(straight.get_width(),straight.get_height(),false,Image.FORMAT_RGBA8)
    for y in straight.get_height():
        for x in straight.get_width():
            var source=straight.get_pixel(x,y)
            if flipped_alpha!=null and absi(flipped_alpha.get_pixel(x,y).a8-source.a8)==1:source.a8=flipped_alpha.get_pixel(x,y).a8
            var value=source.srgb_to_linear()
            value.r*=source.a;value.g*=source.a;value.b*=source.a
            value=value.linear_to_srgb()
            expected.set_pixel(x,y,Color8(roundi(value.r*255.0),roundi(value.g*255.0),roundi(value.b*255.0),source.a8))
    return expected

func modular(category: String,slot: String,row: int,profile: String,mirror: bool) -> Dictionary:
    var path="/media/smallscale/modular/"+category+"/Idle.png"
    # Media preparation admits the body metadata before any descriptor read.
    Geometry.BodySources.prepare_descriptor(path,slot,cache)
    var material=ShaderMaterial.new();material.shader=Modular
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new()
    var entry={"node":node,"material":material,"scale":2.0,"placement":{"scale_x":-1.0 if mirror else 1.0},"actor_layer":{"slot":slot}}
    material.set_shader_parameter("sheet",texture(path));material.set_shader_parameter("frame_uv",Vector4(0,float(row)/8,1.0/15,1.0/8))
    material.set_shader_parameter("material_cell_size",Vector2(128,128))
    var tint=Color(.62,.81,.95,.73)
    material.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b));material.set_shader_parameter("layer_alpha",tint.a)
    Geometry.bind(entry,path,cache,texture,true,true,profile)
    var source=Geometry.record(path,slot,cache)
    var normals=Geometry.normal_paths(path,slot,cache)
    var geometry_root: String=ProjectSettings.get_setting("source_data/character_geometry_root")
    var colour: Image=images[path].get_region(Rect2i(0,row*128,128,128))
    var decoded=Image.create(128,128,false,Image.FORMAT_RGBAF)
    var supported := 0
    for y in 128:
        for x in 128:
            var at=Vector2i(x,row*128+y)
            var n=Vector3(0,0,1)
            var packed: Color=images[normals.value[profile]].get_pixelv(at)
            if images[geometry_root.path_join(source.files.support)].get_pixelv(at).r>.5 and images[geometry_root.path_join(source.files.normal_valid)].get_pixelv(at).r>.5 and images[geometry_root.path_join(source.files.depth)].get_pixelv(at).a>.5 and packed.a>.5:
                n=Vector3((packed.r*2-1)*(-1 if mirror else 1),-(packed.g*2-1),packed.b*2-1).normalized()
                if colour.get_pixel(x,y).a>0:supported+=1
            decoded.set_pixel(x,y,Color(n.x,n.y,n.z,1))
    node.free()
    check(supported>0,category+" actual frame has admitted delivered normals")
    return {"id":category+"-r"+str(row)+"-"+profile+("-mirror" if mirror else ""),"material":material,"colour":colour,"normals":decoded,"tint":tint,"visible":1.0,"mirror":mirror,"supported":supported,"basis":Basis.IDENTITY}

func corner(quarter: int,remembered: bool) -> Dictionary:
    var probe=SourceProbe.new();root.add_child(probe);probe.hide()
    probe.camera=Camera3D.new();probe.add_child(probe.camera)
    probe.quarter=quarter
    var rotation=Basis(Vector3.UP,quarter*PI*.5)
    probe.camera.position=rotation*Vector3(12,12*Placement.HEIGHT_UNIT,12);probe.camera.look_at(Vector3.ZERO)
    var row={"id":"source-corner","kind":"wall","material":"stone","position":[0,0],"base_height_steps":0,"layer":1,"orientation":"east","boundaries":["north","east"],"tint":[.61,.79,.93,.81]}
    probe.add_entry(row,"wall",12,probe.ENVIRONMENT_SHADER,1)
    var entry: Dictionary=probe.entries.back();probe.initialize_entry(entry)
    var material: ShaderMaterial=entry.material.duplicate()
    material.set_shader_parameter("current_visibility",0.0 if remembered else 1.0)
    var camera_basis: Basis=probe.camera.basis
    var world_to_canvas=Basis(camera_basis.x,-camera_basis.y,camera_basis.z).transposed()
    var record: Dictionary=entry.record
    var rect: Array=record.get("rect",[0,0,256,256])
    var colour: Image=probe.images[record.path].get_region(Rect2i(rect[0],rect[1],rect[2],rect[3]))
    var decoded=Image.create(colour.get_width(),colour.get_height(),false,Image.FORMAT_RGBAF)
    var registered=probe.matrix3(record.normal.normalToLocal)
    var local_to_world=(rotation*Basis.from_scale(Vector3(1,Placement.HEIGHT_UNIT,1))).inverse().transposed()
    var geometry: Image=probe.images[record.geometry_region.path]
    var normals: Image=probe.images[record.normal.region.path]
    var supported := 0
    for y in colour.get_height():
        for x in colour.get_width():
            var n=Vector3(0,0,1)
            var p=Vector2(x,y)
            var gp=(p*probe.v2(record.geometry_sampling.scale)+probe.v2(record.geometry_sampling.offset)).floor()
            var gr: Array=record.geometry_region.rect
            if gp.x>=0 and gp.y>=0 and gp.x<gr[2] and gp.y<gr[3]:
                var packet=geometry.get_pixel(int(gr[0]+gp.x),int(gr[1]+gp.y))
                var np=(p*probe.v2(record.normal.sampling.scale)+probe.v2(record.normal.sampling.offset)).floor()
                var nr: Array=record.normal.region.rect
                if packet.r8*256+packet.g8>0 and np.x>=0 and np.y>=0 and np.x<nr[2] and np.y<nr[3]:
                    var packed=normals.get_pixel(int(nr[0]+np.x),int(nr[1]+np.y))
                    n=Vector3(packed.b*2-1,packed.a*2-1,1-absf(packed.b*2-1)-absf(packed.a*2-1))
                    var fold=maxf(-n.z,0)
                    n.x+=-fold if n.x>=0 else fold;n.y+=-fold if n.y>=0 else fold
                    var world_normal=(local_to_world*registered*n.normalized()).normalized()
                    n=(world_to_canvas*world_normal).normalized()
                    if colour.get_pixel(x,y).a>0:supported+=1
            decoded.set_pixel(x,y,Color(n.x,n.y,n.z,1))
    probe.free()
    check(supported>0,"Corner q"+str(quarter)+" original has registered octahedral normals")
    return {"id":"corner-q"+str(quarter)+( "-remembered" if remembered else ""),"material":material,"colour":colour,"normals":decoded,"tint":Color(.61,.79,.93,.81),"visible":0.0 if remembered else 1.0,"mirror":false,"supported":supported,"basis":camera_basis}

func alpha_flips(actual: Image,straight: Image) -> int:
    var result := 0
    for y in actual.get_height():
        for x in actual.get_width():
            if absi(actual.get_pixel(x,y).a8-straight.get_pixel(x,y).a8)==1:result+=1
    return result

func compare(actual: Image,expected: Image) -> Dictionary:
    var changed := 0;var alpha := 0;var maximum := 0;var over_one := 0;var examples: Array=[]
    for y in actual.get_height():
        for x in actual.get_width():
            var a=actual.get_pixel(x,y);var b=expected.get_pixel(x,y)
            var difference=maxi(maxi(absi(a.r8-b.r8),absi(a.g8-b.g8)),maxi(absi(a.b8-b.b8),absi(a.a8-b.a8)))
            if difference>0:changed+=1
            if difference>1:over_one+=1
            if a.a8!=b.a8:alpha+=1
            if (difference>1 or a.a8!=b.a8) and examples.size()<6:examples.append({"at":[x,y],"actual":[a.r8,a.g8,a.b8,a.a8],"expected":[b.r8,b.g8,b.b8,b.a8]})
            maximum=maxi(maximum,difference)
    return {"changed_pixels":changed,"alpha_mismatches":alpha,"maximum_byte_error":maximum,"pixels_over_one_byte":over_one,"examples":examples}

# Native reference of a source fixture drawn by `transform` (cell UV square to
# screen) on a reference page; the Canvas item itself stays unmirrored.
func reference_page(fixture: Dictionary,transform: Transform2D,lit: bool,lights: Variant=null,size: Vector2i=PAGE) -> SubViewport:
    var view=page(lit,lights,size)
    add_reference(view,fixture,transform)
    return view

func add_reference(view: SubViewport,fixture: Dictionary,transform: Transform2D) -> Sprite2D:
    var oracle=ShaderMaterial.new();oracle.shader=reference_shader
    oracle.set_shader_parameter("original",ImageTexture.create_from_image(fixture.colour));oracle.set_shader_parameter("decoded_normals",ImageTexture.create_from_image(fixture.normals))
    oracle.set_shader_parameter("tint",fixture.tint);oracle.set_shader_parameter("visible_now",fixture.visible)
    var inverse=transform.affine_inverse()
    oracle.set_shader_parameter("source_origin",transform.origin);oracle.set_shader_parameter("source_inverse",Vector4(inverse.x.x,inverse.x.y,inverse.y.x,inverse.y.y))
    var bounds: Rect2=transform*Rect2(0,0,1,1)
    return sprite(view,oracle,Transform2D(Vector2(bounds.size.x,0),Vector2(0,bounds.size.y),bounds.position))

func check_source(fixture: Dictionary,lit: bool) -> void:
    var colour: Image=fixture.colour
    var size=colour.get_size()
    var original_transform=Transform2D(Vector2(-size.x if fixture.mirror else size.x,0),Vector2(0,size.y),Vector2(40+size.x if fixture.mirror else 40,40))
    var reference=reference_page(fixture,original_transform,lit)
    var view=lit_view(PAGE,fixture.basis)
    lit_quad(view,fixture.material.duplicate(),Rect2(40,40,size.x,size.y),fixture.mirror)
    publish_receiving(page_lights() if lit else [],AMBIENT if lit else 1.0)
    var native_reference=await capture(reference);var lit_output=await capture(view)
    var straight=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8);straight.fill(Color(0,0,0,0))
    var actual=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8);actual.fill(Color(0,0,0,0))
    var opaque := 0;var partial := 0
    for y in size.y:
        for x in size.x:
            var uv=(Vector2(x,y)+Vector2(.5,.5))/Vector2(size)
            var at=Vector2i((original_transform*uv).floor())
            straight.set_pixel(x,y,native_reference.get_pixelv(at))
            actual.set_pixel(x,y,lit_output.get_pixelv(at))
            var alpha=colour.get_pixel(x,y).a8
            if alpha>0:opaque+=1
            if alpha>0 and alpha<255:partial+=1
    var expected=linear_alpha_reference(straight)
    var result=compare(actual,expected)
    var id: String=fixture.id+("-lit" if lit else "-white")
    # Stored alpha is round(source alpha x tint alpha x 255). Where that product
    # lies within 0.05 of a half byte, the native RGBA8 target may round either
    # way (Vulkan float-to-UNORM conversion); count those one-byte flips apart.
    var flips := 0
    for y in size.y:
        for x in size.x:
            var difference: int=absi(actual.get_pixel(x,y).a8-expected.get_pixel(x,y).a8)
            if difference==0:continue
            var stored: float=colour.get_pixel(x,y).a*fixture.tint.a*255.0
            if difference==1 and absf(stored-floorf(stored)-.5)<.05:flips+=1
    result.merge({"id":id,"source_pixels":opaque,"partial_source_alpha":partial,"supported":fixture.supported,"rgb_tolerance_bytes":1,"alpha_half_byte_rounding_flips":flips})
    comparisons.append(result)
    # The lit sprite's spatial output is linear-alpha blended in a half-float
    # target: one RGB byte of quantization; alpha is exact except documented
    # half-byte rounding flips of the native reference's own RGBA8 storage.
    check(result.alpha_mismatches==flips,id+" lit sprite alpha matches independent native reference exactly (except half-byte rounding flips): "+str(result))
    check(result.maximum_byte_error<=1,id+" lit sprite matches independent CPU-normal native Canvas reference within one RGB byte: "+str(result))
    actual.save_png("res://.captures/native-2d-source/"+id+"-actual.png");expected.save_png("res://.captures/native-2d-source/"+id+"-reference.png")
    reference.queue_free();view.queue_free();await process_frame

func run() -> void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var one=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE);white=ImageTexture.create_from_image(one)
    cookie=texture(COOKIE);reference_shader=Shader.new();reference_shader.code=REFERENCE
    DirAccess.make_dir_recursive_absolute("res://.captures/native-2d-source")
    for category in [["Head15","helmet"],["Chest14","chest"]]:
        for profile in ["original","gentle","reference"]:
            var fixture=modular(category[0],category[1],0,profile,false)
            await check_source(fixture,true)
            if profile=="reference":await check_source(fixture,false)
        await check_source(modular(category[0],category[1],7,"reference",true),true)
    for q in 4:
        var fixture=corner(q,q%2==1)
        await check_source(fixture,true)
        await check_source(fixture,false)
    var report={"checks":checks,"failures":failures,"comparisons":comparisons,"scope":"Actual authored Head15/Chest14 Idle and all four stone corner source views through the production lit sprite shaders (modular/environment) and the light table, versus an independent direct native Canvas reference with CPU-decoded original normals under the same native PointLight2D cookie/ambient. Spatial output against the linear-alpha composite of the native reference: exact alpha, at most one RGB byte (half-float target). No gameplay/SDK inference; generated shadows excluded."}
    FileAccess.open("res://generated/native_2d_source_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_2D_SOURCE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
