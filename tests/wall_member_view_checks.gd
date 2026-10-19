extends SceneTree
const ViewPublication=preload("res://tests/view_publication.gd")
# Whole recorded room: reconstruct all native wall artwork independently of the
# runtime visibility selector. No neighboring wall is allowed to cancel its bug.
const Player = preload("res://play.tscn")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Cells=preload("res://sdk/fold_cells.gd")
const BACK_FACES = [["west","south"],["west","north"],["east","north"],["east","south"]]
var checks=0
var failures: Array=[]
var comparisons: Array=[]
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures.append(label); print("WALL_MEMBER_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func capture() -> Image:
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func press_z() -> void:
    var event=InputEventKey.new(); event.keycode=KEY_Z; event.physical_keycode=KEY_Z; event.pressed=true
    root.push_input(event,true); event=event.duplicate(); event.pressed=false; root.push_input(event,true)
func compare(a: Image,b: Image,label: String,tolerance: float=0.0) -> void:
    var bad=0; var maximum=0.0; var differences=[]
    for y in range(0,a.get_height(),2):
        for x in range(0,a.get_width(),2):
            var av=a.get_pixel(x,y); var bv=b.get_pixel(x,y)
            var delta=maxf(absf(av.r-bv.r),maxf(absf(av.g-bv.g),absf(av.b-bv.b)))
            maximum=maxf(maximum,delta)
            # Recreated transparent draws can round by two output bytes at an
            # MSAA/mask edge. Hidden and restoration retain exact measurements.
            if delta>tolerance+.000001:
                bad+=1
                if differences.size()<12: differences.append([x,y,str(av),str(bv)])
    if bad>0:
        print("WALL_MEMBER_PIXELS ",label," ",differences)
        a.save_png("res://.captures/walls/member-failed-actual.png"); b.save_png("res://.captures/walls/member-failed-reference.png")
    check(bad==0,label+": complete room equals independent native-member composition (differing %d, max %s)"%[bad,maximum])
    comparisons.append({"case":label,"different_samples":bad,"maximum":maximum,"tolerance":tolerance})
func reference(scene: Node, quarter: int, mode: String) -> Image:
    var original: Array=scene.static_entries.duplicate()
    var original_entries: Array=scene.entries.duplicate()
    var shown={}; var sources={}
    var visibility:Dictionary=scene.WorldRows.visibility(scene.timeline.presentation_state())
    for entry in original:
        if not entry.has("wall_source"): continue
        sources[entry.wall_source.id]=entry.wall_source
        shown[entry.node.get_instance_id()]=entry.node.visible; entry.node.hide()
    scene.static_entries=original.filter(func(entry):return not entry.has("wall_source"))
    var first: int=scene.entries.size()
    for source in sources.values():
        var members: Array=source.get("wall_members",[source])
        var front: Array=members.filter(func(member):return not member.boundaries[0] in BACK_FACES[quarter])
        var same_style:bool=members.all(func(member):return visibility.get(member.id,false)==visibility.get(members[0].id,false))
        var selected: Array=[source] if same_style and (mode=="solid" or front.is_empty() or front.size()==members.size()) else members
        for row in selected:
            var fading: bool=not row.boundaries[0] in BACK_FACES[quarter]
            var alpha=1.0 if mode=="solid" or not fading else (.28 if mode=="translucent" else 0.0)
            if alpha==0: continue
            var start: int=scene.entries.size()
            scene.add_environment_entries(row)
            for entry in scene.entries.slice(start):
                scene.initialize_entry(entry); scene._light_entry(entry)
                entry.material.set_shader_parameter("current_visibility",1.0 if visibility.get(row.id,false) else 0.0)
                if quarter==2 and mode=="hidden":
                    for prior in original:
                        if prior.placement==entry.placement and prior.role==entry.role and prior.layer==entry.layer and shown.get(prior.node.get_instance_id(),false):
                            for field in ["local_to_world","source_to_local","normal_to_local","local_normal_to_world","current_visibility","geometry_rect","source_tint"]:
                                if prior.material.get_shader_parameter(field)!=entry.material.get_shader_parameter(field):print("WALL_REFERENCE_UNIFORM ",entry.id," ",field," ",prior.material.get_shader_parameter(field)," ",entry.material.get_shader_parameter(field))
                            if prior.node.basis!=entry.node.basis:print("WALL_REFERENCE_BASIS ",entry.id," ",prior.node.basis," ",entry.node.basis)
                            break
                entry.id+=":"+("joined" if row.has("wall_members") else row.id)
                entry.material.set_shader_parameter("wall_opacity",alpha)
                entry.material.set_shader_parameter("wall_mask_enabled",mode=="translucent" and entry.role!="shadow")
                scene.static_entries.append(entry)
    scene.static_order_dirty=true; scene.wall_mask_dirty=true; scene._sort_draws()
    var expected=await capture()
    for entry in scene.entries.slice(first): entry.node.queue_free()
    scene.static_entries=original; scene.entries=original_entries
    for entry in original:
        if entry.has("wall_source"): entry.node.visible=shown[entry.node.get_instance_id()]
    scene.static_order_dirty=true; scene.wall_mask_dirty=true; scene._sort_draws()
    return expected
func picking(scene: Node,quarter: int) -> void:
    var found_front=false; var found_rear=false
    for entry in scene.wall_pick_order:
        var front: bool=not entry.placement.boundaries[0] in BACK_FACES[quarter]
        if (front and found_front) or (not front and found_rear): continue
        var origin: Vector2=scene.camera.unproject_position(scene.Placement.contact(entry.placement))
        var scale: float=origin.distance_to(scene.camera.unproject_position(scene.Placement.contact(entry.placement)+scene.camera.basis.x))/scene.Placement.PIXELS_PER_UNIT
        for y in range(40,220,10):
            for x in range(40,220,10):
                var point: Vector2=origin+(Vector2(x,y)-scene.v2(entry.record.pivot))*entry.record.scale*scale
                if not root.get_visible_rect().has_point(point): continue
                scene.force_attack=true; var forced: Dictionary=scene.pick_world(point)
                scene.force_attack=false; var ordinary: Dictionary=scene.pick_world(point)
                if forced.get("id")!=entry.placement.id: continue
                if front:
                    check(ordinary.get("id")!=entry.placement.id,"Hidden foreground has no ordinary ghost hit q%d"%quarter)
                    found_front=true
                elif ordinary.get("id")==entry.placement.id: found_rear=true
                if (front and found_front) or (not front and found_rear): break
            if (front and found_front) or (not front and found_rear): break
    check(found_front,"Ctrl reaches hidden native front q%d"%quarter)
    check(found_rear,"Ordinary click reaches solid rear q%d"%quarter)
func run() -> void:
    if DisplayServer.get_name()=="headless": quit(2); return
    root.unfocusable=true; root.position=Vector2i(-16000,-16000)
    var scene=Player.instantiate(); scene.timeline.paused=true; root.add_child(scene)
    var opened:Dictionary=scene.session.open_recording(Fixtures.journal("door"))
    check(opened.ok,"Durable original schema16 Door recording opens")
    if not opened.ok:scene.queue_free();await process_frame;quit(1);return
    var deadline=Time.get_ticks_msec()+120000
    while (not scene.session.recording_ready or not scene._environment_media_ready() or not scene.MediaWarmup.ready(scene.media_warmup,scene.media_plan.required)) and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    scene.session.close(); await scene.presentation_updated; scene.set_process(false); scene.hud.hide()
    if "--fixed-direct" in OS.get_cmdline_user_args():
        for light in scene.source_lighting.nodes.values(): light.visible=false
    check(scene.session.issue.is_empty() and not scene.timeline.state.is_empty() and scene._environment_media_ready(),"Real recording and original four-view assets ready")
    if scene.timeline.state.is_empty(): quit(1); return
    var canonical: Dictionary=scene.timeline.state.duplicate(true)
    # Explicit rendering fixture: every disclosed support is currently visible.
    # All recorded walls stand on their own disclosed floor; expected front/back
    # choices therefore require no runtime overlap helper in this pixel oracle.
    scene.timeline.state.senses.visible=Cells.mask(scene.timeline.state.tiles.values().map(func(tile):return tile.position))
    check(scene.placements.any(func(row):return row.kind in ["wall","cliff"]),"Actual disclosed room has physical wall members for framebuffer and picking checks")
    for row in scene.placements:
        if row.kind not in ["wall","cliff"]: continue
        var tile: Dictionary=scene.timeline.state.tiles.get("%d,%d"%row.position,{})
        check(not tile.is_empty() and tile.elevation_steps==row.base_height_steps,"Native wall has same-height interior support: "+row.id)
    var before: Dictionary=scene.timeline.state.duplicate(true)
    DirAccess.make_dir_recursive_absolute("res://.captures/walls")
    for quarter in range(4):
        scene.wall_mode="solid"; check(await ViewPublication.finish(scene,quarter),"Requested camera quarter publishes")
        root.size=Vector2i(1440,900) if quarter%2==0 else Vector2i(1280,720)
        scene.camera_focus=Vector3(4,0,5); scene.camera.size=9.1+quarter*.37; scene.position_camera()
        scene.update_wall_visibility()
        var solid=await capture()
        compare(await capture(),solid,"q%d unchanged solid repeat"%quarter)
        for mode in ["translucent","hidden"]:
            press_z(); check(scene.wall_mode==mode,"Z enters "+mode)
            var actual=await capture(); actual.save_png("res://.captures/walls/member-%s-%d.png"%[mode,quarter])
            var expected=await reference(scene,quarter,mode)
            compare(actual,expected,"q%d %s"%[quarter,mode],2.0/255.0 if mode=="translucent" else 0.0)
            if mode=="hidden": picking(scene,quarter)
        press_z(); compare(await capture(),solid,"q%d solid restoration"%quarter)
        scene.wall_mode="hidden"; scene.update_wall_visibility()
        scene.timeline.state.senses.visible=Cells.mask([]); scene.update_wall_visibility()
        # Lost sight changes floor/member memory styling; compare the restored
        # originals at that same subjective state, not the earlier lit floor.
        var without_supports=await capture()
        compare(without_supports,await reference(scene,quarter,"solid"),"q%d no visible supports restores all members"%quarter)
        scene.timeline.state.senses.visible=before.senses.visible.duplicate(true); scene.update_wall_visibility()
    check(scene.timeline.state==before,"Z/view changes do not alter canonical state")
    scene.timeline.state=canonical
    check(await ViewPublication.finish(scene,0),"Requested camera quarter publishes"); scene.wall_mode="hidden"; scene.update_wall_visibility()
    (await capture()).save_png("res://.captures/walls/member-actual-visibility-hidden.png")
    scene.wall_mode="translucent"; scene.update_wall_visibility()
    (await capture()).save_png("res://.captures/walls/member-actual-visibility-translucent.png")
    var report={"checks":checks,"failures":failures,"comparisons":comparisons,"direct_lights_enabled":"--fixed-direct" not in OS.get_cmdline_user_args(),"scope":"All native walls rebuilt independently; original four-view source RGBA/normal/depth; whole-member opacity; fractional zoom; source targeting; displayed visibility."}
    var file=FileAccess.open("res://generated/wall_member_view_checks.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
    print(JSON.stringify(report)); scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
