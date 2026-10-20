extends SceneTree
# Real recorded Crypt initialization through the production session, media gate,
# source adapters, native 2D receivers, original 3D painter quads and settings.
const Player=preload("res://play.tscn")
const Settings=preload("res://presentation/render_settings.gd")
const Geometry=preload("res://presentation/character_geometry.gd")
class ProfilePlayer extends "res://play.gd":
    var persist_profile:bool=true
    func _save_character_light_profile(name:String)->Error:
        return super._save_character_light_profile(name) if persist_profile else OK
var checks := 0
var failures: Array=[]
var receipts: Array=[]
var prior_settings: Variant
var caption: Label
var original_profile := "reference"

func check(value: bool,label: String) -> void:
    checks+=1
    if not value: failures.append(label); print("NATIVE_2D_INTEGRATION_FAIL ",label)

func _initialize() -> void: run.call_deferred()

func capture(label: String) -> Image:
    caption.text=label
    await process_frame
    await RenderingServer.frame_post_draw
    await process_frame
    await RenderingServer.frame_post_draw
    var image=root.get_texture().get_image()
    image.save_png("res://.captures/native-2d/"+label.validate_filename()+".png")
    return image

func press(key: Key) -> void:
    var event=InputEventKey.new()
    event.keycode=key; event.physical_keycode=key; event.pressed=true
    root.push_input(event,true)
    event=event.duplicate(); event.pressed=false
    root.push_input(event,true)

func profile_ready(scene:Node,name:String)->void:
    var deadline:int=Time.get_ticks_msec()+90000
    while not scene.requested_character_light_profile.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
    await scene.presentation_updated
    check(scene.requested_character_light_profile.is_empty() and scene.character_light_profile==name,
        "Exact requested normal sources publish before sampling "+name+": "+scene.media_issue)

func receiver_nodes(node: Node,counts: Dictionary,helper: bool=false) -> void:
    # Native 3D shadow-measurement worlds are explicitly allowed. A main-world
    # Light3D, including a hidden one, would retain a second receiving pipeline.
    var isolated=helper or (node is SubViewport and node.name.begins_with("ShadowMeasure_"))
    if node is Light3D:
        counts["helper_3d" if isolated else "main_3d"]+=1
    if node is PointLight2D and node.enabled: counts.point_2d+=1
    if node is DirectionalLight2D and node.enabled: counts.directional_2d+=1
    for child in node.get_children(): receiver_nodes(child,counts,isolated)

func signature(scene: Node) -> Dictionary:
    var result={}
    for id in scene.visual_actors:
        var visual: Dictionary=scene.visual_actors[id]
        var layers=[]
        for entry in visual.entries:
            layers.append({"id":entry.id,"visible":entry.node.visible,"transform":entry.node.global_transform,
                "frame":entry.material.get_shader_parameter("frame_uv"),"tint":entry.material.get_shader_parameter("tint"),
                "alpha":entry.material.get_shader_parameter("layer_alpha"),"source":entry.get("texture_path","")})
        result[id]={"position":visual.row.position.duplicate(),"height":visual.row.base_height_steps,
            "facing":visual.row.facing,"clip":scene.playbacks[id].clip,"seconds":scene.playbacks[id].sample_seconds,"layers":layers}
    return result

func actor_pixels(scene: Node) -> Array:
    var selected={}
    for visual in scene.visual_actors.values():
        for entry in visual.entries:
            if not entry.node.visible or entry.role=="shadow" or not entry.material.get_shader_parameter("has_component_geometry"): continue
            var source: Image=scene.source_images[entry.texture_path]
            var uv: Vector4=entry.material.get_shader_parameter("frame_uv")
            var origin=Vector2i(roundi(uv.x*source.get_width()),roundi(uv.y*source.get_height()))
            var size=Vector2i(roundi(uv.z*source.get_width()),roundi(uv.w*source.get_height()))
            for y in range(0,size.y,2):
                for x in range(0,size.x,2):
                    if source.get_pixel(origin.x+x,origin.y+y).a<0.5: continue
                    var local=Vector3(x+0.5-entry.pivot.x,entry.pivot.y-y-0.5,0)*entry.scale/scene.Placement.PIXELS_PER_UNIT
                    var screen=Vector2i(scene.camera.unproject_position(entry.node.global_transform*local))
                    if root.get_visible_rect().has_point(screen) and screen.y>36: selected[screen]=true
    return selected.keys()

func changed_at(a: Image,b: Image,pixels: Array) -> int:
    var changed := 0
    for pixel in pixels:
        if a.get_pixelv(pixel)!=b.get_pixelv(pixel): changed+=1
    return changed

func world_difference(a: Image,b: Image) -> int:
    var changed := 0
    for y in range(40,a.get_height()):
        for x in a.get_width():
            if a.get_pixel(x,y)!=b.get_pixel(x,y): changed+=1
    return changed

func painter_order(scene: Node) -> void:
    var expected: Array=(scene.static_entries+scene.actor_entries).filter(func(entry):return entry.node.visible)
    expected.sort_custom(func(a,b):
        var ka=scene.Order.key(a.placement,a.role,a.layer,scene.quarter,scene.ground_is_background)
        var kb=scene.Order.key(b.placement,b.role,b.layer,scene.quarter,scene.ground_is_background)
        return scene.Order.less(ka,kb) if ka!=kb else a.id<b.id)
    check(scene.draw_order.map(func(entry):return entry.id)==expected.map(func(entry):return entry.id),
        "Native receiving output retains original component/support painter order q"+str(scene.quarter))
    for visual in scene.visual_actors.values():
        var modular: bool=visual.entries.any(func(entry):return entry.get("texture_path","").begins_with("/media/smallscale/modular/"))
        if not modular: continue
        check(visual.entries.all(func(entry):return entry.actor_layer.slot!="shadow"),"Modular actor has no prebaked Shadow component "+visual.row.id)
        var shadows=scene.actor_entries.filter(func(entry):return entry.get("generated_shadow",false) and entry.placement.id==visual.row.id)
        for shadow in shadows:
            var rank: int=scene.draw_order.find(shadow)
            for body in visual.entries:
                if body.node.visible: check(rank>=0 and rank<scene.draw_order.find(body),"Generated support shadow precedes original body layer "+body.id)

func run() -> void:
    if DisplayServer.get_name()=="headless": quit(2); return
    root.unfocusable=true
    root.position=Vector2i(-16000,-16000)
    root.size=Vector2i(960,640)
    if FileAccess.file_exists(Settings.PATH): prior_settings=FileAccess.get_file_as_bytes(Settings.PATH)
    var scene=ProfilePlayer.new()
    scene.timeline.paused=true
    root.add_child(scene)
    var last_progress=Time.get_ticks_msec()
    var deadline=Time.get_ticks_msec()+240000
    while (not scene.session.recording_ready or not scene._media_ready({}) or scene.visual_actors.is_empty()) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
        if Time.get_ticks_msec()-last_progress>10000:
            last_progress=Time.get_ticks_msec()
            print("NATIVE_2D_STARTUP ",JSON.stringify({"recording_ready":scene.session.recording_ready,"media_ready":scene.media_initial_ready,"world":scene.world_revision,"media":scene.MediaWarmup.preload_progress(scene.media_warmup)}))
    check(scene.session.recording_ready and scene.media_initial_ready and scene.world_revision>=0,
        "Authentic Crypt initialization passes source media and world publication gates: "+str(scene.session.issue)+" "+scene.media_issue)
    if not failures.is_empty(): await finish(scene); return
    await scene.presentation_updated
    check(not scene.timeline.state.is_empty() and scene.timeline.sequence==0,"Paused scene displays initialized subjective state, never latest prepared future")
    scene.session.close()
    original_profile=scene.character_light_profile
    var canonical: Dictionary=scene.timeline.state.duplicate(true)
    var initial_ms: float=scene.timeline.display_ms
    var counts={"main_3d":0,"helper_3d":0,"point_2d":0,"directional_2d":0}
    receiver_nodes(scene,counts)
    check(counts.main_3d==0,"Main world has no receiving Light3D nodes")
    check(scene.source_lighting.canvas_sources().any(func(source):return source.enabled),
        "Actual disclosed native2D source operands reach the painted receiving table")
    check(scene.camera is Camera3D and scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Production retains native orthographic3D camera")
    var images_before={}
    for visual in scene.visual_actors.values():
        for entry in visual.entries:
            if entry.node.visible and scene.source_images.has(entry.get("texture_path","")):
                images_before[entry.texture_path]=scene.source_images[entry.texture_path].get_data()
    var overlay=CanvasLayer.new()
    overlay.layer=100
    root.add_child(overlay)
    caption=Label.new()
    caption.position=Vector2(12,8)
    caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
    overlay.add_child(caption)
    DirAccess.make_dir_recursive_absolute("res://.captures/native-2d")
    press(KEY_ESCAPE)
    await process_frame
    check(scene.hud.settings_open(),"Escape opens the actual native settings panel")
    var option: OptionButton=scene.hud.settings_panel.profiles
    var menu_profile="gentle" if original_profile!="gentle" else "reference"
    for index in option.item_count:
        if option.get_item_metadata(index)==menu_profile:
            option.select(index); option.item_selected.emit(index); break
    await profile_ready(scene,menu_profile)
    check(scene.character_light_profile==menu_profile and Settings.read().profile==menu_profile,
        "Native profile option applies and persists the exact selected profile")
    var original_zoom: float=scene.camera.size
    var mouse=InputEventMouseButton.new()
    mouse.position=Vector2(6,root.size.y-6); mouse.button_index=MOUSE_BUTTON_WHEEL_UP;mouse.pressed=true
    root.push_input(mouse,true)
    await process_frame
    check(scene.camera.size==original_zoom,"Modal settings prevent world zoom click-through")
    await capture("settings-native2d")
    press(KEY_ESCAPE)
    await process_frame
    check(not scene.hud.settings_open(),"Escape closes settings without altering the paused game clock")
    scene.hud.hide()
    scene.grid_visible=false
    scene.persist_profile=false
    var profile_changed := 0
    for quarter in range(4):
        print("NATIVE_2D_PHASE quarter=",quarter)
        scene.request_view(quarter)
        deadline=Time.get_ticks_msec()+90000
        while scene.rotation_pending() and Time.get_ticks_msec()<deadline: await process_frame
        check(not scene.rotation_pending() and scene.quarter==quarter,"Actual prepared camera quarter publishes q"+str(quarter))
        await scene.presentation_updated
        var before=signature(scene)
        var pixels=actor_pixels(scene)
        check(not pixels.is_empty(),"Original modular source alpha supplies onscreen samples q"+str(quarter))
        var original_picks=pixels.map(func(pixel):return scene.pick_actor(pixel))
        check(original_picks.any(func(id):return not id.is_empty()),"Actual original-alpha actor picking resolves rendered source samples")
        var rendered={}
        var shadow_updates: int=scene.generated_shadows.diagnostics().updates
        for profile_name in ["original","gentle","reference"]:
            print("NATIVE_2D_PHASE quarter=",quarter," profile=",profile_name)
            # The menu callback is checked once above; the image matrix changes
            # only the in-memory preference and leaves the saved setting alone.
            check(scene.set_character_light_profile(profile_name),"Production profile request accepts "+profile_name)
            await profile_ready(scene,profile_name)
            rendered[profile_name]=await capture("q%d-%s-native2d"%[quarter,profile_name])
            check(scene.character_light_profile==profile_name and Settings.read().profile==menu_profile,"Image matrix applies "+profile_name+" without rewriting saved settings")
            check(signature(scene)==before,"Profile changes preserve source placement/frame/tint/alpha/clock q%d %s"%[quarter,profile_name])
            check(pixels.map(func(pixel):return scene.pick_actor(pixel))==original_picks,"Normal profile preserves original-alpha actor picking q%d %s"%[quarter,profile_name])
            check(scene.timeline.state==canonical and scene.timeline.display_ms==initial_ms,"Profile/view never mutates canonical state or paused source time")
            for visual in scene.visual_actors.values():
                for entry in visual.entries:
                    if not entry.node.visible or not entry.material.get_shader_parameter("has_component_geometry"): continue
                    var paths=Geometry.normal_paths(entry.texture_path,entry.actor_layer.slot,scene.catalog_cache)
                    check(paths.ok and entry.material.get_shader_parameter("component_normal")==scene.textures.get(paths.value.get(profile_name,"")),
                        "Displayed eligible component binds exact admitted "+profile_name+" normal source")
        var changed=changed_at(rendered.original,rendered.reference,pixels)
        profile_changed+=changed
        receipts.append({"quarter":quarter,"actor_sample_pixels":pixels.size(),"original_reference_changed_samples":changed,
            "shadows":scene.generated_shadows.diagnostics()})
        check(scene.generated_shadows.diagnostics().updates==shadow_updates,"Normal profiles leave original depth shadow sampling unchanged q"+str(quarter))
        painter_order(scene)
        var wall_before=signature(scene)
        var wall_updates: int=scene.generated_shadows.diagnostics().updates
        for next_mode in ["translucent","hidden","solid"]:
            print("NATIVE_2D_PHASE quarter=",quarter," wall_mode=",next_mode)
            press(KEY_Z)
            await scene.presentation_updated
            await capture("q%d-walls-%s-native2d"%[quarter,next_mode])
            check(scene.wall_mode==next_mode,"Actual Z input selects "+next_mode+" q"+str(quarter))
            check(signature(scene)==wall_before and scene.timeline.state==canonical and scene.timeline.display_ms==initial_ms,
                "Wall display mode preserves actor sources and displayed authority q%d %s"%[quarter,next_mode])
            painter_order(scene)
        check(scene.generated_shadows.diagnostics().updates==wall_updates,"Wall display modes do not resample unchanged actor depth casters")
    check(profile_changed>0,"Selected normal profiles visibly change actual native character light response")
    var enabled=await capture("generated-shadows-enabled")
    scene.generated_shadows.enabled=false
    var disabled=await capture("generated-shadows-disabled")
    check(scene.actor_entries.all(func(entry):return not entry.get("generated_shadow",false)),"Disabling generated shadows removes them without a baked substitute")
    check(world_difference(enabled,disabled)>0,"Actual generated shadows alter visible ground in the recorded scene")
    scene.generated_shadows.enabled=true
    await capture("generated-shadows-restored")
    for path in images_before:
        check(scene.source_images[path].get_data()==images_before[path],"Original source RGBA/alpha bytes remain unchanged: "+path)
    check(scene.presentation_errors.is_empty(),"Production integration has no source/lighting errors: "+str(scene.presentation_errors))
    check(scene.timeline.state==canonical and scene.timeline.display_ms==initial_ms,"Entire native view/settings matrix preserves displayed authority and clock")
    scene.hud.show()
    overlay.queue_free()
    await finish(scene)

func finish(scene: Node) -> void:
    if is_instance_valid(scene):
        scene.character_light_profile=original_profile
        var helper=weakref(scene.generated_shadows)
        var nodes: Array=[]
        for entry in scene.actor_entries:
            if entry.get("generated_shadow",false): nodes.append(weakref(entry.node))
        scene.queue_free()
        await process_frame
        await process_frame
        check(nodes.all(func(node):return node.get_ref()==null),"Scene shutdown releases generated3D shadow outputs")
        check(helper.get_ref()==null,"Scene shutdown releases shadow owner and frame callback")
    if prior_settings!=null:
        var file=FileAccess.open(Settings.PATH,FileAccess.WRITE)
        file.store_buffer(prior_settings);file.close()
    elif FileAccess.file_exists(Settings.PATH): DirAccess.remove_absolute(Settings.PATH)
    var report={"checks":checks,"failures":failures,"views":receipts,
        "scope":"Actual Crypt recording initialization, displayed actor/source rows, four3D camera quarters, three delivered normal profiles, native settings and original source/painter invariants. No canonical edits or geometry fixtures. Large-map timing is a separate lane."}
    var file=FileAccess.open("res://generated/native_2d_integration_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "));file.close()
    print("NATIVE_2D_INTEGRATION_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
