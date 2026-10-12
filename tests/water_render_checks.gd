extends SceneTree
# Original water graph/mask/ripple with native Godot lighting. The explicit
# timeline clock is exercised through the real player scenery binding helper.
const Catalog=preload("res://source_catalog.gd")
const Placement=preload("res://placement.gd")
const PlayerScript=preload("res://play.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("WATER_RENDER_FAIL ",label)
func _initialize()->void:run.call_deferred()
func capture(view:SubViewport)->Image:
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    return view.get_texture().get_image()
func energy(image:Image)->float:
    var sum=0.0
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var value=image.get_pixel(x,y);sum+=value.r+value.g+value.b
    return sum
func run()->void:
    if DisplayServer.get_name()=="headless":print("WATER_RENDER_CHECKS requires native graphics");quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var binding=PlayerScript.new()
    var row={"id":"water","kind":"terrain","material":"water","position":[0,0],"base_height_steps":0,"orientation":"east","boundaries":[],"layer":0}
    var record=Catalog.environment(row,0,binding.catalog_cache)
    var assets=Catalog.read_file("assets.json",binding.catalog_cache)
    check(record.has("water"),"Actual authored water terrain owns its original graph")
    if not record.has("water"):binding.free();quit(1);return
    for path in [record.path,assets.resources[record.water.ripple].path]:
        var image=Image.load_from_file(Catalog.media_path(path))
        binding.source_images[path]=image;binding.textures[path]=ImageTexture.create_from_image(image)
    var view=SubViewport.new();view.size=Vector2i(256,256);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var environment=WorldEnvironment.new();environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK
    environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED;view.add_child(environment)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.6
    camera.position=Vector3(4,3.265986,4);view.add_child(camera);camera.look_at(Vector3.ZERO);binding.camera=camera
    var mesh=MeshInstance3D.new();mesh.mesh=QuadMesh.new();mesh.basis=camera.basis;view.add_child(mesh)
    var material=ShaderMaterial.new();material.shader=load("res://environment.gdshader");mesh.material_override=material
    var entry={"node":mesh,"material":material,"placement":row,"source_role":1,"role":"terrain","layer":0,"id":"water"}
    binding.set_environment(entry,Basis.IDENTITY)
    binding.static_entries=[entry];binding.world_revision=0;binding.world_quarter=0
    binding.timeline.state={"tiles":{"0,0":{"tile_uuid":"water","position":[0,0],"elevation_steps":0}},"objects":{},"actors":{},"senses":{"visible":[[0,0]]},"audience":{"controlled":[]}}
    binding.timeline.paused=true;binding.timeline.display_ms=1250
    binding._sync_scenery(true)
    check(material.shader==load("res://water.gdshader"),"Production environment binding selects water material")
    check(material.get_shader_parameter("displayed_time_seconds")==1.25,"Production binding uses displayed seconds")
    var dark=await capture(view)
    var omni=OmniLight3D.new();omni.position=Vector3(0,1.5,0);omni.omni_range=5;omni.light_energy=2;omni.shadow_enabled=false;view.add_child(omni)
    var lit=await capture(view)
    check(energy(lit)>energy(dark)+10,"Original water visibly receives native Omni light")
    omni.visible=false
    var directional=DirectionalLight3D.new();directional.rotation_degrees=Vector3(-90,0,0);directional.light_energy=1;view.add_child(directional)
    var sun=await capture(view)
    check(energy(sun)>energy(dark)+10,"Original water visibly receives native directional light")
    var held=await capture(view)
    binding.timeline.advance(5000);binding._sync_scenery()
    var paused=await capture(view)
    check(paused.get_data()==held.get_data(),"Paused timeline preserves exact water pixels despite rendered frames")
    binding.timeline.paused=false;binding.timeline.media_ready=func(_group):return false
    binding.timeline.advance(5000);binding._sync_scenery()
    check(binding.timeline.waiting_for_media and material.get_shader_parameter("displayed_time_seconds")==1.25,"Media backpressure freezes water at the same displayed time")
    binding.timeline.media_ready=Callable();binding.timeline.advance(2750);binding._sync_scenery()
    var moved=await capture(view)
    check(material.get_shader_parameter("displayed_time_seconds")==4.0 and moved.get_data()!=paused.get_data(),"Only displayed advancement moves original ripple pixels")
    binding.timeline.display_ms=1250;binding._sync_scenery()
    check((await capture(view)).get_data()==paused.get_data(),"Replaying the same displayed timestamp restores exact water pixels")
    binding.timeline.state.senses.visible=[];binding.timeline.revision+=1;binding._sync_scenery()
    var memory=await capture(view)
    check(energy(memory)<energy(paused) and energy(memory)>0,"Remembered water remains readable and distinct")
    check(material.get_shader_parameter("current_visibility")==0.0,"Remembered water shares the source sight grant")
    DirAccess.make_dir_recursive_absolute("res://.captures/scenery")
    lit.save_png("res://.captures/scenery/water-native-point.png");memory.save_png("res://.captures/scenery/water-remembered.png")
    var report={"checks":checks,"failures":failures,"energy":{"unlit":energy(dark),"omni":energy(lit),"directional":energy(sun),"remembered":energy(memory)},"scope":"Original source graph/mask/ripple, production binding, native lights, timeline pause/backpressure/replay. No backend water simulation."}
    var file=FileAccess.open("res://generated/water_render_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    print("WATER_RENDER_CHECKS ",JSON.stringify(report));binding.context_menu.free();binding.free();view.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
