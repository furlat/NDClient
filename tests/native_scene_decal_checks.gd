extends SceneTree
## Native Decal projection on a painted floor, compared with a real PlaneMesh.
## This tests receiver coordinates; it does not qualify normal/ORM decal lighting.
const Output=preload("res://presentation/canvas_received.gdshader")
const Capped=preload("res://presentation/canvas_capped_modular.gdshader")
var checks=0
var failures:Array=[]
var measurements:Array=[]
var holders:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("NATIVE_SCENE_DECAL_FAIL ",label)
func _initialize()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    run.call_deferred()
func texture(colour:Color)->ImageTexture:
    var image=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(colour)
    return ImageTexture.create_from_image(image)
func world(kind:String)->Dictionary:
    var view=SubViewport.new();view.size=Vector2i(256,256);view.own_world_3d=true
    view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(view);holders.append(view)
    var camera=Camera3D.new();view.add_child(camera)
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4;camera.current=true
    var floor=MeshInstance3D.new();view.add_child(floor)
    var material=ShaderMaterial.new()
    if kind.begins_with("reference"):
        floor.mesh=PlaneMesh.new();floor.mesh.size=Vector2(64,64) if kind=="reference_control" else Vector2(32,32)
        var shader=Shader.new();shader.code="shader_type spatial; render_mode unshaded,cull_disabled; void fragment(){ALBEDO=vec3(1.); }"
        material.shader=shader
    else:
        floor.mesh=QuadMesh.new();floor.mesh.size=Vector2(4,4)
        material.shader=Capped if kind=="capped" else Output
        material.set_shader_parameter("received",texture(Color.WHITE))
        material.set_shader_parameter("atlas_region",Vector4(0,0,1,1))
        material.set_shader_parameter("source_quad_size",Vector2(4,4))
        material.set_shader_parameter("native_scene_enabled",true)
        material.set_shader_parameter("native_scene_plane",true)
        if kind=="capped":
            material.set_shader_parameter("sheet",texture(Color.WHITE))
            material.set_shader_parameter("frame_uv",Vector4(0,0,1,1))
            material.set_shader_parameter("light_cap",1.0)
    floor.material_override=material
    var decal=Decal.new();decal.size=Vector3(.9,2,.9);decal.cull_mask=1
    var image=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color(0,0,0,0))
    for y in 32:
        for x in 32:
            if Vector2(x-15.5,y-15.5).length()<13:
                image.set_pixel(x,y,Color(.8,.04,.02,1) if x<16 else Color(.02,.2,.8,1))
    decal.texture_albedo=ImageTexture.create_from_image(image)
    decal.upper_fade=0;decal.lower_fade=0;view.add_child(decal)
    return {"kind":kind,"view":view,"camera":camera,"floor":floor,"material":material,"decal":decal}
func draw()->void:
    await process_frame;await RenderingServer.frame_post_draw
    await process_frame;await RenderingServer.frame_post_draw
func compare(actual:Image,expected:Image,label:String,allowed_coverage:int=-1)->Dictionary:
    var changed=0;var largest=0;var coloured=0;var stable_changed=0;var mask_changed=0;var alpha_changed=0
    var errors={}
    for y in 256:
        for x in 256:
            var a=actual.get_pixel(x,y);var e=expected.get_pixel(x,y)
            var delta=maxi(maxi(abs(a.r8-e.r8),abs(a.g8-e.g8)),maxi(abs(a.b8-e.b8),abs(a.a8-e.a8)))
            if delta>0:
                changed+=1;largest=maxi(largest,delta);errors[str(delta)]=errors.get(str(delta),0)+1
                var constant=true
                for yy in range(maxi(y-1,0),mini(y+2,256)):
                    for xx in range(maxi(x-1,0),mini(x+2,256)):
                        if expected.get_pixel(xx,yy)!=e:constant=false
                if constant:stable_changed+=1
            var reference_covered=e.r8<245 or e.g8<245 or e.b8<245
            var actual_covered=a.r8<245 or a.g8<245 or a.b8<245
            if reference_covered:coloured+=1
            if reference_covered!=actual_covered:mask_changed+=1
            if a.a8!=e.a8:alpha_changed+=1
    measurements.append({"label":label,"different_pixels":changed,"max_byte_error":largest,"native_decal_pixels":coloured,
        "error_distribution":errors,"stable_region_differences":stable_changed,"coverage_differences":mask_changed,"alpha_differences":alpha_changed})
    check(coloured>100,label+": native decal visibly projected")
    check(stable_changed==0 and alpha_changed==0,label+": exact stable colour regions and alpha")
    if allowed_coverage>=0:
        check(mask_changed<=allowed_coverage,label+": footprint differs no more than the same-case native PlaneMesh control")
    return measurements.back()
func run()->void:
    DirAccess.make_dir_recursive_absolute("res://.captures/native-scene-decal")
    var reference=world("reference");var control=world("reference_control");var painted=world("painted");var capped=world("capped")
    for quarter in 4:
        var rotation=Basis(Vector3.UP,quarter*PI*.5)
        for state in [reference,control,painted,capped]:
            state.camera.position=rotation*Vector3(5,5,5);state.camera.look_at(Vector3.ZERO)
            if not state.kind.begins_with("reference"):state.floor.basis=state.camera.basis
        for x in [-.7,0.0,.7]:
            for state in [reference,control,painted,capped]:state.decal.position=Vector3(x,.1,.2)
            await draw()
            var expected:Image=reference.view.get_texture().get_image()
            var native_control=compare(control.view.get_texture().get_image(),expected,"reference_control quarter%d x%.1f"%[quarter,x])
            for state in [painted,capped]:
                var actual:Image=state.view.get_texture().get_image()
                compare(actual,expected,"%s quarter%d x%.1f"%[state.kind,quarter,x],native_control.coverage_differences)
                if quarter==0 and x==0:
                    actual.save_png("res://.captures/native-scene-decal/"+state.kind+".png")
            if quarter==0 and x==0:expected.save_png("res://.captures/native-scene-decal/reference.png")
    # No receiver flag is required by existing scenes. With no Decal, enabling
    # or disabling coordinates cannot change colour, alpha or lighting output.
    for state in [reference,control,painted,capped]:state.decal.visible=false
    await draw()
    var enabled:Image=painted.view.get_texture().get_image()
    painted.material.set_shader_parameter("native_scene_enabled",false)
    await draw()
    check(painted.view.get_texture().get_image().get_data()==enabled.get_data(),"No Decal: opt-in coordinates leave the painted output byte-exact")
    for view in holders:view.queue_free()
    await process_frame
    var report={"checks":checks,"failures":failures,"samples":measurements,
        "renderer":RenderingServer.get_current_rendering_method(),
        "scope":"Native moving albedo Decal on painted versus real flat floor; four quarters, capped and uncapped shared output. Exact stable colour/alpha; footprint bounded by the same-case native PlaneMesh extent control; filtered-edge RGB differences recorded. No whole-image byte parity or normal/ORM parity claim."}
    FileAccess.open("res://generated/native_scene_decal_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SCENE_DECAL ",JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
