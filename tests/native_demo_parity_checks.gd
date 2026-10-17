extends "res://tests/native_light_output_checks.gd"
# Direct reference uses the supplied demo shader on a native Canvas page; the
# production side is the lit modular sprite (light table, spatial output).
# A real floor also draws as a one-instance MultiMesh and as a single quad.
const DEMO="C:/Users/tommaso/Documents/Dev/NDCharacterLight/render/modular_2d.gdshader"
const VIEW=Vector2i(768,768)
var rows:Array=[]
func direct(fixture:Dictionary,zoom:float,offset:Vector2,lit:bool)->SubViewport:
    var view=SubViewport.new();view.size=VIEW;view.disable_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    view.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(view)
    var ambient=CanvasModulate.new();ambient.color=Color(AMBIENT,AMBIENT,AMBIENT,1) if lit else Color.WHITE;view.add_child(ambient)
    var mat=ShaderMaterial.new();var shader=Shader.new();shader.code=FileAccess.get_file_as_string(DEMO);mat.shader=shader
    var names={}
    for u in shader.get_shader_uniform_list():names[u.name]=true
    for u in fixture.material.shader.get_shader_uniform_list():
        if names.has(u.name):mat.set_shader_parameter(u.name,fixture.material.get_shader_parameter(u.name))
    var node=Sprite2D.new();node.texture=fixture.material.get_shader_parameter("sheet");node.hframes=15;node.vframes=8;node.centered=false;node.position=offset;node.scale=Vector2.ONE*zoom;node.material=mat;view.add_child(node)
    if lit:native_lights(view,demo_lights(offset+Vector2(64,87)*zoom,zoom))
    return view
func demo_lights(foot:Vector2,zoom:float)->Array:
    return [light(foot+Vector2(14,42)*zoom,WARM,2.0,56*zoom,19.36*zoom)]
# The production lit sprite at the same placement and light.
func lit_output(fixture:Dictionary,zoom:float,offset:Vector2,lit:bool,batched:bool=false)->Image:
    var cell:Vector2=fixture.colour.get_size()
    var view=lit_view(VIEW,fixture.basis)
    var material:ShaderMaterial=fixture.material.duplicate()
    var node:MeshInstance3D=lit_quad(view,material,Rect2(offset,cell*zoom))
    if batched:
        # One terrain row as production batches it: per-instance transform and
        # visibility custom data; both forms receive the same join mask.
        var batch_material:ShaderMaterial=material.duplicate();batch_material.set_shader_parameter("use_instance_visibility",true)
        var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true;multi.mesh=node.mesh;multi.instance_count=1
        multi.set_instance_transform(0,node.transform);multi.set_instance_custom_data(0,Color(1,0,0,0))
        var batch=MultiMeshInstance3D.new();batch.multimesh=multi;batch.material_override=batch_material;view.add_child(batch);node.hide()
    publish_receiving(demo_lights(offset+Vector2(64,87)*zoom,zoom) if lit else [],AMBIENT if lit else 1.0)
    var image:Image=await capture(view)
    view.queue_free()
    return image
func floor_fixture()->Dictionary:
    var probe=SourceProbe.new();root.add_child(probe);probe.hide();probe.camera=Camera3D.new();probe.add_child(probe.camera);probe.camera.position=Vector3(12,12*Placement.HEIGHT_UNIT,12);probe.camera.look_at(Vector3.ZERO)
    var row={"id":"source-floor","kind":"terrain","material":"stone","position":[0,0],"base_height_steps":0,"layer":0,"orientation":"east","boundaries":[]}
    probe.add_entry(row,"terrain",0,probe.ENVIRONMENT_SHADER,1);var e:Dictionary=probe.entries.back();probe.initialize_entry(e)
    var mat:ShaderMaterial=e.material.duplicate();mat.set_shader_parameter("ground_receiver",true);mat.set_shader_parameter("current_visibility",1.0)
    var r:Array=e.record.get("rect",[0,0,256,256]);var colour:Image=probe.images[e.record.path].get_region(Rect2i(r[0],r[1],r[2],r[3]))
    var basis:Basis=probe.camera.basis;probe.free()
    return {"id":"floor-stone","family":"environment","material":mat,"colour":colour,"visible":1.0,"basis":basis,"mirror":false}
func case(fixture:Dictionary,zoom:float,offset:Vector2,lit:bool)->void:
    var actual:Image=await lit_output(fixture,zoom,offset,lit)
    var row={"id":fixture.id,"zoom":zoom,"offset":[offset.x,offset.y],"lit":lit}
    var stem=fixture.id+"-"+str(zoom)+("-lit" if lit else "-raw")
    actual.save_png("res://.captures/demo-parity/"+stem+"-final3d.png")
    if fixture.family=="modular":
        var demo=direct(fixture,zoom,offset,lit)
        var expected=await capture(demo)
        row.demo_vs_final3d=compare(actual,expected)
        check(row.demo_vs_final3d.alpha_mismatches==0,"Final3D alpha equals direct supplied demo shader "+stem)
        check(row.demo_vs_final3d.maximum_byte_error<=3 if lit else row.demo_vs_final3d.changed_pixels==0,"Original unlit byte equality; native lit sampling/3D transfer bounded to observed3RGBbytes "+stem+": "+str(row.demo_vs_final3d))
        expected.save_png("res://.captures/demo-parity/"+stem+"-demo.png")
        demo.queue_free()
    if fixture.family=="environment":
        var batched:Image=await lit_output(fixture,zoom,offset,lit,true)
        row.batch_vs_single=compare(batched,actual)
        check(row.batch_vs_single.changed_pixels==0 and row.batch_vs_single.alpha_mismatches==0,"Lit floor MultiMesh instance equals the single quad exactly "+stem)
        batched.save_png("res://.captures/demo-parity/"+stem+"-batch.png")
    rows.append(row)
    await process_frame
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);DirAccess.make_dir_recursive_absolute("res://.captures/demo-parity")
    var one=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE);white=ImageTexture.create_from_image(one);cookie=light_cookie()
    var body=modular("Chest14","chest",0,"reference",false);body.family="modular";body.material.set_shader_parameter("layer_alpha",1.0);body.material.set_shader_parameter("tint",Vector3.ONE)
    var floor_source=floor_fixture()
    for zoom in [1.0,1.37,3.0]:
        await case(body,zoom,Vector2(91.37,83.23),false);await case(body,zoom,Vector2(91.37,83.23),true)
        await case(floor_source,zoom,Vector2(.37,.23),false);await case(floor_source,zoom,Vector2(.37,.23),true)
    FileAccess.open("res://generated/native_demo_parity_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"rows":rows,"failures":failures,"scope":"Original demo directCanvas vs the lit modular sprite (final3D RGBA) at three zooms and a fractional offset; actual floor single quad vs one-instance MultiMesh, unlit and lit. Lit sampling residual up to3RGBbytes explicitly retained; no extra sourcealbedo cap."},"  "));print("DEMO_PARITY ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
