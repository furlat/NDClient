extends SceneTree
const Recording=preload("res://studio/recording.gd")
const Support=preload("res://tests/weapon_effect_support.gd")
const Play=preload("res://play.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const NativeSupport=preload("res://tests/dynamic_weapon_support.gd")
var checks:int=0
var failures:Array=[]
var evidence:Dictionary={}
var production_case:String=""
var expected_contacts:int=1
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("WEAPON_IMPACT_RENDER_FAIL "+label)
func frame()->void:
    await process_frame
    await RenderingServer.frame_post_draw
func settle(world:Node,ids:Array=[])->bool:
    var ready:bool=await NativeSupport.settle(self,world,ids)
    check(ready,"Native weapon contact prepares and draws: "+str(ids if ready else {"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics}))
    return ready
func run()->void:
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--production-case="):production_case=arg.trim_prefix("--production-case=")
        if arg.begins_with("--expected-contacts="):expected_contacts=int(arg.trim_prefix("--expected-contacts="))
    var path:String="res://tests/fixtures/schema16/weapon-impact/amber" if production_case.is_empty() else Fixtures.journal(production_case)
    var cache:Dictionary=Support.cache(true) if production_case.is_empty() else {}
    var index:Dictionary=Recording.read(path,{},{},cache)
    check(index.ok,"Original weapon-hit journal indexes with "+("test-only" if production_case.is_empty() else "production")+" impact authoring")
    if not index.ok:finish();return
    var impacts:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_weapon_impact",false))
    check(impacts.size()==expected_contacts,"Expected finite impacts on actual accepted attacks")
    if impacts.size()!=expected_contacts or impacts.is_empty():finish();return
    var row:Dictionary=impacts[0];var component:Dictionary=row.component
    var at:float=lerpf(row.start_ms,row.end_ms,.55)
    var view=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    world.component_renderer.audio.set_enabled(false)
    view.add_child(world);world.install_playback(Recording.restore(index,at))
    var intrinsic:Array=world.timeline.component_samples(index.cache).filter(func(value):return value.get("intrinsic_item_effect",false))
    var active_ids:Array=[component.id]+intrinsic.map(func(value):return value.id)
    if not await settle(world,active_ids):view.queue_free();await frame();finish();return
    var admitted:Array=world.timeline.component_samples(index.cache).filter(func(value):return value.id==component.id)
    check(admitted.size()==1 and admitted[0].impact.status=="available","Killing-hit contact remains captured after recipient retirement")
    world.camera_focus=admitted[0].impact.world_anchor;world.initial_focus=true
    world.camera.size=3;world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
    await frame();await frame()
    var native=world.component_renderer.native_spells
    for attached in intrinsic:
        check(native.diagnostics.get(attached.id,{}).get("status")=="rendered","Corrected intrinsic receiver draws alongside the finite contact")
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
        evidence={"changed_pixels":changed,"construction_ms":handle.construction_phases,"event":component.weapon_impact,"contact_ms":row.start_ms,"end_ms":row.end_ms,"source":row.source,"production_assignment":not production_case.is_empty()}
        var capture:String="res://.captures/weapon-impact" if production_case.is_empty() else "res://.captures/weapon-runtime-delivery/"+production_case
        DirAccess.make_dir_recursive_absolute(capture)
        shown.save_png(capture+"/impact.png");plain.save_png(capture+"/plain.png")
        world.set_process(true)
        check(world.try_reset_hidden_playback(Recording.restore(index,row.start_ms-.001)),"Seek before actual contact")
        if await settle(world):check(world.timeline.component_samples(index.cache).all(func(value):return not value.get("native_weapon_impact",false)),"Resource preparation does not publish a future hit effect")
        check(world.try_reset_hidden_playback(Recording.restore(index,at)),"Loop back through the same actual contact")
        if await settle(world,active_ids):check(native.diagnostics.get(component.id,{}).get("status")=="rendered","Loop reproduces the finite impact")
        check(world.try_reset_hidden_playback(Recording.restore(index,row.end_ms+.001)),"Seek past the finite source tail")
        if await settle(world):check(world.timeline.component_samples(index.cache).all(func(value):return not value.get("native_weapon_impact",false)),"Impact retires after its finite span")
    check(world.presentation_errors.is_empty(),"No shared production renderer error")
    view.queue_free();await frame();await frame();finish()
func finish()->void:
    var result={"checks":checks,"failures":failures,"evidence":evidence,"production_case":production_case,"scope":"Actual recorded hit in shared Play renderer, real sprite, native contact pixels, Studio witness and finite seek/loop/retirement. Production assignment and visual acceptance remain distinct; no inferred damage or final performance claim."}
    var report:String="res://.runtime/weapon-impact-render-checks.json" if production_case.is_empty() else "res://.runtime/weapon-runtime-delivery-"+production_case+"-render-checks.json"
    FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
