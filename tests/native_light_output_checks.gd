extends "res://tests/native_2d_source_checks.gd"
# Real authored receivers, native additive lights, and production spatial output.
# No custom light formula is substituted for native rendering.
# Native LDR framebuffer saturation is the same bound used by the source demo.
const PassThrough=preload("res://presentation/canvas_received.gdshader")
const SourceLighting=preload("res://presentation/lighting_2d.gd")
var cases: Array=[]

func water_fixture() -> Dictionary:
    var probe=SourceProbe.new();root.add_child(probe);probe.hide()
    probe.camera=Camera3D.new();probe.add_child(probe.camera)
    probe.camera.position=Vector3(12,12*Placement.HEIGHT_UNIT,12);probe.camera.look_at(Vector3.ZERO)
    var row={"id":"source-water","kind":"terrain","material":"water","position":[0,0],"base_height_steps":0,"layer":0,"orientation":"east","boundaries":[]}
    probe.add_entry(row,"terrain",0,probe.ENVIRONMENT_SHADER,1)
    var entry: Dictionary=probe.entries.back();probe.initialize_entry(entry)
    var material=ShaderMaterial.new();material.shader=load("res://presentation/canvas_water.gdshader")
    for uniform in entry.material.shader.get_shader_uniform_list():material.set_shader_parameter(uniform.name,entry.material.get_shader_parameter(uniform.name))
    material.set_shader_parameter("world_to_canvas",Basis(probe.camera.basis.x,-probe.camera.basis.y,probe.camera.basis.z).transposed())
    material.set_shader_parameter("displayed_time_seconds",1.25)
    var colour: Image=probe.images[entry.record.path]
    probe.free()
    return {"id":"water-authored","material":material,"colour":colour,"visible":1.0,"mirror":false,"family":"water"}

func receiving(fixture: Dictionary,count: int,raw: bool=false,height: float=56.0,zoom: float=1.0,light_energy: float=3.0) -> SubViewport:
    var size: Vector2i=fixture.colour.get_size()
    var view=page(false)
    view.get_child(0).color=Color.WHITE if raw else Color(.176419,.176419,.176419,1)
    var material: ShaderMaterial=fixture.material.duplicate()
    material.set_shader_parameter("source_crop",Vector4(0,0,1,1));material.set_shader_parameter("atlas_cell_size",Vector2(size))
    material.set_shader_parameter("receiver_visibility",fixture.visible)
    material.set_shader_parameter("actual_scene_viewport_size",Vector2(size)*zoom)
    material.set_shader_parameter("receiver_world_origin",Vector3.ZERO)
    var node=sprite(view,material,Transform2D(0.0,Vector2(zoom,zoom),0.0,Vector2.ZERO))
    node.region_enabled=true;node.region_rect=Rect2(0,0,size.x,size.y);node.region_filter_clip_enabled=false
    for i in count:
        var light=PointLight2D.new();light.texture=cookie;light.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
        light.position=Vector2(size)*Vector2(.40,.45)*zoom;light.height=height*zoom
        light.texture_scale=800.0/cookie.get_width()*zoom;light.energy=light_energy
        light.color=Color(.809372,.429306,.269121);view.add_child(light)
    return view

func spatial(fixture: Dictionary,receiving_view: SubViewport) -> SubViewport:
    var size: Vector2i=fixture.colour.get_size()
    var view=SubViewport.new();view.size=size;view.own_world_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world_environment=WorldEnvironment.new();world_environment.environment=Environment.new();world_environment.environment.background_mode=Environment.BG_COLOR;world_environment.environment.background_color=Color(0,0,0,0);view.add_child(world_environment)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.0;camera.position=Vector3(0,0,3);view.add_child(camera)
    var material=ShaderMaterial.new();material.shader=PassThrough
    var accepted={}
    for uniform in material.shader.get_shader_uniform_list():accepted[uniform.name]=true
    for uniform in fixture.material.shader.get_shader_uniform_list():
        if accepted.has(uniform.name):material.set_shader_parameter(uniform.name,fixture.material.get_shader_parameter(uniform.name))
    material.set_shader_parameter("received",receiving_view.get_texture());material.set_shader_parameter("atlas_region",Vector4(0,0,float(size.x)/512,float(size.y)/512))
    material.set_shader_parameter("current_visibility",fixture.visible)
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(2,2);node.material_override=material;view.add_child(node)
    return view

func direct_output(fixture:Dictionary,receiving_view:SubViewport)->SubViewport:
    var view=page(false);view.size=fixture.colour.get_size()
    var node=Sprite2D.new();node.texture=receiving_view.get_texture();node.centered=false
    node.region_enabled=true;node.region_rect=Rect2(Vector2.ZERO,Vector2(view.size))
    node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    var material=CanvasItemMaterial.new();material.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
    node.material=material;view.add_child(node);return view

# Independent native straight-alpha reference over the transparent black target.
# Forward+/Mobile blend in linear space, then encode; non-HDRCanvas and GLES
# spatial output blend encoded colour. This changes fringe appearance, not alpha.
func linear_alpha_reference(straight:Image)->Image:
    var expected=Image.create(straight.get_width(),straight.get_height(),false,Image.FORMAT_RGBA8)
    for y in straight.get_height():
        for x in straight.get_width():
            var source=straight.get_pixel(x,y)
            var value=source.srgb_to_linear()
            value.r*=source.a;value.g*=source.a;value.b*=source.a
            value=value.linear_to_srgb();value.a=source.a
            expected.set_pixel(x,y,value)
    return expected

func overlap_case(fixture: Dictionary) -> void:
    var raw=receiving(fixture,0,true);var raw_output=spatial(fixture,raw)
    var bound=await capture(raw_output)
    var last: Image
    for count in [0,1,2,8]:
        var atlas=receiving(fixture,count)
        var output=spatial(fixture,atlas);var before=direct_output(fixture,atlas)
        var actual=await capture(output);var previous=await capture(before)
        var straight=(await capture(atlas)).get_region(Rect2i(Vector2i.ZERO,fixture.colour.get_size()))
        var linear=RenderingServer.get_current_rendering_method()!="gl_compatibility"
        var expected=linear_alpha_reference(straight) if linear else previous
        var alpha:=0;var over:=0;var native_over:=0
        for y in actual.get_height():
            for x in actual.get_width():
                var a=actual.get_pixel(x,y);var b=bound.get_pixel(x,y);var p=previous.get_pixel(x,y)
                if a.a8!=p.a8:alpha+=1
                over=maxi(over,maxi(a.r8-b.r8,maxi(a.g8-b.g8,a.b8-b.b8)))
                native_over=maxi(native_over,maxi(p.r8-b.r8,maxi(p.g8-b.g8,p.b8-b.b8)))
        check(alpha==0,fixture.id+" "+str(count)+" lights preserve exact original received alpha")
        var transfer=compare(actual,expected)
        check(transfer.alpha_mismatches==0 and (transfer.maximum_byte_error<=1 if linear else transfer.changed_pixels==0),fixture.id+" "+str(count)+" spatial output matches independent native blend-space reference: "+str(transfer))
        if count==0:check(transfer.maximum_byte_error<=1 if linear else transfer.changed_pixels==0,fixture.id+" dim ambient appearance retains independent native output")
        if count==8:check(native_over>5,fixture.id+" eight native lights can brighten beyond albedo; final output does not invent a different colour model")
        cases.append({"id":fixture.id,"lights":count,"alpha_mismatches":alpha,"max_above_source_rgb_bytes":over,"native_max_above_source_rgb_bytes":native_over,"spatial_vs_direct_canvas":compare(actual,previous),"spatial_vs_native_blend_reference":transfer,"expected_blend_space":"linear" if linear else "encoded"})
        last=actual
        output.queue_free();before.queue_free();atlas.queue_free();await process_frame
    last.save_png("res://.captures/native-2d-source/"+fixture.id+"-native-eight.png")
    raw_output.queue_free();raw.queue_free();await process_frame

func height_case(fixture: Dictionary) -> void:
    var low=receiving(fixture,1,false,20,1,.3);var high=receiving(fixture,1,false,56,1,.3);var zoomed=receiving(fixture,1,false,20,2,.3)
    var size: Vector2i=fixture.colour.get_size()
    var a=(await capture(low)).get_region(Rect2i(Vector2i.ZERO,size));var b=(await capture(high)).get_region(Rect2i(Vector2i.ZERO,size));var z=(await capture(zoomed)).get_region(Rect2i(Vector2i.ZERO,size))
    var response=compare(a,b);var invariant=compare(a,z)
    check(response.changed_pixels>10,"Native normal-light height20 vs56 changes actual source response")
    check(response.alpha_mismatches==0,"Changing native normal-light height preserves source alpha")
    check(invariant.alpha_mismatches==0 and invariant.maximum_byte_error<=1,"Native source magnification scales positions/cookie/height together: "+str(invariant))
    cases.append({"id":"height20-vs56","comparison":response,"zoom2":invariant})
    low.queue_free();high.queue_free();zoomed.queue_free();await process_frame

func elevation_case() -> void:
    var view=SubViewport.new();view.size=Vector2i(256,256);root.add_child(view)
    var world_environment=WorldEnvironment.new();world_environment.environment=Environment.new();world_environment.environment.background_mode=Environment.BG_COLOR;world_environment.environment.background_color=Color(0,0,0,0);view.add_child(world_environment)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=10;camera.position=Vector3(12,12*Placement.HEIGHT_UNIT,12);view.add_child(camera);camera.look_at(Vector3.ZERO)
    var lights=SourceLighting.new()
    var source={"item_uuid":"test-height","actor_uuid":"","outer":4.0,"base_height_steps":0.0,"very_bright_radius_feet":0.0,"bright_radius_feet":10.0,"dim_radius_feet":10.0}
    lights.sources=[source];lights.sampled={"test-height":{"position":Vector3.ZERO,"energy":2.0}}
    lights.attach(view);lights.project(camera)
    var zero=lights.canvas_sources()[0].duplicate();var elevated=Vector3(0,2*Placement.HEIGHT_UNIT,0)
    lights.sampled["test-height"].position=elevated;lights.project(camera)
    var raised=lights.canvas_sources()[0]
    check(raised.screen_position.is_equal_approx(camera.unproject_position(elevated)) and not raised.screen_position.is_equal_approx(zero.screen_position),"Source world elevation projects to its actual screen anchor")
    check(is_equal_approx(raised.height,zero.height),"World elevation does not silently replace fixed-reference56px native normal-light convention")
    lights.clear_pages();view.queue_free();await process_frame

func run() -> void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var one=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE);white=ImageTexture.create_from_image(one);cookie=texture(COOKIE)
    var body=modular("Chest14","chest",0,"reference",false);body.family="modular"
    var wall=corner(1,true);wall.family="environment"
    await overlap_case(body);await overlap_case(wall);await overlap_case(water_fixture())
    await height_case(body);await elevation_case()
    var report={"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"checks":checks,"failures":failures,"cases":cases,"scope":"Native PointLight2D zero/one/two/eight overlap on actual modular/wall/water. Final3D output matches an independent linear-alpha oracle in Forward+/Mobile within1RGBbyte of half-float framebuffer quantization; Compatibility matches directCanvas byte exactly. Alpha is exact; no source-albedo clamp. The encodedCanvas comparison remains a separate diagnostic. Native20/56 height response, zoom scaling and unchanged physical source projection. Overlapping native lights may saturate just as in the supplied demo."}
    FileAccess.open("res://generated/native_light_output_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_LIGHT_OUTPUT_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
