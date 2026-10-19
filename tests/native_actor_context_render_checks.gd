extends SceneTree
## Actual schema16 Mirror application through the shared Play/Factory path.
const Recording=preload("res://studio/recording.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Play=preload("res://play.gd")
var checks:int=0
var failures:Array=[]
var evidence:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("ACTOR_CONTEXT_RENDER_FAIL "+label)
func frame()->void:
    await process_frame
    await RenderingServer.frame_post_draw
func settle(world:Node)->bool:
    var deadline:int=Time.get_ticks_msec()+45000
    while Time.get_ticks_msec()<deadline and world.presentation_errors.is_empty() and world.media_issue.is_empty():
        if world.playback_prepared():
            await frame()
            if world.playback_prepared():return true
        await frame()
    check(false,"Actual history playback prepares: "+str({"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics}))
    return false
func run()->void:
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var index:Dictionary=Recording.read("res://tests/fixtures/schema16/mirror-image/amber")
    check(index.ok,"Current actual Mirror Image recording opens: "+str(index.get("error","")))
    if not index.ok:finish();return
    var requirements:Array=[]
    for group in index.groups:
        for row in group.group.get("native_requirements",[]):
            if "actor_context" in row.get("native_clip",{}).get("inputs",[]):requirements.append(row)
    check(not requirements.is_empty(),"Actual condition creates early native requirements")
    for row in requirements:
        check(not row.has("condition") and row.get("native_preparation_inputs",{}).get("history_state",{}).get("duplicate_count")==3,"Early preparation retains only the exact small disclosed count")
    var view:SubViewport=SubViewport.new();view.size=Vector2i(640,480);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false)
    view.add_child(world);world.install_playback(Recording.restore(index,0))
    if not await settle(world):view.queue_free();await frame();finish();return
    # Give received future requirements their real preparation lead, then let
    # production Play advance normally through the actual application.
    for unused in 12:await frame()
    world.timeline.paused=false;world.external_clock=false
    var playback_deadline:int=Time.get_ticks_msec()+30000
    while world.timeline.display_ms<index.presentation_end_ms and Time.get_ticks_msec()<playback_deadline:await frame()
    world.external_clock=true;world.timeline.paused=true
    check(world.timeline.display_ms>=index.presentation_end_ms,"Actual recorded application plays forward from ordinary initial state")
    if world.timeline.display_ms<index.presentation_end_ms:view.queue_free();await frame();finish();return
    if not await settle(world):view.queue_free();await frame();finish();return
    var native=world.component_renderer.native_spells
    var ids:Array=native.handles.keys().filter(func(id):return "actor_context" in native.handles[id].clip.get("inputs",[]))
    check(ids.size()==1,"One real condition owns one native history occurrence")
    if ids.size()==1:
        var id:String=ids[0];var handle:Dictionary=native.handles[id]
        var actor:String=handle.component.actor_uuid
        var row:Dictionary=world.visual_actors[actor].row
        world.camera_focus=Play.Placement.contact(row);world.initial_focus=true
        world.camera.size=4;world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
        await frame();await frame();await frame()
        var history:RefCounted=handle.occurrence.actor_history
        check(handle.root==handle.occurrence,"Display ownership includes the complete source occurrence")
        check(handle.component.condition.state.duplicate_count==3,"Copies use the actual recorded condition count")
        check(handle.get("actor_context_bound",false) and history.admitted,"Actual context admitted through public setter")
        check(history.copies.size()==3 and handle.geometry.size()==3,"All three native outputs are registered after source allocation")
        for piece in handle.geometry:
            check(piece.node.get_world_3d()==world.get_world_3d() and piece.node.layers==handle.layer_mask,"Only same-world output geometry belongs to the native pass")
        for quarter in 4:
            world.request_view(quarter)
            var deadline:int=Time.get_ticks_msec()+45000
            while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
            check(not world.rotation_pending() and world.quarter==quarter,"Actual context follows camera quarter "+str(quarter))
            if not await settle(world):break
            await frame();await frame()
            check(native.handles.has(id) and native.handles[id].occurrence==handle.occurrence,"Camera recapture keeps condition occurrence ownership")
            check(handle.geometry.size()==3 and history.packet.camera==world.camera,"Camera rebuild replaces outputs without retaining capture-world meshes")
        evidence={"native":native.diagnostics.get(id,{}),"construction_ms":handle.construction_phases,"geometry":handle.geometry.size(),"history_allocated":handle.get("history_allocated",false)}
        world.set_process(false);await frame()
        var shown:Image=view.get_texture().get_image()
        Effects.hide(handle);await frame()
        var hidden:Image=view.get_texture().get_image()
        var a:PackedByteArray=shown.get_data();var b:PackedByteArray=hidden.get_data();var pixels:int=0
        for i in range(0,a.size(),4):
            if absi(a[i]-b[i])>3 or absi(a[i+1]-b[i+1])>3 or absi(a[i+2]-b[i+2])>3:pixels+=1
        evidence.changed_pixels=pixels
        evidence.phase_max_ms={}
        for sample in world.profile.frames:
            for phase in ["native_prepare_actor_context","native_spell_sample","native_input_bindings"]:
                evidence.phase_max_ms[phase]=maxf(evidence.phase_max_ms.get(phase,0.0),sample.cpu_ms.get(phase,0.0))
        check(pixels>0,"Real assembled copies contribute framebuffer pixels")
        check(not history.admitted and not handle.root.is_visible_in_tree(),"Inactive retained owner withdraws its public context and all output")
        for group in history.copies.values():
            check(group.colour.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and group.depth.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Inactive copy suspends both capture passes")
        for pass_data in history.live_bodies.values():check(pass_data.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Inactive owner suspends live-body capture")
        DirAccess.make_dir_recursive_absolute("res://.captures/native-actor-context")
        shown.save_png("res://.captures/native-actor-context/mirror-image.png")
        world.set_process(true);await frame();await frame()
        check(history.admitted and handle.root.is_visible_in_tree(),"Normal active sampling restores its exact public context")
        check(world.try_reset_hidden_playback(Recording.restore(index,0)),"Reverse seek restores independent initial state")
        await settle(world)
        check(native.handles.values().all(func(value):return not value.root.is_visible_in_tree()),"Before application no future copies are published")
    check(world.presentation_errors.is_empty(),"Actual playback has no presentation errors")
    view.queue_free();await frame();await frame();finish()
func finish()->void:
    var result={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual Mirror application, native output/ownership and replay. Colour parity, real count loss, Blur predecessors and Banishment departure remain separate gates."}
    FileAccess.open("res://.runtime/native-actor-context-render.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
