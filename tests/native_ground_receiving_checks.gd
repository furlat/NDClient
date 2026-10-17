extends "res://tests/native_light_output_checks.gd"
# A real floor through the production lit environment shader. Its connected-
# floor join mask comes from the ground_supports globals (GroundReceiving's
# texel = highest eligible terrain step per cell), as play.gd publishes them.
const Ground=preload("res://presentation/ground_receiving.gd")
func floor_fixture(quarter:int)->Dictionary:
    var probe=SourceProbe.new();root.add_child(probe);probe.hide()
    probe.camera=Camera3D.new();probe.add_child(probe.camera);probe.quarter=quarter
    var rotation=Basis(Vector3.UP,quarter*PI*.5)
    probe.camera.position=rotation*Vector3(12,12*Placement.HEIGHT_UNIT,12);probe.camera.look_at(Vector3.ZERO)
    var row={"id":"source-floor","kind":"terrain","material":"stone","position":[0,0],"base_height_steps":2,"layer":0,"orientation":"east","boundaries":[]}
    probe.add_entry(row,"terrain",0,probe.ENVIRONMENT_SHADER,1)
    var entry:Dictionary=probe.entries.back();probe.initialize_entry(entry)
    var material:ShaderMaterial=entry.material.duplicate()
    material.set_shader_parameter("ground_receiver",true)
    # The selected receiving packet may add admitted top detail. Classify the
    # original macro top from the unchanged geometry packet, then require the
    # entire selected top response to survive the separate join interpretation.
    var result={"id":"floor-q"+str(quarter),"material":material,"colour":probe.images[entry.record.path],"visible":1.0,"row":row,
        "original_geometry":probe.images[entry.record.geometry_region.path],"basis":probe.camera.basis,"mirror":false,"family":"environment"}
    probe.free();return result
# Supports keyed by grid cell; the lit quad sits at the world origin = cell (0,0).
func publish_supports(supports:Dictionary)->void:
    var low:=Vector2(INF,INF);var high:=-low
    for cell in supports:low=low.min(cell);high=high.max(cell)
    var size:=Vector2i(high-low)+Vector2i.ONE
    var image:=Image.create_empty(size.x,size.y,false,Image.FORMAT_RF);image.fill(Color(-1e30,0,0))
    for cell in supports:image.set_pixelv(Vector2i(cell-low),Color(float(supports[cell]),0,0))
    RenderingServer.global_shader_parameter_set(&"ground_supports",ImageTexture.create_from_image(image))
    RenderingServer.global_shader_parameter_set(&"ground_supports_rect",Vector4(low.x,low.y,size.x,size.y))
func neighbours(own:float,value:float)->Dictionary:
    return {Vector2.ZERO:own,Vector2(1,0):value,Vector2(0,1):value,Vector2(-1,0):value,Vector2(0,-1):value}
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var one=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE);white=ImageTexture.create_from_image(one);cookie=light_cookie()
    DirAccess.make_dir_recursive_absolute("res://.captures/ground-receiving")
    for quarter in 4:
        var fixture=floor_fixture(quarter)
        var lights:Array=output_lights(fixture,1,56,1,.8)
        publish_supports({Vector2.ZERO:2.0})
        check(Ground.mask(fixture.row,{})==0,"An isolated floor has no published neighbours q"+str(quarter))
        var before:Image=await lit_receiving(fixture,lights)
        var joins={Vector2(1,0):2,Vector2(0,1):2,Vector2(-1,0):2,Vector2(0,-1):2}
        check(Ground.mask(fixture.row,joins)==15,"Equal neighbours join every side q"+str(quarter))
        publish_supports(neighbours(2.0,2.0))
        var after:Image=await lit_receiving(fixture,lights)
        var delta=compare(before,after)
        check(delta.changed_pixels>0,"Connected lit floor removes independently lit interior skirt q"+str(quarter))
        check(delta.alpha_mismatches==0,"Connected lit floor retains exact original alpha q"+str(quarter))
        var top_changes=0;var top_pixels=0
        var size:Vector2i=fixture.colour.get_size()
        for y in size.y:
            for x in size.x:
                var packet:Color=fixture.original_geometry.get_pixel(x,y)
                if fixture.colour.get_pixel(x,y).a>0 and packet.b8==128 and packet.a8==255:
                    top_pixels+=1
                    if before.get_pixel(x,y)!=after.get_pixel(x,y):top_changes+=1
        check(top_pixels>1000 and top_changes==0,"All original top-plane pixels remain byteexact q"+str(quarter))
        check(Ground.mask(fixture.row,{Vector2(1,0):0,Vector2(0,1):0,Vector2(-1,0):0,Vector2(0,-1):0})==0,"Lower neighbours join no side q"+str(quarter))
        publish_supports(neighbours(2.0,0.0))
        var elevated:Image=await lit_receiving(fixture,lights)
        check(compare(before,elevated).changed_pixels==0,"Raised floor above lower neighbours keeps exposed returns byteexact q"+str(quarter))
        before.save_png("res://.captures/ground-receiving/q%d-exposed.png"%quarter);after.save_png("res://.captures/ground-receiving/q%d-connected.png"%quarter)
        cases.append({"quarter":quarter,"difference":delta,"top_pixels":top_pixels,"top_changed":top_changes,"raised_difference":compare(before,elevated)})
    var report={"checks":checks,"failures":failures,"cases":cases,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),
        "scope":"Actual stone floor, four quarters, production lit environment shader: the ground_supports globals select the join mask (isolated / equal neighbours / lower neighbours)."}
    FileAccess.open("res://generated/native_ground_receiving_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("NATIVE_GROUND_RECEIVING ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
