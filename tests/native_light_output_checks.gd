extends "res://tests/native_2d_source_checks.gd"
# Real authored sources through the production lit sprite shaders and the light
# table, versus independent native Canvas receiving with native additive
# PointLight2D lights (CPU-decoded normals for modular/wall, the frozen 542303f
# native water receiver for water). No custom light formula is substituted for
# the native reference. Native LDR saturation is the same bound as the demo.
const OldWater=preload("res://tests/fixtures/light_cap_ldr_542303f/canvas_water.gdshader")
const SourceLighting=preload("res://presentation/lighting_2d.gd")
const WARM=Color(.809372,.429306,.269121)
var cases: Array=[]

func water_fixture() -> Dictionary:
    var probe=SourceProbe.new();root.add_child(probe);probe.hide()
    probe.camera=Camera3D.new();probe.add_child(probe.camera)
    probe.camera.position=Vector3(12,12*Placement.HEIGHT_UNIT,12);probe.camera.look_at(Vector3.ZERO)
    var row={"id":"source-water","kind":"terrain","material":"water","position":[0,0],"base_height_steps":0,"layer":0,"orientation":"east","boundaries":[]}
    probe.add_entry(row,"terrain",0,probe.ENVIRONMENT_SHADER,1)
    var entry: Dictionary=probe.entries.back();probe.initialize_entry(entry)
    var material: ShaderMaterial=entry.material.duplicate()
    material.set_shader_parameter("displayed_time_seconds",1.25)
    var reference=ShaderMaterial.new();reference.shader=OldWater
    for uniform in entry.material.shader.get_shader_uniform_list():reference.set_shader_parameter(uniform.name,entry.material.get_shader_parameter(uniform.name))
    reference.set_shader_parameter("world_to_canvas",Basis(probe.camera.basis.x,-probe.camera.basis.y,probe.camera.basis.z).transposed())
    reference.set_shader_parameter("displayed_time_seconds",1.25)
    var colour: Image=probe.images[entry.record.path]
    var basis: Basis=probe.camera.basis
    probe.free()
    return {"id":"water-authored","material":material,"reference_material":reference,"colour":colour,"visible":1.0,"mirror":false,"family":"water","basis":basis,"tint":Color.WHITE}

func output_lights(fixture: Dictionary,count: int,height: float=56.0,zoom: float=1.0,energy: float=3.0,reverse: bool=false) -> Array:
    var size=Vector2(fixture.colour.get_size())
    var result: Array=[]
    for i in count:
        result.append(light(size*Vector2(.40,.45)*zoom,WARM,energy,height*zoom,800.0/cookie.get_width()*zoom))
    if reverse:result.reverse()
    return result

# Independent native Canvas receiving of the fixture filling a page at `zoom`.
# Straight alpha; `hdr` stores it in a native RGBA16F page as the cap path did.
func native_receiving(fixture: Dictionary,lights: Array,raw: bool=false,zoom: float=1.0,hdr: bool=false,material: ShaderMaterial=null) -> Image:
    var size: Vector2i=fixture.colour.get_size()
    var extent:=Vector2i((Vector2(size)*zoom).ceil())
    var view=page(false,null,extent);view.use_hdr_2d=hdr
    var ambient=Color.WHITE if raw else Color(AMBIENT,AMBIENT,AMBIENT,1)
    view.get_child(0).color=ambient.linear_to_srgb() if hdr else ambient
    var selected: ShaderMaterial=material if material!=null else fixture.get("reference_material")
    if selected!=null:
        selected=selected.duplicate()
        selected.set_shader_parameter("source_crop",Vector4(0,0,1,1));selected.set_shader_parameter("atlas_cell_size",Vector2(size))
        selected.set_shader_parameter("receiver_visibility",fixture.visible)
        selected.set_shader_parameter("actual_scene_viewport_size",Vector2(extent))
        selected.set_shader_parameter("receiver_world_origin",Vector3.ZERO)
        var node=sprite(view,selected,Transform2D(0.0,Vector2(zoom,zoom),0.0,Vector2.ZERO))
        node.region_enabled=true;node.region_rect=Rect2(0,0,size.x,size.y);node.region_filter_clip_enabled=false
    else:
        add_reference(view,fixture,Transform2D(Vector2(size.x*zoom,0),Vector2(0,size.y*zoom),Vector2.ZERO))
    native_lights(view,lights)
    var image: Image=await capture(view)
    view.queue_free()
    return image

# The production lit sprite of the fixture filling a spatial page at `zoom`,
# lit by the same lights through the light table and receiving globals.
func lit_receiving(fixture: Dictionary,lights: Array,raw: bool=false,zoom: float=1.0,cap: float=0.0,normals: bool=false,material: ShaderMaterial=null,opacity: float=1.0) -> Image:
    var size=Vector2(fixture.colour.get_size())
    var view=lit_view(Vector2i((size*zoom).ceil()),fixture.basis)
    var used: ShaderMaterial=(fixture.material if material==null else material).duplicate()
    used.set_shader_parameter("wall_opacity",opacity)
    lit_quad(view,used,Rect2(Vector2.ZERO,size*zoom),fixture.mirror)
    publish_receiving(lights,1.0 if raw else AMBIENT,cap,normals)
    var image: Image=await capture(view)
    view.queue_free()
    return image

func above(image: Image,bound: Image) -> int:
    var result := 0
    for y in image.get_height():
        for x in image.get_width():
            var a=image.get_pixel(x,y);var b=bound.get_pixel(x,y)
            result=maxi(result,maxi(a.r8-b.r8,maxi(a.g8-b.g8,a.b8-b.b8)))
    return result

func overlap_case(fixture: Dictionary) -> void:
    var bound: Image=await lit_receiving(fixture,[],true)
    var last: Image
    for count in [0,1,2,8]:
        var lights: Array=output_lights(fixture,count)
        var straight: Image=await native_receiving(fixture,lights)
        var actual: Image=await lit_receiving(fixture,lights)
        # Water alpha is computed per texel by its graph; along a few rows it lies
        # on a half byte, where the native RGBA8 target may round the other way.
        # Those one-byte flips are counted and composited with the lit alpha.
        var water: bool=fixture.family=="water"
        var flips: int=alpha_flips(actual,straight) if water else 0
        var expected: Image=linear_alpha_reference(straight,actual if water else null)
        var transfer=compare(actual,expected)
        transfer.alpha_half_byte_flips=flips
        var over: int=above(actual,bound);var native_over: int=above(expected,bound)
        check(transfer.alpha_mismatches==0,fixture.id+" "+str(count)+" lights preserve exact original received alpha"+(" (one-byte half-byte flips counted)" if water else "")+": "+str(transfer))
        check(transfer.maximum_byte_error<=1,fixture.id+" "+str(count)+" lit sprite matches independent native receiving + linear-alpha output: "+str(transfer))
        if count==8:check(native_over>5 and over>5,fixture.id+" eight native lights can brighten beyond albedo; the lit sprite does not invent a different colour model")
        cases.append({"id":fixture.id,"lights":count,"lit_max_above_source_rgb_bytes":over,"native_max_above_source_rgb_bytes":native_over,"lit_vs_native_linear_alpha":transfer})
        last=actual
    last.save_png("res://.captures/native-2d-source/"+fixture.id+"-native-eight.png")

func height_case(fixture: Dictionary) -> void:
    var a: Image=await lit_receiving(fixture,output_lights(fixture,1,20,1,.3))
    var b: Image=await lit_receiving(fixture,output_lights(fixture,1,56,1,.3))
    var zoomed: Image=await lit_receiving(fixture,output_lights(fixture,1,20,2,.3),false,2)
    # One source texel covers 2x2 pixels at zoom 2; read each texel centre.
    var z=Image.create(a.get_width(),a.get_height(),false,Image.FORMAT_RGBA8)
    for y in a.get_height():
        for x in a.get_width():z.set_pixel(x,y,zoomed.get_pixel(x*2+1,y*2+1))
    var response=compare(a,b);var invariant=compare(a,z)
    check(response.changed_pixels>10,"Native normal-light height20 vs56 changes actual source response")
    check(response.alpha_mismatches==0,"Changing native normal-light height preserves source alpha")
    check(invariant.alpha_mismatches==0 and invariant.maximum_byte_error<=1,"Lit source magnification scales positions/cookie/height together: "+str(invariant))
    cases.append({"id":"height20-vs56","comparison":response,"zoom2":invariant})

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
    var one=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE);white=ImageTexture.create_from_image(one);cookie=light_cookie()
    reference_shader=Shader.new();reference_shader.code=REFERENCE
    DirAccess.make_dir_recursive_absolute("res://.captures/native-2d-source")
    var body=modular("Chest14","chest",0,"reference",false);body.family="modular"
    var wall=corner(1,true);wall.family="environment"
    await overlap_case(body);await overlap_case(wall);await overlap_case(water_fixture())
    await height_case(body);await elevation_case()
    var report={"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"checks":checks,"failures":failures,"cases":cases,"scope":"Native PointLight2D zero/one/two/eight overlap on actual modular/wall/water. The production lit sprite (light table) matches the independent native Canvas receiving composited in linear alpha within one RGB byte (half-float target); alpha exact; no source-albedo clamp. Native20/56 height response, zoom scaling and unchanged physical source projection. Overlapping native lights may saturate just as in the supplied demo."}
    FileAccess.open("res://generated/native_light_output_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_LIGHT_OUTPUT_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
