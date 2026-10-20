extends SceneTree
# Actual Crypt emitter activation/art plus named presentation-height fixtures.
const FixturePublication=preload("res://tests/prepared_world_fixture.gd")
const Player = preload("res://play.tscn")
const UI=preload("res://presentation/ui_catalog.gd")
const Lighting=preload("res://presentation/lighting_2d.gd")
var checks = 0
var failures: Array = []
func check(ok: bool,label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("EMITTER_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func capture() -> Image:
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
static func actor_pixels(scene: Node) -> Dictionary:
    var output = {}
    for entry in scene.actor_entries:
        if entry.role=="shadow" or entry.get("generated_shadow",false) or not entry.node.visible or not entry.has("texture_path"): continue
        var row: Dictionary = entry.placement
        if not output.has(row.id): output[row.id] = {}
        var image: Image = scene.source_images[entry.texture_path]
        var uv: Vector4 = entry.material.get_shader_parameter("frame_uv")
        var ox = roundi(uv.x*image.get_width()); var oy = roundi(uv.y*image.get_height())
        for y in range(int(entry.cell.y)):
            for x in range(int(entry.cell.x)):
                if image.get_pixel(ox+x,oy+y).a<.5: continue
                var local = Vector3((x+.5-entry.pivot.x)*entry.scale/scene.Placement.PIXELS_PER_UNIT,(entry.pivot.y-y-.5)*entry.scale/scene.Placement.PIXELS_PER_UNIT,0)
                var screen = scene.camera.unproject_position(entry.node.global_transform*local)
                if scene.get_viewport().get_visible_rect().has_point(screen):output[row.id][Vector2i(screen)] = true
    return output
static func brightness(image: Image, pixels: Dictionary) -> Dictionary:
    var result = {}
    for id in pixels:
        var total = 0.0; var dark = 0
        for point in pixels[id]:
            var value = image.get_pixelv(point).get_luminance()
            total += value
            if value<.02: dark += 1
        result[id] = {"mean_luminance":total/maxi(1,pixels[id].size()),"dark_pixels":dark,"pixels":pixels[id].size()}
    return result
func publish(scene:Node,anchors:Dictionary,energy:Dictionary={},heights:Dictionary={})->void:
    scene.source_lighting.sample(anchors,energy,heights,scene.fixture_shadow_heights)
    scene._sync_native_lighting()

func hide_sources(state:Dictionary,actor_anchored:bool)->void:
    # A named presentation after-value updates the actual optical membership;
    # changing a retained inventory look alone must not remove an observed light.
    for id in state.light_sources.keys():
        if bool(state.light_sources[id].actor_anchored)==actor_anchored:state.light_sources.erase(id)

func run() -> void:
    root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    var scene = Player.instantiate(); scene.timeline.paused = true; root.add_child(scene)
    var opened:Dictionary=FixturePublication.open(scene)
    check(opened.ok,"Durable original schema16 Crypt/Door recording opens")
    if not opened.ok:scene.queue_free();await process_frame;quit(1);return
    var initialized:bool=await FixturePublication.initial_ready(scene)
    check(initialized and scene.presentation_errors.is_empty(),"Actual Crypt fixture/character media and native world admit before reader shutdown: "+str(scene.session.issue)+" "+str(scene.media_issue))
    if not initialized:scene.queue_free();await process_frame;quit(1);return
    scene.session.close();await scene.presentation_updated
    # Later original operations are not this isolated initialization fixture.
    scene.timeline.current={};scene.timeline.queue=[]
    scene.set_process(false); scene.hud.hide(); scene.camera_focus = Vector3(4,0,5); scene.camera.size = 8
    scene.fire_light_flicker=true;scene.source_lighting.fire_light_flicker=true
    scene.normals_visible=false;scene.set_light_strength(1.0,false)
    scene.position_camera(); scene.wall_mode = "hidden"; scene.update_wall_visibility(); scene._sort_draws(); scene._sample_actors(); scene._sample_fixtures()
    var original: Dictionary = scene.timeline.state.duplicate(true)
    var anchors = {}; for row in scene.actor_rows: anchors[row.id] = row
    var pixels = actor_pixels(scene)
    check(not pixels.is_empty(),"Actual original actor alpha supplies visible body samples")
    var held_layers:Array=scene.actor_entries.filter(func(entry):return entry.has("texture_path")).map(func(entry):return [entry.node.global_transform,entry.texture_path,entry.material.get_shader_parameter("frame_uv"),entry.material.get_shader_parameter("tint")])
    var native_sources: Array = scene.source_lighting.sources.duplicate(true)
    check(native_sources.size()==4,"Exactly two canonical carried and two fixture emitters, without duplication")
    var folder = "res://.captures/emitter-placement/"; DirAccess.make_dir_recursive_absolute(folder)
    var comparisons = {}
    for lift in [1.0,2.0,2.5]:
        scene.source_lighting.carried_optical_lift_steps = lift
        var heights: Dictionary = {} if lift==1.0 else scene.fixture_heights
        publish(scene,anchors,scene.fixture_energy,heights)
        var shown = await capture()
        shown.save_png(folder+"carried-"+str(lift)+".png")
        comparisons[str(lift)] = brightness(shown,pixels)
        var projected:Dictionary={}
        for value in scene.source_lighting.canvas_sources():projected[value.id]=value
        var ppu:float=scene.camera.unproject_position(scene.camera.global_position-scene.camera.global_basis.z*10+scene.camera.global_basis.x).distance_to(scene.camera.unproject_position(scene.camera.global_position-scene.camera.global_basis.z*10))
        check(scene.light_table.count==projected.size(),"Every actual native2D source reaches one receiving-table row")
        for i in range(native_sources.size()):
            var source:Dictionary=native_sources[i]
            var sampled:Dictionary=scene.source_lighting.sampled[source.item_uuid]
            var point:Vector3=sampled.position
            check(is_equal_approx(point.x,source.position.x) and is_equal_approx(point.z,source.position.z),"Optical elevation preserves backend radial XY at "+str(lift))
            check(projected.has(source.item_uuid),"Original optical UUID is preserved in native2D projection")
            if not projected.has(source.item_uuid):continue
            var value:Dictionary=projected[source.item_uuid]
            check(value.screen_position.is_equal_approx(scene.camera.unproject_position(point)),"Native2D position is the projected actual optical anchor")
            check(is_equal_approx(value.span.x,source.outer*2.0*ppu) and is_equal_approx(value.span.y,value.span.x*absf(scene.camera.global_basis.z.y)),"Native2D cookie preserves the exact circular support-plane radius")
            check(is_equal_approx(value.height,Lighting.NORMAL_HEIGHT_SOURCE_PIXELS*2.0/scene.Placement.PIXELS_PER_UNIT*ppu),"Native2D normal height retains the approved source-pixel calibration")
            check(value.color==(Lighting.TORCH_COLOUR if source.item_id in Lighting.TORCH_ITEM_IDS else Color.WHITE),"Original disclosed optical appearance retains exact authored light colour")
            check(scene.source_lighting.sources[i]==source,"Optical elevation preserves canonical source radius/identity metadata")
    scene.camera.size = 4.0
    scene.position_camera(); scene._sample_actors()
    for lift in [2.0,2.5]:
        scene.source_lighting.carried_optical_lift_steps = lift
        publish(scene,anchors,scene.fixture_energy,scene.fixture_heights)
        (await capture()).save_png(folder+"calibrated-close-"+str(lift)+".png")
    # Component receiver calibration was a retired3D reconstruction switch.
    # Current2D receiving uses the delivered camera normal directly; compare
    # its supported flat-normal control without changing source colour/tint.
    for entry in scene.actor_entries:
        if entry.has("texture_path"):entry.material.set_shader_parameter("use_component_normals",false)
    (await capture()).save_png(folder+"flat-close-2.5.png")
    for entry in scene.actor_entries:
        if entry.has("texture_path"):entry.material.set_shader_parameter("use_component_normals",true)
    scene.source_lighting.sync({});publish(scene,anchors)
    RenderingServer.global_shader_parameter_set(&"light_ambient",1.0)
    (await capture()).save_png(folder+"unlit-source-tint-close.png")
    scene.source_lighting.sync(scene.timeline.state);publish(scene,anchors,scene.fixture_energy,scene.fixture_heights)
    RenderingServer.global_shader_parameter_set(&"light_ambient",scene.LIGHT_AMBIENT)
    scene.camera.size = 8.0; scene.position_camera(); scene._sample_actors()
    for id in pixels:
        check(not is_equal_approx(comparisons["2.0"][id].mean_luminance,comparisons["1.0"][id].mean_luminance),"Actual body normals respond to optical height: "+original.actors[id].name)
    scene.source_lighting.carried_optical_lift_steps = 2.5
    var fixtures_off:Dictionary=original.duplicate(true)
    for object in fixtures_off.objects.values():
        if object.item.get("is_lit")==true: object.item.is_lit = false
    hide_sources(fixtures_off,false)
    var fixtures_ready:bool=await FixturePublication.replace(scene,fixtures_off,"emitter-world-off")
    check(fixtures_ready,"Actual world-emitter removal publishes with its prepared optical set")
    if not fixtures_ready:scene.queue_free();await process_frame;quit(1);return
    scene.source_lighting.sync(scene.timeline.state);publish(scene,anchors)
    check(scene.source_lighting.sources.size()==2,"Extinguished world fixtures leave exactly the two carried lights")
    for entry in scene.fixture_entries: entry.node.visible = false
    var self_lit = await capture(); self_lit.save_png(folder+"carried-only.png")
    var self_stats = brightness(self_lit,pixels)
    for id in pixels: check(self_stats[id].mean_luminance>.015,"Actual carried source illuminates its owner's original body: "+original.actors[id].name)
    var all_off:Dictionary=fixtures_off.duplicate(true)
    for actor in all_off.actors.values():
        for identity in actor.get("controlled_items",[]):
            var item:Dictionary=UI.item(identity,all_off)
            if item.get("is_lit")==true:
                var source:Dictionary=all_off.items[identity]
                source.state=source.state.duplicate();source.state.is_lit=false
    hide_sources(all_off,true)
    var all_ready:bool=await FixturePublication.replace(scene,all_off,"emitter-all-off")
    check(all_ready,"Actual carried-emitter removal publishes through prepared optical ownership")
    if not all_ready:scene.queue_free();await process_frame;quit(1);return
    scene.source_lighting.sync(scene.timeline.state);publish(scene,anchors)
    check(scene.source_lighting.sources.is_empty(),"Native extinguished after-values remove every emitter")
    var indirect = await capture(); indirect.save_png(folder+"all-extinguished.png")
    var indirect_stats = brightness(indirect,pixels)
    for id in pixels: check(indirect_stats[id].mean_luminance>.02,"Native ambient keeps an extinguished scene readable: "+original.actors[id].name)
    for id in pixels:check(self_stats[id].mean_luminance>indirect_stats[id].mean_luminance,"Actual carried source adds body illumination above the same ambient-only baseline: "+original.actors[id].name)
    # The painted receiver's ambient is a receiving global, not 3D environment
    # energy. This isolated test control leaves the approved setting untouched.
    RenderingServer.global_shader_parameter_set(&"light_ambient",0.0)
    var dark_stats = brightness(await capture(),pixels)
    for id in pixels: check(dark_stats[id].mean_luminance<.002,"Isolated zero-ambient fixture has no stray self-emission: "+original.actors[id].name)
    RenderingServer.global_shader_parameter_set(&"light_ambient",scene.LIGHT_AMBIENT)
    check(await FixturePublication.replace(scene,original,"emitter-restored"),"Original source membership restores through prepared publication at the held display clock")
    scene._sample_fixtures();scene.source_lighting.sync(scene.timeline.state)
    for entry in scene.fixture_entries: entry.node.visible = true
    for id in anchors:
        var raised: Dictionary = anchors[id].duplicate(true); raised.base_height_steps += 2; raised.visual_height += .5
        anchors[id] = raised
    publish(scene,anchors,scene.fixture_energy,scene.fixture_heights)
    for i in range(scene.source_lighting.sources.size()):
        var source: Dictionary = scene.source_lighting.sources[i]
        if not source.actor_uuid.is_empty():
            var row: Dictionary = anchors[source.actor_uuid]
            check(is_equal_approx(scene.source_lighting.sampled[source.item_uuid].position.y,(row.base_height_steps+row.visual_height+2.5)*scene.Placement.HEIGHT_UNIT),"Carried anchor follows displayed raised support and jump lift exactly")
        else:
            check(scene.fixture_heights.has(source.anchor_item_uuid),"Disclosed optical fixture names its exact authored item anchor")
            if scene.fixture_heights.has(source.anchor_item_uuid):
                check(is_equal_approx(scene.source_lighting.sampled[source.item_uuid].position.y,(source.base_height_steps+scene.fixture_heights[source.anchor_item_uuid])*scene.Placement.HEIGHT_UNIT),"Fixture follows original registered flame centroid height")
    for value in scene.fixture_heights.values(): check(value>1.0 and value<2.0,"Original flame elevation replaces fixed one-step placement")
    check(scene.timeline.state==original,"Comparisons restore original canonical snapshot")
    var final_layers:Array=scene.actor_entries.filter(func(entry):return entry.has("texture_path")).map(func(entry):return [entry.node.global_transform,entry.texture_path,entry.material.get_shader_parameter("frame_uv"),entry.material.get_shader_parameter("tint")])
    check(final_layers==held_layers,"Lighting controls preserve actual source colour/tint/frame/placement")
    scene.receiving_globals=[];scene._publish_receiving()
    var report = {"checks":checks,"failures":failures,"candidate_brightness":comparisons,"carried_only":self_stats,"extinguished":indirect_stats,"isolated_all_off":dark_stats,"fixture_heights":scene.fixture_heights,
        "scope":"Actual Crypt initial snapshot; named optical-lift candidates, native ambient readability with all sources extinguished, isolated zero-ambient control, raised-support/jump fixtures. No hand binding, altered XY/range or duplicated light."}
    var file = FileAccess.open("res://generated/emitter_placement_checks.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
    print("EMITTER_PLACEMENT_CHECKS ",JSON.stringify(report))
    scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
