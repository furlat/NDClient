extends SceneTree
## Production renderer, original packets, explicit test-only coating Resources.
const Recording=preload("res://studio/recording.gd")
const Support=preload("res://tests/weapon_effect_support.gd")
const Play=preload("res://play.gd")
const Effects=preload("res://presentation/effect_package.gd")
const ITEM="d581a8b1-8878-4765-ae96-0d882c6310fc"
var checks:int=0
var failures:Array=[]
var evidence:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("WEAPON_EFFECT_RENDER_FAIL "+label)
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
    check(false,"Attached uses prepare in production: "+str({"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics}))
    return false
func run()->void:
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var index:Dictionary=Recording.read("res://tests/fixtures/schema16/created-flame-blade/amber",{},{},Support.cache())
    check(index.ok,"Original item journal indexes through test-only typed authoring")
    if not index.ok:finish();return
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("intrinsic_item_effect",false))
    check(rows.size()==2,"Two actual attached-use tracks are available")
    if rows.size()!=2:finish();return
    var view=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    world.component_renderer.audio.set_enabled(false)
    view.add_child(world);world.install_playback(Recording.restore(index,index.presentation_end_ms))
    if not await settle(world):view.queue_free();await frame();finish();return
    var actor:String=rows[0].component.actor_uuid
    world.camera_focus=Play.Placement.contact(world.visual_actors[actor].row);world.initial_focus=true
    world.camera.size=3;world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
    await frame();await frame()
    var native=world.component_renderer.native_spells
    var handles:Array=[]
    for row in rows:
        check(native.handles.has(row.component.id),"Each typed attached use has an independent native occurrence")
        if not native.handles.has(row.component.id):continue
        var handle:Dictionary=native.handles[row.component.id];handles.append(handle)
        var diagnostic:Dictionary=native.diagnostics.get(row.component.id,{})
        check(diagnostic.get("status")=="rendered" and diagnostic.get("input_bindings",{}).get("unavailable",{}).is_empty(),"Declared receiving inputs reach the actual delivered source: "+str(diagnostic))
        check(handle.occurrence.receiving.admitted_geometry and handle.occurrence.receiving.current_surface.item_uuid==ITEM,"Delivered coating admits the exact modular weapon optical surface")
        check(native.witnesses.any(func(witness):return witness.id==row.component.id+":weapon_surface" and witness.status=="rendered"),"Studio's receiving-surface track gets evidence from the actual bound native draw")
        check(handle.occurrence.receiving.current_surface.points.all(func(point):return point.slot=="weapon"),"Coating never receives full-character or other equipment pixels")
        check(handle.occurrence.receiving.weapon_binding.binding_origin=="intrinsic_authored_item" and not handle.occurrence.receiving.weapon_binding.has("effect_uuid"),"Intrinsic staging does not counterfeit a server condition UUID")
    check(handles.size()==2 and handles[0].occurrence!=handles[1].occurrence,"Effects share immutable art but own distinct source instances")
    check(world.visual_actors[actor].entries.any(func(entry):return entry.actor_layer.get("item_uuid")==ITEM and entry.actor_layer.category=="Melee4" and entry.node.is_visible_in_tree()),"The actual modular sprite sword stays rendered beneath the effects")
    if handles.size()==2:
        world.set_process(false);await frame()
        var decorated:Image=view.get_texture().get_image()
        for handle in handles:Effects.hide(handle)
        await frame()
        var plain:Image=view.get_texture().get_image();var a:PackedByteArray=decorated.get_data();var b:PackedByteArray=plain.get_data();var changed:int=0
        for i in range(0,a.size(),4):
            if absi(a[i]-b[i])>3 or absi(a[i+1]-b[i+1])>3 or absi(a[i+2]-b[i+2])>3:changed+=1
        check(changed>0,"Delivered attached effects contribute visible framebuffer pixels")
        evidence={"changed_pixels":changed,"construction_ms":handles.map(func(handle):return handle.construction_phases),"items":[ITEM],"source":"res://tests/fixtures/wielded_weapon_overlay.tres","production_assignment":false}
        DirAccess.make_dir_recursive_absolute("res://.captures/weapon-effects")
        decorated.save_png("res://.captures/weapon-effects/decorated.png");plain.save_png("res://.captures/weapon-effects/sprite.png")
        world.set_process(true)
        check(world.try_reset_hidden_playback(Recording.restore(index,rows[0].start_ms-.001)),"Seek before actual equipment admission")
        if await settle(world):check(world.timeline.item_effect_owners.is_empty(),"No future attached owner leaks before its ordered admission")
        check(world.try_reset_hidden_playback(Recording.restore(index,index.presentation_end_ms)),"Loop back through actual item admission")
        if await settle(world):check(world.timeline.item_effect_owners.size()==2,"Loop restores both independent authored uses")
    check(world.presentation_errors.is_empty(),"No production presentation error")
    view.queue_free();await frame();await frame();finish()
func finish()->void:
    var result={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual modular weapon sprite plus two test-authored delivered coating occurrences, shared renderer, framebuffer output, seek/loop. No new production art, full-character socket or server event is claimed."}
    FileAccess.open("res://.runtime/weapon-effect-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
