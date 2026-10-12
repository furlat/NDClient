extends SceneTree
# Authentic subjective replay through production admission, animation and render.
const Player=preload("res://play.tscn")
const Geometry=preload("res://presentation/character_geometry.gd")
var checks := 0
var failures: Array=[]
var sources={}
var captures={}
func check(value: bool,label: String) -> void:
    checks+=1
    if not value:failures.append(label);print("CREATURE_SCENE_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func observe(scene: Node) -> bool:
    var capture_needed=false
    for visual in scene.visual_actors.values():
        for entry in visual.entries:
            if not entry.node.visible or entry.role=="shadow":continue
            var path: String=entry.get("texture_path","")
            var packet=Geometry.record(path,entry.actor_layer.slot,scene.catalog_cache)
            if packet.is_empty() or not packet.has("normal_profiles"):continue
            var key: String=path+"/"+str(scene.quarter)+"/"+scene.character_light_profile
            if sources.has(key):continue
            sources[key]={"path":path,"family":packet.family,"quarter":scene.quarter,"sequence":scene.timeline.sequence,"profile":scene.character_light_profile}
            check(entry.material.get_shader_parameter("has_component_geometry"),"Actual disclosed creature binds delivered geometry "+key)
            check(entry.geometry_cell_size==Vector2(packet.cell_size[0],packet.cell_size[1]),"Actual native creature size retained "+key)
            var profiles=Geometry.normal_paths(path,"body",scene.catalog_cache)
            check(entry.material.get_shader_parameter("component_normal")==scene.textures[profiles.value[scene.character_light_profile]],"Profile binds preuploaded exact normal "+key)
            check(Geometry.paths(path,"body",scene.catalog_cache).keys().all(func(p):return scene.textures.has(p) and not scene.source_images.has(p)),"Companions are GPU-resident without CPU image retention "+key)
            check(visual.entries.all(func(e):return e.actor_layer.slot!="shadow"),"No baked shadow doubles generated creature shadow "+key)
            var sheet: Texture2D=entry.material.get_shader_parameter("sheet")
            var frame: Vector4=entry.material.get_shader_parameter("frame_uv")
            check(Vector2i(roundi(frame.z*sheet.get_width()),roundi(frame.w*sheet.get_height()))==Vector2i(packet.cell_size[0],packet.cell_size[1]),"Animation sampling uses exact native cell "+key)
            if not captures.has(packet.family):captures[packet.family]=true;capture_needed=true
    return capture_needed
func run() -> void:
    if DisplayServer.get_name()=="headless":quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,800)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var scene=Player.instantiate();scene.timeline.paused=true;root.add_child(scene)
    var deadline=Time.get_ticks_msec()+300000
    while not scene.session.recording_ready and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline:await scene.presentation_updated
    check(scene.session.recording_ready and scene.session.issue.is_empty(),"Actual journal admitted")
    DirAccess.make_dir_recursive_absolute("res://.captures/creature-scene")
    var steps=0
    while (scene.timeline.busy() or scene.timeline.sequence<scene.session.latest_sequence) and Time.get_ticks_msec()<deadline:
        if observe(scene):
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("res://.captures/creature-scene/reveal-seq"+str(scene.timeline.sequence)+".png")
        scene.timeline.paused=false;scene.timeline.advance(1000.0/60.0);scene.timeline.paused=true
        var actor: Dictionary=scene.timeline.state.actors.get(scene.timeline.state.current_actor_uuid,{})
        if actor.get("last_visual_position")!=null:
            scene.camera_focus=Vector3(actor.last_visual_position[0],0,actor.last_visual_position[1]);scene.position_camera()
        steps+=1
        await scene.presentation_updated
    observe(scene)
    check(not sources.is_empty(),"Real replay reveals creatures with delivered geometry")
    check(scene.timeline.state==scene.session.journal.state and not scene.timeline.busy() and scene.timeline.sequence==scene.session.latest_sequence,"All original causal groups drain to canonical backend state")
    check(scene.presentation_errors.is_empty() and scene.media_issue.is_empty() and scene.generated_shadows.issues.is_empty(),"No presentation/preparation/generated-shadow errors: "+str(scene.presentation_errors)+scene.media_issue)
    var report={"checks":checks,"failures":failures,"sources":sources.values(),"groups":scene.timeline.completed_group_count,"sequence":scene.timeline.sequence,"steps":steps,"captured_families":captures.keys(),"scope":"Actual recorded subjective gameplay, including first creature disclosure, exact source profiles/native cells/GPU-only companions and canonical terminal equality. Pixel oracle is separate creature_source_checks."}
    FileAccess.open("res://generated/creature_scene_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CREATURE_SCENE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"groups":scene.timeline.completed_group_count,"families":captures.keys()}))
    scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
