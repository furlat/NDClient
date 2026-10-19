extends SceneTree
const Recording=preload("res://studio/recording.gd")
const Support=preload("res://tests/weapon_effect_support.gd")
const Play=preload("res://play.gd")
const Effects=preload("res://presentation/effect_package.gd")
var checks:int=0
var failures:Array=[]
var evidence:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("WEAPON_IMPACT_RENDER_FAIL "+label)
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
    check(false,"Native weapon contact prepares: "+str({"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics}))
    return false
func run()->void:
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var index:Dictionary=Recording.read("res://tests/fixtures/schema16/weapon-impact/amber",{},{},Support.cache(true))
    check(index.ok,"Original weapon-hit journal indexes with test-only impact authoring")
    if not index.ok:finish();return
    var impacts:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_weapon_impact",false))
    check(impacts.size()==1,"One authored finite impact on the real attack")
    if impacts.size()!=1:finish();return
    var row:Dictionary=impacts[0];var component:Dictionary=row.component
    var at:float=lerpf(row.start_ms,row.end_ms,.55)
    var view=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    world.component_renderer.audio.set_enabled(false)
    view.add_child(world);world.install_playback(Recording.restore(index,at))
    if not await settle(world):view.queue_free();await frame();finish();return
    var admitted:Array=world.timeline.component_samples(index.cache).filter(func(value):return value.id==component.id)
    check(admitted.size()==1 and admitted[0].impact.status=="available","Killing-hit contact remains captured after recipient retirement")
    world.camera_focus=admitted[0].impact.world_anchor;world.initial_focus=true
    world.camera.size=3;world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
    await frame();await frame()
    var native=world.component_renderer.native_spells
    check(native.handles.has(component.id),"The event-owned weapon impact has a production native occurrence")
    if native.handles.has(component.id):
        var handle:Dictionary=native.handles[component.id]
        check(native.diagnostics.get(component.id,{}).get("status")=="rendered","Actual native source reaches draw: "+str(native.diagnostics.get(component.id,{})))
        check(world.component_renderer.pending_evidence.any(func(value):return value.trace_track_id==component.id and value.get("visible",false)),"Studio receives evidence from the actual finite draw")
        check(world.visual_actors[component.actor_uuid].entries.any(func(entry):return entry.actor_layer.get("item_uuid")==component.weapon_impact.source_item_uuid and entry.actor_layer.category=="Melee2" and entry.node.is_visible_in_tree()),"Actual source sword sheet remains rendered")
        world.set_process(false);await frame()
        var shown:Image=view.get_texture().get_image();Effects.hide(handle);await frame()
        var plain:Image=view.get_texture().get_image();var a:PackedByteArray=shown.get_data();var b:PackedByteArray=plain.get_data();var changed:int=0
        for i in range(0,a.size(),4):
            if absi(a[i]-b[i])>3 or absi(a[i+1]-b[i+1])>3 or absi(a[i+2]-b[i+2])>3:changed+=1
        check(changed>0,"Actual delivered weapon-impact source contributes framebuffer pixels")
        evidence={"changed_pixels":changed,"construction_ms":handle.construction_phases,"event":component.weapon_impact,"contact_ms":row.start_ms,"end_ms":row.end_ms,"source":row.source,"production_assignment":false}
        DirAccess.make_dir_recursive_absolute("res://.captures/weapon-impact")
        shown.save_png("res://.captures/weapon-impact/impact.png");plain.save_png("res://.captures/weapon-impact/plain.png")
        world.set_process(true)
        check(world.try_reset_hidden_playback(Recording.restore(index,row.start_ms-.001)),"Seek before actual contact")
        if await settle(world):check(world.timeline.component_samples(index.cache).all(func(value):return not value.get("native_weapon_impact",false)),"Resource preparation does not publish a future hit effect")
        check(world.try_reset_hidden_playback(Recording.restore(index,at)),"Loop back through the same actual contact")
        if await settle(world):check(native.diagnostics.get(component.id,{}).get("status")=="rendered","Loop reproduces the finite impact")
        check(world.try_reset_hidden_playback(Recording.restore(index,row.end_ms+.001)),"Seek past the finite source tail")
        if await settle(world):check(world.timeline.component_samples(index.cache).all(func(value):return not value.get("native_weapon_impact",false)),"Impact retires after its finite span")
    check(world.presentation_errors.is_empty(),"No shared production renderer error")
    view.queue_free();await frame();await frame();finish()
func finish()->void:
    var result={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual recorded hit in the shared native renderer, real sprite body, test-only delivered impact pixels, Studio draw witness and finite seek/loop/retirement. No fire damage, new production art or final gameplay performance claim."}
    FileAccess.open("res://.runtime/weapon-impact-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
