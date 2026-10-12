extends SceneTree
# Original authored floor pixels: production MultiMesh versus independent single
# draws in exactly the original per-material source order, in all four views.
class Probe extends "res://play.gd":
    func _ready()->void:
        set_process(false);set_process_unhandled_input(false);add_child(context_menu)
        source_lighting.attach(self)
        camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5
        add_child(camera);camera.current=true;position_camera()
    func _process(_delta:float)->void:pass
    func texture(path:String)->Texture2D:
        if not textures.has(path):
            var image=Image.load_from_file(Catalog.media_path(path))
            source_images[path]=image;textures[path]=ImageTexture.create_from_image(image)
        return textures[path]
var checks=0
var failures=[]
var evidence=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("GROUND_VISIBILITY_FAIL ",label)
func capture()->Image:
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func diff(a:Image,b:Image)->int:
    var count=0
    for y in range(a.get_height()):
        for x in range(a.get_width()):
            var av=a.get_pixel(x,y);var bv=b.get_pixel(x,y)
            if maxf(absf(av.r-bv.r),maxf(absf(av.g-bv.g),absf(av.b-bv.b)))>1.0/255+.00001:count+=1
    return count
func _initialize()->void:run.call_deferred()
func run()->void:
    if DisplayServer.get_name()=="headless":quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(480,360)
    var scene=Probe.new();root.add_child(scene)
    var environment=WorldEnvironment.new();environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK
    environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=1
    scene.add_child(environment)
    var rows=[];var tiles={}
    for y in range(-1,2):
        for x in range(-1,2):
            var id="%d,%d"%[x,y]
            rows.append({"id":id,"kind":"terrain","material":"stone","position":[x,y],"base_height_steps":0,"layer":0,"orientation":"east","boundaries":[]})
            tiles[id]={"tile_uuid":id,"position":[x,y],"elevation_steps":0}
    scene.timeline.state={"tiles":tiles,"objects":{},"actors":{},"audience":{"controlled":[]},"senses":{"visible":[]}}
    var background=await capture()
    for quarter in range(4):
        scene.quarter=quarter;scene.world_quarter=quarter;scene.position_camera()
        scene._ground_batch(rows.duplicate(true));var batch:Dictionary=scene.static_entries.back()
        var singles=[]
        for row in batch.batch_rows:
            scene._environment_row(row.duplicate(true));singles.append(scene.static_entries.back())
        for i in range(singles.size()):scene._apply_draw_rank(singles[i],i,-scene.camera.global_basis.z)
        for visible in [rows.map(func(row):return row.position),[],[[0,0],[1,0]]]:
            scene.timeline.state.senses.visible=visible;scene.timeline.revision+=1;scene._sync_scenery(true)
            for entry in singles:entry.node.visible=false
            batch.node.visible=true
            var actual=await capture()
            batch.node.visible=false
            for entry in singles:entry.node.visible=true
            var expected=await capture()
            var delta=diff(actual,expected)
            var painted=diff(expected,background)
            check(painted>100,"q%d independent original floor pixels are visible"%quarter)
            check(delta==0,"q%d batch matches individual source pixels at visibility count%d (%d pixels)"%[quarter,visible.size(),delta])
            evidence.append({"quarter":quarter,"visible_cells":visible.size(),"different_pixels":delta,"original_pixels":painted,"bounds":str(batch.node.multimesh.custom_aabb)})
            if quarter==0 and visible.size()==9:
                DirAccess.make_dir_recursive_absolute("res://.captures/scenery")
                actual.save_png("res://.captures/scenery/floor-batch.png");expected.save_png("res://.captures/scenery/floor-individual.png")
                print("BATCH_NATIVE ",batch.node.multimesh.use_colors," custom ",batch.node.multimesh.get_instance_custom_data(0)," bounds ",batch.node.multimesh.custom_aabb)
        for entry in scene.static_entries:entry.node.queue_free()
        scene.entries=[];scene.static_entries=[];await process_frame
    var report={"checks":checks,"failures":failures,"cases":evidence,"scope":"Production original terrain MultiMesh equals independent single original draws for all current, all remembered and mixed visibility, all4quarters; original overlap/skirt order retained."}
    var file=FileAccess.open("res://generated/ground_visibility_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    print("GROUND_VISIBILITY_CHECKS ",JSON.stringify(report));scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
