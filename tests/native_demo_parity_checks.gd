extends "res://tests/native_light_output_checks.gd"
# Direct reference uses the supplied demo shader, never the atlas/final transfer.
const DEMO="C:/Users/tommaso/Documents/Dev/NDCharacterLight/render/modular_2d.gdshader"
var rows:Array=[]
var address:=Vector2i(8003,29)
var atlas_extent:=Vector2i(8192,1024)
func direct(fixture:Dictionary,zoom:float,offset:Vector2,lit:bool)->SubViewport:
    var view=SubViewport.new();view.size=Vector2i(768,768);view.disable_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    view.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(view)
    var ambient=CanvasModulate.new();ambient.color=Color(.176419,.176419,.176419,1) if lit else Color.WHITE;view.add_child(ambient)
    var mat=ShaderMaterial.new();var shader=Shader.new();shader.code=FileAccess.get_file_as_string(DEMO);mat.shader=shader
    var names={}
    for u in shader.get_shader_uniform_list():names[u.name]=true
    for u in fixture.material.shader.get_shader_uniform_list():
        if names.has(u.name):mat.set_shader_parameter(u.name,fixture.material.get_shader_parameter(u.name))
    var node=Sprite2D.new();node.texture=fixture.material.get_shader_parameter("sheet");node.hframes=15;node.vframes=8;node.centered=false;node.position=offset;node.scale=Vector2.ONE*zoom;node.material=mat;view.add_child(node)
    if lit: add_light(view,offset+Vector2(64,87)*zoom,zoom)
    return view
func add_light(view:SubViewport,foot:Vector2,zoom:float)->void:
    var l=PointLight2D.new();l.texture=cookie;l.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;l.position=foot+Vector2(14,42)*zoom;l.height=56*zoom;l.texture_scale=19.36*zoom;l.color=Color(.809372,.429306,.269121);l.energy=2.0;view.add_child(l)
func atlas_page(fixture:Dictionary,zoom:float,offset:Vector2,lit:bool)->SubViewport:
    var view=page(false);view.size=atlas_extent
    view.get_child(0).color=Color(.176419,.176419,.176419,1) if lit else Color.WHITE
    var crop:Rect2i=fixture.crop;var cell:Vector2=fixture.colour.get_size();var mat:ShaderMaterial=fixture.material.duplicate();mat.set_shader_parameter("source_crop",Vector4(crop.position.x/cell.x,crop.position.y/cell.y,crop.size.x/cell.x,crop.size.y/cell.y));mat.set_shader_parameter("atlas_cell_size",Vector2(crop.size));mat.set_shader_parameter("receiver_visibility",1.0)
    var node=sprite(view,mat,Transform2D(0,Vector2.ONE*zoom,0,offset+Vector2(crop.position)*zoom));node.region_enabled=true;node.region_rect=Rect2(Vector2(address),Vector2(crop.size));node.region_filter_clip_enabled=false
    if lit:add_light(view,offset+Vector2(64,87)*zoom,zoom)
    return view
func output(fixture:Dictionary,atlas:SubViewport,zoom:float,offset:Vector2)->SubViewport:
    var view=SubViewport.new();view.size=Vector2i(768,768);view.own_world_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var cam=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=768;cam.position.z=100;view.add_child(cam)
    var mat=ShaderMaterial.new();mat.shader=PassThrough
    var names={}
    for u in mat.shader.get_shader_uniform_list():names[u.name]=true
    for u in fixture.material.shader.get_shader_uniform_list():
        if names.has(u.name):mat.set_shader_parameter(u.name,fixture.material.get_shader_parameter(u.name))
    var cell:Vector2=fixture.colour.get_size();var crop:Rect2i=fixture.crop;mat.set_shader_parameter("source_crop",Vector4(crop.position.x/cell.x,crop.position.y/cell.y,crop.size.x/cell.x,crop.size.y/cell.y));mat.set_shader_parameter("received",atlas.get_texture());mat.set_shader_parameter("atlas_region",Vector4(float(address.x)/atlas_extent.x,float(address.y)/atlas_extent.y,float(crop.size.x)/atlas_extent.x,float(crop.size.y)/atlas_extent.y));mat.set_shader_parameter("current_visibility",1.0)
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=cell*zoom;node.position=Vector3(offset.x+cell.x*zoom*.5-384,384-offset.y-cell.y*zoom*.5,0);node.material_override=mat;view.add_child(node)
    if fixture.get("multimesh",false):
        var batch=MultiMeshInstance3D.new();var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true;multi.mesh=node.mesh;multi.instance_count=1;multi.set_instance_transform(0,node.transform);multi.set_instance_custom_data(0,Color(1,address.x%1024,address.y%1024,(address.x/1024)+8*(address.y/1024)));batch.multimesh=multi;batch.material_override=mat;mat.set_shader_parameter("use_instance_atlas",true);mat.set_shader_parameter("atlas_cell_size",Vector2(crop.size)/Vector2(atlas_extent));view.add_child(batch);node.hide()
    return view
func floor_fixture()->Dictionary:
    var probe=SourceProbe.new();root.add_child(probe);probe.hide();probe.camera=Camera3D.new();probe.add_child(probe.camera);probe.camera.position=Vector3(12,12*Placement.HEIGHT_UNIT,12);probe.camera.look_at(Vector3.ZERO)
    var row={"id":"source-floor","kind":"terrain","material":"stone","position":[0,0],"base_height_steps":0,"layer":0,"orientation":"east","boundaries":[]}
    probe.add_entry(row,"terrain",0,probe.ENVIRONMENT_SHADER,1);var e:Dictionary=probe.entries.back();probe.initialize_entry(e)
    var mat=ShaderMaterial.new();mat.shader=EnvironmentReceiver
    for u in e.material.shader.get_shader_uniform_list():mat.set_shader_parameter(u.name,e.material.get_shader_parameter(u.name))
    var r:Array=e.record.get("rect",[0,0,256,256]);var colour:Image=probe.images[e.record.path].get_region(Rect2i(r[0],r[1],r[2],r[3]));probe.free()
    return {"id":"floor-stone","family":"environment","material":mat,"colour":colour,"visible":1.0}
func case(fixture:Dictionary,zoom:float,offset:Vector2,lit:bool)->void:
    var atlas=atlas_page(fixture,zoom,offset,lit)
    var single=output(fixture,atlas,zoom,offset)
    var actual=await capture(single)
    var row={"id":fixture.id,"zoom":zoom,"offset":[offset.x,offset.y],"lit":lit,"atlas_address":[address.x,address.y]}
    var stem=fixture.id+"-"+str(zoom)+("-lit" if lit else "-raw")
    actual.save_png("res://.captures/demo-parity/"+stem+"-final3d.png")
    if fixture.family=="modular":
        var demo=direct(fixture,zoom,offset,lit)
        var expected=await capture(demo)
        row.demo_vs_final3d=compare(actual,expected)
        check(row.demo_vs_final3d.alpha_mismatches==0,"Final3D alpha equals direct supplied demo shader")
        check(row.demo_vs_final3d.maximum_byte_error<=3 if lit else row.demo_vs_final3d.changed_pixels==0,"Original unlit byte equality; native lit sampling/3D transfer bounded to observed3RGBbytes")
        expected.save_png("res://.captures/demo-parity/"+stem+"-demo.png")
        demo.queue_free()
    if fixture.family=="environment":
        fixture.multimesh=true
        var batch=output(fixture,atlas,zoom,offset)
        var batched=await capture(batch)
        row.batch_vs_single=compare(batched,actual)
        check(row.batch_vs_single.changed_pixels==0 and row.batch_vs_single.alpha_mismatches==0,"Native packed floor address equals full-precision single draw exactly")
        batched.save_png("res://.captures/demo-parity/"+stem+"-batch.png")
        fixture.erase("multimesh");batch.queue_free()
    rows.append(row)
    atlas.queue_free();single.queue_free();await process_frame
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);DirAccess.make_dir_recursive_absolute("res://.captures/demo-parity")
    var one=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE);white=ImageTexture.create_from_image(one);cookie=texture(COOKIE)
    var body=modular("Chest14","chest",0,"reference",false);body.family="modular";body.material.set_shader_parameter("layer_alpha",1.0);body.material.set_shader_parameter("tint",Vector3.ONE)
    body.crop=Rect2i(0,0,128,128)
    var floor_source=floor_fixture();floor_source.crop=floor_source.colour.get_used_rect()
    for zoom in [1.0,1.37,3.0]:
        await case(body,zoom,Vector2(91.37,83.23),false);await case(body,zoom,Vector2(91.37,83.23),true)
        await case(floor_source,zoom,Vector2(.37,.23),false)
    address=Vector2i(8003,7019);atlas_extent=Vector2i(8192,8192)
    await case(floor_source,1.37,Vector2(.37,.23),false)
    FileAccess.open("res://generated/native_demo_parity_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"rows":rows,"failures":failures,"scope":"Original demo directCanvas vs final3D RGBA; actual cropped floor Single vs MultiMesh odd farX and farY coordinates; no extra sourcealbedo cap. Lit transfer residual up to3RGBbytes explicitly retained."},"  "));print("DEMO_PARITY ",JSON.stringify({"checks":checks,"failures":failures,"rows":rows}));quit(0 if failures.is_empty() else 1)
