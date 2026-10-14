extends SceneTree
## Native cookie calibration only: projected support circles and an independent
## unscaled white-cookie light prove the original optical normal response.
const Lighting=preload("res://presentation/lighting_2d.gd")
const Placement=preload("res://placement.gd")
const Shadows=preload("res://presentation/canvas_shadows.gd")
var checks=0
var failures:Array=[]
var cases:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("LIGHT_PROJECTION_FAIL ",label)
func _initialize()->void:run.call_deferred()
func receiver()->SubViewport:
    var view=SubViewport.new();view.size=Vector2i(384,384);view.disable_3d=true;view.use_hdr_2d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var ambient=CanvasModulate.new();ambient.color=Color.BLACK;view.add_child(ambient)
    var surface=ColorRect.new();surface.size=view.size
    var shader=Shader.new();shader.code="shader_type canvas_item; render_mode blend_disabled; void fragment(){COLOR=vec4(1.0); NORMAL=normalize(vec3(0.3,-0.4,0.8));}"
    var material=ShaderMaterial.new();material.shader=shader;surface.material=material;view.add_child(surface)
    return view
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var actual=receiver();var reference=receiver()
    var projection=SubViewport.new();projection.size=actual.size;root.add_child(projection)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;projection.add_child(camera)
    var adapter=Lighting.new();adapter.attach(actual)
    var source={"item_uuid":"calibration","item_id":"equipment.portable_torch","actor_uuid":"actor", "base_height_steps":0.0,
        "position":Vector3.ZERO,"very_bright_radius_feet":10.0,"bright_radius_feet":20.0,"dim_radius_feet":20.0,"very":2.0,"bright":4.0,"outer":8.0}
    adapter.sources=[source];adapter._source_colours[source.item_uuid]=Lighting.TORCH_COLOUR;adapter._sync_pages()
    var white=Image.create(256,256,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE)
    var native_control=PointLight2D.new();native_control.texture=ImageTexture.create_from_image(white)
    native_control.texture_scale=8;native_control.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;reference.add_child(native_control)
    DirAccess.make_dir_recursive_absolute("res://.captures/light-projection")
    for quarter in 4:
        for zoom in [24.0,32.0]:
            for steps in [0.0,3.5]:
                var support=Vector3(3.25,steps*Placement.HEIGHT_UNIT,-2.5)
                var optical=support+Vector3.UP*2.5*Placement.HEIGHT_UNIT
                # The displayed supporting height is independent of the admitted
                # source boundary and of visual/optical source lift.
                source.base_height_steps=0.0
                adapter.sampled={source.item_uuid:{"position":optical,"support_height_steps":steps,"energy":2.0}}
                camera.size=zoom;camera.position=support+Basis(Vector3.UP,quarter*PI*.5)*Vector3(12,12*Placement.HEIGHT_UNIT,12)
                camera.look_at(support);adapter.project(camera)
                var exposure:Dictionary=adapter.canvas_sources()[0]
                var node:PointLight2D=adapter.nodes[source.item_uuid]
                native_control.position=camera.unproject_position(optical);native_control.height=node.height
                native_control.energy=node.energy;native_control.color=node.color
                check(exposure.cookie_position.is_equal_approx(camera.unproject_position(support)),"Cookie follows displayed support at q%d size%d h%.1f"%[quarter,zoom,steps])
                check(node.position.is_equal_approx(native_control.position) and node.height==native_control.height and native_control.scale==Vector2.ONE,"Native optical origin/height match unscaled control")
                var texture:Image=node.texture.get_image()
                await process_frame;await RenderingServer.frame_post_draw
                var lit=actual.get_texture().get_image();var flat=reference.get_texture().get_image()
                var maximum=0.0;var lit_samples=0;var outside=0
                for ratio in [0.0,.25,.5,.8,1.05]:
                    for octant in 8:
                        var angle=octant*TAU/8.0
                        var point=support+Vector3(cos(angle),0,sin(angle))*source.outer*ratio
                        var projected=camera.unproject_position(point)
                        var uv=(projected-exposure.cookie_position)/exposure.span+Vector2.ONE*.5
                        check(absf((uv-Vector2.ONE*.5).length()*2.0-ratio)<.00002,"Projected support radius agrees at every direction")
                        var pixel=Vector2i(projected.floor())
                        if not Rect2i(Vector2i.ZERO,lit.get_size()).has_point(pixel):continue
                        var sample_uv=(Vector2(pixel)+Vector2.ONE*.5-exposure.cookie_position)/exposure.span+Vector2.ONE*.5
                        var attenuation=Shadows._cookie_at(texture,sample_uv)
                        var expected=flat.get_pixelv(pixel)*attenuation
                        var color=lit.get_pixelv(pixel)
                        maximum=maxf(maximum,maxf(absf(color.r-expected.r),maxf(absf(color.g-expected.g),absf(color.b-expected.b))))
                        check(color.a==1.0,"Native cookie keeps receiver alpha")
                        if ratio==1.05:
                            outside+=1;check(color.r==0 and color.g==0 and color.b==0,"Beyond support radius native cookie contributes zero")
                        elif ratio==.25:lit_samples+=int(color.r>0.01)
                # RGBA16F readbacks introduce at most the native half-float
                # rounding of the two independent light renders (<.004 here).
                check(maximum<.004,"Native normals/color remain the independent white-light response times cookie")
                check(lit_samples==8 and outside==8,"All directions visibly lit inside and dark outside")
                cases.append({"quarter":quarter,"camera_size":zoom,"support_height_steps":steps,"maximum_linear_rgb_error":maximum,
                    "optical_position":str(node.position),"cookie_position":str(exposure.cookie_position),"span":str(exposure.span)})
                if zoom==24 and steps==3.5:lit.save_png("res://.captures/light-projection/q%d-support.png"%quarter)
    # Existing demo/legacy callers deliberately retain their original screen cookie.
    var profile=adapter.range_profile
    var saved_cookie=adapter.nodes[source.item_uuid].texture
    adapter.range_profile=null;adapter.cookie=saved_cookie;adapter._sync_pages();adapter.project(camera)
    var legacy:PointLight2D=adapter.nodes[source.item_uuid]
    var legacy_row:Dictionary=adapter.canvas_sources()[0]
    check(legacy.scale==Vector2.ONE and legacy.offset==Vector2.ZERO and not legacy_row.has("cookie_position"),"Legacy external cookie keeps original screen placement/scale")
    check(is_equal_approx(legacy_row.span.x,legacy_row.span.y),"Legacy receiving-plane cookie remains circular")
    adapter.range_profile=profile;adapter._sync_pages();adapter.project(camera)
    var shadows=Shadows.new()
    check(shadows._prepare_sources(adapter.canvas_sources()),"Generated-shadow source accepts calibrated cookie")
    var exposure:Dictionary=adapter.canvas_sources()[0]
    var packed=shadows._source_texture.get_image().get_pixel(0,0)
    check(Vector2(packed.r,packed.g).is_equal_approx(exposure.cookie_position) and Vector2(packed.b,packed.a).is_equal_approx(exposure.span),"Shadow composite samples the actual cookie ellipse/offset")
    check(shadows._sources[0].screen_position==exposure.screen_position,"Shadow projection retains original optical origin")
    var legacy_source=exposure.duplicate();legacy_source.erase("cookie_position")
    check(shadows._prepare_sources([legacy_source]) and shadows._sources[0].cookie_position==legacy_source.screen_position,"Legacy shadow fixture defaults cookie center to optical position")
    adapter.clear_pages();native_control.queue_free()
    actual.queue_free();reference.queue_free();projection.queue_free();await process_frame
    var report={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"cases":cases,
        "scope":"Native PointLight2D projected cookie over source support plane,4quarters/2zooms/2heights. Independent unscaled white-cookie native light proves unchanged optical normal/color response. Source radius/alpha/outside coverage, shadow cookie packing, legacy demo fallback. No wall occlusion, category-from-RGB or multi-height world-membership claim."}
    FileAccess.open("res://generated/light_projection_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("LIGHT_PROJECTION ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
