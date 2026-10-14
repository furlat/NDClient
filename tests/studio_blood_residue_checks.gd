extends SceneTree
## Actual recorded Dash/OA -> native landing -> persistent server tile stain.
const Studio=preload("res://studio/studio.gd")
const Blood=preload("res://presentation/blood.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
const CAPTURE="res://.captures/studio/blood-residue"
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("STUDIO_BLOOD_RESIDUE_FAIL ",label)
func ready(studio:Control)->bool:
    return not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and not studio.world.rotation_pending() and studio.world.component_renderer.ready
func settle(studio:Control)->bool:
    var deadline=Time.get_ticks_msec()+150000
    while not ready(studio) and Time.get_ticks_msec()<deadline:await process_frame
    check(ready(studio),"Requested recorded view publishes: "+studio.status.text)
    if not ready(studio):return false
    await process_frame;await RenderingServer.frame_post_draw;await process_frame;await RenderingServer.frame_post_draw
    check(studio.world.presentation_errors.is_empty(),"No production presentation source error")
    return true
func capture(studio:Control,label:String)->Image:
    await process_frame;await RenderingServer.frame_post_draw
    var image=studio.viewport.get_texture().get_image();image.save_png(CAPTURE.path_join(label+".png"));return image
func fields(studio:Control)->Dictionary:
    var result={}
    for key in studio.world.component_renderer.blood.deposits:
        var handle:Dictionary=studio.world.component_renderer.blood.deposits[key]
        result[key]=handle.field.get_texture().get_image()
    return result
func nonzero(image:Image)->int:
    var result=0
    for y in image.get_height():
        for x in image.get_width():
            if image.get_pixel(x,y).r>.13:result+=1
    return result
func run()->void:
    if not Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--recording=")):
        print("Usage: --recording=<actual dash-seed3 Amber journal>");quit(2);return
    DisplayServer.window_set_size(Vector2i(1280,720));DirAccess.make_dir_recursive_absolute(CAPTURE)
    var studio=Studio.new();root.add_child(studio)
    if not await settle(studio):await finish(studio);return
    var rows=studio.index.rows.filter(func(row):return row.kind=="residue_deposit")
    check(rows.size()==1,"Actual opportunity hit has one authored residue track")
    if rows.is_empty():await finish(studio);return
    var row:Dictionary=rows[0];var component:Dictionary=row.component
    check(studio.world.component_renderer.blood.deposits.is_empty(),"Initialization has no blood surface")
    var original_state:Dictionary=studio.world.timeline.state
    var tile_shell:Dictionary=original_state.tiles
    var continuous_cost:Array=[];var cold_cost:Array=[];var transient_cost:Array=[];var raw_cost:Array=[];var preparation_cost:Array=[];var hidden_future=true;var bounded_preparation=true;var saw_preparation=false;var seen_flight=false;var deadline_forward=Time.get_ticks_msec()+30000
    studio.world.timeline.paused=false
    while studio.world.timeline.display_ms<row.start_ms+component.duration_ms+.01 and Time.get_ticks_msec()<deadline_forward:
        await process_frame
        var live=studio.world.component_renderer.blood
        if live.prepare_frame==Engine.get_process_frames()-1 and live.prepare_allocations>0:
            preparation_cost.append(live.prepare_usec/1000.)
            bounded_preparation=bounded_preparation and live.prepare_allocations<=2
        for handle in live.pending_deposits.values():
            saw_preparation=true;hidden_future=hidden_future and not handle.entry.node.visible
        var cost=live.last_sample_usec/1000.
        continuous_cost.append(cost)
        raw_cost.append({"display_ms":studio.world.timeline.display_ms,"cpu_ms":cost,"allocations":live.last_allocations,"fields":live.deposits.size(),"flights":live.flights.size()})
        if live.last_allocations>0:cold_cost.append(cost)
        elif studio.world.timeline.display_ms>row.start_ms and studio.world.timeline.display_ms<row.start_ms+component.duration_ms:transient_cost.append(cost)
        seen_flight=seen_flight or not live.flights.is_empty()
    studio.world.timeline.paused=true
    check(studio.world.timeline.display_ms>=row.start_ms+component.duration_ms,"Real playback reaches complete landing without seek")
    check(is_same(tile_shell,studio.world.timeline.state.tiles),"Continuous real commits retain the original mutable tile dictionary")
    check(saw_preparation and hidden_future,"Lookahead creates only hidden future field handles before canonical publication")
    check(bounded_preparation,"Existing preparation owner creates at most two tile fields per rendered frame")
    check(seen_flight,"Continuous real playback shows finite airborne source geometry")
    check(studio.world.component_renderer.blood.deposits.size()==20,"Continuous in-place tile commits discover all twenty new blood surfaces")
    await process_frame;await RenderingServer.frame_post_draw
    var continuous_pixels=0
    for image in fields(studio).values():continuous_pixels+=nonzero(image)
    check(continuous_pixels>100,"Continuous no-blood to impact path draws actual retained stain pixels")
    await capture(studio,"continuous-landing-complete")
    studio._seek(row.start_ms-.01)
    if not await settle(studio):await finish(studio);return
    var before=fields(studio);var before_pixels=0
    for image in before.values():before_pixels+=nonzero(image)
    check(before_pixels==0,"No new stain visible before actual release")
    await capture(studio,"before-contact")
    var at=row.start_ms+component.duration_ms*.78
    studio._seek(at)
    if not await settle(studio):await finish(studio);return
    var renderer=studio.world.component_renderer.blood
    check(not renderer.flights.is_empty(),"Advancing native geometry has actual airborne droplet batches")
    check(renderer.flights.size()<112,"Droplets are batched into painter cells, not one node per particle")
    var snapshots=fields(studio);var active_pixels=0
    for key in snapshots:
        active_pixels+=nonzero(snapshots[key]);snapshots[key].save_png(CAPTURE.path_join("field-"+key.replace(",","_")+".png"))
    check(active_pixels>0,"Partial landing has real nonzero native ground coverage")
    var mid_peak=renderer.peak_sample_usec/1000.0
    var thumb=studio.tracks.thumbnails
    var thumb_key=thumb.request(row,at,studio.world.quarter)
    var deadline=Time.get_ticks_msec()+30000
    while not thumb.textures.has(thumb_key) and not thumb.errors.has(thumb_key) and Time.get_ticks_msec()<deadline:await process_frame
    check(thumb.textures.has(thumb_key),"Actual residue track has a shared native source thumbnail")
    if thumb.textures.has(thumb_key):
        var image:Image=thumb.textures[thumb_key].get_image()
        var used=image.get_used_rect()
        var red=0;var transparent=0;var opaque_white=0
        for y in image.get_height():
            for x in image.get_width():
                var pixel=image.get_pixel(x,y)
                if pixel.a<.01:transparent+=1
                elif pixel.r>pixel.g*2 and pixel.r>pixel.b*1.5:red+=1
                elif pixel.r>.95 and pixel.g>.95 and pixel.b>.95:opaque_white+=1
        check(used.has_area() and red>20 and transparent>20 and opaque_white==0,"Native source thumbnail has actual red blood and transparent surroundings, no unrendered white rectangle")
        image.save_png(CAPTURE.path_join("landing-source.png"))
    await capture(studio,"landing")
    var actor=studio.world.visual_actors.get(component.actor_uuid,{})
    if not actor.is_empty():studio.world.camera_focus=PlacementContact(actor.row);studio.world.camera.size=6;studio.world.position_camera()
    var upload_count=renderer.field_uploads
    for i in 5:await process_frame
    check(renderer.field_uploads==upload_count,"Paused age does not reupload unchanged tile fields")
    var end=minf(studio.index.duration_ms,row.start_ms+component.duration_ms+.05)
    studio._seek(end)
    if not await settle(studio):await finish(studio);return
    renderer=studio.world.component_renderer.blood
    var complete=fields(studio);var settled_pixels=0
    var field_error=0.0;var oracle_pixels=0
    for cell in complete:
        var path="res://.runtime/blood-liquid-reference/"+cell+".bin"
        check(FileAccess.file_exists(path),"Independent original Pygame field exists for "+cell)
        if not FileAccess.file_exists(path):continue
        var expected=FileAccess.get_file_as_bytes(path).to_float32_array()
        for y in 64:
            for x in 64:
                field_error=maxf(field_error,absf(complete[cell].get_pixel(x,y).r-expected[y*64+x]));oracle_pixels+=1
    # Native HDR2D additive storage is RGBA16F; compare its numeric field
    # against the independent float32 Pygame formula and report the residual.
    check(field_error<=.008,"Native affine kernels match independent original pointwise Pygame field")
    for image in complete.values():settled_pixels+=nonzero(image)
    check(complete.size()==20,"All twenty actual residue after-values reach retained native tile surfaces")
    check(settled_pixels>active_pixels and settled_pixels>100,"Landed source kernels create actual nonzero persistent coverage")
    check(renderer.flights.is_empty(),"Finite flight ends while canonical ground stain persists")
    var stable=renderer.field_uploads
    var costs:Array=[]
    for i in 10:await process_frame;costs.append(renderer.last_sample_usec/1000.0)
    check(renderer.field_uploads==stable,"Settled blood performs no per-frame field uploads")
    for quarter in 4:
        if studio.world.quarter!=quarter:studio.world.request_view(quarter)
        if not await settle(studio):break
        var current=fields(studio)
        var exact=current.size()==complete.size()
        for key in current:exact=exact and current[key].get_data()==complete[key].get_data()
        check(exact,"Camera quarter preserves native world-space liquid field "+str(quarter))
        await capture(studio,"q%d-settled"%quarter)
    studio._seek(at)
    if await settle(studio):
        var reversed=fields(studio);var exact=reversed.size()==snapshots.size()
        for key in reversed:exact=exact and reversed[key].get_data()==snapshots[key].get_data()
        check(exact,"Reverse seek restores exact native landing field bytes")
        await capture(studio,"reverse-landing")
    DirAccess.make_dir_recursive_absolute("res://.runtime/blood-native")
    FileAccess.open("res://.runtime/blood-native/cpu_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":raw_cost,"preparation":preparation_cost,"settled":costs}))
    evidence.append({"event":component.source_event_uuid,"tiles":complete.size(),"mid_coverage":active_pixels,"settled_coverage":settled_pixels,"settled_cpu_ms":statistics(costs),"continuous_cpu_ms":statistics(continuous_cost),"allocation_frame_cpu_ms":statistics(cold_cost),"bounded_prepare_cpu_ms":statistics(preparation_cost),"warm_transient_cpu_ms":statistics(transient_cost),"continuous_stain_pixels":continuous_pixels,"mid_ms":at,"mid_peak_cpu_ms":mid_peak,"original_field_pixels":oracle_pixels,"max_original_field_error":field_error,"settled_ms":end,"captures":CAPTURE})
    await prepared_lifetime_probe(studio,component)
    await finish(studio)
func prepared_lifetime_probe(studio:Control,component:Dictionary)->void:
    # Isolated renderer ownership probe, using the actual admitted occurrence.
    # It does not insert a fabricated removal into the recorded Timeline.
    var view=SubViewport.new();view.size=Vector2i(128,128);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var fixture=preload("res://presentation/blood_preview.gd").new();view.add_child(fixture)
    fixture.catalog_cache=studio.world.catalog_cache;fixture.source_lighting=studio.world.source_lighting
    fixture.camera=Camera3D.new();fixture.add_child(fixture.camera);fixture.camera.position=Vector3(4,8,6);fixture.camera.rotation_degrees.x=-90
    fixture.timeline.queue=[{"id":"actual-occurrence-cancellation-probe","components":[component]}]
    var iterations=0;var complete=false;var hidden=true;var bounded=true
    while not complete and iterations<15:
        complete=fixture.renderer.prepare(fixture,fixture.timeline.queue)
        hidden=hidden and fixture.renderer.deposits.is_empty()
        for handle in fixture.renderer.pending_deposits.values():hidden=hidden and not handle.entry.node.visible
        bounded=bounded and fixture.renderer.prepare_allocations<=2
        fixture.sample();iterations+=1;await process_frame;await RenderingServer.frame_post_draw
    check(complete and iterations>=10 and bounded,"Repeated existing preparation calls make bounded progress for twenty fields")
    check(hidden and fixture.timeline.state.tiles.is_empty(),"Prepared fields cannot publish future residue or canonical tile data")
    fixture.timeline.queue=[];fixture.sample()
    check(fixture.renderer.pending_deposits.is_empty() and fixture.actor_entries.is_empty(),"Canceled prepared occurrence releases hidden nodes and fields")
    fixture.close();view.queue_free();await process_frame;await RenderingServer.frame_post_draw
func statistics(values:Array)->Dictionary:
    var ordered=values.duplicate();ordered.sort()
    return {"samples":ordered.size(),"median":ordered[ordered.size()/2],"p95":ordered[mini(ordered.size()-1,ceili(ordered.size()*.95)-1)],"max":ordered.back()} if not ordered.is_empty() else {}
func PlacementContact(row:Dictionary)->Vector3:return Vector3(row.position[0],row.base_height_steps*sqrt(2./3.),row.position[1])
func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame;await RenderingServer.frame_post_draw
    FileAccess.open("res://generated/studio_blood_residue_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual recorded twenty-tile Dash opportunity injury through shared Studio/Timeline/native Canvas receiving; source alpha coverage, immutable world fields, four quarters and reverse seek."},"  "))
    print("STUDIO_BLOOD_RESIDUE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
