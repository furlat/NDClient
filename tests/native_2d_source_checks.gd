extends SceneTree
# Actual source pixels through the production Canvas receivers. The oracle is a
# separately placed native Canvas item with CPU-decoded source normals; it has no
# atlas remapping or native MODEL_MATRIX normal-cancellation code. A second exact
# GPU reference retains the full source cell to isolate storage-crop correctness.
const Catalog = preload("res://source_catalog.gd")
const Geometry = preload("res://presentation/character_geometry.gd")
const Placement = preload("res://placement.gd")
const Modular = preload("res://presentation/canvas_modular.gdshader")
const EnvironmentReceiver = preload("res://presentation/canvas_environment.gdshader")
const COOKIE = "C:/Users/tommaso/Documents/Dev/NDCharacterLight/.reference-template/scenes/vfx/textures/T_basic1_vfx.PNG"
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

func check(value: bool,label: String) -> void:
    checks+=1
    if not value: failures.append(label);print("NATIVE_2D_SOURCE_FAIL ",label)

func texture(path: String) -> Texture2D:
    if not textures.has(path):
        images[path]=Image.load_from_file(Catalog.media_path(path) if path.begins_with("/media/") else path)
        textures[path]=ImageTexture.create_from_image(images[path])
    return textures[path]

func _initialize() -> void: run.call_deferred()

func page(lit: bool) -> SubViewport:
    var view=SubViewport.new();view.size=Vector2i(512,512);view.disable_3d=true;view.transparent_bg=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    view.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    root.add_child(view)
    var ambient=CanvasModulate.new();ambient.color=Color(.176419,.176419,.176419,1) if lit else Color.WHITE;view.add_child(ambient)
    if lit:
        for i in 2:
            var light=PointLight2D.new();light.texture=cookie
            light.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
            light.position=[Vector2(95,95),Vector2(285,185)][i]
            light.color=[Color(.809372,.429306,.269121),Color(.35,.55,.85)][i]
            light.energy=[.9,.55][i];light.height=[28,47][i]
            light.texture_scale=380.0/cookie.get_width();view.add_child(light)
    return view

func capture(view: SubViewport) -> Image:
    await process_frame;await RenderingServer.frame_post_draw
    return view.get_texture().get_image()

func sprite(view: SubViewport,material: ShaderMaterial,transform: Transform2D) -> Sprite2D:
    var node=Sprite2D.new();node.texture=white;node.centered=false;node.transform=transform;node.material=material
    view.add_child(node);return node

func modular(category: String,slot: String,row: int,profile: String,mirror: bool) -> Dictionary:
    var path="/media/smallscale/modular/"+category+"/Idle.png"
    var material=ShaderMaterial.new();material.shader=Modular
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new()
    var entry={"node":node,"material":material,"scale":2.0,"placement":{"scale_x":-1.0 if mirror else 1.0},"actor_layer":{"slot":slot}}
    material.set_shader_parameter("sheet",texture(path));material.set_shader_parameter("frame_uv",Vector4(0,float(row)/8,1.0/15,1.0/8))
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
    return {"id":category+"-r"+str(row)+"-"+profile+("-mirror" if mirror else ""),"material":material,"colour":colour,"normals":decoded,"tint":tint,"visible":1.0,"mirror":mirror,"supported":supported}

func corner(quarter: int,remembered: bool) -> Dictionary:
    var probe=SourceProbe.new();root.add_child(probe);probe.hide()
    probe.camera=Camera3D.new();probe.add_child(probe.camera)
    probe.quarter=quarter
    var rotation=Basis(Vector3.UP,quarter*PI*.5)
    probe.camera.position=rotation*Vector3(12,12*Placement.HEIGHT_UNIT,12);probe.camera.look_at(Vector3.ZERO)
    var row={"id":"source-corner","kind":"wall","material":"stone","position":[0,0],"base_height_steps":0,"layer":1,"orientation":"east","boundaries":["north","east"],"tint":[.61,.79,.93,.81]}
    probe.add_entry(row,"wall",12,probe.ENVIRONMENT_SHADER,1)
    var entry: Dictionary=probe.entries.back();probe.initialize_entry(entry)
    var material=ShaderMaterial.new();material.shader=EnvironmentReceiver
    for uniform in entry.material.shader.get_shader_uniform_list():material.set_shader_parameter(uniform.name,entry.material.get_shader_parameter(uniform.name))
    var camera_basis: Basis=probe.camera.basis
    var world_to_canvas=Basis(camera_basis.x,-camera_basis.y,camera_basis.z).transposed()
    material.set_shader_parameter("world_to_canvas",world_to_canvas)
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
    return {"id":"corner-q"+str(quarter)+( "-remembered" if remembered else ""),"material":material,"colour":colour,"normals":decoded,"tint":Color(.61,.79,.93,.81),"visible":0.0 if remembered else 1.0,"mirror":false,"supported":supported}

func compare(actual: Image,expected: Image) -> Dictionary:
    var changed := 0;var alpha := 0;var maximum := 0
    for y in actual.get_height():
        for x in actual.get_width():
            var a=actual.get_pixel(x,y);var b=expected.get_pixel(x,y)
            var difference=maxi(maxi(absi(a.r8-b.r8),absi(a.g8-b.g8)),maxi(absi(a.b8-b.b8),absi(a.a8-b.a8)))
            if difference>0:changed+=1
            if a.a8!=b.a8:alpha+=1
            maximum=maxi(maximum,difference)
    return {"changed_pixels":changed,"alpha_mismatches":alpha,"maximum_byte_error":maximum}

func check_source(fixture: Dictionary,lit: bool) -> void:
    var colour: Image=fixture.colour
    var size=colour.get_size();var crop=colour.get_used_rect()
    var original_transform=Transform2D(Vector2(-size.x if fixture.mirror else size.x,0),Vector2(0,size.y),Vector2(40+size.x if fixture.mirror else 40,40))
    var crop_uv=Vector4(float(crop.position.x)/size.x,float(crop.position.y)/size.y,float(crop.size.x)/size.x,float(crop.size.y)/size.y)
    var transform=Transform2D(original_transform.x*crop_uv.z,original_transform.y*crop_uv.w,original_transform*Vector2(crop_uv.x,crop_uv.y))
    var packed=page(lit);var reference=page(lit);var full_gpu=page(lit)
    var packing=Rect2i(31,19,crop.size.x,crop.size.y)
    fixture.material.set_shader_parameter("source_crop",crop_uv)
    fixture.material.set_shader_parameter("atlas_cell_size",Vector2(crop.size))
    fixture.material.set_shader_parameter("receiver_visibility",fixture.visible)
    var node=sprite(packed,fixture.material,Transform2D(transform.x/crop.size.x,transform.y/crop.size.y,transform.origin))
    node.region_enabled=true;node.region_rect=Rect2(packing);node.region_filter_clip_enabled=false
    # Identical native GPU source decoding, but original full-cell storage: this
    # comparison admits NO rounding tolerance and isolates crop/UV/alpha transport.
    var full_material: ShaderMaterial=fixture.material.duplicate()
    full_material.set_shader_parameter("source_crop",Vector4(0,0,1,1))
    full_material.set_shader_parameter("atlas_cell_size",Vector2(size))
    var full_node=sprite(full_gpu,full_material,Transform2D(original_transform.x/size.x,original_transform.y/size.y,original_transform.origin))
    full_node.region_enabled=true;full_node.region_rect=Rect2(40,40,size.x,size.y);full_node.region_filter_clip_enabled=false
    var oracle=ShaderMaterial.new();oracle.shader=reference_shader
    oracle.set_shader_parameter("original",ImageTexture.create_from_image(colour));oracle.set_shader_parameter("decoded_normals",ImageTexture.create_from_image(fixture.normals));oracle.set_shader_parameter("tint",fixture.tint);oracle.set_shader_parameter("visible_now",fixture.visible)
    var inverse=original_transform.affine_inverse()
    oracle.set_shader_parameter("source_origin",original_transform.origin);oracle.set_shader_parameter("source_inverse",Vector4(inverse.x.x,inverse.x.y,inverse.y.x,inverse.y.y))
    sprite(reference,oracle,Transform2D(Vector2(size.x,0),Vector2(0,size.y),Vector2(40,40)))
    var actual_packed=await capture(packed);var native_reference=await capture(reference);var native_full=await capture(full_gpu)
    var actual=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8);actual.fill(Color(0,0,0,0))
    var expected=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8);expected.fill(Color(0,0,0,0))
    var opaque := 0;var partial := 0
    for y in size.y:
        for x in size.x:
            var uv=(Vector2(x,y)+Vector2(.5,.5))/Vector2(size)
            expected.set_pixel(x,y,native_reference.get_pixelv(Vector2i((original_transform*uv).floor())))
            if crop.has_point(Vector2i(x,y)):actual.set_pixel(x,y,actual_packed.get_pixel(packing.position.x+x-crop.position.x,packing.position.y+y-crop.position.y))
            var alpha=colour.get_pixel(x,y).a8
            if alpha>0:opaque+=1
            if alpha>0 and alpha<255:partial+=1
    var result=compare(actual,expected)
    var storage=compare(actual,native_full.get_region(Rect2i(40,40,size.x,size.y)))
    var id: String=fixture.id+("-lit" if lit else "-white")
    result.merge({"id":id,"source_pixels":opaque,"partial_source_alpha":partial,"crop":[crop.position.x,crop.position.y,crop.size.x,crop.size.y],"supported":fixture.supported})
    result["full_cell_gpu_storage"]=storage
    var cpu_rounding: bool=lit and fixture.id.begins_with("corner-")
    result["cpu_normal_oracle_rgb_tolerance_bytes"]=1 if cpu_rounding else 0
    result["lit_storage_rgb_tolerance_bytes"]=1 if cpu_rounding else 0
    if cpu_rounding:
        result["precision_attribution"]="native_2d_source_precision.json: native receiving XY interpolation ~1.5e-5px; encoded normal unchanged at all three previously differing pixels"
    comparisons.append(result)
    # Native raster interpolation differs by ~1.5e-5 receiving screen pixels at
    # three original corner texels. The isolated diagnostic proves unchanged
    # normal/alpha and one LDR RGB byte. Keep exact counts; allow only this lit
    # environment RGB rounding bound, never alpha or unlit/source transport.
    var storage_ok: bool=storage.alpha_mismatches==0 and (storage.maximum_byte_error<=1 if cpu_rounding else storage.changed_pixels==0)
    check(storage_ok,id+" crop vs full-cell GPU source"+(" within one lit RGB byte (native receiving interpolation)" if cpu_rounding else " byte exact")+": "+str(storage))
    check(result.alpha_mismatches==0,id+" cropped original source alpha matches independent native reference exactly")
    check(result.maximum_byte_error<=1 if cpu_rounding else result.changed_pixels==0,id+" independent CPU-decoded normal oracle"+(" within one RGB byte (float operation rounding only)" if cpu_rounding else " exact RGBA")+": "+str(result))
    actual.save_png("res://.captures/native-2d-source/"+id+"-actual.png");expected.save_png("res://.captures/native-2d-source/"+id+"-reference.png")
    native_full.get_region(Rect2i(40,40,size.x,size.y)).save_png("res://.captures/native-2d-source/"+id+"-full-gpu.png")
    packed.queue_free();reference.queue_free();full_gpu.queue_free();await process_frame

func precision_diagnostic() -> void:
    # Test-only float attribution. Source data/decoding and receiving transport
    # are unchanged; unshaded outputs separately expose normal and subpixel XY.
    var code: String=EnvironmentReceiver.code.replace('#include "canvas_environment.gdshaderinc"',FileAccess.get_file_as_string("res://presentation/canvas_environment.gdshaderinc"))
    for include in ["canvas_atlas.gdshaderinc","source_colour_environment.gdshaderinc","source_colour_common.gdshaderinc"]:
        code=code.replace('#include "'+include+'"',FileAccess.get_file_as_string("res://presentation/"+include))
    code=code.replace("skip_vertex_transform, blend_disabled","skip_vertex_transform, blend_disabled, unshaded")
    var report: Array=[]
    for q in [1,3]:
        var fixture=corner(q,true)
        var size: Vector2i=fixture.colour.get_size()
        var crop: Rect2i=fixture.colour.get_used_rect()
        var crop_uv=Vector4(float(crop.position.x)/size.x,float(crop.position.y)/size.y,float(crop.size.x)/size.x,float(crop.size.y)/size.y)
        for mode in ["normal","receiving_subpixel"]:
            var output="vec4(NORMAL*.5+.5,1.0)" if mode=="normal" else "vec4(vec2(.5)+(VERTEX-(floor(VERTEX)+vec2(.5)))*4096.0,0.0,1.0)"
            var shader=Shader.new();shader.code=code.replace("COLOR = colour;","COLOR = "+output+";")
            var packed=page(false);var full=page(false)
            for target in [packed,full]:
                var material: ShaderMaterial=fixture.material.duplicate();material.shader=shader
                var cropped: bool=target==packed
                var region=Rect2i(31,19,crop.size.x,crop.size.y) if cropped else Rect2i(40,40,size.x,size.y)
                material.set_shader_parameter("source_crop",crop_uv if cropped else Vector4(0,0,1,1))
                material.set_shader_parameter("atlas_cell_size",Vector2(region.size))
                var node=sprite(target,material,Transform2D(0.0,Vector2(40,40)+(Vector2(crop.position) if cropped else Vector2.ZERO)))
                node.region_enabled=true;node.region_rect=Rect2(region);node.region_filter_clip_enabled=false
            var a=await capture(packed);var b=await capture(full)
            var pixels: Array=[]
            var points=[Vector2i(126,136)] if q==1 else [Vector2i(136,88),Vector2i(117,136)]
            for at in points:
                var ac=a.get_pixelv(Vector2i(31,19)+at-crop.position);var bc=b.get_pixelv(Vector2i(40,40)+at)
                pixels.append({"source_pixel":[at.x,at.y],"cropped_rgba":[ac.r8,ac.g8,ac.b8,ac.a8],"full_rgba":[bc.r8,bc.g8,bc.b8,bc.a8]})
            report.append({"quarter":q,"mode":mode,"pixels":pixels})
            packed.queue_free();full.queue_free();await process_frame
    var value={"observations":report,"scope":"Test-only unshaded production shader instrumentation at the three differing lit pixels. NORMAL encoded as n*.5+.5. Receiving XY residual to half-pixel centers encoded as .5+residual*4096; this amplified diagnostic is not a rendering correction."}
    FileAccess.open("res://generated/native_2d_source_precision.json",FileAccess.WRITE).store_string(JSON.stringify(value,"  "))
    print("NATIVE_2D_SOURCE_PRECISION ",JSON.stringify(value));quit()

func run() -> void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var one=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE);white=ImageTexture.create_from_image(one)
    cookie=texture(COOKIE);reference_shader=Shader.new();reference_shader.code=REFERENCE
    if "--precision-diagnostic" in OS.get_cmdline_user_args():
        await precision_diagnostic();return
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
    var report={"checks":checks,"failures":failures,"comparisons":comparisons,"scope":"Actual authored Head15/Chest14 Idle and all four stone corner source views. Production cropped REGION Canvas receivers vs exact full-cell native GPU source and independent direct native Canvas with CPU-decoded original normals, same native cookie/ambient. Exact alpha and unlit storage everywhere; lit environment corners permit at most one RGB byte for measured native receiving interpolation/CPU-to-GPU normal rounding, with actual differing pixel counts and a separate production-coordinate diagnostic retained. No gameplay/SDK inference; generated shadows excluded."}
    FileAccess.open("res://generated/native_2d_source_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_2D_SOURCE_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
