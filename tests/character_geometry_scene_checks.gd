extends SceneTree
# Compare actual production materials, source frames and disclosed emitters with
# independently reconstructed source receivers under the same native Godot lights.
const Player = preload("res://play.tscn")
const Geometry = preload("res://presentation/character_geometry.gd")
const Placement = preload("res://placement.gd")
var checks = 0
var failures: Array = []
func check(ok: bool,label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("GEOMETRY_SCENE_FAIL ",label)
func linear(c: float) -> float: return c/12.92 if c<.04045 else pow((c+.055)/1.055,2.4)
func encoded(c: float) -> float: return c*12.92 if c<.0031308 else 1.055*pow(c,1.0/2.4)-.055
func native(c: float) -> float:
    return maxf(1.055*pow(c*(c*(c*.305306011+.682171111)+.012522878),.416666667)-.055,0)
func capture(viewport: SubViewport) -> Image:
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    return viewport.get_texture().get_image()
func has_colour(image:Image)->bool:
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var c=image.get_pixel(x,y)
            if c.r+c.g+c.b>.001:return true
    return false
func _initialize() -> void: run.call_deferred()
func run() -> void:
    root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    var scene = Player.instantiate(); scene.timeline.paused = true; root.add_child(scene)
    var deadline = Time.get_ticks_msec()+90000
    while not scene.session.recording_ready and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    while not scene._media_ready({}) and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline: await scene.presentation_updated
    check(scene._media_ready({}) and scene.presentation_errors.is_empty(),"Actual Crypt rest and all exact companion sheets finish preparation")
    if not scene._media_ready({}):
        scene.session.close();scene.queue_free();await process_frame;quit(1);return
    # Keep the producer until its compiled groups' media handoffs are admitted.
    scene.session.close(); await scene.presentation_updated
    scene._sample_actors(); scene.set_process(false); scene.hud.hide(); scene.grid_visible = false
    scene.update_wall_visibility(); scene._sort_draws()
    DirAccess.make_dir_recursive_absolute("res://.captures/character-geometry")
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.captures/character-geometry/actual-crypt.png")
    scene.hide()
    var viewport = SubViewport.new(); viewport.size = Vector2i(128,128); viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
    var environment = WorldEnvironment.new(); environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color.BLACK
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED; viewport.add_child(environment)
    var camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.current = true; viewport.add_child(camera)
    var node = MeshInstance3D.new(); viewport.add_child(node)
    var rows = []
    var light_rows=[]
    for id in scene.source_lighting.nodes:
        var source_node:OmniLight3D=scene.source_lighting.nodes[id]
        var copy=source_node.duplicate();copy.visible=true;viewport.add_child(copy)
        var sample:Dictionary=scene.source_lighting.sampled[id]
        light_rows.append({"id":id,"position":[sample.position.x,sample.position.y,sample.position.z],"range":sample.range,"energy":sample.energy})
    for entry in scene.actor_entries:
        if entry.actor_layer.category not in ["Chest7","Chest14","Head15"]: continue
        node.mesh = entry.node.mesh; node.transform = entry.node.global_transform;node.custom_aabb=entry.node.custom_aabb
        node.material_override = entry.material
        camera.basis = scene.camera.global_basis
        camera.size = 128*entry.scale/Placement.PIXELS_PER_UNIT
        camera.position = node.transform*node.mesh.center_offset+camera.basis.z*10
        var rendered = await capture(viewport)
        check(has_colour(rendered),"Native light comparison contains rendered receiver pixels")
        var original: Image = scene.source_images[entry.texture_path]
        var source = Geometry.record(entry.texture_path,entry.actor_layer.slot,scene.catalog_cache)
        var geometry_root: String = Geometry._root(source)
        # Reference-only CPU reads. Production companions are GPU-only after
        # upload; retaining their decoded images must not be required to render.
        check(source.files.values().all(func(relative):return not scene.source_images.has(geometry_root.path_join(relative)) and scene.textures.has(geometry_root.path_join(relative))),
            "Production "+entry.actor_layer.category+" retains uploaded companions without CPU image copies")
        var depth: Image = Image.load_from_file(geometry_root.path_join(source.files.depth))
        var normal: Image = Image.load_from_file(geometry_root.path_join(source.files.normal))
        var support: Image = Image.load_from_file(geometry_root.path_join(source.files.support))
        var validity: Image = Image.load_from_file(geometry_root.path_join(source.files.normal_valid))
        var uv: Vector4 = entry.material.get_shader_parameter("frame_uv")
        var tint: Vector3 = entry.material.get_shader_parameter("tint")
        var ox = roundi(uv.x*original.get_width()); var oy = roundi(uv.y*original.get_height())
        var difference=0.0;var changed=0;var pixels=0
        var points=Image.create(128,128,false,Image.FORMAT_RGBAF)
        var normals=Image.create(128,128,false,Image.FORMAT_RGBAF)
        for y in range(128):
            for x in range(128):
                var colour = original.get_pixel(ox+x,oy+y)
                if colour.a<=0: continue
                if pixels == 0:
                    var source_local = Vector3((x+.5-entry.pivot.x)*entry.scale/Placement.PIXELS_PER_UNIT,(entry.pivot.y-y-.5)*entry.scale/Placement.PIXELS_PER_UNIT,0)
                    check(scene.pick_actor(scene.camera.unproject_position(entry.node.global_transform*source_local))==entry.placement.id,
                        "Production "+entry.actor_layer.category+" still picks its original colour alpha")
                pixels += 1
                var n = camera.basis.z
                var position = node.transform*Vector3((x+.5-64)*entry.scale/Placement.PIXELS_PER_UNIT,(87-y-.5)*entry.scale/Placement.PIXELS_PER_UNIT,0)
                if support.get_pixel(ox+x,oy+y).r>.5 and validity.get_pixel(ox+x,oy+y).r>.5:
                    var encoded_n = normal.get_pixel(ox+x,oy+y)
                    var en = Vector3(encoded_n.r*2-1,encoded_n.g*2-1,encoded_n.b*2-1).normalized()
                    var right = camera.basis.x
                    var towards = Vector3(camera.basis.z.x,0,camera.basis.z.z).normalized()
                    n = (right*en.x + Vector3.UP*sqrt(.5)*(en.y+en.z) + towards*sqrt(.5)*(en.z-en.y)).normalized()
                    var d = source.depth_range[0]+(depth.get_pixel(ox+x,oy+y).r*255-32)*(source.depth_range[1]-source.depth_range[0])/192
                    # Independent producer render_view equations, integer rays:
                    # source world Y=(-up+D)/sqrt2; Z=(up+D)/sqrt2.
                    position = node.position + (right*(x-64) + Vector3.UP*sqrt(.5)*(96-y+d) + towards*sqrt(.5)*(d-(96-y)))*entry.scale/Placement.PIXELS_PER_UNIT
                points.set_pixel(x,y,Color(position.x,position.y,position.z,1))
                normals.set_pixel(x,y,Color(n.x,n.y,n.z,1))
        var reference=ShaderMaterial.new();reference.shader=load("res://tests/character_geometry_oracle.gdshader")
        reference.set_shader_parameter("per_pixel_reference",true)
        reference.set_shader_parameter("reference_points",ImageTexture.create_from_image(points))
        reference.set_shader_parameter("reference_normals",ImageTexture.create_from_image(normals))
        reference.set_shader_parameter("sheet",entry.material.get_shader_parameter("sheet"))
        reference.set_shader_parameter("frame_uv",uv);reference.set_shader_parameter("tint",tint)
        node.material_override=reference
        var expected_image=await capture(viewport)
        for y in range(128):
            for x in range(128):
                var expected=expected_image.get_pixel(x,y);var actual=rendered.get_pixel(x,y)
                var error=maxf(absf(expected.r-actual.r),maxf(absf(expected.g-actual.g),absf(expected.b-actual.b)))
                difference=maxf(difference,error)
                if error>3.0/255:changed+=1
        node.material_override=entry.material
        var name: String = entry.actor_layer.category
        check(pixels>0 and changed==0,"Production "+name+" matches independent source receiver maps under actual native lights, changed="+str(changed)+" max="+str(difference))
        rows.append({"category":name,"original_pixels":pixels,"changed_pixels":changed,"maximum_error":difference})
        rendered.save_png("res://.captures/character-geometry/actual-"+name+".png")
        expected_image.save_png("res://.captures/character-geometry/cpu-"+name+".png")
        entry.material.set_shader_parameter("use_component_depth",false)
        (await capture(viewport)).save_png("res://.captures/character-geometry/depth-off-"+name+".png")
        entry.material.set_shader_parameter("has_component_geometry",false)
        (await capture(viewport)).save_png("res://.captures/character-geometry/flat-"+name+".png")
        entry.material.set_shader_parameter("has_component_geometry",true); entry.material.set_shader_parameter("use_component_depth",true)
    var report = {"checks":checks,"failures":failures,"actual_receiver_comparisons":rows,"lights":light_rows,"camera_basis":str(scene.camera.basis),"scope":"Frozen authentic Crypt snapshot, production source shader versus CPU-decoded per-pixel source receivers, both using exact actual native Godot Omni nodes. Isolated zero-ambient control; no duplicate custom contribution."}
    var file = FileAccess.open("res://generated/character_geometry_scene_checks.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
    print("CHARACTER_GEOMETRY_SCENE_CHECKS ",JSON.stringify(report))
    scene.queue_free(); viewport.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
