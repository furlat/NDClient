extends "res://tests/native_2d_integration_checks.gd"
# Same actual disclosed scene: receiving-normal and connected-floor correction
# versus the prior single-ray/exposed-skirt baseline, through the lit sprites'
# final3D output. Sprites light themselves from the light table; the baseline
# is reproduced on their own materials and receiving globals.
const GroundReceiving=preload("res://presentation/ground_receiving.gd")
const UI=preload("res://presentation/ui_catalog.gd")
var baseline_normals:Dictionary={}

func snapshot()->Image:
    await process_frame;await RenderingServer.frame_post_draw
    await process_frame;await RenderingServer.frame_post_draw
    return root.get_texture().get_image()

func difference(a:Image,b:Image)->Dictionary:
    var changed:=0;var alpha:=0;var maximum:=0
    for y in a.get_height():
        for x in a.get_width():
            var av=a.get_pixel(x,y);var bv=b.get_pixel(x,y)
            var delta=maxi(absi(av.r8-bv.r8),maxi(absi(av.g8-bv.g8),absi(av.b8-bv.b8)))
            maximum=maxi(maximum,delta)
            if delta>0:changed+=1
            if av.a8!=bv.a8:alpha+=1
    return {"changed":changed,"alpha":alpha,"maximum":maximum}

## Republish the receiving globals (cap/Normals/ambient, light table, supports)
## from the scene's own state while its _process is stopped.
func publish_receiving(scene:Node)->void:
    scene._publish_receiving()

func prop_entries(scene:Node)->Array:
    return scene.entries.filter(func(entry):return entry.get("record",{}).get("normal",{}).has("original_path"))

## Interior skirt joins come from the ground_supports global. NaN supports make
## every neighbour comparison false: each skirt receives as an exposed return.
func set_joins(scene:Node,enabled:bool)->void:
    if enabled:
        scene.ground_supports_revision=-1;publish_receiving(scene);return
    var rect:Vector4=GroundReceiving.support_image(scene.entries).rect
    var image:=Image.create_empty(maxi(1,int(rect.z)),maxi(1,int(rect.w)),false,Image.FORMAT_RF)
    image.fill(Color(NAN,0,0))
    RenderingServer.global_shader_parameter_set(&"ground_supports",ImageTexture.create_from_image(image))

## Original single-ray prop normals live in the registered geometry packet.
func set_prop_normals(scene:Node,corrected:bool)->void:
    for entry in prop_entries(scene):
        var material:ShaderMaterial=entry.material
        var key:int=material.get_instance_id()
        if not baseline_normals.has(key):baseline_normals[key]=material.get_shader_parameter("normal_texture")
        material.set_shader_parameter("normal_texture",baseline_normals[key] if corrected else material.get_shader_parameter("geometry_texture"))

func original_receiving(scene:Node,enabled:bool)->void:
    set_joins(scene,not enabled);set_prop_normals(scene,not enabled)

func receiver_counts(scene:Node)->Dictionary:
    var supports:Dictionary=GroundReceiving.heights(scene.entries)
    var joins:=0;var exposed:=0
    for entry in scene.entries:
        if not entry.node.visible or not entry.has("batch_rows"):continue
        for row in entry.batch_rows:
            if GroundReceiving.mask(row,supports)>0:joins+=1
            else:exposed+=1
    return {"joined":joins,"unjoined":exposed,"props":prop_entries(scene).filter(func(entry):return entry.node.visible).size()}

## Move and brighten every table light; restore by republishing the scene's own sources.
func perturb_lights(scene:Node,perturbed:bool)->void:
    var sources:Array=[]
    for source in scene.source_lighting.canvas_sources():
        var copy:Dictionary=source.duplicate()
        if perturbed:copy.energy=8.0;copy.screen_position+=Vector2(331,173)
        sources.append(copy)
    scene.light_table.publish(sources,scene.generated_shadows.cookie_image)

func lighting_receipt(scene:Node)->Dictionary:
    var actors=[]
    for id in scene.timeline.state.audience.controlled:
        var actor:Dictionary=scene.timeline.state.actors[id]
        var torches=[]
        for item in UI.inventory(actor,"",scene.timeline.state):
            if item.get("item_id","")=="equipment.portable_torch":
                torches.append({"id":item.item_uuid,"name":item.name,"is_lit":item.is_lit})
        actors.append({"id":id,"name":actor.name,"position":actor.last_visual_position,"torches":torches})
    var enabled:Dictionary={}
    for source in scene.source_lighting.canvas_sources():enabled[source.id]=source.enabled
    var lights=[]
    for source in scene.source_lighting.sources:
        var label=""
        if not source.actor_uuid.is_empty(): label=scene.timeline.state.actors[source.actor_uuid].name
        elif scene.timeline.state.objects.has(source.anchor_item_uuid): label=scene.timeline.state.objects[source.anchor_item_uuid].item.name
        lights.append({"id":source.item_uuid,"anchor_item_uuid":source.anchor_item_uuid,"name":label,"actor_id":source.actor_uuid,"position":[source.position.x,source.position.y,source.position.z],"enabled":enabled.get(source.item_uuid,false)})
    return {"sequence":scene.timeline.sequence,"actors":actors,"resolved_sources":lights,"table_lights":scene.light_table.count,"light_strength":scene.source_lighting.light_strength,"source_override":false,"wall_mode":scene.wall_mode}

func run()->void:
    var expect_off="--expect-carried-off" in OS.get_cmdline_user_args()
    var suffix="-carried-off" if expect_off else ""
    var capture_dir="res://.captures/surface-receiving"+suffix
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,800)
    ProjectSettings.set_setting("source_data/encounter_cache_mib",0)
    var scene=Player.instantiate();scene.timeline.paused=true;root.add_child(scene)
    var deadline=Time.get_ticks_msec()+240000
    while (not scene.session.recording_ready or not scene._media_ready({}) or scene.visual_actors.is_empty()) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
    check(scene.session.recording_ready and scene.media_initial_ready,"Actual user scene mandatory media publishes")
    while (scene.timeline.busy() or scene.timeline.sequence<scene.session.latest_sequence) and Time.get_ticks_msec()<deadline:
        scene.timeline.paused=false;scene.timeline.advance(1000);scene.timeline.paused=true;await scene.presentation_updated
    check(not scene.timeline.busy() and scene.timeline.state==scene.session.journal.state,"Actual finite canonical replay completes")
    scene.session.close();scene.hud.hide();scene.grid_visible=false;scene.camera.size=8.137
    if expect_off:
        scene.wall_mode="hidden"
        scene.update_wall_visibility()
    var canonical=scene.timeline.state.duplicate(true)
    var source_receipt=lighting_receipt(scene)
    if expect_off:
        check(source_receipt.actors.size()==2 and source_receipt.actors.all(func(actor):return actor.torches.size()==1 and not actor.torches[0].is_lit),"Both real recorded carried torches are inactive")
        check(source_receipt.resolved_sources.all(func(source):return source.actor_id.is_empty()),"No carried source is admitted into native lighting")
        check(source_receipt.resolved_sources.any(func(source):return source.enabled),"Real recorded wall fixtures remain active")
    DirAccess.make_dir_recursive_absolute(capture_dir)
    for quarter in 4:
        scene.set_process(true);scene.request_view(quarter)
        while scene.rotation_pending() and Time.get_ticks_msec()<deadline:await scene.presentation_updated
        await scene.presentation_updated;await scene.presentation_updated;scene.set_process(false)
        var after=await snapshot()
        set_joins(scene,false)
        var exposed_skirts=await snapshot()
        original_receiving(scene,true)
        var before=await snapshot()
        original_receiving(scene,false)
        var restored_after=await snapshot()
        var counts=receiver_counts(scene)
        var delta=difference(before,after)
        check(counts.joined>0 and counts.props>0,"Actual published terrain/prop receivers use both corrected inputs q"+str(quarter))
        check(difference(exposed_skirts,after).changed>0,"Actual final framebuffer responds to connected-floor joins q"+str(quarter))
        check(difference(before,exposed_skirts).changed>0,"Actual final framebuffer responds to integrated prop normals q"+str(quarter))
        check(delta.changed>0,"Actual final framebuffer responds to corrected receiving q"+str(quarter))
        check(delta.alpha==0,"Actual final framebuffer keeps alpha q"+str(quarter))
        check(difference(after,restored_after).maximum==0,"Restoring corrected inputs restores the published frame exactly q"+str(quarter))
        before.save_png(capture_dir+"/q%d-before.png"%quarter);after.save_png(capture_dir+"/q%d-after.png"%quarter)
        scene.set_normals_visible(true);publish_receiving(scene)
        var normals=await snapshot()
        check(difference(after,normals).changed>0,"Normals view shows receiving vectors without native illumination q"+str(quarter))
        perturb_lights(scene,true)
        var moved_lights=await snapshot()
        check(difference(normals,moved_lights).maximum==0,"Normals view is exactly invariant to light energy and position q"+str(quarter))
        perturb_lights(scene,false)
        var shadow_visible=false
        for entry in scene.actor_entries:
            if entry.get("generated_shadow",false) and entry.node.visible:shadow_visible=true
        check(not shadow_visible,"Normals omits generated shadow overlays q"+str(quarter))
        normals.save_png(capture_dir+"/q%d-normals.png"%quarter)
        scene.set_normals_visible(false);publish_receiving(scene)
        var restored=await snapshot()
        check(difference(after,restored).maximum<=1,"Disabling Normals restores original receiving frame q"+str(quarter))
        receipts.append({"quarter":quarter,"joined":counts.joined,"unjoined":counts.unjoined,"props":counts.props,"difference":delta,"lights":scene.light_table.count})
    check(scene.timeline.state==canonical,"Receiving corrections never alter canonical gameplay")
    check(scene.presentation_errors.is_empty(),"Actual scene has no missing source or receiving errors")
    var report={"lighting":source_receipt,"checks":checks,"failures":failures,"cases":receipts,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"scope":"Final3D finite recorded scene in four quarters, lit sprite shaders. Before uses original single-ray prop normals (geometry packet) and independently exposed floor skirts (no ground supports); after uses source pixel-integrated Cycles normals and published-topology interior joins. Alpha/state unchanged. Pixel differences are recorded, not a subjective-quality assertion."}
    FileAccess.open("res://generated/native_surface_receiving_checks"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("NATIVE_SURFACE_RECEIVING ",JSON.stringify(report));scene.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
