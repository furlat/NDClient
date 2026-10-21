extends SceneTree
# Synthetic admitted depth-extremum fixture on an original Head15 source texel.
# Original artwork/normal/support are retained; only a test-local depth copy is
# assigned the declared packet maximum. This is a culling boundary test, not an
# assertion that this extremum occurs in the selected natural Head15 sheet.
const Geometry=preload("res://presentation/character_geometry.gd")
const Catalog=preload("res://source_catalog.gd")
const Placement=preload("res://placement.gd")
var checks=0
var failures=[]
var cache={}
var textures={}
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("RECEIVER_BOUNDS_FAIL ",label)
func texture(path:String)->Texture2D:
    if not textures.has(path):textures[path]=ImageTexture.create_from_image(Image.load_from_file(Catalog.media_path(path)))
    return textures[path]
func capture(view:SubViewport)->Image:
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    return view.get_texture().get_image()
func _initialize()->void:run.call_deferred()
func run()->void:
    if DisplayServer.get_name()=="headless":quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var view=SubViewport.new();view.size=Vector2i(128,128);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR
    world.environment.background_color=Color.BLACK;world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED;view.add_child(world)
    # Keep the displaced receiver AND its tiny light in the camera frustum.
    # A quad-tight camera independently culls that light, so a black result
    # would say nothing about the mesh/light AABB pairing under test.
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=12;view.add_child(camera);camera.current=true
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2.ONE*128*2/Placement.PIXELS_PER_UNIT
    node.mesh.center_offset=Vector3(0,23*2/Placement.PIXELS_PER_UNIT,0);view.add_child(node)
    var mat=ShaderMaterial.new();mat.shader=load("res://modular.gdshader");node.material_override=mat
    var path="res://assets/art/media/smallscale/modular/Head15/Idle.png";var source=Geometry.record(path,"helmet",cache)
    var root_path:String=Geometry._root(source)
    var depth=Image.load_from_file(root_path.path_join(source.files.depth));var normal=Image.load_from_file(Geometry.normal_paths(path,"helmet",cache).value.original)
    var raw=Image.load_from_file(root_path.path_join(source.files.support));var valid=Image.load_from_file(root_path.path_join(source.files.normal_valid))
    # Choose an opaque supported original texel, then exercise the admitted
    # packet extremum explicitly. Natural sampled receivers were inside the
    # WORLD quad AABB; leaving its plane alone is not a valid negative control.
    var original=Image.load_from_file(Catalog.media_path(path))
    var at=Vector2i.ZERO;var highest=-INF
    for y in range(128):
        for x in range(128):
            var pixel=Vector2i(x,3*128+y)
            if original.get_pixelv(pixel).a<.99 or raw.get_pixelv(pixel).r<.5 or valid.get_pixelv(pixel).r<.5:continue
            var value=source.depth_range[0]+(depth.get_pixelv(pixel).r*255-32)*(source.depth_range[1]-source.depth_range[0])/192
            var elevation=sqrt(.5)*(96-y+value)*2/Placement.PIXELS_PER_UNIT
            if elevation>highest:highest=elevation;at=pixel
    check(raw.get_pixelv(at).r>.5 and valid.get_pixelv(at).r>.5,"Original chosen source pixel has both producer validity grants")
    var d:float=source.depth_range[1]
    depth.set_pixelv(at,Color(224.0/255,0,0,1))
    var extremum_texture=ImageTexture.create_from_image(depth)
    var encoded=normal.get_pixelv(at);var n=Vector3(encoded.r*2-1,encoded.g*2-1,encoded.b*2-1).normalized()
    mat.set_shader_parameter("sheet",texture(path));mat.set_shader_parameter("frame_uv",Vector4(at.x/1920.0,at.y/1024.0,1.0/1920,1.0/1024));mat.set_shader_parameter("authored_base_light",0)
    var entry={"node":node,"material":mat,"actor_layer":{"slot":"helmet"},"placement":{"scale_x":1},"scale":2.0}
    var light=OmniLight3D.new();light.omni_range=.04;light.light_energy=.02;light.shadow_enabled=false;view.add_child(light)
    var cases=[]
    for quarter in range(4):
        var yaw=Basis(Vector3.UP,quarter*PI*.5)
        var right=yaw*Vector3(1,0,-1).normalized();var toward=yaw*Vector3(1,0,1).normalized()
        camera.basis=Basis(right,Vector3.UP*cos(PI/6)-toward*sin(PI/6),toward*cos(PI/6)+Vector3.UP*sin(PI/6))
        node.basis=camera.basis;camera.position=node.basis*node.mesh.center_offset+camera.basis.z*10
        Geometry.bind(entry,path,cache,texture)
        mat.set_shader_parameter("component_depth",extremum_texture)
        var bounds=node.custom_aabb
        # Source observation kernel45deg, selected integer source ray, no yaw
        # beyond rotating the camera world axes. The original quad stays87.
        var point=(right*(at.x-64)+Vector3.UP*sqrt(.5)*(96-(at.y%128)+d)+toward*sqrt(.5)*(d-(96-(at.y%128))))*2/Placement.PIXELS_PER_UNIT
        var normal_world=(right*n.x+Vector3.UP*sqrt(.5)*(n.y+n.z)+toward*sqrt(.5)*(n.z-n.y)).normalized()
        light.position=point+normal_world*.02
        check(camera.is_position_in_frustum(light.position),"q%d tiny native test light is inside the camera frustum"%quarter)
        var painted_world: AABB=node.global_transform*node.mesh.get_aabb()
        check(light.position.y-light.omni_range>painted_world.end.y,"q%d native light sphere is entirely outside the actual painted world AABB"%quarter)
        var lit=await capture(view)
        node.custom_aabb=node.mesh.get_aabb()
        var culled=await capture(view)
        node.custom_aabb=bounds
        var restored=await capture(view)
        var value=lit.get_pixel(64,64).get_luminance();var control=culled.get_pixel(64,64).get_luminance()
        check(value>.05 and control<.001,"q%d native light beyond painted quad reaches only expanded receiver bounds:lit=%f control=%f"%[quarter,value,control])
        check(restored.get_data()==lit.get_data(),"q%d restoring authored bounds restores exact native receiver pixels"%quarter)
        cases.append({"quarter":quarter,"lit":value,"quad_only":control,"pixel":[at.x,at.y],"receiver":str(point),"light":str(light.position)})
    var report={"checks":checks,"failures":failures,"cases":cases,"scope":"Explicit synthetic admitted depth-extremum on one supported original Head15 texel; source colour/normal/masks and painted geometry unchanged. Production decoder and expanded bounds receive native range0.04 light entirely beyond painted world AABB, all4quarters. No claim this extremum occurs naturally in Head15."}
    var file=FileAccess.open("res://generated/receiver_bounds_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    print("RECEIVER_BOUNDS_CHECKS ",JSON.stringify(report));view.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
