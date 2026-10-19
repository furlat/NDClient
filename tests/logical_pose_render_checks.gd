extends SceneTree
## Real completed petrification uses the current production body and source.
const Recording=preload("res://studio/recording.gd")
const Play=preload("res://play.gd")
const Inputs=preload("res://presentation/native_inputs.gd")
const Effects=preload("res://presentation/effect_package.gd")
var checks:int=0
var failures:Array=[]
var evidence:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("LOGICAL_POSE_RENDER_FAIL "+label)
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
    check(false,"Current native petrification prepares: "+str({"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics}))
    return false
func run()->void:
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var index:Dictionary=Recording.read("res://tests/fixtures/schema16/petrification/amber")
    check(index.ok,"Real completed-petrification journal opens")
    if not index.ok:finish();return
    var spans:Array=index.rows.filter(func(row):return row.kind=="condition" and row.owner.condition.behavior_id=="condition.spell.flesh_to_stone.petrified")
    check(spans.size()==1,"Real journal has one completed and cured petrification")
    if spans.size()!=1:finish();return
    var span:Dictionary=spans[0];var actor:String=span.owner.actor_uuid
    var at:float=lerpf(span.start_ms,span.end_ms,.65)
    var view:SubViewport=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    world.component_renderer.audio.set_enabled(false)
    view.add_child(world);world.install_playback(Recording.restore(index,at))
    if not await settle(world):view.queue_free();await frame();finish();return
    var capture:Dictionary=world.timeline.condition_owners[span.owner.id].logical_pose
    world.camera_focus=Play.Placement.contact(world.visual_actors[actor].row);world.initial_focus=true
    world.camera.size=3;world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
    var native=world.component_renderer.native_spells
    var ids:Array=native.handles.keys().filter(func(id):return native.handles[id].get("component",{}).get("condition_uuid")==span.owner.id and native.handles[id].occurrence.parameters.get("actor_operation",{}).get("capture_pose",false))
    if ids.is_empty():print("POSE_RENDER_DIAGNOSTIC "+JSON.stringify({"owners":world.timeline.condition_owners,"samples":world.timeline.component_samples(world.catalog_cache).map(func(v):return {"id":v.id,"kind":v.kind,"status":v.get("status")}),"package":Effects.conditions("condition.spell.flesh_to_stone.petrified").size(),"ready":world.component_renderer.ready,"native_diagnostics":native.diagnostics}))
    check(ids.size()==1,"One actual condition binds the captured-body source: "+str(native.handles.values().map(func(h):return {"id":h.component.id,"condition_uuid":h.component.get("condition_uuid"),"clip":h.clip.get("id"),"operation":h.occurrence.parameters.get("actor_operation",{})})))
    if ids.size()==1:
        var handle:Dictionary=native.handles[ids[0]]
        for quarter in 4:
            world.request_view(quarter)
            var deadline:int=Time.get_ticks_msec()+45000
            while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
            if not await settle(world):break
            await frame();await frame()
            check(world.quarter==quarter and not world.rotation_pending(),"Captured body uses prepared camera quarter "+str(quarter))
            var playback:Node=world.playbacks[actor]
            check(playback.clip==capture.clip and mini(int(playback.sample_seconds*world.rigs[capture.rig].clips[capture.clip].fps),int(world.rigs[capture.rig].clips[capture.clip].frames)-1)==capture.frame,"Camera rotation preserves captured logical clip/frame")
            check(world.visual_actors[actor].row.facing==capture.world_facing,"Camera rotation preserves logical world-facing")
            check(handle.occurrence.body_treatment.logical_capture and not handle.occurrence.body_treatment.materials.is_empty(),"Actual pose lease and current recipient layers remain bound")
        world.set_process(false);await frame()
        var shown:Image=view.get_texture().get_image()
        Effects.set_input(handle,"actor_layers",{"actor_uuid":"","layers":[]});await frame()
        var untreated:Image=view.get_texture().get_image()
        var original_shaders:Dictionary={}
        for entry in world.visual_actors[actor].entries:original_shaders[entry.actor_layer.slot]=entry.material.shader
        var a:PackedByteArray=shown.get_data();var b:PackedByteArray=untreated.get_data();var pixels:int=0
        for i in range(0,a.size(),4):
            if absi(a[i]-b[i])>3 or absi(a[i+1]-b[i+1])>3 or absi(a[i+2]-b[i+2])>3:pixels+=1
        check(pixels>0,"Actual delivered petrified body treatment contributes framebuffer pixels")
        evidence={"changed_pixels":pixels,"capture":capture,"construction_ms":handle.construction_phases,"native":native.diagnostics.get(ids[0],{})}
        DirAccess.make_dir_recursive_absolute("res://.captures/logical-pose")
        shown.save_png("res://.captures/logical-pose/petrified.png");untreated.save_png("res://.captures/logical-pose/untreated.png")
        var lease:RefCounted=handle.pose_provider_binding
        world.set_process(true)
        check(world.try_reset_hidden_playback(Recording.restore(index,span.end_ms+500)),"Actual cure restores a fresh current prefix")
        if await settle(world):
            check(not world.timeline.actor_samples().get(actor,{}).get("captured",false),"Cured actor has no held capture")
            check(lease.owners.is_empty(),"Retiring old source releases its exact logical-pose lease")
            check(world.visual_actors[actor].entries.all(func(entry):return entry.material.shader==original_shaders.get(entry.actor_layer.slot)),"Current actor shader restores after actual cure")
        check(world.try_reset_hidden_playback(Recording.restore(index,at)),"Reverse seek rebuilds the original admitted pose")
        if await settle(world):check(world.timeline.condition_owners[span.owner.id].logical_pose==capture,"Reverse seek keeps original application capture")
    check(world.presentation_errors.is_empty(),"Current native playback reports no presentation errors")
    view.queue_free();await frame();await frame();finish()
func finish()->void:
    var result={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual idle-target petrification/cure, current native body material pixels, four camera views, logical frame and private lease restoration. No fabricated moving trap, art approval or final-performance claim."}
    FileAccess.open("res://.runtime/logical-pose-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
