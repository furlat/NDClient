extends SceneTree
# Original authored frames through actual live/offline layer materials. Compare
# native pixels with source RGB × the authored tint, including unmapped whites.
const Player = preload("res://play.tscn")
const Catalog = preload("res://source_catalog.gd")
class Workshop extends "res://main.gd":
    func _ready() -> void: set_process(false); set_process_unhandled_input(false)
    func _process(_delta: float) -> void: pass
var checks = 0
var failures: Array = []
var results: Array = []
func check(ok: bool,label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("TINT_FAIL ",label)
func native_srgb(value: float) -> float:
    # Compatibility's documented native spatial colour transfer (same oracle as
    # chest_render_checks), separate from the requested multiplication.
    var linear = value*(value*(value*.305306011+.682171111)+.012522878)
    return maxf(1.055*pow(linear,.416666667)-.055,0)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    var scene = Player.instantiate(); scene.timeline.paused = true; root.add_child(scene)
    var deadline = Time.get_ticks_msec()+60000
    while not scene.session.recording_ready and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    scene.session.close(); await scene.presentation_updated
    while (not scene._environment_media_ready() or not scene.MediaWarmup.ready(scene.media_warmup,scene.media_plan.required)) and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await scene.presentation_updated
    check(scene._environment_media_ready() and scene.MediaWarmup.ready(scene.media_warmup,scene.media_plan.required) and scene.media_issue.is_empty(),"Exact paused source images finish preparation before tint capture")
    scene.set_process(false); scene.hide(); scene.hud.hide()
    check(scene.session.issue.is_empty() and not scene.timeline.state.is_empty(),"Actual Crypt player initializes")
    if scene.timeline.state.is_empty(): quit(1); return
    var cases: Array = []
    for entry in scene.actor_entries:
        if entry.actor_layer.category in ["Chest7","Chest14","Head13","Legs7"]:
            cases.append({"path":"live","entry":entry,"clips":["Idle","Run","Attack1"]})
    var workshop = Workshop.new(); root.add_child(workshop); workshop.hide()
    workshop.rigs = scene.rigs; workshop.resources = scene.resources
    workshop.add_modular_entries({"id":"tint-workshop","kind":"actor","rig":"neuroclient.modular","equipment":["Leather Armor","Longsword","Shield"]})
    for entry in workshop.actor_entries:
        if entry.actor_layer.category in ["Chest3","Legs1"]: cases.append({"path":"workshop","entry":entry,"clips":["Idle"]})
    check(cases.size()==6,"Both actual live outfits and the offline equipment path are exercised")
    var viewport = SubViewport.new(); viewport.size = Vector2i(128,128); viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
    var environment = WorldEnvironment.new(); environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color.BLACK
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED; viewport.add_child(environment)
    var camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 128
    camera.position = Vector3(0,0,10); camera.current = true; viewport.add_child(camera)
    var node = MeshInstance3D.new(); var mesh = QuadMesh.new(); mesh.size = Vector2(128,128); node.mesh = mesh; viewport.add_child(node)
    var rig: Dictionary = scene.rigs["neuroclient.modular"]
    DirAccess.make_dir_recursive_absolute("res://.captures/tint")
    for sample in cases:
        var entry: Dictionary = sample.entry; var layer: Dictionary = entry.actor_layer
        var material: ShaderMaterial = entry.material.duplicate()
        material.set_shader_parameter("source_light_count",0); material.set_shader_parameter("authored_base_light",1.0)
        node.material_override = material
        var tint = Color.hex(layer.tint*256+255)
        for clip_name in sample.clips:
            var clip: Dictionary = rig.clips[clip_name]
            var path: String = scene.resources[clip.sheets[layer.category]]
            var source: Image = Image.load_from_file(Catalog.media_path(path))
            material.set_shader_parameter("sheet",ImageTexture.create_from_image(source))
            var frame = int(clip.frames)/2
            for facing in rig.facing_rows:
                var row: int = rig.facing_rows[facing]
                material.set_shader_parameter("frame_uv",Vector4(frame*128.0/source.get_width(),row*128.0/source.get_height(),128.0/source.get_width(),128.0/source.get_height()))
                await process_frame; await process_frame; await RenderingServer.frame_post_draw
                var rendered = viewport.get_texture().get_image()
                var maximum = 0.0; var changed = 0; var visible = 0
                for y in range(128):
                    for x in range(128):
                        var raw = source.get_pixel(frame*128+x,row*128+y)
                        var actual = rendered.get_pixel(x,y)
                        var tinted = raw*tint
                        var expected = Vector3(native_srgb(tinted.r),native_srgb(tinted.g),native_srgb(tinted.b))*raw.a*layer.alpha
                        var error = maxf(absf(actual.r-expected.x),maxf(absf(actual.g-expected.y),absf(actual.b-expected.z)))
                        maximum = maxf(maximum,error)
                        if error>2.0/255: changed += 1
                        if raw.a>0: visible += 1
                var label = "%s %s %s %s" % [sample.path,layer.category,clip_name,facing]
                check(visible>0 and changed==0,"Source shading, bright pixels and alpha receive tint once: "+label+" changed="+str(changed))
                results.append({"case":label,"tint":layer.tint,"visible_pixels":visible,"changed_pixels":changed,"maximum_error":maximum})
                if clip_name=="Idle" and facing=="SW": rendered.save_png("res://.captures/tint/"+sample.path+"-"+layer.category+".png")
    # Explicit white/near-white and partial-alpha inputs cover the reported
    # highlight failure even when a particular original frame has none.
    var material: ShaderMaterial = cases[0].entry.material.duplicate()
    material.set_shader_parameter("source_light_count",0); material.set_shader_parameter("authored_base_light",1.0)
    material.set_shader_parameter("frame_uv",Vector4(0,0,1,1)); node.material_override = material
    var tint = Color.hex(cases[0].entry.actor_layer.tint*256+255)
    for raw in [Color.WHITE,Color8(240,239,238,128)]:
        var source = Image.create(1,1,false,Image.FORMAT_RGBA8); source.fill(raw)
        material.set_shader_parameter("sheet",ImageTexture.create_from_image(source))
        await process_frame; await process_frame; await RenderingServer.frame_post_draw
        var actual = viewport.get_texture().get_image().get_pixel(64,64)
        var tinted = raw*tint
        var expected = Vector3(native_srgb(tinted.r),native_srgb(tinted.g),native_srgb(tinted.b))*raw.a
        check(Vector3(actual.r,actual.g,actual.b).distance_to(expected)<.012,"White highlight and alpha get ordinary tint: "+str(raw))
    var report = {"checks":checks,"failures":failures,"comparisons":results,"scope":"Original live/workshop equipment frames, 8 facings, source alpha and encoded tint before lighting."}
    var file = FileAccess.open("res://generated/modular_tint_checks.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
    print("MODULAR_TINT_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"comparisons":results.size()}))
    scene.queue_free(); workshop.queue_free(); viewport.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
