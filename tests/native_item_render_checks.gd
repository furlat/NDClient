extends SceneTree
## Real received item creation through Studio restore, Play and native compositing.
const Recording=preload("res://studio/recording.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Play=preload("res://play.gd")
const ITEM="d581a8b1-8878-4765-ae96-0d882c6310fc"
var checks:int=0
var failures:Array=[]
var evidence:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_ITEM_RENDER_FAIL "+label)
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
    check(false,"Actual native item playback prepares: "+str({"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics}))
    return false
func run()->void:
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var index:Dictionary=Recording.read("res://tests/fixtures/schema16/created-flame-blade/amber")
    check(index.ok,"Actual creation recording opens")
    if not index.ok:finish();return
    var view=SubViewport.new();view.size=Vector2i(960,640);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    world.component_renderer.audio.set_enabled(false)
    view.add_child(world);world.install_playback(Recording.restore(index,index.presentation_end_ms))
    if not await settle(world):view.queue_free();await frame();finish();return
    var owner:Dictionary=world.timeline.item_appearance_owners[ITEM]
    var actor:Dictionary=world.timeline.state.actors[owner.creator_uuid]
    world.camera_focus=Vector3(actor.last_visual_position[0],.5,actor.last_visual_position[1]);world.initial_focus=true
    world.camera.size=4;world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
    await frame();await frame()
    var native=world.component_renderer.native_spells
    var id:String="item:"+ITEM+":appearance"
    check(native.handles.has(id),"Actual created item has a production native instance")
    if native.handles.has(id):
        var handle:Dictionary=native.handles[id]
        var diagnostic:Dictionary=native.diagnostics.get(id,{})
        check(diagnostic.get("status")=="rendered","Real item reaches native draw: "+str(diagnostic))
        check(diagnostic.get("input_bindings",{}).get("supplied",[]).has("created_item_binding"),"Exact item packet reaches the delivered setter")
        var source:Node3D=handle.inner.components.appearance
        check(source.capture_observation().admitted,"Delivered appearance admits actual holdings and lifetime")
        check(source.visual.global_transform.is_equal_approx(handle.created_item_input.hand_transform),"Native grip follows actual current authored hand frame")
        check(handle.seekable and handle.emitters.is_empty(),"Qualified material-only source has no simulation catch-up")
        for quarter in 4:
            world.request_view(quarter)
            var deadline:int=Time.get_ticks_msec()+45000
            while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
            check(not world.rotation_pending() and world.quarter==quarter,"Native item follows prepared camera quarter "+str(quarter))
            if not await settle(world):break
            await frame();await frame()
            check(native.handles.has(id) and native.handles[id].occurrence==handle.occurrence,"Camera changes keep the exact private item occurrence")
            check(source.visual.global_transform.is_equal_approx(handle.created_item_input.hand_transform),"Rotated native item uses current body basis and authored hand")
        for age in [600.0,.2,8.5]:
            Effects.sample(handle,age)
            check(is_equal_approx(float(source.fire_materials[0].get_shader_parameter("fire_owner_seconds")),age),"Absolute material clock receives exact age/rewind "+str(age))
            check(is_equal_approx(handle.age,age),"Absolute native item source samples requested age "+str(age))
        evidence={"item":ITEM,"native":diagnostic,"source":source.capture_observation(),"construction_ms":handle.construction_phases}
        world.set_process(false);await frame()
        var shown:Image=view.get_texture().get_image()
        handle.root.hide();await frame()
        var hidden:Image=view.get_texture().get_image()
        var a:PackedByteArray=shown.get_data();var b:PackedByteArray=hidden.get_data();var pixels:int=0
        for i in range(0,a.size(),4):
            if absi(a[i]-b[i])>3 or absi(a[i+1]-b[i+1])>3 or absi(a[i+2]-b[i+2])>3:pixels+=1
        evidence.changed_pixels=pixels
        check(pixels>0,"Actual created item contributes framebuffer pixels")
        DirAccess.make_dir_recursive_absolute("res://.captures/native-created-items")
        shown.save_png("res://.captures/native-created-items/flame-blade.png")
        world.set_process(true)
    check(world.presentation_errors.is_empty(),"No native renderer error")
    check(world.try_reset_hidden_playback(Recording.restore(index,0)),"Reverse seek/loop installs independent initial state")
    await settle(world)
    check(world.timeline.item_appearance_owners.is_empty(),"Before creation no future item or lifetime is displayed")
    view.queue_free();await frame();await frame();finish()
func finish()->void:
    var result={"checks":checks,"failures":failures,"evidence":evidence}
    FileAccess.open("res://.runtime/native-item-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
