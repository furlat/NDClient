extends "res://tests/native_light_output_checks.gd"
const Ground=preload("res://presentation/ground_receiving.gd")
func floor_fixture(quarter:int)->Dictionary:
    var probe=SourceProbe.new();root.add_child(probe);probe.hide()
    probe.camera=Camera3D.new();probe.add_child(probe.camera);probe.quarter=quarter
    var rotation=Basis(Vector3.UP,quarter*PI*.5)
    probe.camera.position=rotation*Vector3(12,12*Placement.HEIGHT_UNIT,12);probe.camera.look_at(Vector3.ZERO)
    var row={"id":"source-floor","kind":"terrain","material":"stone","position":[0,0],"base_height_steps":2,"layer":0,"orientation":"east","boundaries":[]}
    probe.add_entry(row,"terrain",0,probe.ENVIRONMENT_SHADER,1)
    var entry:Dictionary=probe.entries.back();probe.initialize_entry(entry)
    var material=ShaderMaterial.new();material.shader=EnvironmentReceiver
    for uniform in entry.material.shader.get_shader_uniform_list():material.set_shader_parameter(uniform.name,entry.material.get_shader_parameter(uniform.name))
    material.set_shader_parameter("world_to_canvas",Basis(probe.camera.basis.x,-probe.camera.basis.y,probe.camera.basis.z).transposed())
    # The selected receiving packet may add admitted top detail. Classify the
    # original macro top from the unchanged geometry packet, then require the
    # entire selected top response to survive the separate join interpretation.
    var result={"id":"floor-q"+str(quarter),"material":material,"colour":probe.images[entry.record.path],"visible":1.0,"row":row,"original_geometry":probe.images[entry.record.geometry_region.path]}
    probe.free();return result
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var one=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE);white=ImageTexture.create_from_image(one);cookie=texture(COOKIE)
    DirAccess.make_dir_recursive_absolute("res://.captures/ground-receiving")
    for quarter in 4:
        var fixture=floor_fixture(quarter)
        var isolated=receiving(fixture,1,false,56,1,.8)
        var before=(await capture(isolated)).get_region(Rect2i(0,0,256,256))
        var joins={Vector2(1,0):2,Vector2(0,1):2,Vector2(-1,0):2,Vector2(0,-1):2}
        fixture.material.set_shader_parameter("ground_join_mask",Ground.mask(fixture.row,joins))
        var connected=receiving(fixture,1,false,56,1,.8)
        var after=(await capture(connected)).get_region(Rect2i(0,0,256,256))
        var delta=compare(before,after)
        check(delta.changed_pixels>0,"Connected native floor removes independently lit interior skirt q"+str(quarter))
        check(delta.alpha_mismatches==0,"Connected native floor retains exact original alpha q"+str(quarter))
        var top_changes=0;var top_pixels=0
        for y in 256:
            for x in 256:
                var packet:Color=fixture.original_geometry.get_pixel(x,y)
                if fixture.colour.get_pixel(x,y).a>0 and packet.b8==128 and packet.a8==255:
                    top_pixels+=1
                    if before.get_pixel(x,y)!=after.get_pixel(x,y):top_changes+=1
        check(top_pixels>1000 and top_changes==0,"All original top-plane pixels remain byteexact q"+str(quarter))
        fixture.material.set_shader_parameter("ground_join_mask",Ground.mask(fixture.row,{Vector2(1,0):0,Vector2(0,1):0,Vector2(-1,0):0,Vector2(0,-1):0}))
        var raised=receiving(fixture,1,false,56,1,.8)
        var elevated=(await capture(raised)).get_region(Rect2i(0,0,256,256))
        check(compare(before,elevated).changed_pixels==0,"Raised floor above lower neighbours keeps exposed returns byteexact q"+str(quarter))
        before.save_png("res://.captures/ground-receiving/q%d-exposed.png"%quarter);after.save_png("res://.captures/ground-receiving/q%d-connected.png"%quarter)
        cases.append({"quarter":quarter,"difference":delta,"top_pixels":top_pixels,"top_changed":top_changes,"raised_difference":compare(before,elevated)})
        isolated.queue_free();connected.queue_free();raised.queue_free();await process_frame
    var report={"checks":checks,"failures":failures,"cases":cases,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name()}
    FileAccess.open("res://generated/native_ground_receiving_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("NATIVE_GROUND_RECEIVING ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
