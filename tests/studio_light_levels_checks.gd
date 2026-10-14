extends SceneTree
const Overlay=preload("res://studio/light_levels.gd")
const Studio=preload("res://studio/studio.gd")
var checks=0
var failures=[]
var evidence=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("LIGHT_LEVELS_FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var view=SubViewport.new();view.size=Vector2i(640,480);view.own_world_3d=true;root.add_child(view)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9;view.add_child(camera)
    var overlay=Overlay.new();overlay.size=Vector2(640,480)
    var source=Studio.new()
    overlay.level_source=source._light_marker_level
    overlay.legend_label="Perceived light";root.add_child(overlay)
    var state={"tiles":{},"senses":{"visible":[],"effective_light_levels":{}}}
    for level in 5:
        var p=[level-2,0];var key="%d,0"%p[0]
        state.tiles[key]={"tile_uuid":"tile"+str(level),"position":p,"elevation_steps":level%2,"resolved_light":4-level}
        state.senses.visible.append(p);state.senses.effective_light_levels[key]=level
    state.tiles["0,1"]={"tile_uuid":"remembered","position":[0,1],"elevation_steps":0,"resolved_light":4}
    state.tiles["1,1"]={"tile_uuid":"unknown","position":[1,1],"elevation_steps":0}
    state.senses.visible.append([1,1]);state.senses.visible.append([2,1]);state.senses.effective_light_levels["2,1"]=3
    var original=state.duplicate(true)
    for quarter in 4:
        for zoom in [9.0,12.0]:
            camera.size=zoom;camera.position=Basis(Vector3.UP,quarter*PI/2)*Vector3(6,6,6);camera.look_at(Vector3.ZERO)
            overlay.refresh(state,[1],camera,Vector2(640,480))
            check(overlay.markers.size()==5,"Only disclosed currently visible tiles with current perceived level q%d zoom%s"%[quarter,zoom])
            for marker in overlay.markers:
                var tile:Dictionary=state.tiles["%d,%d"%marker.position]
                check(marker.level==state.senses.effective_light_levels["%d,%d"%marker.position],"Current perceived level wins over different tile observation q%d level%d"%[quarter,marker.level])
                var p=Vector3(tile.position[0],tile.elevation_steps*Overlay.Placement.HEIGHT_UNIT,tile.position[1])
                check(marker.center.distance_to(camera.unproject_position(p))<.001,"Marker follows original support elevation/view q%d level%d"%[quarter,marker.level])
            var revisions=overlay.rebuilds
            overlay.refresh(state,[1],camera,Vector2(640,480))
            check(overlay.rebuilds==revisions,"Unchanged displayed/view key does no marker rebuild")
    var sources=[{"item_uuid":"source","position":Vector3(1,4,2),"base_height_steps":1,"very":1.5,"bright":2.0,"outer":3.0}]
    overlay.refresh_ranges(sources,{"source":{"position":Vector3(2,8,2)}},camera,Vector2(640,480))
    check(overlay.ranges.size()==3,"Same diagnostic draws only the three existing resolved source ranges")
    for ring in overlay.ranges:
        check(ring.radius_cells==[1.5,2.0,3.0][ring.tier],"Source range preserves resolved radius without new light classification")
        check(ring.origin==Vector3(2,Overlay.Placement.HEIGHT_UNIT,2),"Moving source range follows sampled XY and authoritative support band")
        check(ring.points[0].distance_to(camera.unproject_position(ring.origin+Vector3(ring.radius_cells,0,0)))<.001,"Range projection uses supplied circle geometry")
    overlay.visible=false
    check(overlay.inspection().markers.is_empty(),"Disabled overlay exposes no drawn markers")
    overlay.visible=true
    check(overlay.inspection().markers.size()==5 and overlay.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Toggle restores passive markers without intercepting clicks")
    check(state==original,"Projection and toggles cannot mutate canonical light/visibility")
    var changed=state.duplicate(true);changed.senses.effective_light_levels["0,0"]=1
    overlay.refresh(changed,[2],camera,Vector2(640,480))
    check(overlay.markers.any(func(m):return m.tile_uuid=="tile2" and m.level==1),"New admitted perception replaces previous marker without a tile change")
    overlay.free();view.free();source.free()
    var native=false
    for arg in OS.get_cmdline_user_args():native=native or arg.begins_with("--recording=")
    if native:await actual_studio()
    var report={"checks":checks,"failures":failures,"native_recording":native,"evidence":evidence,"scope":"Current displayed senses.effective_light_levels, explicit Perceived label including darkvision, no stale tile fallback, disclosed current visibility, elevation/camera/zoom, passive toggle and cached redraw. Does not claim native radiance equals server categories."}
    FileAccess.open("res://generated/studio_light_levels_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_LIGHT_LEVELS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func settle(studio:Control)->bool:
    var deadline=Time.get_ticks_msec()+120000
    while (studio.index.is_empty() or studio.loader!=null or studio.seeker!=null or studio.installing or studio.requested_seek>=0 or studio.world.rotation_pending()) and Time.get_ticks_msec()<deadline:await process_frame
    var ok=not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and not studio.world.rotation_pending()
    check(ok,"Actual Studio publishes requested recording boundary")
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    return ok
func capture(studio:Control)->Image:
    await process_frame;await RenderingServer.frame_post_draw
    return root.get_texture().get_image().get_region(Rect2i(studio.preview.get_global_rect()))
func actual_studio()->void:
    DisplayServer.window_set_size(Vector2i(1280,720))
    var studio=Studio.new();root.add_child(studio)
    if not await settle(studio):studio.queue_free();await process_frame;return
    var state=studio.world.timeline.state.duplicate(true);var clock=studio.world.timeline.display_ms
    check(not studio.light_levels_button.button_pressed and not studio.light_levels.visible,"Studio opens with diagnostic off")
    var before=await capture(studio)
    studio.light_levels_button.button_pressed=true
    var shown=await capture(studio)
    check(not studio.light_levels.inspection().markers.is_empty(),"Actual enabled Control contains rendered marker geometry")
    check(before.get_data()!=shown.get_data(),"Toggle visibly draws native unlit marker overlay")
    check(studio.light_levels_button.get_global_rect().end.x<=studio.size.x,"Light levels control fits actual toolbar")
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/light-levels")
    shown.save_png("res://.captures/studio/light-levels/initial-on.png")
    studio.light_levels_button.button_pressed=false
    var restored=await capture(studio)
    check(before.get_data()==restored.get_data(),"Disabling diagnostic at the same view restores exact original preview pixels")
    studio.light_levels_button.button_pressed=true;await capture(studio)
    check(studio.light_levels.ranges.size()==studio.world.source_lighting.sources.size()*3,"Actual Studio projects current disclosed source ranges")
    for q in 4:
        studio.world.request_view(q)
        if not await settle(studio):break
        var image=await capture(studio);image.save_png("res://.captures/studio/light-levels/q%d.png"%q)
        var visible={}
        for p in studio.world.timeline.state.senses.visible:visible["%d,%d"%p]=true
        for marker in studio.light_levels.markers:
            var key="%d,%d"%marker.position
            check(visible.has(key) and studio.world.timeline.state.senses.effective_light_levels.get(key)==marker.level,"Actual q%d marker uses displayed perceived visible tile"%q)
        evidence.append({"quarter":q,"markers":studio.light_levels.markers.size(),"level_counts":_level_counts(studio.light_levels.markers),"source_rings":studio.light_levels.ranges.size()})
    check(studio.world.timeline.state==state and studio.world.timeline.display_ms==clock,"Toggle and camera never change displayed canonical state/clock")
    studio.world.request_view(0);await settle(studio)
    studio._seek(float(studio.index.groups[0].start_ms)+float(studio.index.groups[0].group.duration_ms))
    if await settle(studio):
        studio.light_levels_button.button_pressed=true;await capture(studio)
        check(studio.light_levels.visible and studio.light_levels.inspection().enabled,"Toggle survives atomic seek owner replacement")
    var has_blue=studio.active_case.get("perspectives",[]).any(func(p):return str(p.id)=="blue")
    check(has_blue,"Actual Hide case supplies its independent Blue recording")
    if has_blue:
        studio.select_perspective("blue")
        if await settle(studio):
            await capture(studio)
            check(studio.active_perspective=="blue" and studio.light_levels.visible,"Diagnostic stays enabled on faction switch")
            for marker in studio.light_levels.markers:
                var cell="%d,%d"%marker.position
                check(studio.world.timeline.state.senses.effective_light_levels.get(cell)==marker.level,"Faction markers use only the newly displayed observer aggregate")
    var before_reload=studio.world
    studio._load(studio.active_directory)
    if await settle(studio):
        await capture(studio)
        check(studio.world!=before_reload and studio.light_levels.visible,"Enabled overlay follows accepted reload owner")
    check(studio.world.presentation_errors.is_empty() and studio.world.media_issue.is_empty(),"Overlay introduces no production source errors")
    studio.queue_free();await process_frame;await process_frame

func _level_counts(markers:Array)->Dictionary:
    var counts={}
    for marker in markers:counts[str(marker.level)]=counts.get(str(marker.level),0)+1
    return counts
